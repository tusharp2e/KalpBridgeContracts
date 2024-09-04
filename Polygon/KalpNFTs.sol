// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract KalpNFTs is ERC1155 {

    constructor() public ERC1155("https://game.example/api/item/{id}.json") {
    }

    function mintToken(uint256 _tokenId, uint256 _amount) public {
        _mint(msg.sender, _tokenId, _amount,"");
    }

    function burnToken(uint256 _tokenId, uint256 amount) public {
        _burn(msg.sender, _tokenId, amount);
    }
}