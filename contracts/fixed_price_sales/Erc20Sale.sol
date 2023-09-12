// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import 'contracts/fee/IFeeSettings.sol';
import './IErc20Sale.sol';
import './IErc20SaleCounterOffer.sol';
import '../lib/ownable/Ownable.sol';

contract Erc20Sale is IErc20Sale, IErc20SaleCounterOffer {
    using SafeERC20 for IERC20;

    uint8 public constant WHITELIST_FLAG = 1 << 0;
    uint8 public constant BUYLIMIT_FLAG = 1 << 1;

    IFeeSettings immutable _feeSettings;
    mapping(uint256 => PositionData) _positions;
    mapping(uint256 => mapping(address => bool)) _whiteLists;
    mapping(uint256 => uint256) _limits;
    mapping(uint256 => mapping(address => uint256)) _usedLimits;
    mapping(uint256 => OfferData) _offers;
    uint256 public totalOffers;
    uint256 _totalPositions;

    constructor(address feeSettings) {
        _feeSettings = IFeeSettings(feeSettings);
    }

    event OnCreate(
        uint256 indexed positionId,
        address indexed owner,
        address asset1,
        address asset2,
        uint256 priceNom,
        uint256 priceDenom
    );
    event OnBuy(
        uint256 indexed positionId,
        address indexed account,
        uint256 count
    );
    event OnPrice(
        uint256 indexed positionId,
        uint256 priceNom,
        uint256 priceDenom
    );
    event OnWithdraw(
        uint256 indexed positionId,
        uint256 assetCode,
        address to,
        uint256 count
    );
    event OnWhiteListed(
        uint256 indexed positionId,
        bool isWhiteListed,
        address[] accounts
    );
    event OnWhiteListEnabled(uint256 indexed positionId, bool enabled);
    event OnBuyLimitEnable(uint256 indexed positionId, bool enable);
    event OnBuyLimit(uint256 indexed positionId, uint256 limit);

    function createOffer(
        uint256 positionId,
        uint256 asset1Count,
        uint256 asset2Count
    ) external {
        // get position data
        PositionData memory position = _positions[positionId];
        require(position.owner != address(0), 'position is not exists');

        // create offer
        ++totalOffers;
        _offers[totalOffers].positionId = positionId;
        _offers[totalOffers].state = 1;
        _offers[totalOffers].owner = msg.sender;
        _offers[totalOffers].asset1Count = asset1Count;
        _offers[totalOffers].asset2Count = asset2Count;

        // transfer asset
        uint256 lastCount = IERC20(position.asset2).balanceOf(address(this));
        IERC20(position.asset2).safeTransferFrom(
            msg.sender,
            address(this),
            asset2Count
        );
        _offers[totalOffers].asset2Count =
            IERC20(position.asset2).balanceOf(address(this)) -
            lastCount;

        // event
        emit OnOfer(positionId, totalOffers);
    }

    function removeOffer(uint256 offerId) external {
        OfferData storage offer = _offers[offerId];
        require(offer.state == 1, 'offer is not created or already used');
        require(offer.owner == msg.sender, 'only owner can remove the offer');
        offer.state = 0;
        PositionData memory position = _positions[offer.positionId];
        IERC20(position.asset2).safeTransferFrom(
            address(this),
            offer.owner,
            offer.asset2Count
        );
        emit OnRemoveOfer(offer.positionId, offerId);
    }

    function applyOffer(uint256 offerId) external {
        // get offer
        OfferData storage offer = _offers[offerId];
        require(offer.state == 1, 'offer is not created or already used');
        offer.state = 2;

        // get position data
        PositionData storage position = _positions[offer.positionId];
        require(position.owner != address(0), 'position is not exists');
        require(position.owner == msg.sender, 'only owner can apply offer');

        // buyCount
        uint256 buyCount = offer.asset1Count;
        require(
            buyCount <= position.count1,
            'not enough owner asset to apply offer'
        );
        require(buyCount > 0, 'nothing to buy');

        // calculate the fee of buy count
        uint256 buyFee = (buyCount * _feeSettings.feePercentFor(offer.owner)) /
            _feeSettings.feeDecimals();
        uint256 buyToTransfer = buyCount - buyFee;

        // transfer the buy asset
        if (buyFee > 0)
            IERC20(position.asset1).safeTransfer(
                _feeSettings.feeAddress(),
                buyFee
            );
        IERC20(position.asset1).safeTransfer(offer.owner, buyToTransfer);

        // transfer asset2 to position
        position.count1 -= buyCount;
        position.count2 += buyCount;

        // event
        emit OnApplyOfer(offer.positionId, offerId);
    }

    function getOffer(
        uint256 offerId
    ) external view returns (OfferData memory) {
        return _offers[offerId];
    }

    function createAsset(
        address asset1,
        address asset2,
        uint256 priceNom,
        uint256 priceDenom,
        uint256 count,
        uint8 flags,
        uint256 buyLimit,
        address[] calldata whiteList
    ) external {
        if (count > 0) {
            uint256 lastCount = IERC20(asset1).balanceOf(address(this));
            IERC20(asset1).safeTransferFrom(msg.sender, address(this), count);
            count = IERC20(asset1).balanceOf(address(this)) - lastCount;
        }

        _positions[++_totalPositions] = PositionData(
            msg.sender,
            asset1,
            asset2,
            priceNom,
            priceDenom,
            count,
            0,
            flags
        );

        if (buyLimit > 0) _limits[_totalPositions] = buyLimit;
        for (uint256 i = 0; i < whiteList.length; ++i)
            _whiteLists[_totalPositions][whiteList[i]] = true;

        emit OnCreate(
            _totalPositions,
            msg.sender,
            asset1,
            asset2,
            priceNom,
            priceDenom
        );
    }

    function addBalance(uint256 positionId, uint256 count) external {
        PositionData storage pos = _positions[positionId];
        uint256 lastCount = IERC20(pos.asset1).balanceOf(address(this));
        IERC20(pos.asset1).safeTransferFrom(msg.sender, address(this), count);
        pos.count1 += IERC20(pos.asset1).balanceOf(address(this)) - lastCount;
    }

    function withdraw(
        uint256 positionId,
        uint256 assetCode,
        address to,
        uint256 count
    ) external {
        PositionData storage pos = _positions[positionId];
        require(pos.owner == msg.sender, 'only for position owner');
        uint256 fee = (_feeSettings.feePercentFor(msg.sender) * count) /
            _feeSettings.feeDecimals();
        uint256 toWithdraw = count - fee;

        if (assetCode == 1) {
            require(pos.count1 >= count, 'not enough asset count');
            uint256 lastCount = IERC20(pos.asset1).balanceOf(address(this));
            IERC20(pos.asset1).safeTransfer(_feeSettings.feeAddress(), fee);
            IERC20(pos.asset1).safeTransfer(to, toWithdraw);
            uint256 transferred = lastCount -
                IERC20(pos.asset1).balanceOf(address(this));
            require(
                pos.count1 >= transferred,
                'not enough asset count after withdraw'
            );
            pos.count1 -= transferred;
        } else if (assetCode == 2) {
            require(pos.count2 >= count, 'not enough asset count');
            uint256 lastCount = IERC20(pos.asset2).balanceOf(address(this));
            IERC20(pos.asset2).safeTransfer(_feeSettings.feeAddress(), fee);
            IERC20(pos.asset2).safeTransfer(to, toWithdraw);
            uint256 transferred = lastCount -
                IERC20(pos.asset2).balanceOf(address(this));
            require(
                pos.count2 >= transferred,
                'not enough asset count after withdraw'
            );
            pos.count2 -= transferred;
        } else revert('unknown asset code');

        emit OnWithdraw(positionId, assetCode, to, count);
    }

    function setPrice(
        uint256 positionId,
        uint256 priceNom,
        uint256 priceDenom
    ) external {
        PositionData storage pos = _positions[positionId];
        require(pos.owner == msg.sender, 'only for position owner');
        pos.priceNom = priceNom;
        pos.priceDenom = priceDenom;
        emit OnPrice(positionId, priceNom, priceDenom);
    }

    function setWhiteList(
        uint256 positionId,
        bool whiteListed,
        address[] calldata accounts
    ) external {
        PositionData storage pos = _positions[positionId];
        require(pos.owner == msg.sender, 'only for position owner');
        for (uint256 i = 0; i < accounts.length; ++i) {
            _whiteLists[positionId][accounts[i]] = whiteListed;
        }

        emit OnWhiteListed(positionId, whiteListed, accounts);
    }

    function isWhiteListed(
        uint256 positionId,
        address account
    ) external view returns (bool) {
        return _whiteLists[positionId][account];
    }

    function enableWhiteList(uint256 positionId, bool enabled) external {
        PositionData storage pos = _positions[positionId];
        require(pos.owner == msg.sender, 'only for position owner');

        if (enabled) pos.flags |= WHITELIST_FLAG;
        else pos.flags &= ~WHITELIST_FLAG;

        emit OnWhiteListEnabled(positionId, enabled);
    }

    function enableBuyLimit(uint256 positionId, bool enabled) external {
        PositionData storage pos = _positions[positionId];
        require(pos.owner == msg.sender, 'only for position owner');

        if (enabled) pos.flags |= BUYLIMIT_FLAG;
        else pos.flags &= ~BUYLIMIT_FLAG;

        emit OnBuyLimitEnable(positionId, enabled);
    }

    function setBuyLimit(uint256 positionId, uint256 limit) external {
        PositionData storage pos = _positions[positionId];
        require(pos.owner == msg.sender, 'only for position owner');

        _limits[positionId] = limit;

        emit OnBuyLimit(positionId, limit);
    }

    function buy(
        uint256 positionId,
        address to,
        uint256 count,
        uint256 priceNom,
        uint256 priceDenom,
        address antibot
    ) external {
        PositionData storage pos = _positions[positionId];

        // check antibot
        require(msg.sender == antibot, 'antibot');

        // check whitelist
        if (pos.flags & WHITELIST_FLAG > 0) {
            require(
                _whiteLists[positionId][msg.sender],
                'the account is not in whitelist'
            );
        }

        // check limit
        if (pos.flags & BUYLIMIT_FLAG > 0) {
            uint256 usedLimit = _usedLimits[positionId][msg.sender] + count;
            _usedLimits[positionId][msg.sender] = usedLimit;
            require(
                usedLimit <= _limits[positionId],
                'account buy limit is over'
            );
        }

        // price frontrun protection
        require(
            pos.priceNom == priceNom && pos.priceDenom == priceDenom,
            'the price is changed'
        );
        uint256 spend = _spendToBuy(pos, count);
        require(
            spend > 0,
            'spend asset count is zero (count parameter is less than minimum count to spend)'
        );
        uint256 buyFee = (count * _feeSettings.feePercentFor(to)) /
            _feeSettings.feeDecimals();
        uint256 buyToTransfer = count - buyFee;

        // transfer buy
        require(pos.count1 >= count, 'not enough asset count at position');
        uint256 lastCount = IERC20(pos.asset1).balanceOf(address(this));
        if (buyFee > 0)
            IERC20(pos.asset1).safeTransfer(_feeSettings.feeAddress(), buyFee);
        IERC20(pos.asset1).safeTransfer(to, buyToTransfer);
        uint256 transferred = lastCount -
            IERC20(pos.asset1).balanceOf(address(this));
        require(
            pos.count1 >= transferred,
            'not enough asset count after withdraw'
        );
        pos.count1 -= transferred;

        // transfer spend
        lastCount = IERC20(pos.asset2).balanceOf(address(this));
        IERC20(pos.asset2).safeTransferFrom(msg.sender, address(this), spend);
        pos.count2 += IERC20(pos.asset2).balanceOf(address(this)) - lastCount;

        // emit event
        emit OnBuy(positionId, to, count);
    }

    function spendToBuy(
        uint256 positionId,
        uint256 count
    ) external view returns (uint256) {
        return _spendToBuy(_positions[positionId], count);
    }

    function _spendToBuy(
        PositionData memory pos,
        uint256 count
    ) private pure returns (uint256) {
        return (count * pos.priceNom) / pos.priceDenom;
    }

    function getPosition(
        uint256 positionId
    ) external view returns (PositionData memory) {
        return _positions[positionId];
    }
}
