// SPDX-License-Identifier: MIT
pragma solidity^0.8.29;

import "../IUtilityContract.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Vesting is IUtilityContract, Ownable {

    constructor() Ownable(msg.sender) {}

    bool private initialized;
    IERC20 public token;
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

    mapping(address => VestingInfo) public vestings;

    event VestingCreated(address beneficiary, uint256 ammount, uint256 creationTime);

    error AlreadyInitialized();
    error VestingNotFound();
    error CliffNotReached();
    error NothingToClaim();
    error TransferFailed();
    error InsufficientBalance();
    error VestingAlreadyExist();
    error AmountCantBeZero();
    error StartTimeShouldBeFuture();
    error DurationCantBeZero();
    error CliffCantBeLongerThanDuration();
    error CooldownCantBeLongerThanDuration();
    error InvalidBeneficiary();
    error BelowMinimalClaimAmount();
    error CooldownNotPassed();
    error CantClaimMoreThanTotalAmount();
    error WithdrawTransferFailed();
    error NothingToWithdraw();

    event Claim(address _beneficiary, uint256 amount, uint256 timestamp);
    event TokensWithdrawn(address to, uint256 amount);

    modifier notInitialized() {
        if(initialized) revert AlreadyInitialized();
        _;
    }

    function claim() public {
        VestingInfo storage vesting = vestings[msg.sender];

        if(vesting.totalAmount == 0) revert VestingNotFound();
        if(block.timestamp <= vesting.startTime + vesting.cliff) revert CliffNotReached();
        if(block.timestamp < vesting.lastClaimTime + vesting.claimCooldown) revert CooldownNotPassed();

        uint256 claimable = claimableAmount(msg.sender);
        if(claimable <= 0) revert NothingToClaim();
        if(claimable < vesting.minClaimAmount) revert BelowMinimalClaimAmount();
        if(claimable + vesting.claimed > vesting.totalAmount) revert CantClaimMoreThanTotalAmount();

        vesting.claimed += claimable;
        vesting.lastClaimTime = block.timestamp;
        allocatedTokens -= claimable;

        if(!token.transfer(msg.sender, claimable)) revert TransferFailed();

        emit Claim(msg.sender, claimable, block.timestamp);
    }

    function vestedAmount(address _claimer) internal view returns(uint256) {
        VestingInfo storage vesting = vestings[_claimer];

        if(block.timestamp < vesting.startTime + vesting.cliff) return 0;

        uint256 passedTime = block.timestamp - (vesting.startTime + vesting.cliff);
        if (passedTime > vesting.duration) {
            passedTime = vesting.duration;
        }

        return (vesting.totalAmount * passedTime) / vesting.duration;
    }

    function claimableAmount(address _claimer) public view returns(uint256) {
        VestingInfo storage vesting = vestings[_claimer];

        if(block.timestamp < vesting.startTime + vesting.cliff) return 0;

        return vestedAmount(msg.sender) - vesting.claimed;
    }

    function startVesting(
        address _beneficiary,
        uint256 _totalAmount,
        uint256 _startTime,
        uint256 _cliff,
        uint256 _duration,
        uint256 _claimCooldown,
        uint256 _minClaimAmount
    ) external onlyOwner {
        if(token.balanceOf(address(this)) - allocatedTokens < _totalAmount) revert InsufficientBalance();
        if(_totalAmount == 0) revert AmountCantBeZero();
        require(vestings[_beneficiary].totalAmount == 0 || vestings[_beneficiary].totalAmount == vestings[_beneficiary].claimed, VestingAlreadyExist());
        if(_startTime < block.timestamp) revert StartTimeShouldBeFuture();
        if(_duration == 0) revert DurationCantBeZero();
        if(_cliff > _duration) revert CliffCantBeLongerThanDuration();
        if(_claimCooldown > _duration) revert CooldownCantBeLongerThanDuration();
        if(_beneficiary == address(0)) revert InvalidBeneficiary();

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

    function withdrawUnallocated(address _to) external onlyOwner {
        uint256 available = token.balanceOf(address(this)) - allocatedTokens;
        if(available == 0) revert NothingToWithdraw();

        if(!token.transfer(_to, available)) revert WithdrawTransferFailed();
        
        emit TokensWithdrawn(_to, available);
    }

    function initialize(bytes memory _initData) external returns(bool) {
        (address _token, address _owner) = abi.decode(_initData, (address, address));

        Ownable.transferOwnership(_owner);
        token = IERC20(_token);

        initialized = true;
        return true;
    }

    function getInitData(address _token, address _owner) external pure returns(bytes memory) {
        return abi.encode(_token, _owner);
    }
 }