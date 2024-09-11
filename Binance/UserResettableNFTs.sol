// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// This is the test contract
// BatchTransfer wont work here 
// Its creation to complete the easy development of bridge contract and its development
contract UserResettableNFTs is ERC1155 {

    uint public tokenId = 1;
    uint256[] private _tokenIds;
    mapping(uint256 => mapping(address => uint256)) public _tokenBalances;
    mapping(uint256 => address []) public _tokenHolders;

    // Solve this to have reset functionality for any address 
    constructor() ERC1155("https://game.example/api/item/{id}.json") {
    }

    // Function to mint tokens (for demonstration purposes)
    function mint(address account, uint256 id, uint256 amount, bytes memory data) internal {
        _mint(account, id, amount, data);
        _tokenBalances[id][account] += amount;
        _tokenHolders[id].push(account);
        if (!_exists(id)) {
            _tokenIds.push(id);
        }
    }

    function mintBatch(address account, uint256[] memory ids, uint256[] memory values, bytes memory data) internal{
        _mintBatch(msg.sender, ids, values, "");
        for(uint256 i=0; i<ids.length; i++) {
             _tokenBalances[ids[i]][account] += values[i];
             _tokenHolders[ids[i]].push(account);
              if (!_exists(ids[i])) {
                _tokenIds.push(ids[i]);
              }
        }
    }

    // Function to check if a token ID exists
    function _exists(uint256 id) private view returns (bool) {
        for (uint i = 0; i < _tokenIds.length; i++) {
            if (_tokenIds[i] == id) {
                return true;
            }
        }
        return false;
    }

    // Function to reset all token IDs to zero
    function resetAllTokenIds() public {
        for (uint i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            address[] memory _addr =  _tokenHolders[tokenId];
            for (uint j=0;j < _addr.length; j++){
                uint256 amount = balanceOf(_addr[j], tokenId);
                _tokenBalances[tokenId][_addr[j]] -= amount;
                _burn(_addr[j], tokenId, amount);                
            }
        }
        // Clear the list of token IDs
        delete _tokenIds;
    }

    // Override the balanceOf function to use our mapping
    function balanceOf(address account, uint256 id) public view override returns (uint256) {
        return _tokenBalances[id][account];
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes memory data) public override{
       _tokenHolders[id].push(to);
       _tokenBalances[id][from] -= value;
       _tokenBalances[id][to] += value;
       super.safeTransferFrom(from, to, id, value, data);
    }

    function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _value, bytes memory _data) public virtual returns (bytes4) {
        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }

    function mintToken(uint256 _amount) public {
        mint(msg.sender, tokenId, _amount,"");
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
        mintBatch(msg.sender, ids, values, "");
        tokenId = tempTokenId;
    }

    function burnToken(uint256 _tokenId, uint256 amount) public {
        _tokenBalances[_tokenId][msg.sender] -= amount;
        _burn(msg.sender, _tokenId, amount);
    }
}

