// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

struct OfferData {
    uint256 positionId;
    uint256 asset1Count;
    uint256 asset2Count;
    /// @dev state
    /// 0 - not created
    /// 1 - created
    /// 2 - applied
    uint8 state;
    address owner;
}

interface IErc20SaleCounterOffer {
    event OnOfer(uint256 indexed positionId, uint256 indexed offerId);
    event OnApplyOfer(uint256 indexed positionId, uint256 indexed offerId);
    event OnRemoveOfer(uint256 indexed positionId, uint256 indexed offerId);

    function createOffer(
        uint256 positionId,
        uint256 asset1Count,
        uint256 asset2Count
    ) external;

    function removeOffer(uint256 offerId) external;

    function getOffer(
        uint256 offerId
    ) external returns (OfferData memory);

    function applyOffer(uint256 offerId) external;
}
