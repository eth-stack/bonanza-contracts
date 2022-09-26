// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/IReferral.sol";

contract Referral is IReferral, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Role associated to Games smart contracts.
    bytes32 public constant GAME_ROLE = keccak256("GAME_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    uint256 public constant DECIMALS = 10000;
    uint256 public constant MAX_REWARD_RATE = 1000;
    uint256 public constant BASE_REWARD_RATE = 500;

    uint256 public minWithdraw = 3 ether;

    struct Link {
        uint96 percent; // 0 (0%) - 10000 (100%)
        address owner;
    }

    mapping(address => uint256) public _mainRewardRates;

    // map agent address => main agent address
    mapping(address => address) public _mainAgents;

    mapping(address => bytes32[]) private _ownerCodes;
    mapping(bytes32 => Link) private _links;

    // Credit of a address
    mapping(address => mapping(address => uint256)) private _credits;

    // End-user address -> agent code
    mapping(address => bytes32) private _accounts;

    event NewRefLink(bytes32 code, uint96 percent, address mainAgent, address owner);
    event NewMainAgentRate(address agent, uint96 rewardRate);
    event RegisteredReferrer(address referee, bytes32 code);
    event AddReferralCredit(address refererrer, address token, uint256 credit);

    /// @notice Emitted after the referrer withdraw credits.
    /// @param payee Address of the referrer.
    /// @param token Address of the token.
    /// @param amount Amount of credited tokens.
    event WithdrawnReferralCredit(address indexed payee, address indexed token, uint256 amount);
    event NewMinWithdraw(uint256 amount);

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function addReferrer(address user, bytes32 code) external onlyRole(GAME_ROLE) {
        if (
            _accounts[user] != bytes32(0) || // Address have been registered upline
            _links[code].percent == 0 || // referrer is not exist
            _links[code].owner == user // Use same account as ref
        ) {
            return;
        }

        _accounts[user] = code;
        emit RegisteredReferrer(user, code);
    }

    function payReferral(
        address user,
        address token,
        uint256 amount
    ) external onlyRole(GAME_ROLE) returns (uint256, uint256) {
        bytes32 code = _accounts[user];
        if (code == bytes32(0) || token == address(0)) {
            return (0, 0);
        }

        address referrer = _links[code].owner;

        uint256 totalReferral = (amount * _calcRewardRate(referrer)) / DECIMALS;
        uint256 credit = (totalReferral * _links[code].percent) / DECIMALS;
        _credits[token][referrer] += credit;

        emit AddReferralCredit(referrer, token, credit);

        return (totalReferral - credit, totalReferral);
    }

    function createLink(
        bytes32 code,
        uint96 percent,
        address mainAgent
    ) external nonReentrant {
        require(code != bytes32(0) && _links[code].percent == 0, "Code used");
        require(_ownerCodes[msg.sender].length < 10, "Max is 10 ref per adress");
        require(percent <= DECIMALS && percent > 0, "Rate invalid");

        // Set main agent for 1st create ref
        if (_ownerCodes[msg.sender].length == 0 && mainAgent != address(0)) {
            require(_mainRewardRates[mainAgent] > 0, "main agent not set");
            _mainAgents[msg.sender] = mainAgent;
        }

        _links[code] = Link({percent: percent, owner: msg.sender});
        _ownerCodes[msg.sender].push(code);

        emit NewRefLink(code, percent, _mainAgents[msg.sender], msg.sender);
    }

    function updateMainAgentRate(address agent, uint96 rewardRate)
        external
        onlyRole(MANAGER_ROLE)
    {
        require(agent != address(0), "Not zero-address");
        require(rewardRate > 0 && rewardRate <= MAX_REWARD_RATE, "Exceed max rewardRate");

        _mainRewardRates[agent] = rewardRate;

        emit NewMainAgentRate(agent, rewardRate);
    }

    /// @notice Referrer withdraw credits.
    /// @param tokens The tokens addresses.
    function withdrawCredits(address[] calldata tokens) external nonReentrant {
        for (uint8 i; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 credit = _credits[msg.sender][token];

            require(credit >= minWithdraw, "should >= minWithdraw");

            _credits[msg.sender][token] = 0;
            IERC20(token).safeTransfer(msg.sender, credit);
            emit WithdrawnReferralCredit(msg.sender, token, credit);
        }
    }

    function setMinWithdraw(uint256 min) external onlyRole(DEFAULT_ADMIN_ROLE) {
        minWithdraw = min;

        emit NewMinWithdraw(min);
    }

    function hasReferrer(address addr) external view returns (bool) {
        return _accounts[addr] != bytes32(0);
    }

    /**
     * @dev View all ref links created by a address
     * @param owner address to view links
     * @return percents Array of percent
     * @return codes Array of percent
     */
    function viewLinks(address owner)
        external
        view
        returns (uint256[] memory percents, bytes32[] memory codes)
    {
        uint256 totalRef = _ownerCodes[owner].length;

        percents = new uint256[](totalRef);
        codes = new bytes32[](totalRef);
        for (uint256 i = 0; i < totalRef; i++) {
            codes[i] = _ownerCodes[owner][i];
            percents[i] = _links[codes[i]].percent;
        }
    }

    /// @notice Gets the referrer's token credits.
    /// @param payee Address of the referrer.
    /// @param token Address of the token.
    /// @return The number of tokens available to withdraw.
    function creditOf(address payee, address token) external view returns (uint256) {
        return _credits[payee][token];
    }

    /// @notice Gets the referrer's account information.
    /// @param user Address of the referrer.
    /// @return referrer The address of referer.
    /// @return code Identify the ref.
    function getReferralAccount(address user)
        external
        view
        returns (address referrer, bytes32 code)
    {
        code = _accounts[user];
        referrer = _links[code].owner;
    }

    function viewLinkInfo(bytes32 code)
        public
        view
        returns (
            uint96 referralPercent,
            address owner,
            uint256 agentRate
        )
    {
        referralPercent = _links[code].percent;

        owner = _links[code].owner;
        agentRate = _calcRewardRate(owner);
    }

    function viewLinkInfoForUser(address user)
        public
        view
        returns (
            bytes32 code,
            uint96 referralPercent,
            address owner,
            uint256 agentRate
        )
    {
        code = _accounts[user];
        (referralPercent, owner, agentRate) = viewLinkInfo(code);
    }

    function _calcRewardRate(address referrer) internal view returns (uint256) {
        return
            _mainAgents[referrer] != address(0)
                ? _mainRewardRates[_mainAgents[referrer]]
                : BASE_REWARD_RATE;
    }
}
