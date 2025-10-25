// SPDX-License-Identifier: MIT
pragma solidity^0.8.29;

import "../IUtilityContract.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract CrowdFunding is IUtilityContract, Ownable {

    constructor(
        uint256 _goal,
        address _fundraiser,
        uint256 _duration
    ) Ownable(msg.sender) {
        goal = _goal;
        fundraiser = _fundraiser;
        duration = _duration;
    }

    address payable  public vesting;
    bool    private initialized;
    uint256 public  liveAmount;
    bool public finalized;
//-----------constructor-------------
    uint256 public  goal;              
    address public  fundraiser;
    uint256 public  duration;
//-----------initialize--------------
    IERC20  public  token;
    address public  vestingWallet;
//-----------------------------------

//          user       amount
    mapping(address => uint256) public userVested;

    error AlreadyInitialized();
    error GoalReached();
    error InvalidVestingImplementation();
    error TransferFailed();
    error InvalidAmount();
    error InitializationFailed();
    error OnlyFundraiserCanWithdraw();
    error VestingCallFailed();
    error NotInitialized();
    error Finalized();

    event amountContributed(address _user, uint256 _amount, uint256 timestamp);
    event amountRefunded(address _user, uint256 _amount, uint256 timestamp);
    event vestingCreated(address _vestinf, address _fundraiser, uint256 _goal, uint256 _duration, uint256 timestamp);

    modifier  notInitialized() {
        if (initialized) revert AlreadyInitialized();
        _;
    }

    modifier needInitialize() {
        if (!initialized) revert NotInitialized();
        _;
    }

    function withdraw () needInitialize public {
        if (msg.sender != fundraiser && msg.sender != owner()) {
            revert OnlyFundraiserCanWithdraw();
        }

        (bool success, ) = vesting.call(
            abi.encodeWithSignature("release(address)", address(token))
        );

        if (!success) revert VestingCallFailed();
    }

    function contribute(uint256 _amount) needInitialize public payable returns (address) {

        if (finalized) revert Finalized();

        if (!token.transferFrom(msg.sender, address(this), _amount)) {
            revert TransferFailed();
        }

        liveAmount += _amount;
        userVested[msg.sender] += _amount;

        emit amountContributed(msg.sender, _amount, block.timestamp);

        if (liveAmount >= goal) {
            if (vestingWallet == address(0)) revert InvalidVestingImplementation();

            address _vesting = Clones.clone(vestingWallet);

            vesting = payable(_vesting);

            if (!IUtilityContract(vesting).initialize(getInitDataToVesting())) {
                revert InitializationFailed();
            }
            if (!token.transfer(vesting, liveAmount)) revert TransferFailed();

            finalized = true;

            emit vestingCreated (vesting, fundraiser, goal, duration, block.timestamp);

            return vesting;
        } 

        return address(0);
        
    }

    function refund(uint256 _amount) needInitialize public {
        if (liveAmount >= goal) revert GoalReached();
        if (userVested[msg.sender] < _amount) revert InvalidAmount();

        if (!token.transfer(msg.sender, _amount)) revert  TransferFailed();

        liveAmount -= _amount;
        userVested[msg.sender] -= _amount;

        emit amountRefunded(msg.sender, _amount, block.timestamp);
    }

    function getInitDataToVesting() public view returns (bytes memory) {
        return abi.encode(fundraiser, uint64(block.timestamp), duration);
    }

    function getInitDate(address _owner, address _token, address _vestingWallet) external pure returns (bytes memory) {
        return abi.encode(_owner, _token, _vestingWallet);
    }


    function initialize (bytes memory _initData) external notInitialized returns (bool) {
        (address _owner, address _token, address _vestingWallet) = abi.decode(_initData, (address, address, address));

        Ownable.transferOwnership(_owner);

        token = IERC20(_token);
        vestingWallet = _vestingWallet;

        initialized = true;
        return true;
    }
    
}