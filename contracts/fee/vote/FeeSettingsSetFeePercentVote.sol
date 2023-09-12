// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import 'contracts/fee/IFeeSettingsSetters.sol';
import 'contracts/votes/VoteExecutorBase.sol';

contract FeeSettingsSetFeePercentVote is VoteExecutorBase {
    mapping(uint256 => uint256) public data;

    constructor(
        address voteAddress,
        address writerAddress
    ) VoteExecutorBase(voteAddress, writerAddress) {}

    function startVote(uint256 newValue) external payable {
        (uint256 voteId, ) = _startVote(msg.value, msg.sender);
        data[voteId] = newValue;
    }

    function _execute(uint256 voteId) internal override {
        IFeeSettingsSetters(writer).setFeePercent(data[voteId]);
    }
}
