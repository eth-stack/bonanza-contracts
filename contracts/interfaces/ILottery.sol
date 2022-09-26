// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import "./ICoupon.sol";

interface ILottery {
    /**
     * @notice Buy tickets for the current lottery
     * @dev Callable by users
     */
    function buyTickets(
        uint256 lotteryId,
        bytes6[] calldata ticketNumbers,
        bytes32 code,
        ICoupon.Coupon calldata coupon
    ) external;

    /**
     * @notice Claim a set of winning tickets for a lottery
     * @param _lotteryId: lottery id
     * @param _ticketIds: array of ticket ids
     * @dev Callable by users only, not contract!
     */
    function claimTickets(uint256 _lotteryId, uint256[] calldata _ticketIds) external;

    /**
     * @notice Close lottery
     * @param _lotteryId: lottery id
     * @dev Callable by operator
     */
    function closeLottery(uint256 _lotteryId) external;

    /**
     * @notice Draw the final number, calculate reward in CAKE per group, and make lottery claimable
     * @param _lotteryId: lottery id
     * @dev Callable by operator
     */
    function drawFinalNumberAndMakeLotteryClaimable(
        uint256 _lotteryId,
        uint256[4] calldata winCounts
    ) external;

    /**
     * @notice Inject funds
     * @dev Callable by operator
     */
    function injectFunds() external;

    /**
     * @notice Start the lottery
     * @dev Callable by operator
     */
    function startLottery(
        uint256 _endTime,
        uint256 _priceTicket,
        uint256 _discountDivisor
    ) external;

    function viewCurrentLotteryId() external view returns (uint256);
}
