// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import 'contracts/votes/VoteExecutorBase.sol';
import 'contracts/giga_swap_erc20_token/vote/IGigaSwapTokenSetters.sol';

contract GigaSwapTokenSetExtraContractAddressVote is VoteExecutorBase {
    mapping(uint256 => address) public data;

    constructor(
        address voteAddress,
        address writerAddress
    ) VoteExecutorBase(voteAddress, writerAddress) {}

    function startVote(address newValue) external payable {
        (uint256 voteId, ) = _startVote(msg.value, msg.sender);
        data[voteId] = newValue;
    }

    function _execute(uint256 voteId) internal override {
        IGigaSwapTokenSetters(writer).SetExtraContractAddress(data[voteId]);
    }
}
