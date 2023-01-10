// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import 'contracts/position_trading/IPositionsController.sol';
import 'contracts/lib/ownable/OwnableSimple.sol';
import 'contracts/position_trading/IAssetsController.sol';
import 'contracts/lib/factories/ContractData.sol';
import 'contracts/position_trading/IPositionAlgorithm.sol';
import 'contracts/position_trading/algorithms/TradingPair/ITradingPairAlgorithm.sol';
import 'contracts/position_trading/algorithms/TradingPair/FeeSettings.sol';
import 'contracts/position_trading/AssetCreationData.sol';
import 'contracts/position_trading/ItemRefAsAssetLibrary.sol';

contract PositionsFactory is OwnableSimple {
    using ItemRefAsAssetLibrary for ItemRef;
    IPositionsController public positionsController;
    IAssetsController public ethAssetsController; // assetType 1
    IAssetsController public erc20AssetsController; // assetType 2
    IAssetsController public erc721AssetsController; // assetType 3
    IPositionAlgorithm public lockAlgorithm;
    ITradingPairAlgorithm public tradingPair;

    constructor(
        address positionsController_,
        address ethAssetsController_,
        address erc20AssetsController_,
        address erc721AssetsController_,
        address lockAlgorithm_,
        address tradingPair_
    ) OwnableSimple(msg.sender) {
        positionsController = IPositionsController(positionsController_);
        ethAssetsController = IAssetsController(ethAssetsController_);
        erc20AssetsController = IAssetsController(erc20AssetsController_);
        erc721AssetsController = IAssetsController(erc721AssetsController_);
        lockAlgorithm = IPositionAlgorithm(lockAlgorithm_);
        tradingPair = ITradingPairAlgorithm(tradingPair_);
    }

    function createLockPosition(
        AssetCreationData calldata data1,
        uint256 lockSeconds
    ) external payable {
        // create a position
        uint256 positionId = positionsController.createPosition(msg.sender);

        // set assets
        _createAsset(positionId, 1, data1);

        // set algorithm
        positionsController.setAlgorithm(positionId, address(lockAlgorithm));

        if (lockSeconds > 0)
            lockAlgorithm.lockPosition(positionId, lockSeconds);

        positionsController.stopBuild(positionId);
    }

    function createTradingPairPosition(
        AssetCreationData calldata data1,
        AssetCreationData calldata data2,
        FeeSettings calldata feeSettings
    ) external payable {
        // create a position
        uint256 positionId = positionsController.createPosition(msg.sender);

        // set assets
        _createAsset(positionId, 1, data1);
        _createAsset(positionId, 2, data2);

        // set algorithm
        tradingPair.createAlgorithm(positionId, feeSettings);

        positionsController.stopBuild(positionId);
    }

    function _createAsset(
        uint256 positionId,
        uint256 assetCode,
        AssetCreationData calldata data
    ) internal {
        IAssetsController controller;

        if (data.assetTypeCode == 1) {
            controller = ethAssetsController;
        } else if (data.assetTypeCode == 2) {
            controller = erc20AssetsController;
        } else if (data.assetTypeCode == 3) {
            controller = erc721AssetsController;
        } else revert('unknown asset type code');

        ItemRef memory asset = positionsController.createAsset(
            positionId,
            assetCode,
            address(controller)
        );
        asset.assetsController().initialize{ value: msg.value }(
            msg.sender,
            asset.id,
            data
        );
    }
}
