// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts@v4.9.3/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts@v4.9.3/utils/Strings.sol";

contract UserNFTs is ERC1155 {
    uint public tokenId = 1;

    constructor() public ERC1155("https://game.example/api/item/{id}.json") {
        _mint(msg.sender, 0, 1, "");
    }

    function mint(uint256 _amount) public{
        _mint(msg.sender, tokenId, _amount, "");
        tokenId++;
    }

    function bulkMint(uint256 _value) public {
        uint tempTokenId = tokenId;     

        uint[] memory ids = new uint[](_value);
        uint[] memory values = new uint[](_value);
        
        // Initialize all elements of the array to 1
        for (uint i = 0; i < _value; i++) {
            ids[i] = tempTokenId;
            values[i] = 1;
            tempTokenId++;
        }
        _mintBatch(msg.sender, ids, values, "");
        tokenId = tempTokenId;
    }

    function uri(uint256 _id) override public pure returns (string memory){
        return(
            string(
                abi.encodePacked("https://blush-solid-boar-947.mypinata.cloud/ipfs/QmeQumKBArsZMxmod1ocSThK37Twwbxo2Ck6pBL7ukLKvt/", 
                Strings.toString(_id),
                ".json")));
    }
}