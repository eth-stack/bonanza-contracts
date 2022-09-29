// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TestnetFaucet is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public currency;
    uint256 public claimAmount = 100 ether;
    uint256 public delayDuration = 24 hours;
    mapping(address => uint256) public lastClaimed;
    
    event FaucetClaimed(address claimer, uint256 amount);

    constructor(address token) {
        currency = IERC20(token);
    }

    function claimFaucet() external nonReentrant {
        require(claimable(msg.sender), "Not claimable");

        lastClaimed[msg.sender] = block.timestamp;
        currency.safeTransfer(msg.sender, claimAmount);

        emit FaucetClaimed(msg.sender, claimAmount);
    }

    function claimable(address user) public view returns (bool) {
        return
            block.timestamp > lastClaimed[user] &&
            block.timestamp - lastClaimed[user] > delayDuration;
    }

    function withdraw() external onlyOwner {
        currency.safeTransfer(msg.sender, currency.balanceOf(address(this)));
    }

    function config(uint256 amount, uint256 duration) external onlyOwner {
        claimAmount = amount;
        delayDuration = duration;
    }
}
