// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import '../IAssetsController.sol';
import '../IPositionsController.sol';

abstract contract AssetsControllerBase is IAssetsController {
    IPositionsController immutable _positionsController;
    mapping(uint256 => bool) _suppressNotifyListener;
    mapping(uint256 => uint256) _counts;

    constructor(address positionsController_) {
        _positionsController = IPositionsController(positionsController_);
    }

    modifier onlyOwner(uint256 assetId) {
        require(this.owner(assetId) == msg.sender, 'only for asset owner');
        _;
    }

    modifier onlyFactory() {
        require(
            _positionsController.isFactory(msg.sender),
            'only for factories'
        );
        _;
    }

    modifier onlyBuildMode(uint256 assetId) {
        require(
            _positionsController.isBuildMode(
                _positionsController.getAssetPositionId(assetId)
            ),
            'only for factories'
        );
        _;
    }

    modifier onlyPositionsController() {
        require(
            msg.sender == address(_positionsController),
            'only for positions controller'
        );
        _;
    }

    function positionsController() external view returns (address) {
        return address(_positionsController);
    }

    function getPositionId(uint256 assetId) external view returns (uint256) {
        return _positionsController.getAssetPositionId(assetId);
    }

    function getAlgorithm(uint256 assetId)
        external
        view
        returns (address algorithm)
    {
        return _positionsController.getAlgorithm(this.getPositionId(assetId));
    }

    function owner(uint256 assetId) external view returns (address) {
        return
            _positionsController.ownerOf(
                _positionsController.getAssetPositionId(assetId)
            );
    }

    function isNotifyListener(uint256 assetId) external view returns (bool) {
        return !_suppressNotifyListener[assetId];
    }

    function setNotifyListener(uint256 assetId, bool value)
        external
        onlyFactory
    {
        _suppressNotifyListener[assetId] = !value;
    }

    function transferToAsset(AssetTransferData calldata arg)
        external
        payable
        onlyPositionsController
    {
        _transferToAssetCodeFrom(arg);
    }

    function withdraw(
        uint256 assetId,
        address recepient,
        uint256 count
    ) external onlyPositionsController {
        require(_counts[assetId] >= count, 'not enough asset balance');
        _withdraw(assetId, recepient, count);
        _counts[assetId] -= count;
    }

    function _withdraw(
        uint256 assetId,
        address recepient,
        uint256 count
    ) internal virtual;

    function count(uint256 assetId) external view returns (uint256) {
        return _counts[assetId];
    }

    function _transferToAssetCodeFrom(AssetTransferData calldata arg) private {
        _positionsController.beforeAssetTransfer(arg);
        AssetTransferData memory argNew = arg;
        argNew.count = _transferToAsset(arg.asset.id, arg.from, arg.count);
        if (!_suppressNotifyListener[arg.asset.id])
            _positionsController.afterAssetTransfer(arg);
    }

    function _transferToAsset(
        uint256 assetId,
        address from,
        uint256 count
    ) internal virtual returns (uint256 countTransferred);

    function getData(uint256 assetId)
        external
        view
        returns (AssetData memory data)
    {
        uint256 positionId = this.getPositionId(assetId);
        AssetData memory data = AssetData(
            address(this),
            assetId,
            this.assetTypeId(),
            positionId,
            _getCode(positionId, assetId),
            this.owner(assetId),
            this.count(assetId),
            this.contractAddr(assetId),
            this.value(assetId)
        );
        return data;
    }

    function getCode(uint256 assetId) external view returns (uint256) {
        return _getCode(this.getPositionId(assetId), assetId);
    }

    function _getCode(uint256 positionId, uint256 assetId)
        private
        view
        returns (uint256)
    {
        (
            ItemRef memory position1,
            ItemRef memory position2
        ) = _positionsController.getAllPositionAssetReferences(positionId);

        if (position1.id == assetId) return 1;
        if (position2.id == assetId) return 2;
        return 0;
    }
}
