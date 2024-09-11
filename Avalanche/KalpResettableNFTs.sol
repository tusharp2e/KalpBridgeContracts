// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts@v4.9.3/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts@v4.9.3/utils/Strings.sol";

// This is the test contract
// BatchTransfer wont work here 
// Its creation to complete the easy development of bridge contract and its development
contract KalpResettableNFTs is ERC1155 {

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

    function mintToken(uint256 _tokenId, uint256 _amount) public {
        mint(msg.sender, _tokenId, _amount,"");
    }

    function burnToken(uint256 _tokenId, uint256 amount) public {
        _tokenBalances[_tokenId][msg.sender] -= amount;
        _burn(msg.sender, _tokenId, amount);
    }
}
