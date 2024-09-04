// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

interface ERC1155 {
    event TransferSingle(address indexed _operator, address indexed _from, address indexed _to, uint256 _id, uint256 _value);
    event TransferBatch(address indexed _operator, address indexed _from, address indexed _to, uint256[] _ids, uint256[] _values);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);
    event URI(string _value, uint256 indexed _id);
    function mintToken(uint256 _tokenId, uint256 _amount) external;
    function burnToken(uint256 _tokenId, uint256 _amount) external;
    function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _value, bytes calldata _data) external;
    function safeBatchTransferFrom(address _from, address _to, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata _data) external;
    function balanceOf(address _owner, uint256 _id) external view returns (uint256);
    function balanceOfBatch(address[] calldata _owners, uint256[] calldata _ids) external view returns (uint256[] memory);
    function setApprovalForAll(address _operator, bool _approved) external;
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);
}

contract KalpBridge {
    event TransferAndLock(bytes32 txId, address tokenSmartContract, uint256 tokenId, uint256 amount, address owner, uint256 timestamp, string status, uint256 souceChainId, uint256 destinationChainId, address receiverAddress);
    event MintAndLock(bytes32 txId, uint256 mintedTokenId, uint256 amount, uint256 timestamp, string status, uint256 sourceChainId);
    event BurnAndRelease(bytes32 txId, uint256 mintedTokenId, uint256 amount, uint256 timestamp, string status, uint256 sourceChainId);
    event WithdrawToken(address tokenSmartContract, uint256 tokenId,uint256 amount , address caller, uint256 sourceChainId);
    event WithdrawTokenResponse(bytes32 _txId, address tokenSmartContract, address owner,uint256 tokenId, uint256 amount, uint256 sourceChainId);

    uint256 public sourceChainId = 2;
    uint256 public txNonce = 0;
    address superAdmin;
    address mintSmartContract; 
    mapping(address => bool) public admins;
 
    modifier onlyAdmin {
        require(admins[msg.sender] == true);
        _;
    }

    modifier onlySuperAdmin {
        require(msg.sender == superAdmin);
        _;
    }

    constructor() {
        superAdmin = msg.sender;
    }

    function addAdmin(address _admin) onlySuperAdmin public{
        admins[_admin] = true;
    }

    function removeAdmin(address _admin) onlySuperAdmin public{
        admins[_admin] = false;
    }

    function addMintSmartContract(address _address) onlyAdmin public {
        mintSmartContract = _address; 
    }
    
    function transferAndLock(
        address _tokenContractAddress,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _destinationChainId,
        address _receiverAddress ) public {
            ERC1155 erc1155 = ERC1155(_tokenContractAddress);
            uint256 balance = erc1155.balanceOf(msg.sender, _tokenId);
            require(balance >= _amount, "Not enough balance or not correct owner"); 
            uint256 bridgeBeforeBalance = erc1155.balanceOf(address(this), _tokenId);
            erc1155.safeTransferFrom(msg.sender, address(this), _tokenId, _amount, "0x");
            uint256 bridgeAfterBalance = erc1155.balanceOf(address(this), _tokenId);
            bytes32 txId = keccak256(abi.encodePacked(block.number, block.timestamp, msg.sender, txNonce));
            require(bridgeAfterBalance == bridgeBeforeBalance + _amount, "Amount is not being transferred to Bridge"); 
            emit TransferAndLock(txId, _tokenContractAddress, _tokenId, _amount, msg.sender, block.timestamp, "temporaryLocked", sourceChainId, _destinationChainId, _receiverAddress);
    }

    function mintAndLock(
        bytes32 _txId,
        uint256 _tokenId,
        uint256 _amount ) onlyAdmin public {
            ERC1155 erc1155 = ERC1155(mintSmartContract);
            uint bridgeBeforeBalance = erc1155.balanceOf(address(this), _tokenId);
            _mint(_tokenId, _amount);
            uint bridgeAfterBalance = erc1155.balanceOf(address(this), _tokenId);
            require(bridgeAfterBalance == bridgeBeforeBalance + _amount, "Not minted"); 
            emit MintAndLock(_txId, _tokenId, _amount, block.timestamp, "temporaryLocked", sourceChainId);
    }

    function burnAndRelease(
        bytes32 _txId,
        uint256 _tokenId,
        uint256 _amount ) onlyAdmin public {
            ERC1155 erc1155 = ERC1155(mintSmartContract);
            uint256 bridgeBeforeBalance = erc1155.balanceOf(address(this), _tokenId);
            _burn(_tokenId, _amount);
            uint256 bridgeAfterBalance = erc1155.balanceOf(address(this), _tokenId);
            require(bridgeAfterBalance == bridgeBeforeBalance - _amount, "Not burned"); 
            emit BurnAndRelease(_txId, _tokenId, _amount, block.timestamp, "burned", sourceChainId);
    }

    function withdrawToken(
        address _tokenContractAddress,
        uint256 _tokenId,
        uint256 _amount) public{
        emit WithdrawToken(_tokenContractAddress, _tokenId, _amount, msg.sender, sourceChainId);
    }

    function withdrawTokenResponse(
        bytes32 _txId,
        address _tokenContractAddress,
        address _owner,
        uint256 _tokenId,
        uint256 _amount) public onlyAdmin {
        ERC1155 erc1155 = ERC1155(_tokenContractAddress);
        uint256 bridgeBeforeBalance = erc1155.balanceOf(_owner, _tokenId);
        erc1155.safeTransferFrom(address(this), _owner, _tokenId, _amount, "0x");
        uint256 bridgeAfterBalance = erc1155.balanceOf(_owner, _tokenId);
        require(bridgeBeforeBalance + _amount == bridgeAfterBalance, "Not transaferred, failed");
        emit WithdrawTokenResponse(_txId, _tokenContractAddress, _owner,_tokenId, _amount, sourceChainId);
    }

    function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _value, bytes memory _data) public virtual returns (bytes4) {
        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }

    function _mint(uint256 _tokenId, uint256 _amount) internal {
        ERC1155 erc1155 = ERC1155(mintSmartContract);
        erc1155.mintToken(_tokenId, _amount);
    }

    function _burn(uint256 _tokenId, uint256 _amount) internal{
        ERC1155 erc1155 = ERC1155(mintSmartContract);
        erc1155.burnToken(_tokenId, _amount);
    }
}