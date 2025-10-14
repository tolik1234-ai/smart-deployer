// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "../IUtilityContract.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Vesting2 is IUtilityContract, Ownable {

    constructor(
        uint256 _startTime, 
        uint256 _cliff, 
        uint256 _duration, 
        uint256 _claimCooldown, 
        uint256 _minimalClaim) Ownable(msg.sender) {
        startTime = _startTime;
        cliff = _cliff;
        duration = _duration;
        claimCooldown = _claimCooldown;
        minimalClaim = _minimalClaim;
    }

    IERC20 public token;
    bool private initialized;
    uint256 public totalAmount;
    uint256 public totalInvested;
    uint256 public startTime;
    uint256 public cliff;
    uint256 public duration;
    uint256 public claimCooldown;
    uint256 public minimalClaim;

    //   beneficiary =>   invested
    mapping (address => uint256) public beneficiaryInvested;

    //   beneficiary =>   claimed    
    mapping (address => uint256) public claimedByBeneficiary;

    //   benificiary => lstlastClaimCall
    mapping (address => uint256) public lastClaimCall;


    error AlreadyInitialized();
    error ClaimerIsNotBeneficiary();
    error CliffNotReached();
    error NothingToClaim();
    error TransferFailed();
    error ClaimCooldownNotReached();
    error MinimalClaimNotReached();
    error VestingAllreadyStarted();
    error InvestedAmountMustBeGreaterThan0();

    event Claim (address _beneficiary, uint256 _amount, uint256 _timestamp);

    event newBenificiaryAdded (address _beneficiary, uint256 _invested, uint256 _timestamp);

    modifier  notInitialized() {
        require(!initialized, AlreadyInitialized());
        _;
    }

    function addBenificiary ( address _beneficiary, uint256 _invested) external onlyOwner {
        require(startTime > block.timestamp, VestingAllreadyStarted());
        require(_invested > 0, InvestedAmountMustBeGreaterThan0());

        beneficiaryInvested[_beneficiary] = _invested;
        totalInvested += _invested;

        emit newBenificiaryAdded(_beneficiary, _invested, block.timestamp);
    }

    function initialize (bytes memory _initData) external notInitialized returns (bool) {
        (address _token, uint256 _totalAmount, address _owner) = abi.decode(_initData, (address, uint256, address));

        token = IERC20(_token);
        totalAmount = _totalAmount;

        Ownable.transferOwnership(_owner);
        
        initialized = true;
        return true;
    }

    function claim() public {
        require(beneficiaryInvested[msg.sender] != 0, ClaimerIsNotBeneficiary());
        require(block.timestamp > startTime + (block.timestamp - cliff), CliffNotReached());
        require(block.timestamp > lastClaimCall[msg.sender] + claimCooldown, ClaimCooldownNotReached());
        lastClaimCall[msg.sender] = block.timestamp;

        uint256 claimable = claimableAmount(msg.sender);
        require(claimable > 0, NothingToClaim());
        require(minimalClaim < claimable, MinimalClaimNotReached());

        claimedByBeneficiary[msg.sender] += claimable;
        require(token.transfer(msg.sender, claimable), TransferFailed());

        emit Claim(msg.sender, claimable, block.timestamp);
    }

    function vestedAmount(address _beneficiary) internal view returns (uint256) {
        if (block.timestamp < startTime + cliff) return 0;

        uint256 passedTime = block.timestamp - (startTime + cliff);
        return (((beneficiaryInvested[_beneficiary] / totalInvested) * passedTime) / duration) * totalAmount;
    }

    function claimableAmount(address _beneficiary) public view returns (uint256) {
        if (block.timestamp < startTime + cliff) return 0;

        return vestedAmount(_beneficiary) - claimedByBeneficiary[_beneficiary];
    }


    function getInitDate(address _token, uint256 _totalAmount, address _owner) external pure returns (bytes memory) {
        return abi.encode(_token, _totalAmount, _owner);
    }
}