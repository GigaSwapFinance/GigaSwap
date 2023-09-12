// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import './ITestValue.sol';

contract TestValue is ITestValue {
    uint256 _value;

    function getValue() external view returns (uint256) {
        return _value;
    }

    function setValue(uint256 value) external {
        _value = value;
    }
}
