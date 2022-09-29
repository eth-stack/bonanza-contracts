// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IReferral {
    /// @notice Adds an address as referrer.
    /// @param user The address of the user.
    /// @param code The unique code of for referral link would set as referrer of user.
    /// @dev Callable by lottery contract
    function addReferrer(address user, bytes32 code) external;

    /// @notice Calculates and allocate referrer(s) credits to uplines.
    /// @param user Address of the gamer to find referrer(s).
    /// @param token The token to allocate.
    /// @param amount The number of tokens allocated for referrer(s).
    /// @dev Callable by lottery contract
    function payReferral(
        address user,
        address token,
        uint256 amount
    ) external returns (uint256 payneeReduced, uint256 totalReferral);

    /// @notice Utils function for check whether an address has the referrer.
    /// @param user The address of the user.
    /// @return Whether user has a referrer.
    function hasReferrer(address user) external view returns (bool);

    /// @notice Gets the referrer's account information.
    /// @param user Address of the referrer.
    /// @return referer The address of referer.
    /// @return code Identify the .
    function getReferralAccount(address user)
        external
        view
        returns (address referer, bytes32 code);
}
