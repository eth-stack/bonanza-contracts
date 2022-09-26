// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

import "../interfaces/IPredictionGame.sol";

contract PredictionChecker is Ownable, Pausable {
    address public predictContract;

    constructor(address _predictContract) {
        predictContract = _predictContract;
    }

    function checkRound(uint256 epoch)
        public
        view
        returns (
            bool _canRun,
            bool finalized,
            bool hasBets
        )
    {
        IPredictionGame.Round memory round = IPredictionGame(predictContract)
            .rounds(epoch);
        finalized = round.finalized;
        hasBets = round.totalAmount > 0;

        if (IPredictionGame(predictContract).paused() || round.finalized) {
            _canRun = false;
        } else {
            uint256 resultBlock = IPredictionGame(predictContract)
                .getResultBlock(epoch);
            _canRun = block.number >= resultBlock;
        }
    }
}
