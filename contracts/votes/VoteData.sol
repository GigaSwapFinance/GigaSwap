// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

struct VoteData {
    address owner;
    uint256 endTime;
    uint256 etherCount;
    uint256 erc20Count;
    uint256 forCount;
    uint256 againstCount;
    bool executed; // is vote is used after win and executed
    address executor; // the executing contract for vote
}