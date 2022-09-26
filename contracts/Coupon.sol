// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "./interfaces/ICoupon.sol";

contract Coupon is EIP712, ReentrancyGuard, AccessControl, ICoupon {
    // https://eips.ethereum.org/EIPS/eip-712#specification
    bytes32 public constant COUPON_TYPE_HASH =
        keccak256(
            "Coupon(uint256 id,uint256 saleoff,uint256 maxSaleOff,uint256 minPayment,uint256 start,uint256 end,address owner)"
        );
    bytes32 public constant GAME_ROLE = keccak256("GAME_ROLE");

    uint256 public maxSaleoff = 5000;
    address public couponSigner;
    mapping(uint256 => bool) public couponsUsed;

    event NewCouponSigner(address signer);

    constructor(address _couponSigner) EIP712("Coupon", "1") {
        couponSigner = _couponSigner;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function useCoupon(Coupon memory coupon, address user, uint256 payAmount)
        external
        nonReentrant
        onlyRole(GAME_ROLE)
        returns (uint256)
    {
        // Validate max sale off
        require(coupon.saleoff <= maxSaleoff, "Coupon: Exceed max saleoff");
        require(payAmount >= coupon.minPayment, "Coupon: Not pass min payment");
        require(coupon.start <= block.timestamp, "Coupon: Not valid start");
        require(coupon.end == 0 || coupon.end >= block.timestamp, "Coupon: Not valid end");
        require(coupon.owner == user, "Coupon: Not owner");

        // Validate coupon signature
        require(
            SignatureChecker.isValidSignatureNow(couponSigner, _hashCoupon(coupon), coupon.sig),
            "Coupon: Invalid signature"
        );

        couponsUsed[coupon.id] = true;
        uint256 amount = (coupon.saleoff * payAmount) / 10000;

        return amount > coupon.maxSaleOff ? coupon.maxSaleOff : amount;
    }

    function isCouponAvailable(Coupon memory coupon, uint256 payAmount, address owner)
        external
        view
        returns (bool)
    {
        return
            coupon.saleoff <= maxSaleoff &&
            payAmount >= coupon.minPayment &&
            coupon.start <= block.timestamp &&
            (coupon.end == 0 || coupon.end >= block.timestamp) &&
            coupon.owner == owner
            && !couponsUsed[coupon.id];
    }

    function setCouponSigner(address signer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        couponSigner = signer;

        emit NewCouponSigner(signer);
    }

    function _hashCoupon(Coupon memory coupon) internal view returns (bytes32) {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        COUPON_TYPE_HASH,
                        coupon.id,
                        coupon.saleoff,
                        coupon.maxSaleOff,
                        coupon.minPayment,
                        coupon.start,
                        coupon.end,
                        coupon.owner
                    )
                )
            );
    }
}
