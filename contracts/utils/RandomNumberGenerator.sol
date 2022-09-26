// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IRandom.sol";
import "../interfaces/ILottery.sol";

contract RandomNumberGenerator is VRFConsumerBaseV2, IRandom, Ownable {
    using SafeERC20 for IERC20;

    bytes32 private constant MEGA_6_45 =
        0x0102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F20;
    bytes13 private constant MEGA_6_45_EXTENDED = 0x2122232425262728292A2B2C2D;

    address public jpAddress;
    uint32 numWords;

    uint256 public latestRequestId;
    bytes public randomResult;
    uint256 public latestLotteryId;

    // Chainlink
    uint64 private subscriptionId;
    address private vrfCoordinator;
    bytes32 private keyHash;
    uint32 private callbackGasLimit;
    uint16 private requestConfirmations;
    VRFCoordinatorV2Interface internal coordinator;

    event ChangeRandomnessConfigure(
        uint64 indexed subscriptionId,
        address vrfCoordinator,
        bytes32 keyHash,
        uint32 callbackGasLimit,
        uint16 requestConfirmations
    );

    constructor(
        uint64 _subscriptionId,
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations,
        uint32 _numWords
    ) VRFConsumerBaseV2(vrfCoordinator) {
        coordinator = VRFCoordinatorV2Interface(vrfCoordinator);

        subscriptionId = _subscriptionId;
        vrfCoordinator = _vrfCoordinator;
        keyHash = _keyHash;
        callbackGasLimit = _callbackGasLimit;
        requestConfirmations = _requestConfirmations;

        require(numWords > 0, "numwords should > 0");
        numWords = _numWords;
    }

    /**
     * @notice Request randomness from a user-provided seed
     */
    function requestRandomNumbers() external override {
        require(msg.sender == jpAddress, "Only Lottery");
        latestRequestId = coordinator.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
    }

    function changeRandomConfig(
        uint64 _subscriptionId,
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations
    ) external onlyOwner {
        coordinator = VRFCoordinatorV2Interface(_vrfCoordinator);

        subscriptionId = _subscriptionId;
        vrfCoordinator = _vrfCoordinator;
        keyHash = _keyHash;
        callbackGasLimit = _callbackGasLimit;
        requestConfirmations = _requestConfirmations;

        emit ChangeRandomnessConfigure(
            subscriptionId,
            vrfCoordinator,
            keyHash,
            callbackGasLimit,
            requestConfirmations
        );
    }

    /**
     * @notice Set the address for the PancakeSwapLottery
     * @param _jpAddress: address of the PancakeSwap lottery
     */
    function setLotteryAddress(address _jpAddress) external onlyOwner {
        jpAddress = _jpAddress;
    }

    /**
     * @notice It allows the admin to withdraw tokens sent to the contract
     * @param _tokenAddress: the address of the token to withdraw
     * @param _tokenAmount: the number of token amount to withdraw
     * @dev Only callable by owner.
     */
    function withdrawTokens(address _tokenAddress, uint256 _tokenAmount) external onlyOwner {
        IERC20(_tokenAddress).safeTransfer(address(msg.sender), _tokenAmount);
    }

    /**
     * @notice View latestLotteryId
     */
    function viewLatestLotteryId() external view override returns (uint256) {
        return latestLotteryId;
    }

    /**
     * @notice View random result
     */
    function viewRandomResult() external view override returns (bytes memory) {
        return randomResult;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)
        internal
        override
    {
        require(latestRequestId == requestId, "Wrong requestId");
        bytes memory alphabet = new bytes(45);
        assembly {
            mstore(add(alphabet, 32), MEGA_6_45)
            mstore(add(alphabet, 64), MEGA_6_45_EXTENDED)
        }

        randomResult = new bytes(numWords);

        for (uint8 i = 0; i < randomWords.length; i++) {
            uint256 index = randomWords[i] % (alphabet.length - i);
            randomResult[i] = bytes1(uint8(alphabet[index]));
            alphabet[index] = alphabet[alphabet.length - 1 - i];
        }

        latestLotteryId = ILottery(jpAddress).viewCurrentLotteryId();
    }
}
