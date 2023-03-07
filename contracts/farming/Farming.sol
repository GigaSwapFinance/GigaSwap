// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import 'hardhat/console.sol';

import './IFarming.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

struct Erc20Info {
    uint256 intervalNumber; // the last known claim interval (uses for update totalCountForClaim)
    uint256 totalCountOnInterval;
}

contract Farming is IFarming {
    using SafeERC20 for IERC20;
    IERC20 _stackingContract; // erc20 contract for stacking
    mapping(address => Stack) _stacks; // stacks by users
    uint256 constant _timeInterval = 1 weeks; // reward interval time length
    uint256 _nextIntervalTime; // next interval time
    uint256 _intervalNumber; // current interval number
    uint256 _totalStacksOnInterval; // current interval total stacks count
    uint256 _totalEthOnInterval; // current interval eth rewards
    mapping(address => Erc20Info) _erc20nfos; // information about each erc20 (at current interval)
    mapping(address => uint256) _ethClaimIntervals; // users eth claim intervals
    mapping(address => mapping(address => uint256)) _erc20ClaimIntervals; // [account][erc20] cache of last erc20 claim intervals for accounts

    uint256 _creationTime;

    constructor(address stackingContract) {
        _stackingContract = IERC20(stackingContract);
        _creationTime = block.timestamp;
    }

    receive() external payable {}

    function timeIntervalLength() external pure returns (uint256) {
        return _timeInterval;
    }

    function intervalNumber() external view returns (uint256) {
        if (block.timestamp >= this.nextIntervalTime())
            return _intervalNumber + 1;
        return _intervalNumber;
    }

    function nextIntervalTime() external view returns (uint256) {
        if (_intervalNumber == 0) return _creationTime + _timeInterval;
        return _nextIntervalTime;
    }

    function nextIntervalLapsedSeconds() external view returns (uint256) {
        if (block.timestamp >= this.nextIntervalTime()) return 0;
        return (this.nextIntervalTime() - block.timestamp) / (1 seconds);
    }

    function getStack(address account) external view returns (Stack memory) {
        return _stacks[account];
    }

    function addStack(uint256 count) external returns (Stack memory) {
        _nextInterval();
        uint256 lastCount = _stackingContract.balanceOf(address(this));
        _stackingContract.transferFrom(msg.sender, address(this), count);
        uint256 added = _stackingContract.balanceOf(address(this)) - lastCount;
        _stacks[msg.sender].count += added;
        _stacks[msg.sender].creationInterval = _intervalNumber;
        emit OnAddStack(msg.sender, _stacks[msg.sender], added);
        return _stacks[msg.sender];
    }

    function addFullStack() external returns (Stack memory) {
        return this.addStack(_stackingContract.balanceOf(msg.sender));
    }

    function removeStack(uint256 count) external returns (Stack memory) {
        _nextInterval();
        require(_stacks[msg.sender].count >= count, 'not enough stack count');
        uint256 lastCount = _stackingContract.balanceOf(address(this));
        _stackingContract.transfer(msg.sender, count);
        uint256 removed = lastCount -
            _stackingContract.balanceOf(address(this));
        _stacks[msg.sender].count -= removed;
        emit OnRemoveStack(msg.sender, _stacks[msg.sender], removed);
        return _stacks[msg.sender];
    }

    function removeFullStack() external returns (Stack memory) {
        return this.removeStack(_stacks[msg.sender].count);
    }

    function totalStacks() external view returns (uint256) {
        return _stackingContract.balanceOf(address(this));
    }

    function totalStacksOnInterval() external view returns (uint256) {
        if (this.intervalNumber() <= _intervalNumber)
            return _totalStacksOnInterval;
        return _stackingContract.balanceOf(address(this));
    }

    function ethTotal() external view returns (uint256) {
        return address(this).balance;
    }

    function erc20Total(address erc20) external view returns (uint256) {
        return IERC20(erc20).balanceOf(address(this));
    }

    function ethOnInterval() external view returns (uint256) {
        if (this.intervalNumber() <= _intervalNumber)
            return _totalEthOnInterval;
        return address(this).balance;
    }

    function erc20OnInterval(address erc20) external view returns (uint256) {
        return
            _expectedErc20Info(erc20, this.intervalNumber())
                .totalCountOnInterval;
    }

    function _expectedErc20Info(address erc20, uint256 expectedIntervalNumber)
        internal
        view
        returns (Erc20Info memory)
    {
        Erc20Info memory info = _erc20nfos[erc20];
        if (expectedIntervalNumber <= info.intervalNumber) return info;
        info.intervalNumber = expectedIntervalNumber;
        info.totalCountOnInterval = IERC20(erc20).balanceOf(address(this));
        return info;
    }

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

    function erc20ClaimIntervalForAccount(address account, address erc20)
        external
        view
        returns (uint256)
    {
        uint256 interval = _erc20ClaimIntervals[account][erc20];
        if (_stacks[account].creationInterval > interval)
            interval = _stacks[account].creationInterval;
        return interval + 1;
    }

    function ethClaimCountForAccount(address account)
        external
        view
        returns (uint256)
    {
        if (this.ethClaimIntervalForAccount(account) > this.intervalNumber())
            return 0;
        return this.ethClaimCountForStack(_stacks[account].count);
    }

    function erc20ClaimCountForAccount(address account, address erc20)
        external
        view
        returns (uint256)
    {
        if (
            this.erc20ClaimIntervalForAccount(account, erc20) >
            this.intervalNumber()
        ) return 0;
        return this.erc20ClaimCountForStack(_stacks[account].count, erc20);
    }

    function ethClaimCountForAccountExpect(address account)
        external
        view
        returns (uint256)
    {
        return this.ethClaimCountForStackExpect(_stacks[account].count);
    }

    function erc20ClaimCountForAccountExpect(address account, address erc20)
        external
        view
        returns (uint256)
    {
        return
            this.erc20ClaimCountForStackExpect(_stacks[account].count, erc20);
    }

    function ethClaimCountForStackExpect(uint256 stackSize)
        external
        view
        returns (uint256)
    {
        return
            _claimCountForStack(
                stackSize,
                this.totalStacks(),
                address(this).balance
            );
    }

    function erc20ClaimCountForStackExpect(uint256 stackSize, address erc20)
        external
        view
        returns (uint256)
    {
        return
            _claimCountForStack(
                stackSize,
                this.totalStacks(),
                IERC20(erc20).balanceOf(address(this))
            );
    }

    function ethClaimCountForNewStackExpect(uint256 stackSize)
        external
        view
        returns (uint256)
    {
        return
            _claimCountForStack(
                stackSize,
                this.totalStacks() + stackSize,
                address(this).balance
            );
    }

    function erc20ClaimCountForNewStackExpect(uint256 stackSize, address erc20)
        external
        view
        returns (uint256)
    {
        return
            _claimCountForStack(
                stackSize,
                this.totalStacks() + stackSize,
                IERC20(erc20).balanceOf(address(this))
            );
    }

    function ethClaimCountForStack(uint256 stackSize)
        external
        view
        returns (uint256)
    {
        return
            _claimCountForStack(
                stackSize,
                this.totalStacksOnInterval(),
                this.ethOnInterval()
            );
    }

    function erc20ClaimCountForStack(uint256 stackSize, address erc20)
        external
        view
        returns (uint256)
    {
        return
            _claimCountForStack(
                stackSize,
                this.totalStacksOnInterval(),
                this.erc20OnInterval(erc20)
            );
    }

    function _claimCountForStack(
        uint256 stackCount,
        uint256 totalStacksOnInterwal,
        uint256 assetCountOnInterwal
    ) internal pure returns (uint256) {
        if (stackCount > totalStacksOnInterwal) return assetCountOnInterwal;
        if (totalStacksOnInterwal == 0) return 0;
        return (stackCount * assetCountOnInterwal) / totalStacksOnInterwal;
    }

    function erc20ClaimForStack(address erc20, uint256 stackCount)
        external
        view
        returns (uint256)
    {
        return
            _claimCountForStack(
                stackCount,
                this.totalStacksOnInterval(),
                this.erc20OnInterval(erc20)
            );
    }

    function _nextInterval() internal returns (bool) {
        if (block.timestamp < this.nextIntervalTime()) return false;
        _totalStacksOnInterval = this.totalStacks();
        _nextIntervalTime = block.timestamp + _timeInterval;
        _totalEthOnInterval = address(this).balance;
        ++_intervalNumber;
        emit OnNextInterval(_intervalNumber);
        return true;
    }

    function claimEth() external {
        _nextInterval();
        require(
            this.ethClaimIntervalForAccount(msg.sender) <= _intervalNumber,
            'can not claim on current interval'
        );
        _ethClaimIntervals[msg.sender] = _intervalNumber;
        uint256 claimCount = _claimCountForStack(
            _stacks[msg.sender].count,
            _totalStacksOnInterval,
            _totalEthOnInterval
        );
        require(claimCount > 0, 'notging to claim');
        (bool sent, ) = payable(msg.sender).call{ value: claimCount }('');
        require(sent, 'sent ether error: ether is not sent');
        emit OnClaimEth(msg.sender, _stacks[msg.sender], claimCount);
    }

    function claimErc20(address erc20) external {
        // move interval
        _nextInterval();
        // move erc20 to interval
        Erc20Info storage info = _erc20nfos[erc20];
        if (_intervalNumber > info.intervalNumber) {
            info.intervalNumber = _intervalNumber;
            info.totalCountOnInterval = IERC20(erc20).balanceOf(address(this));
        }

        require(
            this.erc20ClaimIntervalForAccount(msg.sender, erc20) <=
                _intervalNumber,
            'can not claim on current interval'
        );
        _erc20ClaimIntervals[msg.sender][erc20] = _intervalNumber;
        uint256 claimCount = _claimCountForStack(
            _stacks[msg.sender].count,
            _totalStacksOnInterval,
            info.totalCountOnInterval
        );
        require(claimCount > 0, 'nothing to claim');
        IERC20(erc20).safeTransfer(msg.sender, claimCount);
        emit OnClaimErc20(msg.sender, _stacks[msg.sender], claimCount);
    }
}
