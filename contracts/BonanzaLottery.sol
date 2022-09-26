// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/ILottery.sol";
import "./interfaces/IRandom.sol";
import "./interfaces/IReferral.sol";
import "./interfaces/ICoupon.sol";
import "./libs/ArrayLib.sol";

contract BonanzaLottery is ILottery, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    uint256 internal constant MIN_LENGTH_LOTTERY = 6 minutes - 5 minutes; // 4 hours
    uint256 internal constant MAX_LENGTH_LOTTERY = 4 days + 5 minutes; // 4 days
    uint256 internal constant MIN_DISCOUNT_DIVISOR = 300;
    uint256 internal constant MIN_JP_PRIZE = 1200 ether;
    uint256 internal constant MAX_PRIZE_1ST = 500 ether;
    uint256 internal constant MAX_PRIZE_2ND = 15 ether;
    uint256 internal constant MAX_PRIZE_3RD = 1.5 ether;

    uint256 internal constant AFFILIATE_RATE = 500;
    uint256 internal constant TOTAL_PRIZE_RATE = 4500;
    uint256 internal constant ESCROW_RETURN_RATE = 2000;
    uint256 internal constant RATE_PRIZE_1ST = 287;
    uint256 internal constant RATE_PRIZE_2ND = 409;
    uint256 internal constant RATE_PRIZE_3RD = 673;

    uint256 private currentLotteryId;
    uint256 public currentTicketId;

    uint256 public maxNumberTicketsPerBuyOrClaim = 100;
    uint256 public maxPriceTicket = 50 ether;
    uint256 public minPriceTicket = 0.005 ether;

    IRandom public randomGenerator;
    IERC20 public currency;
    IReferral public referralProgram;
    ICoupon public couponCenter;

    address public injectorAddress;
    address public operatorAddress;
    address public treasuryAddress;
    uint256 public stoppedAt;

    enum Status {
        Pending,
        Open,
        Close,
        Claimable
    }

    struct Ticket {
        bytes6 number;
        address owner;
    }

    struct Lottery {
        uint256 startTime;
        uint256 endTime;
        uint256 priceTicket;
        uint256 discountDivisor;
        uint256 firstTicketId;
        uint256 firstTicketIdNextLottery;
        uint256 amountUsed;
        uint256 totalReferral;
        uint256 amountTotal;
        uint256 jpTreasury;
        uint256 affiliateTreasury;
        uint256 escrowCredit;
        uint256 affiliatePrize;
        uint256[4] prizeAmounts;
        uint256[4] ticketsWin;
        bytes finalNumber;
        Status status;
    }

    mapping(uint256 => mapping(uint256 => address)) public _ticketOwner;
    mapping(uint256 => Lottery) private lotteries;
    mapping(uint256 => Ticket) private tickets;

    // Keep track of user ticket ids for a given lotteryId
    mapping(address => mapping(uint256 => uint256[])) private userTicketIdsPerLotteryId;

    modifier onlyOperator() {
        require(msg.sender == operatorAddress, "Not operator");
        _;
    }

    modifier onlyInjector() {
        require((msg.sender == injectorAddress), "Not injector");
        _;
    }

    modifier notContract() {
        require(!_isContract(msg.sender), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
    }

    event AdminTokenRecovery(address token, uint256 amount);
    event LotteryClose(uint256 indexed lotteryId, uint256 firstTicketIdNextLottery);
    event LotteryInjection(uint256 indexed lotteryId, uint256 injectedAmount);
    event LotteryOpen(
        uint256 indexed lotteryId,
        uint256 startTime,
        uint256 endTime,
        uint256 priceTicket,
        uint256 firstTicketId
    );
    event LotteryNumberDrawn(uint256 indexed lotteryId, bytes finalNumber);
    event DebtPaid(uint256 indexed lotteryId, uint256 amount);
    event NewRandomGenerator(address indexed randomGenerator);
    event TicketsPurchase(
        address indexed buyer,
        uint256 indexed lotteryId,
        uint256 numberTickets,
        uint256 couponId
    );
    event TicketsClaim(
        address indexed claimer,
        uint256 amount,
        uint256 indexed lotteryId,
        uint256 numberTickets
    );
    event AffiliatePrizeClaim(
        address claimer,
        uint256 amount,
        uint256 lotteryId,
        uint256 ticketId
    );
    event WithdrawnEscrowFunds(uint256 lotteryId, address receiver, uint256 amount);
    event LotteryStopped(
        uint256 lotteryId,
        address receiver,
        uint256 withdrawnAmount,
        uint256 refundAmount
    );

    constructor(
        address _currency,
        address _randomGeneratorAddress,
        address _coupon,
        address _referral
    ) {
        currency = IERC20(_currency);
        randomGenerator = IRandom(_randomGeneratorAddress);
        couponCenter = ICoupon(_coupon);
        referralProgram = IReferral(_referral);
    }

    function buyTickets(
        uint256 lotteryId,
        bytes6[] calldata ticketNumbers,
        bytes32 code,
        ICoupon.Coupon calldata coupon
    ) external notContract nonReentrant {
        require(ticketNumbers.length != 0, "No ticket specified");
        require(ticketNumbers.length <= maxNumberTicketsPerBuyOrClaim, "Too many tickets");

        require(lotteries[lotteryId].status == Status.Open, "Lottery is not open");
        require(block.timestamp < lotteries[lotteryId].endTime, "Lottery is over");

        if (code != bytes32(0) && !referralProgram.hasReferrer(msg.sender)) {
            referralProgram.addReferrer(msg.sender, code);
        }

        uint256 baseAmount = ticketNumbers.length * lotteries[lotteryId].priceTicket;
        uint256 amountToTransfer = lotteries[lotteryId].discountDivisor != 0
            ? _calculateTotalPriceForBulkTickets(
                lotteries[lotteryId].discountDivisor,
                lotteries[lotteryId].priceTicket,
                ticketNumbers.length
            )
            : baseAmount;

        (uint256 reduceAmount, uint256 totalReferral) = referralProgram.payReferral(
            msg.sender,
            address(currency),
            baseAmount
        );

        uint256 couponSale;
        if (coupon.id != 0) {
            couponSale = couponCenter.useCoupon(coupon, msg.sender, baseAmount);
        }
        currency.safeTransferFrom(
            msg.sender,
            address(this),
            amountToTransfer - reduceAmount - couponSale
        );

        // Increment amount
        lotteries[lotteryId].amountTotal += baseAmount;
        lotteries[lotteryId].totalReferral += totalReferral;
        lotteries[lotteryId].amountUsed +=
            (baseAmount - amountToTransfer) +
            totalReferral +
            couponSale;

        for (uint256 i = 0; i < ticketNumbers.length; i++) {
            bytes6 number = ticketNumbers[i];
            _validateTicket(number);

            userTicketIdsPerLotteryId[msg.sender][lotteryId].push(currentTicketId);

            tickets[currentTicketId] = Ticket({number: number, owner: msg.sender});

            // Increase lottery ticket number
            currentTicketId++;
        }

        emit TicketsPurchase(msg.sender, lotteryId, ticketNumbers.length, coupon.id);
    }

    /**
     * @notice Claim a set of winning tickets for a lottery
     * @param _lotteryId: lottery id
     * @param _ticketIds: array of ticket ids
     * @dev Callable by users only, not contract!
     */
    function claimTickets(uint256 _lotteryId, uint256[] calldata _ticketIds)
        external
        override
        notContract
        nonReentrant
    {
        require(_ticketIds.length != 0, "Length must be >0");
        require(_ticketIds.length <= maxNumberTicketsPerBuyOrClaim, "Too many tickets");
        require(lotteries[_lotteryId].status == Status.Claimable, "Lottery not claimable");

        uint256 rewardToTransfer;

        for (uint256 i = 0; i < _ticketIds.length; i++) {
            uint256 thisTicketId = _ticketIds[i];

            require(
                lotteries[_lotteryId].firstTicketIdNextLottery > thisTicketId,
                "TicketId too high"
            );
            require(lotteries[_lotteryId].firstTicketId <= thisTicketId, "TicketId too low");
            require(msg.sender == tickets[thisTicketId].owner, "Not the owner");

            // Update the lottery ticket owner to 0x address
            tickets[thisTicketId].owner = address(0);

            uint8 _matched = ArrayLib.countMatch(
                lotteries[_lotteryId].finalNumber,
                tickets[thisTicketId].number
            );

            // Check user is claiming the correct ticket
            if (_matched >= 3) {
                // Save the owner for affiliate program
                if (_matched == 6) {
                    _ticketOwner[_lotteryId][thisTicketId] = msg.sender;
                }

                // Increment the reward to transfer
                rewardToTransfer += lotteries[_lotteryId].prizeAmounts[6 - _matched];
            } else {
                // Check refunable
                if (stoppedAt != 0 && _lotteryId == stoppedAt) {
                    rewardToTransfer += lotteries[_lotteryId].priceTicket;
                } else {
                    revert("No prize for this ticket");
                }
            }
        }

        // Transfer money to msg.sender
        currency.safeTransfer(msg.sender, rewardToTransfer);

        emit TicketsClaim(msg.sender, rewardToTransfer, _lotteryId, _ticketIds.length);
    }

    function withdrawAffiliate(uint256 _lotteryId, uint256 _ticketId)
        external
        notContract
        nonReentrant
    {
        require(lotteries[_lotteryId].firstTicketIdNextLottery > _ticketId, "TicketId too high");
        require(lotteries[_lotteryId].firstTicketId <= _ticketId, "TicketId too low");
        require(lotteries[_lotteryId].affiliatePrize != 0, "No prize");

        address owner = _ticketOwner[_lotteryId][_ticketId];
        require(owner != address(0), "Claimed or not win jackpot");

        (address referrer, ) = referralProgram.getReferralAccount(owner);

        if (referrer != address(0)) {
            require(msg.sender == referrer, "Not referrer of this ticket owner");
        } else {
            _checkOwner();
        }

        _ticketOwner[_lotteryId][_ticketId] = address(0);
        currency.safeTransfer(msg.sender, lotteries[_lotteryId].affiliatePrize);

        emit AffiliatePrizeClaim(
            msg.sender,
            lotteries[_lotteryId].affiliatePrize,
            _lotteryId,
            _ticketId
        );
    }

    /**
     * @notice Close lottery
     * @param lotteryId: lottery id
     * @dev Callable by operator
     */
    function closeLottery(uint256 lotteryId) external override onlyOperator nonReentrant {
        require(lotteries[lotteryId].status == Status.Open, "Lottery not open");
        require(block.timestamp > lotteries[lotteryId].endTime, "Lottery not over");
        lotteries[lotteryId].firstTicketIdNextLottery = currentTicketId;

        randomGenerator.requestRandomNumbers();
        lotteries[lotteryId].status = Status.Close;

        emit LotteryClose(lotteryId, currentTicketId);
    }

    /**
     * @notice Draw the final number, calculate rewards, and make lottery claimable
     * @param _lotteryId: lottery id
     * @dev Callable by operator
     */
    function drawFinalNumberAndMakeLotteryClaimable(
        uint256 _lotteryId,
        uint256[4] calldata winCounts
    ) external override onlyOperator nonReentrant {
        require(lotteries[_lotteryId].status == Status.Close, "Lottery not close");
        require(_lotteryId == randomGenerator.viewLatestLotteryId(), "Numbers not drawn");

        Lottery storage lottery = lotteries[_lotteryId];

        lottery.status = Status.Claimable;
        lottery.finalNumber = randomGenerator.viewRandomResult();
        lottery.ticketsWin = winCounts;
        lottery.prizeAmounts[1] = _calculatePrize(
            lottery.amountTotal,
            RATE_PRIZE_1ST,
            winCounts[1],
            MAX_PRIZE_1ST
        );
        lottery.prizeAmounts[2] = _calculatePrize(
            lottery.amountTotal,
            RATE_PRIZE_2ND,
            winCounts[2],
            MAX_PRIZE_2ND
        );
        lottery.prizeAmounts[3] = _calculatePrize(
            lottery.amountTotal,
            RATE_PRIZE_3RD,
            winCounts[3],
            MAX_PRIZE_3RD
        );

        uint256 prizeAmount = (lottery.amountTotal * TOTAL_PRIZE_RATE) / 10000;

        uint256 jpAmount = prizeAmount -
            (lottery.prizeAmounts[1] *
                winCounts[1] +
                lottery.prizeAmounts[2] *
                winCounts[2] +
                lottery.prizeAmounts[3] *
                winCounts[3]);

        // Pay debt
        if (lottery.escrowCredit > 0) {
            uint256 maxDebtReturn = (lottery.amountTotal * ESCROW_RETURN_RATE) / 10000;
            uint256 debtToReturn = maxDebtReturn > lottery.escrowCredit
                ? lottery.escrowCredit
                : maxDebtReturn;
            jpAmount -= debtToReturn;
            lottery.escrowCredit -= debtToReturn;

            if (debtToReturn > 0) {
                currency.safeTransfer(injectorAddress, debtToReturn);
                emit DebtPaid(_lotteryId, debtToReturn);
            }
        }

        // Increase affilicate treasury
        uint256 affiliateTreasury = (lottery.amountTotal * AFFILIATE_RATE) / 10000;
        lottery.affiliateTreasury += affiliateTreasury;

        // Pay or increase prize
        if (winCounts[0] > 0) {
            lottery.jpTreasury = 0;
            lottery.prizeAmounts[0] =
                ((lotteries[_lotteryId - 1].jpTreasury + jpAmount) * 1000) /
                winCounts[0] /
                1000;

            lottery.affiliatePrize = (lottery.affiliateTreasury * 1000) / winCounts[0] / 1000;
            lottery.affiliateTreasury = 0;
        } else {
            lottery.jpTreasury = lotteries[_lotteryId - 1].jpTreasury + jpAmount;
        }

        // Send revenue
        uint256 treasuryAmount = lottery.amountTotal -
            lottery.amountUsed -
            prizeAmount -
            affiliateTreasury;
        if (treasuryAmount > 0) {
            currency.safeTransfer(treasuryAddress, treasuryAmount);
        }

        // Send referral
        if (lottery.totalReferral > 0) {
            currency.safeTransfer(address(referralProgram), lottery.totalReferral);
        }

        emit LotteryNumberDrawn(currentLotteryId, lottery.finalNumber);
    }

    /**
     * @notice Inject funds. Inject some funds to start new lottery
     * @dev Callable by injector address
     */
    function injectFunds() external override onlyInjector {
        require(
            currentLotteryId == 0 || lotteries[currentLotteryId].status == Status.Claimable,
            "Lottery is not claimable"
        );
        require(
            lotteries[currentLotteryId].jpTreasury == 0,
            "Only injectfunds when has jp winners"
        );

        lotteries[currentLotteryId].escrowCredit += MIN_JP_PRIZE;
        lotteries[currentLotteryId].jpTreasury = MIN_JP_PRIZE;

        currency.safeTransferFrom(address(msg.sender), address(this), MIN_JP_PRIZE);

        emit LotteryInjection(currentLotteryId, MIN_JP_PRIZE);
    }

    function safeStopAndWithdrawTreasury(address receiver) external onlyOwner {
        require(receiver != address(0), "receiver address is zero");

        Lottery memory lottery = lotteries[currentLotteryId];
        require(lottery.status == Status.Claimable, "only withdraw when lottery claimable");
        require(lottery.ticketsWin[0] == 0, "only close when no one win jackpot prize");
        require(stoppedAt == 0, "already stopped");

        stoppedAt = currentLotteryId;

        uint256 amount = lottery.affiliateTreasury + lottery.jpTreasury;
        uint256 refundAmount = lottery.amountTotal -
            (lottery.ticketsWin[0] + lottery.ticketsWin[1] + lottery.ticketsWin[2]) *
            lottery.priceTicket;

        if (amount < refundAmount) {
            currency.safeTransferFrom(msg.sender, address(this), refundAmount - amount);
        } else if (amount > refundAmount) {
            currency.safeTransfer(receiver, amount - refundAmount);
        }

        emit LotteryStopped(stoppedAt, receiver, amount, refundAmount);
    }

    /**
     * @notice Start the lottery
     * @dev Callable by operator
     * @param _endTime: endTime of the lottery
     * @param _priceTicket: price of a ticket
     * @param _discountDivisor: the divisor to calculate the discount magnitude for bulks
     */
    function startLottery(
        uint256 _endTime,
        uint256 _priceTicket,
        uint256 _discountDivisor
    ) external override onlyOperator {
        require(stoppedAt == 0, "already stopped");
        require(
            (currentLotteryId == 0) || (lotteries[currentLotteryId].status == Status.Claimable),
            "Not time to start lottery"
        );
        require(
            lotteries[currentLotteryId].jpTreasury >= MIN_JP_PRIZE,
            "Not enough treasury to start"
        );
        require(
            ((_endTime - block.timestamp) > MIN_LENGTH_LOTTERY) &&
                ((_endTime - block.timestamp) < MAX_LENGTH_LOTTERY),
            "Lottery length outside of range"
        );

        require(
            (_priceTicket >= minPriceTicket) && (_priceTicket <= maxPriceTicket),
            "Outside of limits"
        );

        require(
            _discountDivisor == 0 || _discountDivisor >= MIN_DISCOUNT_DIVISOR,
            "Discount divisor too low"
        );

        uint256 lastLotteryId = currentLotteryId;
        currentLotteryId++;

        lotteries[currentLotteryId] = Lottery({
            status: Status.Open,
            startTime: block.timestamp,
            endTime: _endTime,
            priceTicket: _priceTicket,
            discountDivisor: _discountDivisor,
            firstTicketId: currentTicketId,
            firstTicketIdNextLottery: currentTicketId,
            amountUsed: 0,
            totalReferral: 0,
            amountTotal: 0,
            finalNumber: new bytes(6),
            prizeAmounts: [uint256(0), 0, 0, 0],
            ticketsWin: [uint256(0), 0, 0, 0],
            jpTreasury: 0,
            affiliateTreasury: lotteries[lastLotteryId].affiliateTreasury,
            escrowCredit: lotteries[lastLotteryId].escrowCredit,
            affiliatePrize: 0
        });

        emit LotteryOpen(
            currentLotteryId,
            block.timestamp,
            _endTime,
            _priceTicket,
            currentTicketId
        );
    }

    /**
     * @notice It allows the admin to recover wrong tokens sent to the contract
     * @param _tokenAddress: the address of the token to withdraw
     * @param _tokenAmount: the number of token amount to withdraw
     * @dev Only callable by owner.
     */
    function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount) external onlyOwner {
        require(_tokenAddress != address(currency), "Cannot be currency token");

        IERC20(_tokenAddress).safeTransfer(address(msg.sender), _tokenAmount);

        emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
    }

    /**
     * @notice Change the random generator
     * @dev The calls to functions are used to verify the new generator implements them properly.
     * It is necessary to wait for the VRF response before starting a round.
     * Callable only by the contract owner
     * @param _randomGeneratorAddress: address of the random generator
     */
    function changeRandomGenerator(address _randomGeneratorAddress) external onlyOwner {
        require(
            lotteries[currentLotteryId].status == Status.Claimable,
            "Lottery not in claimable"
        );

        // Request a random number from the generator based on a seed
        IRandom(_randomGeneratorAddress).requestRandomNumbers();

        // Calculate the finalNumber based on the randomResult generated by ChainLink's fallback
        IRandom(_randomGeneratorAddress).viewRandomResult();

        randomGenerator = IRandom(_randomGeneratorAddress);

        emit NewRandomGenerator(_randomGeneratorAddress);
    }

    function setTicketValues(
        uint256 _minPriceTicket,
        uint256 _maxPriceTicket,
        uint256 _maxNumberTicketsPerBuy
    ) external onlyOwner {
        require(_minPriceTicket <= _maxPriceTicket, "minPrice must be < maxPrice");
        require(_maxNumberTicketsPerBuy != 0, "Must be > 0");

        minPriceTicket = _minPriceTicket;
        maxPriceTicket = _maxPriceTicket;
        maxNumberTicketsPerBuyOrClaim = _maxNumberTicketsPerBuy;
    }

    /**
     * @notice Set operator, treasury, and injector addresses
     * @dev Only callable by owner
     * @param _operatorAddress: address of the operator
     * @param _treasuryAddress: address of the treasury
     * @param _injectorAddress: address of the injector
     */
    function setOperatorAndTreasuryAndInjectorAddresses(
        address _operatorAddress,
        address _treasuryAddress,
        address _injectorAddress
    ) external onlyOwner {
        require(
            _operatorAddress != address(0) &&
                _treasuryAddress != address(0) &&
                _treasuryAddress != address(0),
            "Cannot be zero address"
        );

        operatorAddress = _operatorAddress;
        treasuryAddress = _treasuryAddress;
        injectorAddress = _injectorAddress;
    }

    /**
     * @dev Only callable by owner
     * @param _referral: address of the referral
     * @param _coupon: address of the coupon
     */
    function setReferralAndCoupon(address _referral, address _coupon) external onlyOwner {
        referralProgram = IReferral(_referral);
        couponCenter = ICoupon(_coupon);
    }

    /*
    /**
     * @notice View current lottery id
     */
    function viewCurrentLotteryId() external view returns (uint256) {
        return currentLotteryId;
    }

    /**
     * @notice View lottery information
     * @param _lotteryId: lottery id
     */
    function viewLottery(uint256 _lotteryId) external view returns (Lottery memory) {
        return lotteries[_lotteryId];
    }

    /**
     * @notice View ticker statuses and numbers for an array of ticket ids
     * @param _ticketIds: array of _ticketId
     */
    function viewNumbersAndAddressForTicketIds(uint256[] calldata _ticketIds)
        external
        view
        returns (bytes6[] memory, address[] memory)
    {
        uint256 length = _ticketIds.length;
        bytes6[] memory ticketNumbers = new bytes6[](length);
        address[] memory ticketStatuses = new address[](length);

        for (uint256 i = 0; i < length; i++) {
            ticketNumbers[i] = tickets[_ticketIds[i]].number;
            ticketStatuses[i] = tickets[_ticketIds[i]].owner;
        }

        return (ticketNumbers, ticketStatuses);
    }

    /**
     * @notice View rewards for a given ticket, providing a bracket, and lottery id
     * @dev Computations are mostly offchain. This is used to verify a ticket!
     * @param _lotteryId: lottery id
     * @param _ticketId: ticket id
     */
    function viewRewardsForTicketId(uint256 _lotteryId, uint256 _ticketId)
        external
        view
        returns (uint256)
    {
        // Check lottery is in claimable status
        if (lotteries[_lotteryId].status != Status.Claimable) {
            return 0;
        }

        // Check ticketId is within range
        if (
            (lotteries[_lotteryId].firstTicketIdNextLottery < _ticketId) &&
            (lotteries[_lotteryId].firstTicketId >= _ticketId)
        ) {
            return 0;
        }

        uint8 _matched = ArrayLib.countMatch(
            lotteries[_lotteryId].finalNumber,
            tickets[_ticketId].number
        );
        return _matched >= 3 ? lotteries[_lotteryId].prizeAmounts[6 - _matched] : 0;
    }

    /**
     * @notice View user ticket ids, numbers, and statuses of user for a given lottery
     * @param _user: user address
     * @param _lotteryId: lottery id
     * @param _cursor: cursor to start where to retrieve the tickets
     * @param _size: the number of tickets to retrieve
     */
    function viewUserInfoForLotteryId(
        address _user,
        uint256 _lotteryId,
        uint256 _cursor,
        uint256 _size
    )
        external
        view
        returns (
            uint256[] memory,
            bytes6[] memory,
            bool[] memory,
            uint256
        )
    {
        uint256 length = _size;
        uint256 numberTicketsBoughtAtLotteryId = userTicketIdsPerLotteryId[_user][_lotteryId]
            .length;

        if (length > (numberTicketsBoughtAtLotteryId - _cursor)) {
            length = numberTicketsBoughtAtLotteryId - _cursor;
        }

        uint256[] memory lotteryTicketIds = new uint256[](length);
        bytes6[] memory ticketNumbers = new bytes6[](length);
        bool[] memory ticketStatuses = new bool[](length);

        for (uint256 i = 0; i < length; i++) {
            lotteryTicketIds[i] = userTicketIdsPerLotteryId[_user][_lotteryId][i + _cursor];
            ticketNumbers[i] = tickets[lotteryTicketIds[i]].number;

            ticketStatuses[i] = tickets[lotteryTicketIds[i]].owner == address(0);
        }

        return (lotteryTicketIds, ticketNumbers, ticketStatuses, _cursor + length);
    }

    /**
     * @notice Calculate final price for bulk of tickets
     * @param _discountDivisor: divisor for the discount (the smaller it is, the greater the discount is), should be >= 0
     * @param _priceTicket: price of a ticket
     * @param _numberTickets: number of tickets purchased
     */
    function _calculateTotalPriceForBulkTickets(
        uint256 _discountDivisor,
        uint256 _priceTicket,
        uint256 _numberTickets
    ) internal pure returns (uint256) {
        return
            (_priceTicket * _numberTickets * (_discountDivisor + 1 - _numberTickets)) /
            _discountDivisor;
    }

    function _validateTicket(bytes6 number) internal pure {
        require(uint8(number[0]) <= 45 && uint8(number[0]) >= 1, "numbers should in range 1-45");
        for (uint8 i = 1; i < 6; i++) {
            require(
                uint8(number[i]) <= 45 && uint8(number[i]) >= 1,
                "number should in range 1-45"
            );
            require(uint8(number[i]) > uint8(number[i - 1]), "number should be asc");
        }
    }

    /**
     * @notice Check if an address is a contract
     */
    function _isContract(address _addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }

    function _calculatePrize(
        uint256 amountTotal,
        uint256 rate,
        uint256 winCount,
        uint256 maxPrize
    ) internal pure returns (uint256 prize) {
        if (winCount == 0) {
            return 0;
        }
        prize = (amountTotal * rate) / winCount / 10000;

        if (prize > maxPrize) {
            prize = maxPrize;
        }
    }
}
