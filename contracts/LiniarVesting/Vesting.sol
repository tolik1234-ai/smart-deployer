// SPDX-License-Identifier: MIT
pragma solidity^0.8.29;

import "../IUtilityContract.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Vesting is IUtilityContract, Ownable {

    constructor() Ownable(msg.sender) {}

    bool private initialized;
    IERC20 public token;
    address public beneficiary;
    uint256 public totalAmount;
    uint256 public startTime;
    uint256 public cliff;
    uint256 public duration;
    uint256 public claimed;

    error AlreadyInitialized();
    error ClaimerIsNotBeneficiary();
    error CliffNotReached();
    error NothingToClaim();
    error TransferFailed();

    event Claim(address _beneficiary, uint256 amount, uint256 timestamp);

    modifier notInitialized() {
        if(initialized) revert AlreadyInitialized();
        _;
    }

    function claim() public {
        if(msg.sender != beneficiary) revert ClaimerIsNotBeneficiary();
        if(block.timestamp <= startTime + cliff) revert CliffNotReached();

        uint256 claimable = claimableAmount();
        if(claimable <= 0) revert NothingToClaim();

        claimed += claimable;
        if(!token.transfer(beneficiary, claimable)) revert TransferFailed();

        emit Claim(msg.sender, claimable, block.timestamp);
    }

    function vestedAmount() internal view returns(uint256) {
        if(block.timestamp < startTime + cliff) return 0;

        uint256 passedTime = block.timestamp - (startTime + cliff);
        return (totalAmount * passedTime) / duration;
    }

    function claimableAmount() public view returns(uint256) {
        if(block.timestamp < startTime + cliff) return 0;

        return vestedAmount() - claimed;
    }

    function initialize(bytes memory _initData) external returns(bool) {}

    function getInitData() external pure returns(bytes memory) {}
 }