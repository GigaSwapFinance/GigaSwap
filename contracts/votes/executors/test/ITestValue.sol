// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

interface ITestValue {
    function getValue() external view returns (uint256);
    function setValue(uint256 value) external;
}
