// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import './IOwnable.sol';

contract Ownable is IOwnable {
    address _owner;

    constructor() {
        _owner = msg.sender;
    }

    modifier onlyOwner() {
        require(_owner == msg.sender, 'caller is not the owner');
        _;
    }

    function owner() external virtual view returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) external override onlyOwner {
        _owner = newOwner;
    }
}
