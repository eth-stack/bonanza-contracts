// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

contract PredictionGame is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public adminAddress; // address of the admin
    address public operatorAddress; // address of the operator
    address public treasuryAddress; // address of treasury

    IERC20 public immutable currency; // Prediction token

    uint256 public minBetAmount; // in wei
    uint256 public treasuryRate; // multiple with 10000. ex 95% = 0.95 * 10000 = 9500
    uint256 public treasuryAmount;

    uint256 public resultGap; // number of blocks for calculate round result
    uint256 public genesisBlock;
    uint256 public intervalBlocks;

    uint256 public constant MAX_TREASURY_FEE = 1000; // 10%

    // epoch => user => Bet
    mapping(uint256 => mapping(address => Bet)) public ledger;
    // epoch => Bet
    mapping(uint256 => Round) public rounds;
    // epoch => user => epoch[]
    mapping(address => uint256[]) public userRounds;

    struct Bet {
        bool head;
        uint256 amount;
        bool claimed;
    }

    struct Round {
        uint256 epoch;
        uint256 totalAmount;
        uint256 headAmount;
        uint256 endAmount;
        bool finalized; // Already calculated
        bool valid; // Round valid.
        uint256 resultBlock;
        uint8 lastDigit;
        bool head; // determine whether head win
        uint256 rewardBaseCalAmount;
        uint256 rewardAmount;
    }

    event BetHead(uint256 epoch, address user, uint256 amount);
    event BetEnd(uint256 epoch, address user, uint256 amount);
    event BetClaimed(uint256 epoch, address user, uint256 amount);
    event RewardsCalculated(
        uint256 epoch,
        uint256 rewardBaseCalAmount,
        uint256 rewardAmount,
        uint256 treasuryAmt,
        uint256 resultBlock,
        uint8 lastDigit
    );
    event RoundInvalid(uint256 round, uint256 resultBlock);

    event TokenRecovery(address token, uint256 amount);
    event NewAdminAddress(address admin);
    event NewTreasuryAddress(address treasuryAddress);
    event NewTreasuryRate(uint256 round, uint256 treasuryFee);

    modifier onlyAdmin() {
        require(msg.sender == adminAddress, "Not admin");
        _;
    }

    modifier onlyOperator() {
        require(msg.sender == operatorAddress, "Not operator");
        _;
    }

    modifier notContract() {
        require(!_isContract(msg.sender), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
    }

    constructor(
        address _adminAddress, // address of the admin
        address _operatorAddress, // address of the operator
        address _currency,
        address _treasuryAddress,
        uint256 _minBetAmount, // in wei
        uint256 _treasuryRate, // multiple with 10000. ex 95% = 0.95 * 10000 = 9500
        uint256 _resultGap, // number of blocks for calculate round result
        uint256 _genesisBlock,
        uint256 _intervalBlocks
    ) {
        adminAddress = _adminAddress;
        operatorAddress = _operatorAddress;
        treasuryAddress = _treasuryAddress;

        currency = IERC20(_currency);
        minBetAmount = _minBetAmount;
        treasuryRate = _treasuryRate;

        resultGap = _resultGap;
        genesisBlock = _genesisBlock;
        intervalBlocks = _intervalBlocks;
    }

    function betHead(uint256 amount, uint256 epoch)
        external
        whenNotPaused
        nonReentrant
        notContract
    {
        require(epoch == _getEpoch(block.number), "Bet not active for this epoch");
        require(amount >= minBetAmount, "Bet amount invalid");
        require(ledger[epoch][msg.sender].amount == 0, "Can only bet once per round");

        currency.safeTransferFrom(msg.sender, address(this), amount);

        // Update round data
        Round storage round = rounds[epoch];
        round.totalAmount = round.totalAmount + amount;
        round.headAmount = round.headAmount + amount;

        // Update user data
        Bet storage bet = ledger[epoch][msg.sender];
        bet.head = true;
        bet.amount = amount;
        userRounds[msg.sender].push(epoch);

        emit BetHead(epoch, msg.sender, amount);
    }

    function betEnd(uint256 amount, uint256 epoch)
        external
        whenNotPaused
        nonReentrant
        notContract
    {
        require(epoch == _getEpoch(block.number), "Bet not active for this epoch");
        require(amount >= minBetAmount, "Bet amount invalid");
        require(ledger[epoch][msg.sender].amount == 0, "Can only bet once per round");

        currency.safeTransferFrom(msg.sender, address(this), amount);

        // Update round data
        Round storage round = rounds[epoch];
        round.totalAmount = round.totalAmount + amount;
        round.endAmount = round.endAmount + amount;

        // Update user data
        Bet storage bet = ledger[epoch][msg.sender];
        bet.head = false;
        bet.amount = amount;
        userRounds[msg.sender].push(epoch);

        emit BetEnd(epoch, msg.sender, amount);
    }

    function claimReward(uint256[] calldata epochs) external whenNotPaused nonReentrant {
        uint256 reward;

        for (uint256 i = 0; i < epochs.length; i++) {
            require(rounds[epochs[i]].finalized, "Round not finalized");

            uint256 addedReward = 0;

            // Round valid, rewards
            if (rounds[epochs[i]].valid) {
                require(claimable(epochs[i], msg.sender), "Not eligible for claim");

                Round memory round = rounds[epochs[i]];

                addedReward =
                    (ledger[epochs[i]][msg.sender].amount * round.rewardAmount) /
                    round.rewardBaseCalAmount;

                // Round invalid, refund bet amount
            } else {
                require(refundable(epochs[i], msg.sender), "Not eligible for refund");
                addedReward = ledger[epochs[i]][msg.sender].amount;
            }

            ledger[epochs[i]][msg.sender].claimed = true;
            reward += addedReward;

            emit BetClaimed(epochs[i], msg.sender, addedReward);
        }

        if (reward > 0) {
            currency.safeTransfer(msg.sender, reward);
        }
    }

    /**
     * @notice Close current round
     */
    function executeRound(uint256 epoch) external whenNotPaused onlyOperator nonReentrant {
        require(!rounds[epoch].finalized, "Round finalized");
        uint256 resultBlock = getResultBlock(epoch);
        require(block.number >= resultBlock, "Should call after result block");

        Round storage round = rounds[epoch];
        round.epoch = epoch;
        round.resultBlock = resultBlock;
        round.finalized = true;

        bytes32 _hash = blockhash(round.resultBlock);
        // Execute round too late. Hash is not available => Round invalid
        if (_hash == 0) {
            round.valid = false;

            emit RoundInvalid(epoch, resultBlock);
        } else {
            // Round valid
            _endRound(round, _hash);
        }
    }

    function getResultBlock(uint256 round) public view returns (uint256) {
        return _getEndBlock(round) + resultGap;
    }

    function _endRound(Round storage round, bytes32 _hash) internal {
        round.lastDigit = uint8(_hash[31] & 0x0f);
        round.head = round.lastDigit <= 7;
        round.valid = true;

        uint256 rewardBaseCalAmount;
        uint256 rewardAmount;
        uint256 treasuryAmt;

        // Head wins
        if (round.head) {
            rewardBaseCalAmount = round.headAmount;

            //no winner , house win
            if (rewardBaseCalAmount == 0) {
                treasuryAmt = round.totalAmount;
            } else {
                treasuryAmt = (round.totalAmount * treasuryRate) / 10000;
            }

            rewardAmount = round.totalAmount - treasuryAmt;
            // End wins
        } else {
            rewardBaseCalAmount = round.endAmount;

            //no winner , house win
            if (rewardBaseCalAmount == 0) {
                treasuryAmt = round.totalAmount;
            } else {
                treasuryAmt = (round.totalAmount * treasuryRate) / 10000;
            }

            rewardAmount = round.totalAmount - treasuryAmt;
        }

        round.rewardBaseCalAmount = rewardBaseCalAmount;
        round.rewardAmount = rewardAmount;

        treasuryAmount += treasuryAmt;
        if (treasuryAmt > 0) {
            currency.safeTransfer(treasuryAddress, treasuryAmt);
        }

        emit RewardsCalculated(
            round.epoch,
            rewardBaseCalAmount,
            rewardAmount,
            treasuryAmt,
            round.resultBlock,
            round.lastDigit
        );
    }

    function _getEpoch(uint256 number) internal view returns (uint256) {
        return (number - genesisBlock) / intervalBlocks + 1;
    }

    function _getEndBlock(uint256 round) internal view returns (uint256) {
        return round * intervalBlocks + genesisBlock - 1;
    }

    function currentEpoch() external view returns (uint256) {
        require(block.number >= genesisBlock, "Round not started");
        return _getEpoch(block.number);
    }

    /**
     * @notice It allows the owner to recover tokens sent to the contract by mistake
     * @param _token: token address
     * @param _amount: token amount
     * @dev Callable by owner
     */
    function recoverToken(address _token, uint256 _amount) external onlyOwner {
        require(_token != address(currency), "Cannot be prediction token address");
        IERC20(_token).safeTransfer(address(msg.sender), _amount);

        emit TokenRecovery(_token, _amount);
    }

    /**
     * @notice Set admin address
     * @dev Callable by owner
     */
    function setAdmin(address _adminAddress) external onlyOwner {
        require(_adminAddress != address(0), "Cannot be zero address");
        adminAddress = _adminAddress;

        emit NewAdminAddress(_adminAddress);
    }

    /**
     * @notice Set treasury address
     * @dev Callable by owner
     */
    function setTreasuryAddress(address _treasuryAddress) external onlyOwner {
        require(_treasuryAddress != address(0), "Cannot be zero address");
        _treasuryAddress = _treasuryAddress;

        emit NewTreasuryAddress(_treasuryAddress);
    }

    /**
     * @notice Set treasury fee
     * @dev Callable by admin
     */
    function setTreasuryFee(uint256 _treasuryFee) external whenPaused onlyAdmin {
        require(_treasuryFee <= MAX_TREASURY_FEE, "Treasury fee too high");
        treasuryRate = _treasuryFee;

        emit NewTreasuryRate(_getEpoch(block.number), treasuryRate);
    }

    /**
     * @notice Returns round epochs and bet information for a user that has participated
     * @param user: user address
     * @param cursor: cursor
     * @param size: size
     */
    function getUserRounds(
        address user,
        uint256 cursor,
        uint256 size
    )
        external
        view
        returns (
            uint256[] memory,
            Bet[] memory,
            uint256
        )
    {
        uint256 length = size;

        if (length > userRounds[user].length - cursor) {
            length = userRounds[user].length - cursor;
        }

        uint256[] memory values = new uint256[](length);
        Bet[] memory bet = new Bet[](length);

        for (uint256 i = 0; i < length; i++) {
            values[i] = userRounds[user][cursor + i];
            bet[i] = ledger[values[i]][user];
        }

        return (values, bet, cursor + length);
    }

    /**
     * @notice Returns round epochs length
     * @param user: user address
     */
    function getUserRoundsLength(address user) external view returns (uint256) {
        return userRounds[user].length;
    }

    function claimable(uint256 epoch, address user) public view returns (bool) {
        Round memory round = rounds[epoch];
        Bet memory bet = ledger[epoch][user];
        return round.valid && bet.amount != 0 && !bet.claimed && bet.head == round.head;
    }

    /**
     * @notice Get the refundable stats of specific epoch and user account
     * @param epoch: epoch
     * @param user: user address
     */
    function refundable(uint256 epoch, address user) public view returns (bool) {
        Bet memory bet = ledger[epoch][user];
        Round memory round = rounds[epoch];

        return round.finalized && !round.valid && !bet.claimed && bet.amount != 0;
    }

    /**
     * @notice Returns true if `account` is a contract.
     * @param account: account address
     */
    function _isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}
