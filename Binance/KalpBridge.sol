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
    event TransferAndLock(bytes32 txId, address tokenContractAddress, uint256 tokenId, uint256 amount, address senderAddress, address receiverAddress, uint256 souceChainId, uint256 destinationChainId, uint256 timestamp, string status);
    event MintAndLock(bytes32 txId, uint256 mintedTokenId, uint256 amount, uint256 timestamp, uint256 currentChainId, string status);
    event BurnAndRelease(bytes32 txId, uint256 mintedTokenId, uint256 amount, uint256 timestamp, uint256 currentChainId, string status);
    event WithdrawToken(address tokenContractAddress, uint256 tokenId, uint256 amount, address caller, uint256 currentChainId);
    event WithdrawTokenResponse(bytes32 txId, address tokenContractAddress, address receiverAddress, uint256 tokenId, uint256 amount, uint256 currentChainId);

    uint256 public currentChainId = 1;
    uint256 public txNonce = 0;
    address superAdmin;
    address kalpNFTContractAddress; 
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

    /**
     * @dev Grants admin rights to a specified address.
     * 
     * This function can only be called by the super admin. It modifies the 
     * `admins` mapping to give the specified address administrative privileges.
     * 
     * @param _adminAddress The address to be added as an admin.
     * 
     * Requirements:
     * - The caller must have the `onlySuperAdmin` privilege.
     * 
     * Effects:
     * - Sets the `_adminAddress` address's status in the `admins` mapping to `true`, 
     *   granting them administrative rights.
     * 
     * Emits:
     * - No specific events.
    */
    function addAdmin(address _adminAddress) onlySuperAdmin public {
        admins[_adminAddress] = true;
    }

    /**
     * @dev Removes an admin by setting their admin status to `false`.
     * 
     * This function can only be called by the super admin. It modifies the 
     * `admins` mapping to revoke the admin rights of the specified address.
     * 
     * @param _adminAddress The address of the admin to be removed.
     * 
     * Requirements:
     * - The caller must have the `onlySuperAdmin` privilege.
     * 
     * Effects:
     * - Sets the `_admin` address's status in the `admins` mapping to `false`, effectively 
     *   removing their administrative rights.
     * 
     * Emits:
     * - No specific events.
    */
    function removeAdmin(address _adminAddress) onlySuperAdmin public {
        admins[_adminAddress] = false;
    }

    /**
     * @dev Updates the address of the KalpNFT contract. 
     * This function is restricted to the admin only, ensuring that 
     * only authorized users can set the contract address.
     * 
     * @param _kalpNFTContractAddress The new address of the KalpNFT contract.
     * 
     * Requirements:
     * - The caller must have the 'onlyAdmin' role.
     * 
     * Emits:
     * - No specific events.
    */
    function addKalpNFTContractAddress(address _kalpNFTContractAddress) onlyAdmin public {
        kalpNFTContractAddress = _kalpNFTContractAddress; 
    }
    
    /**
     * @dev Transfers tokens from the caller's address to the contract address and locks them for cross-chain transfer.
     * This function can only be called by anyone who has completed setApproval part. 
     * 
     * This function performs the following actions:
     * 1. Verifies that the caller has enough tokens to transfer.
     * 2. Transfers the specified amount of tokens from the caller to the contract address.
     * 3. Ensures the correct amount of tokens has been transferred.
     * 4. Emits an event with transaction details.
     * 
     * @param _tokenContractAddress The address of the ERC1155 token contract.
     * @param _tokenId The ID of the token to transfer.
     * @param _amount The amount of tokens to transfer.
     * @param _destinationChainId The ID of the destination chain for cross-chain operations.
     * @param _receiverAddress The address of the receiver on the destination chain.
     * 
     * Requirements:
     * - The caller must have done setApproval on his tokenContract. 
     * - The caller must have a sufficient balance of the specified token.
     * - The amount of tokens must be correctly transferred to the contract.
     * 
     * Emits:
     * - `TransferAndLock` event with the transaction details, including:
     *   - `txId` The unique transaction ID for tracking. is being maintained to distinguish transaction done on same chain via same contract and amount
     *   - `_tokenContractAddress` The address of the token contract.
     *   - `_tokenId` The ID of the token.
     *   - `_amount` The amount of tokens transferred.
     *   - `msg.sender` The address of the token sender.
     *   - `_receiverAddress` The address of the receiver on the destination chain.
     *   - `currentChainId` The ID of the current chain.
     *   - `_destinationChainId` The ID of the destination chain.
     *   - `block.timestamp` The timestamp of the transaction.
     *   - `"temporaryLocked"` A status indicating the tokens are temporarily locked.
     */
    function transferAndLock(
        address _tokenContractAddress,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _destinationChainId,
        address _receiverAddress ) public {
            ERC1155 erc1155 = ERC1155(_tokenContractAddress);
            bool approvalStatus = erc1155.isApprovedForAll(msg.sender, address(this));
            require(approvalStatus == true, "Approval is not done!");
            uint256 balance = erc1155.balanceOf(msg.sender, _tokenId);
            require(balance >= _amount, "Not enough balance or not correct owner"); 
            uint256 bridgeBeforeBalance = erc1155.balanceOf(address(this), _tokenId);
            erc1155.safeTransferFrom(msg.sender, address(this), _tokenId, _amount, "0x");
            uint256 bridgeAfterBalance = erc1155.balanceOf(address(this), _tokenId);
            bytes32 txId = keccak256(abi.encodePacked(currentChainId, _tokenContractAddress, _tokenId, msg.sender, txNonce, block.timestamp));
            require(bridgeAfterBalance == bridgeBeforeBalance + _amount, "Amount is not being transferred to Bridge"); 
            emit TransferAndLock(txId, _tokenContractAddress, _tokenId, _amount, msg.sender, _receiverAddress, currentChainId, _destinationChainId, block.timestamp, "temporaryLocked");
    }

    /**
     * @dev Mints a specified amount of tokens and locks them on the bridge.
     * 
     * This function allows an admin to mint a certain number of tokens for a given token ID, 
     * and locks the minted tokens by transferring them to the bridge (contract's address).
     * 
     * The function checks the contract's token balance before minting, then mints the specified
     * amount of tokens and ensures they are locked in the contract by verifying the balance after
     * minting. It emits a MintAndLock event to record the transaction.
     * 
     * @param _txId The transaction ID associated with this minting operation. Userful for intermediate service and HLF contract. 
     * @param _tokenId The ID of the token being minted.
     * @param _amount The amount of tokens to be minted.
     * 
     * Requirements:
     * - The caller must have admin privileges (`onlyAdmin` modifier).
     * 
     * Effects:
     * - Mints `_amount` of tokens with the ID `_tokenId`.
     * - Transfers and locks the minted tokens by moving them to the bridge's balance (contract's address).
     * - Emits a `MintAndLock` event after successful minting and locking.
     * 
     * Emits:
     * - `MintAndLock` event with details about the transaction, token ID, amount, current chain ID, 
     *   and status set to "temporaryLocked".
     * Emits:
     * - `MintAndLock` event with details about the transaction, including:
     *   - `txId` The unique transaction ID for tracking. is being maintained to distinguish transactions
     *   - `_tokenId` The ID of the token.
     *   - `_amount` The amount of tokens transferred.
     *   - `block.timestamp` The timestamp of the transaction.
     *   - `currentChainId` The ID of the current chain.
     *   - `"temporaryLocked"` A status indicating the tokens are temporarily locked.
    */
    function mintAndLock(
        bytes32 _txId,
        uint256 _tokenId,
        uint256 _amount ) onlyAdmin public {
            ERC1155 erc1155 = ERC1155(kalpNFTContractAddress);
            uint bridgeBeforeBalance = erc1155.balanceOf(address(this), _tokenId);
            _mint(_tokenId, _amount);
            uint bridgeAfterBalance = erc1155.balanceOf(address(this), _tokenId);
            require(bridgeAfterBalance == bridgeBeforeBalance + _amount, "Not minted"); 
            emit MintAndLock(_txId, _tokenId, _amount, block.timestamp, currentChainId, "temporaryLocked");
    }

    /**
     * @dev Burns the specified amount of tokens and releases them from the bridge.
     * This function is restricted to the admin role, ensuring that only authorized 
     * users can burn tokens and trigger the release process.
     * 
     * The function first checks the current token balance held by the bridge, burns 
     * the specified amount, and then verifies that the token balance is updated correctly. 
     * 
     * @param _txId The unique transaction ID related to the burning event. Userful for intermediate service and HLF contract. 
     * @param _tokenId The ID of the token to be burned.
     * @param _amount The amount of tokens to be burned.
     * 
     * Requirements:
     * - The caller must have the 'Admin' role.
     * - The token balance of the bridge must be sufficient to perform the burn.
     * 
     * Emits:
     * - `BurnAndRelease` event with the transaction details, including:
     *   - `txId` The unique transaction ID for tracking. This is maintained to distinguish the burn transaction.
     *   - `_tokenId` The ID of the token being burned.
     *   - `_amount` The amount of tokens burned.
     *   - `block.timestamp` The timestamp of when the burn occurred.
     *   - `currentChainId` The ID of the current chain where the burn operation is executed.
     *   - `"burned"` A status indicating that the tokens have been successfully burned.
    */
    function burnAndRelease(
        bytes32 _txId,
        uint256 _tokenId,
        uint256 _amount ) onlyAdmin public {
            ERC1155 erc1155 = ERC1155(kalpNFTContractAddress);
            uint256 bridgeBeforeBalance = erc1155.balanceOf(address(this), _tokenId);
            _burn(_tokenId, _amount);
            uint256 bridgeAfterBalance = erc1155.balanceOf(address(this), _tokenId);
            require(bridgeAfterBalance == bridgeBeforeBalance - _amount, "Not burned"); 
            emit BurnAndRelease(_txId, _tokenId, _amount, block.timestamp, currentChainId, "burned");
    }

    /**
     * @dev Initiates a token withdrawal by emitting a `WithdrawToken` event. 
     * This function does not actually transfer tokens but signals the start of a withdrawal process.
     * Can be called publicly by anyone. Will complete withdraw only for valid receiver.
     * 
     * @param _tokenContractAddress The address of the token contract from which the withdrawal is initiated. It can be of KalpNFTs or of UserNFTs
     * @param _tokenId The ID of the token to be withdrawn.
     * @param _amount The amount of tokens to be withdrawn.
     * 
     * Requirements:
     * - The function does not enforce any balance checks or ownership verification.
     * 
     * Emits:
     * - `WithdrawToken` event with the withdrawal details, including:
     *   - `_tokenContractAddress` The address of the token contract.
     *   - `_tokenId` The ID of the token being withdrawn.
     *   - `_amount` The amount of tokens to be withdrawn.
     *   - `msg.sender` The address of the account initiating the withdrawal.
     *   - `currentChainId` The ID of the current chain.
    */
    function withdrawToken(
        address _tokenContractAddress,
        uint256 _tokenId,
        uint256 _amount) public {
        emit WithdrawToken(_tokenContractAddress, _tokenId, _amount, msg.sender, currentChainId);
    }

    /**
     * @dev Processes the token withdrawal request and transfers the tokens to the receiver.
     * This function transfers tokens from the contract to the receiver and verifies that the transfer was successful.
     * 
     * @param _txId The unique transaction ID associated with the withdrawal.
     * @param _tokenContractAddress The address of the token contract from which the withdrawal is being processed.
     * @param _receiverAddress The address of the receiver to whom the tokens are being transferred.
     * @param _tokenId The ID of the token being transferred.
     * @param _amount The amount of tokens being transferred.
     * 
     * Requirements:
     * - The caller must have the `Admin` role.
     * - The balance of the contract for the specified token must be sufficient to cover the withdrawal.
     * 
     * Emits:
     * - `WithdrawTokenResponse` event with the following details:
     *   - `_txId` The unique transaction ID for tracking.
     *   - `_tokenContractAddress` The address of the token contract.
     *   - `_receiverAddress` The address of the receiver.
     *   - `_tokenId` The ID of the token being transferred.
     *   - `_amount` The amount of tokens transferred.
     *   - `currentChainId` The ID of the current chain where the transfer took place.
     * 
    */
    function withdrawTokenResponse(
        bytes32 _txId,
        address _tokenContractAddress,
        address _receiverAddress,
        uint256 _tokenId,
        uint256 _amount) public onlyAdmin {
        ERC1155 erc1155 = ERC1155(_tokenContractAddress);
        uint256 bridgeBeforeBalance = erc1155.balanceOf(_receiverAddress, _tokenId);
        erc1155.safeTransferFrom(address(this), _receiverAddress, _tokenId, _amount, "0x");
        uint256 bridgeAfterBalance = erc1155.balanceOf(_receiverAddress, _tokenId);
        require(bridgeBeforeBalance + _amount == bridgeAfterBalance, "Not transferred, failed");
        emit WithdrawTokenResponse(_txId, _tokenContractAddress, _receiverAddress, _tokenId, _amount, currentChainId);
    }

    function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _value, bytes memory _data) public virtual returns (bytes4) {
        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }

    function _mint(uint256 _tokenId, uint256 _amount) internal {
        ERC1155 erc1155 = ERC1155(kalpNFTContractAddress);
        erc1155.mintToken(_tokenId, _amount);
    }

    function _burn(uint256 _tokenId, uint256 _amount) internal {
        ERC1155 erc1155 = ERC1155(kalpNFTContractAddress);
        erc1155.burnToken(_tokenId, _amount);
    }
}