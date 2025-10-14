// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "../IUtilityContract.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Vesting is IUtilityContract, Ownable {

    constructor(uint256 _claimCooldown) Ownable(msg.sender) {
        claimCooldown = _claimCooldown;
    }

    IERC20 public token;
    bool private initialized;
    address public beneficiary;
    uint256 public totalAmount;
    uint256 public startTime;
    uint256 public cliff;
    uint256 public duration; 
    uint256 public claimed;
    uint256 public claimCooldown;
    uint256 public lastClaimCall;
    uint256 public minimalClaim;

    //   beneficiary =>   claimed    
    mapping (address => uint256) public claimedByBeneficiary;


    error AlreadyInitialized();
    error ClaimerIsNotBeneficiary();
    error CliffNotReached();
    error NothingToClaim();
    error TransferFailed();
    error ClaimCooldownNotReached();
    error MinimalClaimNotReached();

    event Claim (address beneficiary, uint256 amount, uint256 timestamp);

    modifier  notInitialized() {
        require(!initialized, AlreadyInitialized());
        _;
    }

    function initialize (bytes memory _initData) external notInitialized returns (bool) {
        (address _token, uint256 _amount, address _treasury, address _owner) = abi.decode(_initData, (address, uint256, address, address));

        Ownable.transferOwnership(_owner); 
        
        initialized = true;
        return true;
    }

    function claim() public {
        require(claimedByBeneficiary[msg.sender] != 0, ClaimerIsNotBeneficiary());
        require(block.timestamp > startTime + cliff, CliffNotReached());
        require(block.timestamp > lastClaimCall + claimCooldown, ClaimCooldownNotReached());

        uint256 claimable = claimableAmount();
        require(claimable > 0, NothingToClaim());
        require(minimalClaim < claimable, MinimalClaimNotReached());

        claimed += claimable;
        require(token.transfer(beneficiary, claimable), TransferFailed());

        emit Claim(beneficiary, claimable, block.timestamp);
    }

    function vestedAmount() internal view returns (uint256) {
        if (block.timestamp < startTime + cliff) return 0;

        uint256 passedTime = block.timestamp - (startTime + cliff);
        return (totalAmount * passedTime) / duration;
    }

    function claimableAmount() public view returns (uint256) {
        if (block.timestamp < startTime + cliff) return 0;

        return vestedAmount() - claimed;
    }

    function getInitDate(address _token, uint256 _amount, address _treasury, address _owner) external pure returns (bytes memory) {
        return abi.encode(_token, _amount, _treasury, _owner);
    }
    
}