// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/*interface IERC20Test {
    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external;

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external;
}*/

contract AssetTest {
    using SafeERC20 for IERC20;
    address contractAddress;

    constructor(address contractAddress_) {
        contractAddress = contractAddress_;
    }

    function count() external view returns (uint256) {
        return IERC20(contractAddress).balanceOf(address(this));
    }

    function getContractAddress() external view returns (address) {
        return contractAddress;
    }

    function transferToAsset(uint256 amount) external {
        IERC20(contractAddress).safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(address recipient, uint256 amount) external {
        IERC20(contractAddress).safeTransfer(recipient, amount);
    }
}
