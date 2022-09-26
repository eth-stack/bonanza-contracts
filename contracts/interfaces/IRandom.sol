// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IRandom {
    /**
     * Requests randomness from a user-provided seed
     */
    function requestRandomNumbers() external;

    /**
     * View latest lotteryId numbers
     */
    function viewLatestLotteryId() external view returns (uint256);

    /**
     * Views random result
     */
    function viewRandomResult() external view returns (bytes memory);
}