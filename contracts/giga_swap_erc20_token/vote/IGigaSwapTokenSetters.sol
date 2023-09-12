// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

interface IGigaSwapTokenSetters {
    function setBuyFee(uint256 newBuyFeePpm) external;
    function setSellFee(uint256 newSellFeePpm) external;
    function SetExtraContractAddress(address newExtraContractAddress) external;
    function removeExtraContractAddress() external;
    function setShare(uint256 thisSharePpm, uint256 stackingSharePpm) external;
    function setWithdrawAddress(address newWithdrawAddress) external;
}
