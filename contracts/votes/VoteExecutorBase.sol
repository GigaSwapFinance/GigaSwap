// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import 'contracts/votes/IVote.sol';
import 'contracts/votes/IVoteExecutor.sol';

abstract contract VoteExecutorBase is IVoteExecutor {
    IVote public immutable vote;
    address public immutable writer;

    constructor(address voteAddress, address writerAddress) {
        vote = IVote(voteAddress);
        writer = writerAddress;
    }

    modifier onlyVote() {
        require(msg.sender == address(vote), 'only for vote contract');
        _;
    }

    function _startVote(
        uint256 value,
        address surplusRevertAddress
    ) internal returns (uint256 voteId, uint256 surplus) {
        uint256 etherPrice = vote.newVoteEtherPrice();
        require(value >= etherPrice, 'not enough ether to start vote');
        voteId = vote.startVote{ value: etherPrice }(msg.sender);
        surplus = value - etherPrice;
        if (surplus > 0) {
            if (surplusRevertAddress != address(0)) {
                (bool sent, ) = payable(surplusRevertAddress).call{
                    value: surplus
                }('');
                require(sent, 'withdraw error: ether is not sent');
                surplus = 0;
            }
        }
    }

    function execute(uint256 voteId) external onlyVote {
        _execute(voteId);
    }

    function _execute(uint256 voteId) internal virtual;
}
