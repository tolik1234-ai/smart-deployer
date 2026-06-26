// SPDX-License-Identifier: MIT
pragma solidity^0.8.29;

import "../IUtilityContract.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ClassERC20Airdroper is IUtilityContract, Ownable {

    constructor() Ownable(msg.sender) {}

    IERC20 public token;
    uint256 public amount;
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

    function airdrop(address[] calldata receivers, uint256[] calldata amounts) external onlyOwner {
        if(!initialized) revert ContractNotInitialized();
        if(receivers.length != amounts.length) revert ArraysLengthMismatch();
        if(token.allowance(treasury, address(this)) < amount) revert NotEnoughtApprovedTokens();

        for (uint256 i = 0; i < receivers.length; i++) {
            if(!token.transferFrom(treasury, receivers[i], amounts[i])) revert TransferFailed();
        }
    }

    function initialize(bytes memory _initData) external notInitialized returns(bool){
        (address _token, uint256 _amount, address _treasury, address _owner) = abi.decode(_initData, (address, uint256, address, address));

        token = IERC20(_token);
        amount = _amount;
        treasury = _treasury;

        Ownable.transferOwnership(_owner);

        initialized = true;

        return true;
    }

    function getInitData(address _token, uint256 _amount, address _treasury, address _owner) external pure returns(bytes memory) {
        return abi.encode(_token, _amount, _treasury, _owner);
    }
}