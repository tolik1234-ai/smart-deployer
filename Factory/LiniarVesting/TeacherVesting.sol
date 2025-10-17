// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "../IUtilityContract.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Vesting is IUtilityContract, Ownable {

    constructor() Ownable(msg.sender) {}

    IERC20 public token;
    bool private initialized;
    uint256 public allocatedTokens;


    struct VestingInfo {
        uint256 totalAmount;
        uint256 startTime;
        uint256 cliff;
        uint256 duration; 
        uint256 claimed;
        uint256 lastClaimTime;
        uint256 claimCooldown;
        uint256 minClaimAmount;
    }

    mapping ( address => VestingInfo ) public vestings;

    error AlreadyInitialized();
    error CliffNotReached();
    error NothingToClaim();
    error TransferFailed();
    error InsufficientBalance();
    error VestinAlreadyExst();
    error AmountCantBeZero();
    error StartTimeShouldBeFuture();
    error DuretionCantBeZero();
    error CliffCantBeLongerThanDuration();
    error ClaimCooldownCantBeLongerThanDuration();
    error InvalidBeneficiory();
    error VestingNotFound();
    error BelowMinimalClaimAmount();
    error CooldownNotPassed();
    error CantClaimMoreThanTotalAmount();
    error WithdrawTransferFailed();
    error NothingToWithdraw();

    event Claim (address beneficiary, uint256 amount, uint256 timestamp);
    event TokenWithdrawn(address to, uint256 amount);
    event VestingCreated(address beneficiary, uint256 amount, uint256 creationTime);

    modifier  notInitialized() {
        require(!initialized, AlreadyInitialized());
        _;
    }

    function withdrawUnallocated(address _to) external onlyOwner {
        uint256 available = token.balanceOf(address(this)) - allocatedTokens;
        require(available > 0, NothingToWithdraw());

        require(token.transfer(_to, available), WithdrawTransferFailed());

        emit TokenWithdrawn(_to, available);
    }

    function claim() public {
        VestingInfo storage vesting = vestings[msg.sender];

        require(vesting.totalAmount != 0, VestingNotFound());
        require(block.timestamp > vesting.startTime + vesting.cliff, CliffNotReached());
        require(block.timestamp >= vesting.lastClaimTime + vesting.claimCooldown, CooldownNotPassed());

        uint256 claimable = claimableAmount(msg.sender);
        require(claimable > 0, NothingToClaim());
        require(vesting.minClaimAmount <= claimable, BelowMinimalClaimAmount());
        require(claimable + vesting.claimed <= vesting.totalAmount, CantClaimMoreThanTotalAmount());

        vesting.claimed += claimable;
        vesting.lastClaimTime = block.timestamp;
        allocatedTokens -= claimable;

        require(token.transfer(msg.sender, claimable), TransferFailed());

        emit Claim(msg.sender, claimable, block.timestamp);
    }

    function vestedAmount(address _claimer) internal view returns (uint256) {
        VestingInfo storage vesting = vestings[_claimer];
        if (block.timestamp < vesting.startTime + vesting.cliff) return 0;

        uint256 passedTime = block.timestamp - (vesting.startTime + vesting.cliff);
        if (passedTime > vesting.duration) {
            passedTime = vesting.duration;
        }
        return (vesting.totalAmount * passedTime) / vesting.duration;
    }

    function claimableAmount(address _claimer) public view returns (uint256) {
        VestingInfo storage vesting = vestings[_claimer];
        if (block.timestamp < vesting.startTime + vesting.cliff) return 0;

        return vestedAmount(_claimer) - vesting.claimed;
    }

    function startVesting(
        address _beneficiary,
        uint256 _startTime,
        uint256 _totalAmount,
        uint256 _cliff,
        uint256 _duration,
        uint256 _claimCooldown,
        uint256 _minClaimAmount
    ) external onlyOwner{
        require(token.balanceOf(address(this)) - allocatedTokens >= _totalAmount, InsufficientBalance());
        require(vestings[_beneficiary].totalAmount == 0 || vestings[_beneficiary].totalAmount == vestings[_beneficiary].claimed, VestinAlreadyExst());
        require(_totalAmount > 0, AmountCantBeZero());
        require(_startTime > block.timestamp, StartTimeShouldBeFuture());
        require(_duration > 0, DuretionCantBeZero());
        require(_cliff < _duration, CliffCantBeLongerThanDuration());
        require(_claimCooldown < _duration, ClaimCooldownCantBeLongerThanDuration());
        require(_beneficiary != address(0), InvalidBeneficiory());

        vestings[_beneficiary] = VestingInfo({
            totalAmount: _totalAmount,
            startTime: _startTime,
            cliff: _cliff,
            duration: _duration,
            claimed: 0,
            lastClaimTime: 0,
            claimCooldown: _claimCooldown,
            minClaimAmount: _minClaimAmount
        });

        allocatedTokens += _totalAmount;

        emit VestingCreated(_beneficiary, _totalAmount, block.timestamp);
    }

    function initialize (bytes memory _initData) external notInitialized returns (bool) {
        (address _token, address _owner) = abi.decode(_initData, (address, address));

        Ownable.transferOwnership(_owner); 
        
        token =IERC20( _token);

        initialized = true;
        return true;
    }

    function getInitDate(address _token, address _owner) external pure returns (bytes memory) {
        return abi.encode(_token, _owner);
    }
    
}