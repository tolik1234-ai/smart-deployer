// SPDX-License-Identifier: MIT
pragma solidity^0.8.29;

import "../IUtilityContract.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/finance/VestingWallet.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract CroudFunding is IUtilityContract, Ownable {

    constructor(
        uint256 _goal,
        address _fundraiser,
        uint256 _duration
    ) Ownable(msg.sender) {
        goal = _goal;
        fundraiser = _fundraiser;
        duration = _duration;
    }

    address public vesting;
    bool    private initialized;
    uint256 public  liveAmount;
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
    error GoalNotReached();
    error TransferFailed();
    error InvalidAmount();
    error InitializationFailed();
    error OnlyFundraiserCanWithdraw();
    error VestingCallFailed();
    error NotInitialized();

    modifier  notInitialized() {
        require(!initialized, AlreadyInitialized());
        _;
    }

    modifier needInitialize() {
        require(initialized, NotInitialized());
        _;
    }

    function withraw () needInitialize public {
        require(msg.sender == fundraiser || msg.sender == owner(), OnlyFundraiserCanWithdraw());

        (bool success, ) = vesting.call(
            abi.encodeWithSignature("release(address)", token)
        );
        require(success, VestingCallFailed());
    }

    function contribute(uint256 _amount) needInitialize public payable returns (address) {

        require(token.transferFrom(msg.sender, address(this), _amount), TransferFailed());

        liveAmount += _amount;
        userVested[msg.sender] += _amount;

        if (liveAmount >= goal) {
            require(vestingWallet != address(0), GoalNotReached());

            address _vesting = Clones.clone(vestingWallet);

            vesting = payable(_vesting);

            require(IUtilityContract(vesting).initialize(getInitDateToVesting()), InitializationFailed());
            require(token.transfer(vesting, _amount), TransferFailed());

            return vesting;
        } 

        return address(0);
        
    }

    function refund(uint256 _amount) needInitialize public {
        require(liveAmount < goal, GoalReached());
        require(userVested[msg.sender] >= _amount, InvalidAmount());

        require(token.transfer(msg.sender, _amount), TransferFailed());

        liveAmount -= _amount;
        userVested[msg.sender] -= _amount;
    }

    function getInitDateToVesting() public view returns (bytes memory) {
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