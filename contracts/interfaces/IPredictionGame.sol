// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
interface IPredictionGame {

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

    function rounds(uint256 id)
        external
        view
        returns (Round memory);
    function paused() external view returns (bool);

    function getResultBlock(uint256 epoch) external view returns (uint256);

    function executeRound(uint256 epoch) external;
}

