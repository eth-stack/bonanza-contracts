// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface ICoupon {
    struct Coupon {
        uint256 id;
        uint256 saleoff;
        uint256 maxSaleOff;
        uint256 minPayment;
        uint256 start;
        uint256 end;
        address owner;
        bytes sig;
    }

    function useCoupon(Coupon memory coupon, address user, uint256 payAmount) external returns (uint256);
}
