// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "hardhat/console.sol";

contract BwheelGame is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Total lotteries which a address bought
    mapping(address => uint256) public lotteries;
    mapping(uint256 => bool) public claimed;
    uint256 public lotteryPrice;
    IERC20 public currency;

    address internal adminSigner;

    enum ClaimType {
        ERC20
    }

    event BuyLottery(address user, uint256 qty, uint256 price);
    event ClaimERC20(address user, uint256 collectId, uint256 amount);
    event TokenWithdrawn(address token, uint256 amount);

    constructor(
        uint256 _lotteryPrice,
        address _currency,
        address _adminSigner
    ) {
        lotteryPrice = _lotteryPrice;
        currency = IERC20(_currency);
        adminSigner = _adminSigner;
    }

    modifier notContract() {
        require(!_isContract(msg.sender), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
    }

    function buyLottery(uint256 qty, uint256 payAmount)
        external
        whenNotPaused
        nonReentrant
        notContract
    {
        uint256 rawAmount = qty * lotteryPrice;
        require(rawAmount == payAmount, "Incorrect amount");

        // Make payment
        currency.safeTransferFrom(_msgSender(), address(this), rawAmount);

        // Increase use lotteries
        lotteries[_msgSender()] += qty;

        emit BuyLottery(_msgSender(), qty, lotteryPrice);
    }

    function claimERC20(
        uint256 collectId,
        uint256 amount,
        bytes memory sig
    ) external nonReentrant whenNotPaused {
        require(amount != 0, "Amount is 0");
        require(!claimed[collectId], "Claimed");

        bytes32 digest = keccak256(abi.encode(ClaimType.ERC20, _msgSender(), collectId, amount));
        require(
            SignatureChecker.isValidSignatureNow(
                adminSigner,
                ECDSA.toEthSignedMessageHash(digest),
                sig
            ),
            "Invalid signature"
        );

        claimed[collectId] = true;
        currency.safeTransfer(_msgSender(), amount);

        emit ClaimERC20(_msgSender(), collectId, amount);
    }

    function viewClaimStatuses(uint256[] calldata collectIds)
        external
        view
        returns (bool[] memory)
    {
        bool[] memory claimeds = new bool[](collectIds.length);

        for (uint256 i = 0; i < claimeds.length; i++) {
            claimeds[i] = claimed[collectIds[i]];
        }

        return claimeds;
    }

    /**Admin function */
    /***************************/
    function withdrawToken(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).safeTransfer(address(msg.sender), _amount);

        emit TokenWithdrawn(_token, _amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setLotteryPrice(uint256 newPrice) external onlyOwner {
        lotteryPrice = newPrice;
    }

    function setPaymentToken(address newToken) external onlyOwner {
        require(newToken != address(0), "Token should not be zero address");
        currency = IERC20(newToken);
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
