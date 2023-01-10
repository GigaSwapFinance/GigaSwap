// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import 'contracts/position_trading/ItemRef.sol';

interface IFeeDistributer {
    function ownerAsset() external view returns (ItemRef memory);

    function outputAsset() external view returns (ItemRef memory);
}
