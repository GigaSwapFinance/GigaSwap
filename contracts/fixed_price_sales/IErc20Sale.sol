// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

struct PositionData {
    address owner;
    address asset1;
    address asset2;
    uint256 priceNom;
    uint256 priceDenom;
    uint256 count1;
    uint256 count2;
    /// @dev flags
    /// 0 - has whiteList
    /// 1 - has buy limit by addresses
    uint8 flags;
}

interface IErc20Sale {
    function getPosition(
        uint256 positionId
    ) external view returns (PositionData memory);
}