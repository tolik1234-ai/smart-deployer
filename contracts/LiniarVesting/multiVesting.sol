// SPDX-License-Identifier: MIT
pragma solidity^0.8.29;

import "../IUtilityContract.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract MultiVesting is IUtilityContract, Ownable {

    bool private initialized;
    uint256[] public vestingIds;

    struct Vesting {
        IERC20 token;
        bytes32 merkleRoot;
        uint256 totalAmount;
        uint256 startTime;
        uint256 cliff;
        uint256 duration;
        uint256 cooldown;
        uint256 minClaimSum;
    }

    struct UserActions {
        uint256 lastCallTime;
        uint256 claimed;
    }

//        vestingId => vestingSettings
    mapping(uint256 => Vesting) public vestingList;
//             user =>       vestingId => UserActions
    mapping(address => mapping(uint256 => UserActions)) public usersActions;

    error VestingIdAlreadyRegistered();
    error YourNotInWhiteList();
    error AlreadyInitialized();
    error NotEnoughTokenOnBalance();
    error CliffNotReached();
    error CoolDawnNotReached();
    error NothingToClaim();
    error TransferFailed();
    error YouMustToClaimMoreAmount();

    event Claim(uint256 _vestingId, address _beneficiary, uint256 _claimAmount, uint256 _timestamp);

    modifier InWhiteList(uint256 vestingId, uint256 _amount, bytes32[] memory _proof) {

        bytes32 leaf = keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(msg.sender, _amount)
                )
            )
        );

        if(!MerkleProof.verify(_proof, vestingList[vestingId].merkleRoot, leaf)) revert YourNotInWhiteList();
        _;
    }

    modifier notInitialized() {
        if(initialized) revert AlreadyInitialized();
        _;
    }

    constructor() Ownable(msg.sender) {}

    function claim(
        uint256 _vestingId, 
        uint256 _amount, 
        bytes32[] memory _proof) external InWhiteList(_vestingId, _amount, _proof) {
        Vesting memory vesting = vestingList[_vestingId];
        UserActions storage user = usersActions[msg.sender][_vestingId];

        if(block.timestamp <= vesting.startTime + vesting.cliff) revert CliffNotReached();
        if(block.timestamp - user.lastCallTime < vesting.cooldown) revert CoolDawnNotReached();

        uint256 claimable = claimableAmount(_vestingId, _amount);

        if(claimable < vesting.minClaimSum) revert YouMustToClaimMoreAmount();
        if(claimable <= 0) revert NothingToClaim();

        user.claimed += claimable;
        user.lastCallTime = block.timestamp;
        if(!vesting.token.transfer(msg.sender, claimable)) revert TransferFailed();

        emit Claim(_vestingId, msg.sender, claimable, block.timestamp);
        }
    
    function vestedAmount(
        uint256 _vestingId, 
        uint256 _amount) internal
        view returns(uint256) {
        Vesting memory vesting = vestingList[_vestingId];
    
        if(block.timestamp <= vesting.startTime + vesting.cliff) return 0;
        uint256 passedTime = block.timestamp - (vesting.startTime + vesting.cliff);

        if(passedTime >= vesting.duration) return _amount;
        return(_amount * passedTime) / vesting.duration;
    }

    function claimableAmount(
        uint256 _vestingId, 
        uint256 _amount) internal view returns(uint256) {
        Vesting memory vesting = vestingList[_vestingId];
        UserActions memory user = usersActions[msg.sender][_vestingId];

        if(block.timestamp < vesting.startTime + vesting.cliff) return 0;
        if(vestedAmount(_vestingId, _amount) < user.claimed) return 0;

        return vestedAmount(_vestingId, _amount) - user.claimed;
        }

    function startVesting(
        uint256 _vestingId,
        address _token,
        bytes32 _merkleRoot,
        uint256 _totalAmount,
        uint256 _cliff,
        uint256 _duration,
        uint256 _cooldown,
        uint256 _minClaimSum
    ) external onlyOwner {
        if(IERC20(_token).balanceOf(address(this)) < _totalAmount) revert NotEnoughTokenOnBalance();
        for(uint i = 0; i < vestingIds.length; i++){
            if(vestingIds[i] == _vestingId) revert VestingIdAlreadyRegistered();
        }

        vestingList[_vestingId] = Vesting({
            token: IERC20(_token),
            merkleRoot: _merkleRoot,
            totalAmount: _totalAmount,
            startTime: block.timestamp,
            cliff: _cliff,
            duration: _duration,
            cooldown: _cooldown,
            minClaimSum: _minClaimSum
        });

        vestingIds.push(_vestingId);
    }

    function initialize(bytes memory _initData) external notInitialized returns(bool) {
        address _owner = abi.decode(_initData, (address));
        Ownable.transferOwnership(_owner);

        initialized = true;
        return true;
    }

    function getInitData(address _owner) external pure returns(bytes memory) {
        return abi.encode(_owner);
    }
}