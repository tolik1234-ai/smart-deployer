// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./VestingWalletForFundriser.sol";
import "../IUtilityContract.sol";

contract CrowdFunding is Ownable, IUtilityContract {

    address public fundriser;
    uint256 public goal;
    uint256 public introduced;
    bool private initialized;
    bool public isGoalReached;
 
    address public vestingWallet;
    uint64 public vestingStartTimestamp;
    uint64 public vestingDuration;

    mapping(address => uint256) public UsercsDeposits; // user => amount

    error AlreadyInitialized();
    error GoalIsReached();
    error transferBalanceToVestingWalletIsFailed();
    error OwnerCantContribute();
    error FundriserCantContribute();
    error OwnerCantRefound();
    error FundriserCantRefound();
    error VestingIsAlreadyStarted();
    error NothingToRefound();
    error RefoundWasFailed();
    error YouMustContributeMoreThenZero();
    error VestingIsNotStarted();
    error NothingToWithdraw();
    error WithdrawWasFailed();

    event Contributed(address user, uint256 amount, uint256 timestamp);
    event VestingWasStarted(address newVestingWallet, uint256 vestedAmount, uint256 timestamp);

    modifier notInitialized() {
        require(!initialized, AlreadyInitialized());
        _;
    }

    constructor() Ownable(msg.sender) {}

    function contribute() external payable returns(bool) {
        require(!isGoalReached, GoalIsReached());
        require(msg.sender != owner(), OwnerCantContribute());
        require(msg.sender != fundriser, FundriserCantContribute());
        require(msg.value != 0, YouMustContributeMoreThenZero());
        
        introduced += msg.value;
        UsercsDeposits[msg.sender] += msg.value;

        if(introduced >= goal) {
            VestingWalletForFundriser _vestingWallet = new VestingWalletForFundriser(fundriser, uint64(block.timestamp), vestingDuration);
            (bool succes, ) = address(_vestingWallet).call{value: goal}("");
            require(succes, transferBalanceToVestingWalletIsFailed());

            vestingStartTimestamp = uint64(block.timestamp);
            vestingWallet = address(_vestingWallet);

            isGoalReached = true;

            emit VestingWasStarted(vestingWallet, goal, block.timestamp);
        } 

        emit Contributed(msg.sender, msg.value, block.timestamp);
        
        return true;
    }

    function refound() external returns(uint256) {
        require(!isGoalReached, VestingIsAlreadyStarted());
        require(msg.sender != owner(), OwnerCantRefound());
        require(msg.sender != fundriser, FundriserCantRefound());

        uint256 amount = UsercsDeposits[msg.sender];
        require(amount != 0, NothingToRefound());

        UsercsDeposits[msg.sender] = 0;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, RefoundWasFailed());

        return amount;
    }

    function withdraw() external onlyOwner {
        require(isGoalReached, VestingIsNotStarted());
        require(introduced > goal, NothingToWithdraw());
        
        (bool success, ) = payable(owner()).call{value: introduced - goal}("");
        require(success, WithdrawWasFailed());
    }

    function getInitData(
        address _owner, 
        address _fundriser, 
        uint256 _goal, 
        uint64 _vestingDuration) external pure returns(bytes memory) {
            return abi.encode(_owner, _fundriser, _goal, _vestingDuration);
    }

    function initialize(bytes memory _initData) external notInitialized returns(bool) {
        (address _owner, address _fundriser, uint256 _goal, uint64 _vestingDuration) = abi.decode(_initData, (address, address, uint256, uint64));

        Ownable.transferOwnership(_owner);
        fundriser = _fundriser;
        goal = _goal;
        vestingDuration = _vestingDuration;

        initialized =true;
        return true;
    }
}