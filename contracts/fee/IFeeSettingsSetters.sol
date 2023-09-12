// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

interface IFeeSettingsSetters {
    function setFeeAddress(address newFeeAddress) external;

    function setFeePercent(uint256 newFeePercent) external;

    function setFeeEth(uint256 newFeeEth) external;
}