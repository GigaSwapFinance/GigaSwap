// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import './IFeeSettings.sol';

contract FeeSettingsDecorator is IFeeSettings {
    IFeeSettings public immutable feeSettings;

    constructor(address feeSettingsAddress) {
        feeSettings = IFeeSettings(feeSettingsAddress);
    }

    function zeroFeeShare() external view virtual returns (uint256) {
        return feeSettings.zeroFeeShare();
    }

    function feeAddress() external view virtual returns (address) {
        return feeSettings.feeAddress();
    }

    function feePercent() external view virtual returns (uint256) {
        return feeSettings.feePercent();
    }

    function feePercentFor(address account) external view returns (uint256) {
        return feeSettings.feePercentFor(account);
    }

    function feeDecimals() external view returns (uint256) {
        return feeSettings.feeDecimals();
    }

    function feeEth() external view virtual returns (uint256) {
        return feeSettings.feeEth();
    }

    function feeEthFor(address account) external view returns (uint256) {
        return feeSettings.feeEthFor(account);
    }
}
