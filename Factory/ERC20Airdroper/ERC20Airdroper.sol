// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "../IUtilityContract.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ERC20Airdroper is IUtilityContract, Ownable {

    constructor() Ownable(msg.sender) {}

    error AlreadyInitialized();
    error ArraysLengthMisMatch();
    error NotEnoughtApprovedTokens();
    error TransferFailed(uint256 index);
    

    modifier  notInitialized() {
        require(!initialized, AlreadyInitialized());
        _;
    }


    bool private initialized;
    IERC20 public token;
    uint256 public amount;
    address public treasury;

    function airdrop (address[] calldata receivers, uint256[] calldata amounts) external onlyOwner {
        require(receivers.length == amounts.length, ArraysLengthMisMatch());
        require(token.allowance(treasury, address(this)) >= amount, NotEnoughtApprovedTokens());

        for (uint256 i = 0; i < receivers.length; i++) {
            require(token.transferFrom(treasury, receivers[i], amounts[i]), TransferFailed(i)); 
        }
    }

    function initialize (bytes memory _initData) external notInitialized returns (bool) {
        (address _token, uint256 _amount, address _treasury, address _owner) = abi.decode(_initData, (address, uint256, address, address));

        token = IERC20(_token);
        amount = _amount;
        treasury = _treasury;

        Ownable.transferOwnership(_owner); 
        
        initialized = true;
        return true;
    }

    function getInitDate(address _token, uint256 _amount, address _treasury, address _owner) external pure returns (bytes memory) {
        return abi.encode(_token, _amount, _treasury, _owner);
    }
}

// ["0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db","0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB","0x617F2E2fD72FD9D5503197092aC168c91465E7f2","0x17F6AD8Ef982297579C203069C1DbfFE4348c372"]
// [123234432423,5345434,454423,675767]