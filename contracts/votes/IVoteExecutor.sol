// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

/// @dev executor for wined votes
interface IVoteExecutor {
    /// executes the vote
    function execute(uint256 voteId) external;
}
