// SPDX-License-Identifier: MIT
pragma solidity^0.8.29;

import "../IUtilityContract.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol"; 

contract ERC721Airdroper is IUtilityContract, Ownable {

    constructor() Ownable(msg.sender) {}

    IERC721 public token;
    address public treasury;

    error AlreadyInitialized();
    error TransferFailed();
    error ArraysLengthMismatch();
    error NotEnoughtApprovedTokens();
    error ContractNotInitialized();

    bool private initialized;

    modifier notInitialized() {
        require(!initialized, AlreadyInitialized());
        _;
    }

    function airdrop(address[] calldata receivers, uint256[] calldata tokenId) external onlyOwner {
        if(!initialized) revert ContractNotInitialized();
        if(receivers.length != tokenId.length) revert ArraysLengthMismatch();
        if(!token.isApprovedForAll(treasury, address(this))) revert NotEnoughtApprovedTokens();
        
        for(uint256 i = 0; i < receivers.length; i++) {
            token.safeTransferFrom(treasury, receivers[i], tokenId[i]);
        }
    }

    function initialize(bytes memory _initData) external notInitialized returns(bool){
        (address _token, address _treasury, address _owner) = abi.decode(_initData, (address, address, address));

        token = IERC721(_token);
        treasury = _treasury;

        Ownable.transferOwnership(_owner);

        initialized = true;

        return true;
    }

    function getInitData(address _token, address _treasury, address _owner) external pure returns(bytes memory) {
        return abi.encode(_token, _treasury, _owner);
    }
}