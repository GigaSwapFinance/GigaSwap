// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import 'contracts/position_trading/algorithms/PositionAlgorithm.sol';
import 'contracts/position_trading/IPositionsController.sol';
import 'contracts/position_trading/PositionSnapshot.sol';
import 'contracts/lib/erc20/Erc20ForFactory.sol';
import 'contracts/position_trading/FeeDistributer.sol';
import 'contracts/position_trading/IFeeDistributer.sol';
import 'contracts/position_trading/algorithms/TradingPair/ITradingPairAlgorithm.sol';
import 'contracts/position_trading/algorithms/TradingPair/FeeSettings.sol';
import 'contracts/position_trading/AssetTransferData.sol';

struct SwapData {
    uint256 inputlastCount;
    uint256 buyCount;
    uint256 lastPrice;
    uint256 newPrice;
    uint256 snapPrice;
    uint256 outFee;
    uint256 priceImpact;
    uint256 slippage;
}

struct SwapSnapshot {
    uint256 input;
    uint256 output;
    uint256 slippage;
}

struct PositionAddingAssets {
    ItemRef ownerAsset;
    ItemRef outputAsset;
}

contract TradingPairAlgorithm is PositionAlgorithm, ITradingPairAlgorithm {
    using ItemRefAsAssetLibrary for ItemRef;

    mapping(uint256 => FeeSettings) public fee;
    mapping(uint256 => address) public liquidityTokens;
    mapping(uint256 => address) public feeTokens;
    mapping(uint256 => address) public feeDistributers;

    event Swap(
        uint256 indexed positionId,
        address indexed account,
        ItemRef inputAsset,
        ItemRef outputAsset,
        uint256 inputCount,
        uint256 outputCount
    );

    constructor(address positionsControllerAddress)
        PositionAlgorithm(positionsControllerAddress)
    {}

    function createAlgorithm(
        uint256 positionId,
        FeeSettings calldata feeSettings
    ) external onlyFactory {
        positionsController.setAlgorithm(positionId, address(this));

        // set fee settings
        fee[positionId] = feeSettings;

        Erc20ForFactory liquidityToken = new Erc20ForFactory(
            'liquidity',
            'LIQ',
            0
        );
        Erc20ForFactory feeToken = new Erc20ForFactory('fee', 'FEE', 0);
        liquidityTokens[positionId] = address(liquidityToken);
        feeTokens[positionId] = address(feeToken);
        (ItemRef memory own, ItemRef memory out) = _getAssets(positionId);
        liquidityToken.mintTo(
            positionsController.ownerOf(positionId),
            own.count() * out.count()
        );
        feeToken.mintTo(msg.sender, own.count() * out.count());
        // create assets for fee
        ItemRef memory feeOwnerAsset = positionsController
            .getAssetReference(positionId, 1)
            .clone(address(this));
        ItemRef memory feeOutputAsset = positionsController
            .getAssetReference(positionId, 2)
            .clone(address(this));
        // create fee distributor
        FeeDistributer feeDistributer = new FeeDistributer(
            address(this),
            address(feeToken),
            feeOwnerAsset,
            feeOutputAsset
        );
        feeDistributers[positionId] = address(feeDistributer);
        // transfer the owner to the fee distributor
        //feeOwnerAsset.transferOwnership(address(feeDistributer)); // todo проверить работоспособность!!!
        //feeOutputAsset.transferOwnership(address(feeDistributer));
    }

    function getFeeSettings(uint256 positionId)
        external
        view
        returns (FeeSettings memory)
    {
        return fee[positionId];
    }

    function _positionLocked(uint256 positionId)
        internal
        view
        override
        returns (bool)
    {
        return address(liquidityTokens[positionId]) != address(0); // position lock automatically, after adding the algorithm
    }

    function _isPermanentLock(uint256 positionId)
        internal
        view
        override
        returns (bool)
    {
        return _positionLocked(positionId); // position lock automatically, after adding the algorithm
    }

    function addLiquidity(
        uint256 positionId,
        uint256 assetCode,
        uint256 count
    ) external payable {
        // position must be created
        require(
            liquidityTokens[positionId] != address(0),
            'position id is not exists'
        );
        uint256 assetBCode = 1;
        if (assetCode == assetBCode) assetBCode = 2;
        // get assets
        ItemRef memory assetA = positionsController.getAssetReference(
            positionId,
            assetCode
        );
        ItemRef memory assetB = positionsController.getAssetReference(
            positionId,
            assetBCode
        );
        // take total supply of liquidity tokens
        Erc20ForFactory liquidityToken = Erc20ForFactory(
            liquidityTokens[positionId]
        );

        uint256 countB = (count * assetB.count()) / assetA.count();

        // save the last asset count
        uint256 lastAssetACount = assetA.count();
        //uint256 lastAssetBCount = assetB.count();
        // transfer from adding assets
        assetA.setNotifyListener(false);
        assetB.setNotifyListener(false);
        uint256[] memory data;
        uint256 lastCountA = assetA.count();
        uint256 lastCountB = assetB.count();
        positionsController.transferToAssetFrom(
            msg.sender,
            positionId,
            assetCode,
            count,
            data
        );
        positionsController.transferToAssetFrom(
            msg.sender,
            positionId,
            assetBCode,
            countB,
            data
        );
        require(
            assetA.count() == lastCountA + count,
            'transferred asset 1 count to pair is not correct'
        );
        require(
            assetB.count() == lastCountB + countB,
            'transferred asset 2 count to pair is not correct'
        );
        assetA.setNotifyListener(true);
        assetB.setNotifyListener(true);
        // mint liquidity tokens
        uint256 liquidityTokensToMint = (liquidityToken.totalSupply() *
            (assetA.count() - lastAssetACount)) / lastAssetACount;
        liquidityToken.mintTo(msg.sender, liquidityTokensToMint);
    }

    function _getAssets(uint256 positionId)
        internal
        view
        returns (ItemRef memory ownerAsset, ItemRef memory outputAsset)
    {
        ItemRef memory ownerAsset = positionsController.getAssetReference(
            positionId,
            1
        );
        ItemRef memory outputAsset = positionsController.getAssetReference(
            positionId,
            2
        );
        require(ownerAsset.id != 0, 'owner asset required');
        require(outputAsset.id != 0, 'output asset required');

        return (ownerAsset, outputAsset);
    }

    function getOwnerAssetPrice(uint256 positionId)
        external
        view
        returns (uint256)
    {
        return _getOwnerAssetPrice(positionId);
    }

    function _getOwnerAssetPrice(uint256 positionId)
        internal
        view
        returns (uint256)
    {
        (ItemRef memory ownerAsset, ItemRef memory outputAsset) = _getAssets(
            positionId
        );
        uint256 ownerCount = ownerAsset.count();
        uint256 outputCount = outputAsset.count();
        require(outputCount > 0, 'has no output count');
        return ownerCount / outputCount;
    }

    function getOutputAssetPrice(uint256 positionId)
        external
        view
        returns (uint256)
    {
        return _getOutputAssetPrice(positionId);
    }

    function _getOutputAssetPrice(uint256 positionId)
        internal
        view
        returns (uint256)
    {
        (ItemRef memory ownerAsset, ItemRef memory outputAsset) = _getAssets(
            positionId
        );
        uint256 ownerCount = ownerAsset.count();
        uint256 outputCount = outputAsset.count();
        require(outputCount > 0, 'has no output count');
        return outputCount / ownerCount;
    }

    function getBuyCount(
        uint256 positionId,
        uint256 inputAssetCode,
        uint256 amount
    ) external view returns (uint256) {
        (ItemRef memory ownerAsset, ItemRef memory outputAsset) = _getAssets(
            positionId
        );
        uint256 inputLastCount;
        uint256 outputLastCount;
        if (inputAssetCode == 1) {
            inputLastCount = ownerAsset.count();
            outputLastCount = outputAsset.count();
        } else if (inputAssetCode == 2) {
            inputLastCount = outputAsset.count();
            outputLastCount = ownerAsset.count();
        } else revert('incorrect asset code');
        return
            _getBuyCount(
                inputLastCount,
                inputLastCount + amount,
                outputLastCount
            );
    }

    function _getBuyCount(
        uint256 inputLastCount,
        uint256 inputNewCount,
        uint256 outputLastCount
    ) internal pure returns (uint256) {
        return
            outputLastCount -
            ((inputLastCount * outputLastCount) / inputNewCount);
    }

    function _afterAssetTransfer(AssetTransferData calldata arg)
        internal
        virtual
        override
    {
        (ItemRef memory ownerAsset, ItemRef memory outputAsset) = _getAssets(
            arg.positionId
        );
        // transfers from assets are not processed
        if (arg.from == ownerAsset.addr || arg.from == outputAsset.addr) return;
        // swap only if editing is locked
        require(
            _positionLocked(arg.positionId), // todo переделать на onlyBuildMode!!!!!!!!!!!!!!!!!
            'swap can be maked only if position editing is locked'
        );
        // if there is no snapshot, then we do nothing
        require(
            arg.data.length == 3,
            'data must be snapshot, where [owner asset, output asset, slippage]'
        );

        // take fee
        FeeSettings memory feeSettings = fee[arg.positionId];
        // make a swap
        if (arg.to == outputAsset.addr)
            // if the exchange is direct
            _swap(
                arg.positionId,
                arg.from,
                arg.count,
                outputAsset,
                ownerAsset,
                feeSettings.outputAsset,
                feeSettings.ownerAsset,
                SwapSnapshot(arg.data[1], arg.data[0], arg.data[2]),
                IFeeDistributer(feeDistributers[arg.positionId]).outputAsset(),
                IFeeDistributer(feeDistributers[arg.positionId]).ownerAsset()
            );
        else
            _swap(
                arg.positionId,
                arg.from,
                arg.count,
                ownerAsset,
                outputAsset,
                feeSettings.ownerAsset,
                feeSettings.outputAsset,
                SwapSnapshot(arg.data[0], arg.data[1], arg.data[2]),
                IFeeDistributer(feeDistributers[arg.positionId]).ownerAsset(),
                IFeeDistributer(feeDistributers[arg.positionId]).outputAsset()
            );
    }

    function _swap(
        uint256 positionId,
        address from,
        uint256 amount,
        ItemRef memory input,
        ItemRef memory output,
        AssetFee memory inputFee,
        AssetFee memory outputFee,
        SwapSnapshot memory snapshot,
        ItemRef memory inputFeeAsset,
        ItemRef memory outputFeeAsset
    ) internal {
        SwapData memory data;
        // count how much bought
        data.inputlastCount = input.count() - amount;
        data.buyCount = _getBuyCount(
            data.inputlastCount,
            input.count(),
            output.count()
        );
        require(data.buyCount <= output.count(), 'not enough asset to buy');

        // count the old price
        data.lastPrice = (data.inputlastCount * 100000) / output.count();
        if (data.lastPrice == 0) data.lastPrice = 1;

        // fee counting
        if (inputFee.input > 0) {
            positionsController.withdrawInternal(
                input,
                inputFeeAsset.addr,
                (inputFee.input * amount) / 10000
            );
        }
        if (outputFee.output > 0) {
            data.outFee = (outputFee.output * data.buyCount) / 10000;
            data.buyCount -= data.outFee;
            positionsController.withdrawInternal(
                output,
                outputFeeAsset.addr,
                data.outFee
            );
        }

        // transfer the asset
        uint256 devFee = (data.buyCount *
            positionsController.getFeeSettings().feePercent()) /
            positionsController.getFeeSettings().feeDecimals();
        if (devFee > 0) {
            positionsController.withdrawInternal(
                output,
                positionsController.getFeeSettings().feeAddress(),
                devFee
            );
            positionsController.withdrawInternal(
                output,
                from,
                data.buyCount - devFee
            );
        } else {
            positionsController.withdrawInternal(output, from, data.buyCount);
        }

        // count the old price
        data.newPrice = (input.count() * 100000) / output.count();
        if (data.newPrice == 0) data.newPrice = 1;

        // count the snapshot price
        data.snapPrice = (snapshot.input * 100000) / snapshot.output;
        if (data.snapPrice == 0) data.snapPrice = 1;
        // slippage limiter
        if (data.newPrice >= data.snapPrice)
            data.slippage = (data.newPrice * 100000) / data.snapPrice;
        else data.slippage = (data.snapPrice * 100000) / data.newPrice;
        require(
            data.slippage <= snapshot.slippage,
            'price has changed by more than slippage'
        );

        // price should not change more than 50%
        data.priceImpact = (data.newPrice * 100000) / data.lastPrice;
        require(data.priceImpact < 150000, 'too large price impact');

        // event
        emit Swap(positionId, from, input, output, amount, data.buyCount);
    }

    function withdraw(uint256 positionId, uint256 liquidityCount) external {
        // take a token
        address liquidityAddr = liquidityTokens[positionId];
        require(
            liquidityAddr != address(0),
            'algorithm has no liquidity tokens'
        );
        // take assets
        (ItemRef memory own, ItemRef memory out) = _getAssets(positionId);
        // withdraw of owner asset
        positionsController.withdrawInternal(
            own,
            msg.sender,
            (own.count() * liquidityCount) /
                Erc20ForFactory(liquidityAddr).totalSupply()
        );
        // withdraw asset output
        positionsController.withdrawInternal(
            out,
            msg.sender,
            (out.count() * liquidityCount) /
                Erc20ForFactory(liquidityAddr).totalSupply()
        );

        // burn liquidity token
        Erc20ForFactory(liquidityAddr).burn(msg.sender, liquidityCount);
    }

    function checkCanWithdraw(
        ItemRef calldata asset,
        uint256 assetCode,
        uint256 count
    ) external view {
        require(
            !this.positionLocked(asset.getPositionId()),
            'position is locked'
        );
    }

    function getSnapshot(uint256 positionId, uint256 slippage)
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return (
            positionsController.getAssetReference(positionId, 1).count(),
            positionsController.getAssetReference(positionId, 2).count(),
            100000 + slippage
        );
    }

    function liquidityToken(uint256 positionId)
        external
        view
        returns (address)
    {
        return liquidityTokens[positionId];
    }
}
