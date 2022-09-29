// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IRandom.sol";
import "../interfaces/ILottery.sol";

contract RandomNumberGeneratorForTesting is IRandom, Ownable {
    address public jpAddress;
    uint32 public numWords;

    uint256 public latestLotteryId;
    uint256 public latestRequestId;
    bytes public randomResult;

    function requestRandomNumbers() external override {
        require(msg.sender == jpAddress, "Only Lottery");
        latestRequestId = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
        latestLotteryId = ILottery(jpAddress).viewCurrentLotteryId();
    }

    function saveRandomResult(bytes calldata results) external onlyOwner {
        require(results.length == numWords, "length is incorrect");
        randomResult = results;
        latestLotteryId = ILottery(jpAddress).viewCurrentLotteryId();
    }

    function viewLatestLotteryId() external view override returns (uint256) {
        return latestLotteryId;
    }

    function viewRandomResult() external view override returns (bytes memory) {
        return randomResult;
    }

    function setLotteryAddress(address _jpAddress) external onlyOwner {
        jpAddress = _jpAddress;
    }
}
