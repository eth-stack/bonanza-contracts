
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestERC20 is ERC20 {
  constructor(uint256 totalSupply) ERC20("Test ERC20", "TERC20") {
    _mint(_msgSender(), totalSupply);
  }
}