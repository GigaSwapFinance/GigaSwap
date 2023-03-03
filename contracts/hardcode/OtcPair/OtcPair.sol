// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
//import 'hardhat/console.sol';

struct Pair {
    IERC20 asset1;
    IERC20 asset2;
    uint256 count1;
    uint256 count2;
}

contract OtcPair {
    mapping(uint256 => Pair) _pairs;
    uint256 _pairsCount;

    event OnCreatePair(uint256 pairId, Pair pair);
    event OnSwap(
        uint256 pairId,
        uint256 lastCount1,
        uint256 lastCount2,
        uint256 newCount1,
        uint256 newCount2
    );

    function createPair(
        address asset1,
        address asset2,
        uint256 count1,
        uint256 count2
    ) external {
        ++_pairsCount;
        Pair memory pair;
        pair.asset1 = IERC20(asset1);
        pair.asset2 = IERC20(asset2);

        uint256 lastCount = IERC20(asset1).balanceOf(address(this));
        IERC20(asset1).transferFrom(msg.sender, address(this), count1);
        pair.count1 = IERC20(asset1).balanceOf(address(this)) - lastCount;

        lastCount = IERC20(asset2).balanceOf(address(this));
        IERC20(asset2).transferFrom(msg.sender, address(this), count2);
        pair.count2 = IERC20(asset2).balanceOf(address(this)) - lastCount;

        _pairs[_pairsCount] = pair;
        emit OnCreatePair(_pairsCount, pair);
    }

    function getPair(uint256 pairId) external view returns (Pair memory) {
        return _pairs[pairId];
    }

    function buy2ForCertain1(uint256 positionId, uint256 asset1Count) external {
        Pair storage pair = _pairs[positionId];
        uint256 lastPairCount1 = pair.count1;
        uint256 lastpairCount2 = pair.count2;
        uint256 lastCount1 = pair.asset1.balanceOf(address(this));

        pair.asset1.transferFrom(msg.sender, address(this), asset1Count);
        uint256 newCount1 = pair.asset1.balanceOf(address(this));
        uint256 transferred1 = newCount1 - lastCount1;

        uint256 buyCount = pair.count2 -
            ((pair.count1 * pair.count2) / (pair.count1 + transferred1));
        pair.asset2.transfer(msg.sender, buyCount);

        // modify pair
        pair.count1 += transferred1;
        pair.count2 -= buyCount;

        emit OnSwap(
            positionId,
            lastPairCount1,
            lastpairCount2,
            pair.count1,
            pair.count2
        );
    }

    function _getBuyCount(
        uint256 inputLastCount,
        uint256 inputNewCount,
        uint256 outputLastCount
    ) internal pure returns (uint256) {
        return
            outputLastCount -
            ((inputLastCount * outputLastCount) / inputNewCount);
    }
}
