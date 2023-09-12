// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

interface IFeeSettings {
    function feeAddress() external view returns (address); // address to pay fee

    function feePercent() external view returns (uint256); // fee in 1/decimals for dividing values

    function feePercentFor(address account) external view returns (uint256); // fee in 1/decimals for dividing values

    function feeDecimals() external view returns (uint256); // fee decimals

    function feeEth() external view returns (uint256); // fee value for not dividing deal points

    function feeEthFor(address account) external view returns (uint256); // fee in 1/decimals for dividing values

    function zeroFeeShare() external view returns (uint256); // if this account balance than zero fee
}
