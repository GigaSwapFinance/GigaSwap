// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import 'contracts/position_trading/assets/AssetsControllerBase.sol';

contract EthAssetsController is AssetsControllerBase {
    constructor(address positionsController)
        AssetsControllerBase(positionsController)
    {}

    receive() external payable {}

    function assetTypeId() external pure returns (uint256) {
        return 1;
    }

    function initialize(
        address from,
        uint256 assetId,
        AssetCreationData calldata data
    ) external payable onlyBuildMode(assetId) {
        if (data.value > 0) _transferToAsset(assetId, from, data.value);
    }

    function value(uint256 assetId) external pure returns (uint256) {
        return 0;
    }

    function contractAddr(uint256 assetId) external view returns (address) {
        return address(0);
    }

    function clone(uint256 assetId, address owner)
        external
        returns (ItemRef memory)
    {
        ItemRef memory newAsset = ItemRef(
            address(this),
            _positionsController.createNewAssetId()
        );
        return newAsset;
    }

    function _withdraw(
        uint256 assetId,
        address recepient,
        uint256 count
    ) internal override {
        (bool sent, ) = payable(recepient).call{ value: count }('');
        require(sent, 'sent ether error: ether is not sent');
    }

    function _transferToAsset(
        uint256 assetId,
        address from,
        uint256 count
    ) internal override returns (uint256 countTransferred) {
        require(msg.value >= count, 'not enouth eth');
        _counts[assetId] += count;
        countTransferred = count;
    }
}
