// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';

contract Erc721TestToken is ERC721Enumerable {
    uint256 public totalCount;

    constructor() ERC721('TestErc721', 'erc721') {}

    function mint(uint256 count, address to) external {
        for (uint256 i = 0; i < count; ++i) _mint(to, ++totalCount);
    }
}
