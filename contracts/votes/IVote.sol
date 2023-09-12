// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import './VoteData.sol';

interface IVote {
    /// @dev new vote created
    event NewVote(uint256 indexed voteId, address indexed executor);
    /// @dev execute vote result
    event ExecuteVote(uint256 indexed voteId, address indexed executor);
    /// @dev the user make vote
    event UserVote(
        uint256 indexed voteId,
        address indexed executor,
        address account
    );

    /// @dev total votes count
    function totalVotesCount() external view returns (uint256);

    /// @dev returns the data of the vote
    function getVote(
        uint256 id
    ) external view returns (VoteData memory data, bool isEnd);

    /// @dev makes vote
    function vote(uint256 voteId, bool voteValue) external;

    /// @dev returns true if account can claim reward after vote
    function canClaim(
        uint256 voteId,
        address account
    ) external view returns (bool);

    /// @dev returns true if account claimed reward after vote
    function isClaimed(
        uint256 voteId,
        address account
    ) external view returns (bool);

    /// @dev claim ether after vote
    function claim(uint256 voteId) external;

    /// @dev current vote ether reward
    function voteEtherRewardCount(uint256 voteId) external view returns (uint256);

    /// @dev starts new vote and returns its ID
    /// onlyFactory
    function startVote(address owner) external payable returns (uint256);

    /// @dev returns true if vote time is end
    function isVoteEnd(uint256 voteId) external view returns (bool);

    /// @dev vote lapsed seconds
    function voteLapsedSeconds(uint256 voteId) external view returns (uint256);

    /// @dev executes the vote (if ended and win and not yet executed)
    function execute(uint256 voteId) external;

    /// @dev if true than vote can be executed
    function canExecute(uint256 voteId) external view returns (bool);

    /// @dev new vote ethers fee
    function newVoteEtherPrice() external view returns (uint256);

    /// @dev returns the user vote
    /// 0 - has no vote
    /// 1 - for
    /// 2 - against
    function userVote(
        uint256 voteId,
        address account
    ) external view returns (uint256);
}
