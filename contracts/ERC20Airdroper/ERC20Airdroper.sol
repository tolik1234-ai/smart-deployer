//SPDX-License-Identifier: MIT
pragma solidity^0.8.29;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../IUtilityContract.sol";

contract ERC20Airdroper is IUtilityContract {

    IERC20 public token;
    uint256 public amount;

    bool private initialized;

    error TransferFailed();
    error ArraysLengthMismatch();
    error NotEnoughtApprovedTokens();
    error AlreadyInitialized();
    error ContractNotInitialized();

    modifier notInitialized() {
        require(!initialized, AlreadyInitialized());
        _;
    }

    function initialize(bytes memory _initData) external notInitialized returns(bool) {
        (address _tokenAddress, uint256 _airdropAmount) = abi.decode(_initData, (address, uint256));

        token = IERC20(_tokenAddress);
        amount = _airdropAmount;

        initialized = true;

        return true;
    }

    function getInitData(address _tokenAddress, uint256 _airdropAmount) external pure returns(bytes memory) {
        return abi.encode(_tokenAddress, _airdropAmount);
    }

    function airdrop(address[] calldata receivers, uint256[] calldata amounts) external {
        if(!initialized) revert ContractNotInitialized();
        if(receivers.length != amounts.length) revert ArraysLengthMismatch();
        if(token.allowance(msg.sender, address(this)) < amount) revert NotEnoughtApprovedTokens();

        for (uint256 i = 0; i < receivers.length; i++) {
            if(!token.transferFrom(msg.sender, receivers[i], amounts[i])) revert TransferFailed();
        }
    }
}