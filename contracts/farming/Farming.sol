// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

struct Stack {
    uint256 count;
    uint256 creationInterval;
}

contract Farming {
    using SafeERC20 for IERC20;
    // stacking contract
    IERC20 _stackingContract;
    // user stacks
    mapping(address => Stack) _stacks;
    uint256 _stacksTotalCount;
    // reward interval time
    uint256 constant _timeInterval = 1 weeks;
    // next interval times
    uint256 _nextEthIntervalTime;
    mapping(address => uint256) _nextErc20IntervalTime;
    // current interval number
    uint256 _ethIntervalNumber;
    mapping(address => uint256) _erc20IntervalNumber;
    // current interval rewards
    uint256 _totalEthForClaimOnInterval;
    mapping(address => uint256) _totalErc20ForClaimOnInterval;
    // users claim intervals
    mapping(address => uint256) _ethClaimIntervals;
    mapping(address => mapping(address => uint256)) _erc20ClaimIntervals; // [account][erc20] cache

    uint256 _creationTime;

    // existing events
    event OnAddStack(address indexed account, Stack stack, uint256 count);
    event OnRemoveStack(address indexed account, Stack stack, uint256 count);
    event OnClaimEth(address indexed account, Stack stack, uint256 count);
    event OnClaimErc20(address indexed account, Stack stack, uint256 count);

    constructor(address stackingContract) {
        _stackingContract = IERC20(stackingContract);
        _creationTime = block.timestamp;
    }

    receive() external payable {}

    function getStack(address account) external view returns (Stack memory) {
        return _stacks[account];
    }

    function addStack(uint256 count) external returns (Stack memory) {
        uint256 lastCount = _stackingContract.balanceOf(address(this));
        _stackingContract.transferFrom(msg.sender, address(this), count);
        uint256 added = _stackingContract.balanceOf(address(this)) - lastCount;
        _stacks[msg.sender].count += added;
        _stacks[msg.sender].creationInterval = _ethIntervalNumber;
        _stacksTotalCount += added;
        emit OnAddStack(msg.sender, _stacks[msg.sender], added);
        return _stacks[msg.sender];
    }

    function removeStack(uint256 count) external returns (Stack memory) {
        require(_stacks[msg.sender].count >= count, 'not enough stack count');
        uint256 lastCount = _stackingContract.balanceOf(address(this));
        _stackingContract.transfer(msg.sender, count);
        uint256 removed = lastCount -
            _stackingContract.balanceOf(address(this));
        _stacks[msg.sender].count -= removed;
        _stacksTotalCount -= removed;
        emit OnRemoveStack(msg.sender, _stacks[msg.sender], removed);
        return _stacks[msg.sender];
    }

    function ethIntervalNumber() external view returns (uint256) {
        if (block.timestamp >= this.nextEthIntervalTime())
            return _ethIntervalNumber + 1;
        return _ethIntervalNumber;
    }

    function erc20IntervalNumber(address erc20)
        external
        view
        returns (uint256)
    {
        if (block.timestamp >= this.nextErc20IntervalTime(erc20))
            return _erc20IntervalNumber[erc20] + 1;
        return _erc20IntervalNumber[erc20];
    }

    function timeInterval() external pure returns (uint256) {
        return _timeInterval;
    }

    function nextEthIntervalTime() external view returns (uint256) {
        if (_ethIntervalNumber == 0) return _creationTime + _timeInterval;
        return _nextEthIntervalTime;
    }

    function nextErc20IntervalTime(address erc20)
        external
        view
        returns (uint256)
    {
        if (_erc20IntervalNumber[erc20] == 0)
            return _creationTime + _timeInterval;
        return _nextErc20IntervalTime[erc20];
    }

    function nextEthIntervalLapsedSeconds() external view returns (uint256) {
        if (block.timestamp >= this.nextEthIntervalTime()) return 0;
        return (this.nextEthIntervalTime() - block.timestamp) / (1 seconds);
    }

    function nextErc20IntervalLapsedSeconds(address erc20)
        external
        view
        returns (uint256)
    {
        if (block.timestamp >= this.nextErc20IntervalTime(erc20)) return 0;
        return
            (this.nextErc20IntervalTime(erc20) - block.timestamp) / (1 seconds);
    }

    function stacksTotalCount() external view returns (uint256) {
        return _stacksTotalCount;
    }

    function totalEthForClaimOnInterval() external view returns (uint256) {
        if (block.timestamp >= this.nextEthIntervalTime()) {
            return address(this).balance;
        }
        return _totalEthForClaimOnInterval;
    }

    function totalErc20ForClaimOnInterval(address erc20)
        external
        view
        returns (uint256)
    {
        if (block.timestamp >= this.nextErc20IntervalTime(erc20)) {
            return IERC20(erc20).balanceOf(address(this));
        }
        return _totalErc20ForClaimOnInterval[erc20];
    }

    /// @dev the interval from which an account can claim ethereum rewards
    /// sets to next interval if add stack or claim eth
    function ethClaimIntervalForAccount(address account)
        external
        view
        returns (uint256)
    {
        uint256 interval = _ethClaimIntervals[account];
        if (_stacks[account].creationInterval > interval)
            interval = _stacks[account].creationInterval;
        return interval + 1;
    }

    /// @dev the interval from which an account can claim erc20 rewards
    /// sets to next interval if add stack or claim eth
    function erc20ClaimIntervalForAccount(address erc20, address account)
        external
        view
        returns (uint256)
    {
        uint256 interval = _erc20ClaimIntervals[account][erc20];
        if (_stacks[account].creationInterval > interval)
            interval = _stacks[account].creationInterval;
        return interval + 1;
    }

    function claimEth() external {
        _nextEthInterval();
        require(
            this.ethClaimIntervalForAccount(msg.sender) <= _ethIntervalNumber,
            'can not claim on current interval'
        );
        _ethClaimIntervals[msg.sender] = _ethIntervalNumber;
        uint256 claimCount = this.ethClaimForStack(_stacks[msg.sender].count);
        require(claimCount > 0, 'notging to claim');
        (bool sent, ) = payable(msg.sender).call{ value: claimCount }('');
        require(sent, 'sent ether error: ether is not sent');
        emit OnClaimEth(msg.sender, _stacks[msg.sender], claimCount);
    }

    function claimErc20(address erc20) external {
        _nextErc20Interval(erc20);
        require(
            this.erc20ClaimIntervalForAccount(erc20, msg.sender) <=
                _erc20IntervalNumber[erc20],
            'can not claim on current interval'
        );
        _erc20ClaimIntervals[msg.sender][erc20] = _erc20IntervalNumber[erc20];
        uint256 claimCount = this.erc20ClaimForStack(
            erc20,
            _stacks[msg.sender].count
        );
        require(claimCount > 0, 'notging to claim');
        IERC20(erc20).safeTransfer(msg.sender, claimCount);
        emit OnClaimErc20(msg.sender, _stacks[msg.sender], claimCount);
    }

    function expectedClaimEth(address account) external view returns (uint256) {
        // get expected interval number
        uint256 expectedIntervalNumber = _ethIntervalNumber;
        uint256 expectedTotalForClaimOnInterval = _totalEthForClaimOnInterval;
        if (block.timestamp >= this.nextEthIntervalTime()) {
            ++expectedIntervalNumber;
            expectedTotalForClaimOnInterval = address(this).balance;
        }
        // check conditions
        if (this.ethClaimIntervalForAccount(account) > expectedIntervalNumber)
            return 0;
        // get expected count
        return
            (_stacks[account].count * expectedTotalForClaimOnInterval) /
            _stacksTotalCount;
    }

    function expectedClaimErc20(address erc20, address account)
        external
        view
        returns (uint256)
    {
        // get expected interval number
        uint256 expectedIntervalNumber = _erc20IntervalNumber[erc20];
        uint256 expectedTotalForClaimOnInterval = _totalErc20ForClaimOnInterval[
            erc20
        ];
        if (block.timestamp >= this.nextErc20IntervalTime(erc20)) {
            ++expectedIntervalNumber;
            expectedTotalForClaimOnInterval = IERC20(erc20).balanceOf(
                address(this)
            );
        }
        // check conditions
        if (
            this.erc20ClaimIntervalForAccount(erc20, account) >
            expectedIntervalNumber
        ) return 0;
        // get expected count
        return
            (_stacks[account].count * expectedTotalForClaimOnInterval) /
            _stacksTotalCount;
    }

    function ethClaimForStack(uint256 stackCount)
        external
        view
        returns (uint256)
    {
        if (_stacksTotalCount == 0) return 0;
        return (stackCount * _totalEthForClaimOnInterval) / _stacksTotalCount;
    }

    function erc20ClaimForStack(address erc20, uint256 stackCount)
        external
        view
        returns (uint256)
    {
        if (_stacksTotalCount == 0) return 0;
        return
            (stackCount * _totalErc20ForClaimOnInterval[erc20]) /
            _stacksTotalCount;
    }

    function getErc20Reward(address token) external {}

    function _nextEthInterval() internal returns (bool) {
        if (block.timestamp < this.nextEthIntervalTime()) return false;
        _nextEthIntervalTime = block.timestamp + _timeInterval;
        _totalEthForClaimOnInterval = address(this).balance;
        ++_ethIntervalNumber;
        return true;
    }

    function _nextErc20Interval(address erc20) internal returns (bool) {
        if (block.timestamp < this.nextErc20IntervalTime(erc20)) return false;
        _nextErc20IntervalTime[erc20] = block.timestamp + _timeInterval;
        _totalErc20ForClaimOnInterval[erc20] = IERC20(erc20).balanceOf(
            address(this)
        );
        ++_erc20IntervalNumber[erc20];
        return true;
    }
}
