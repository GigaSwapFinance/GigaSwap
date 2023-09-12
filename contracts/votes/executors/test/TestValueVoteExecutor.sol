// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import './ITestValue.sol';
import 'contracts/votes/VoteExecutorBase.sol';

contract TestValueVoteExecutor is VoteExecutorBase {
    mapping(uint256 => uint256) _executeData;

    constructor(
        address voteAddress,
        address writerAddress
    ) VoteExecutorBase(voteAddress, writerAddress) {}

    function startVote(uint256 newValue) external payable {
        (uint256 voteId, ) = _startVote(msg.value, msg.sender);
        _executeData[voteId] = newValue;
    }

    function _execute(uint256 voteId) internal override {
        ITestValue(writer).setValue(_executeData[voteId]);
    }
}
