// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import './VoteData.sol';
import './IVote.sol';
import './IVoteExecutor.sol';
import 'contracts/lib/factories/HasFactories.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract Vote is IVote, HasFactories {
    uint256 _newVoteEtherPrice = 1e17;
    uint256 _newVoteERC20Price = 300000000 * 1e9;
    uint256 _voteTimer = 48 hours;
    IERC20 _erc20;

    uint256 _votesCount;
    mapping(uint256 => VoteData) _votes;
    mapping(uint256 => mapping(address => uint8)) _userVotes; // 1- for 2 - against
    mapping(uint256 => mapping(address => bool)) _userClaims;

    constructor(address erc20Address) {
        _erc20 = IERC20(erc20Address);
    }

    function erc20Address() external view returns (address) {
        return address(_erc20);
    }

    function totalVotesCount() external view returns (uint256) {
        return _votesCount;
    }

    function getVote(
        uint256 id
    ) external view returns (VoteData memory data, bool isEnd) {
        data = _votes[id];
        isEnd = _isVoteEnd(data);
    }

    function startVote(
        address owner
    ) external payable onlyFactory returns (uint256) {
        // check ether sum
        require(
            msg.value >= _newVoteEtherPrice,
            'not enough ether price for start vote'
        );
        // send ether surplus
        uint256 surplus = msg.value - _newVoteEtherPrice;
        if (surplus > 0) _sendEther(msg.sender, surplus);

        // transfer erc20
        if (_newVoteERC20Price > 0)
            _erc20.transferFrom(owner, address(this), _newVoteERC20Price);

        // create new vote
        ++_votesCount;
        _votes[_votesCount].endTime = block.timestamp + _voteTimer;
        _votes[_votesCount].etherCount = _newVoteEtherPrice;
        _votes[_votesCount].erc20Count = _newVoteERC20Price;
        _votes[_votesCount].executor = msg.sender;
        _votes[_votesCount].owner = owner;

        // emit event
        emit NewVote(_votesCount, msg.sender);

        // returns result
        return _votesCount;
    }

    function vote(uint256 voteId, bool voteValue) external {
        VoteData storage data = _getExistingVote(voteId);
        require(
            _userVotes[voteId][msg.sender] == 0,
            'already voted by this address'
        );
        require(!_isVoteEnd(data), 'can not vote - vote end');

        if (voteValue) {
            ++data.forCount;
            _userVotes[voteId][msg.sender] = 1;
        } else {
            ++data.againstCount;
            _userVotes[voteId][msg.sender] = 2;
        }

        emit UserVote(voteId, data.executor, msg.sender);
    }

    function userVote(
        uint256 voteId,
        address account
    ) external view returns (uint256) {
        return _userVotes[voteId][msg.sender];
    }

    function isVoteEnd(uint256 voteId) external view returns (bool) {
        VoteData storage data = _getExistingVote(voteId);
        return _isVoteEnd(data);
    }

    function voteLapsedSeconds(uint256 voteId) external view returns (uint256) {
        return _voteLapsedSeconds(_getExistingVote(voteId));
    }

    function _voteLapsedSeconds(
        VoteData memory data
    ) internal view returns (uint256) {
        if (block.timestamp >= data.endTime) return 0;
        return data.endTime - block.timestamp;
    }

    function _isVoteEnd(VoteData memory data) internal view returns (bool) {
        return block.timestamp >= data.endTime;
    }

    function canExecute(uint256 voteId) external view returns (bool) {
        return _canExecute(voteId);
    }

    function _canExecute(uint256 voteId) internal view returns (bool) {
        VoteData storage data = _getExistingVote(voteId);
        return
            _isVoteEnd(data) &&
            !data.executed &&
            data.forCount > 0 &&
            data.forCount > data.againstCount;
    }

    function execute(uint256 voteId) external {
        require(_canExecute(voteId), 'vote can not be executed');
        VoteData storage data = _getExistingVote(voteId);
        data.executed = true;
        IVoteExecutor(data.executor).execute(voteId);
        emit ExecuteVote(voteId, data.executor);
    }

    function _getExistingVote(
        uint256 voteId
    ) internal view returns (VoteData storage) {
        VoteData storage data = _votes[voteId];
        require(data.executor != address(0), 'vote id is not exists');
        return data;
    }

    function newVoteEtherPrice() external view returns (uint256) {
        return _newVoteEtherPrice;
    }

    function newVoteErc20Price() external view returns (uint256) {
        return _newVoteERC20Price;
    }

    function canClaim(
        uint256 voteId,
        address account
    ) external view returns (bool) {
        return _canClaim(voteId, _getExistingVote(voteId), account);
    }

    function _canClaim(
        uint256 voteId,
        VoteData storage data,
        address account
    ) internal view returns (bool) {
        if (!_isVoteEnd(data)) return false;
        if (_userClaims[voteId][account]) return false;
        uint256 sum = data.forCount + data.againstCount;
        if (sum == 0 && account == data.owner) return true;
        if (_userVotes[voteId][account] == 0) return false;

        return true;
    }

    function isClaimed(
        uint256 voteId,
        address account
    ) external view returns (bool) {
        return _userClaims[voteId][account];
    }

    function claim(uint256 voteId) external {
        VoteData storage data = _getExistingVote(voteId);
        require(
            _canClaim(voteId, data, msg.sender),
            'can not claim vote reward'
        );
        _userClaims[voteId][msg.sender] = true;
        _sendEther(msg.sender, _voteEtherRewardCount(data));
        uint256 erc20RewardCount = _voteErc20RewardCount(data);
        if (erc20RewardCount > 0) _erc20.transfer(msg.sender, erc20RewardCount);
    }

    function voteEtherRewardCount(
        uint256 voteId
    ) external view returns (uint256) {
        return _voteEtherRewardCount(_getExistingVote(voteId));
    }

    function voteErc20RewardCount(
        uint256 voteId
    ) external view returns (uint256) {
        return _voteErc20RewardCount(_getExistingVote(voteId));
    }

    function _voteEtherRewardCount(
        VoteData storage data
    ) internal view returns (uint256) {
        uint256 sum = data.forCount + data.againstCount;
        if (sum == 0) return data.etherCount;
        return data.etherCount / sum;
    }

    function _voteErc20RewardCount(
        VoteData storage data
    ) internal view returns (uint256) {
        uint256 sum = data.forCount + data.againstCount;
        if (sum == 0) return data.erc20Count;
        return data.erc20Count / sum;
    }

    function _sendEther(address to, uint256 etherValue) internal {
        (bool sent, ) = payable(to).call{ value: etherValue }('');
        require(sent, 'error: ether is not sent');
    }
}
