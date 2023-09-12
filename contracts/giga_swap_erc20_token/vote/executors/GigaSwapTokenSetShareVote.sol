// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import 'contracts/votes/VoteExecutorBase.sol';
import 'contracts/giga_swap_erc20_token/vote/IGigaSwapTokenSetters.sol';
struct Data {
    uint256 thisSharePpm;
    uint256 stackingSharePpm;
}

contract GigaSwapTokenSetShareVote is VoteExecutorBase {
    mapping(uint256 => Data) public data;

    constructor(
        address voteAddress,
        address writerAddress
    ) VoteExecutorBase(voteAddress, writerAddress) {}

    function startVote(
        uint256 thisSharePpm,
        uint256 stackingSharePpm
    ) external payable {
        (uint256 voteId, ) = _startVote(msg.value, msg.sender);
        data[voteId].thisSharePpm = thisSharePpm;
        data[voteId].stackingSharePpm = stackingSharePpm;
    }

    function _execute(uint256 voteId) internal override {
        IGigaSwapTokenSetters(writer).setShare(
            data[voteId].thisSharePpm,
            data[voteId].stackingSharePpm
        );
    }
}
