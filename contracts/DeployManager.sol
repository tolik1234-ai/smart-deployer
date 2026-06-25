// SPDX-License-Identifier: MIT
pragma solidity^0.8.29;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./IUtilityContract.sol";

contract DeployManager is Ownable {

    event NewContractAdded(
        address _contractAddress,
        uint256 _fee,
        bool _isActive,
        uint256 _timestamp
    );

    event ContractFeeApdated(
        address _contractAddress,
        uint256 _oldFee,
        uint256 _newFee,
        uint256 _timestamp
    );

    event ContractStatusUpdated(
        address _contractAddress,
        bool _isActive,
        uint256 _timestamp
    );

    event NewDeployment(
        address _deployer,
        address _contractAddress,
        uint256 _fee,
        uint256 _timestamp
    );

    modifier MustBeRegistred(address _contractAddress) {
        require(contractsData[_contractAddress].registredAt > 0, ContractDoesNotRegistred());
        _;
    }

    constructor() Ownable(msg.sender) {}

    struct ContractInfo {
        uint256 fee;
        bool isActive;
        uint256 registredAt;
    }

    mapping(address => address[]) public deployedContracts;
    mapping(address => ContractInfo) public contractsData;

    error ContractNotActive();
    error NotEnoughtFunds();
    error ContractDoesNotRegistred();
    error InitializationFailed();
    error WithdrowWasFailed();

    function deploy(address _utilityContract, bytes calldata _initData) external payable returns(address){
        ContractInfo memory info = contractsData[_utilityContract];
        require(info.isActive, ContractNotActive());
        require(msg.value >= info.fee, NotEnoughtFunds());
        require(info.registredAt > 0, ContractDoesNotRegistred());

        address clone = Clones.clone(_utilityContract);

        require(IUtilityContract(clone).initialize(_initData), InitializationFailed());

        (bool success, ) = payable(owner()).call{value: msg.value}("");
        require(success, WithdrowWasFailed());

        deployedContracts[msg.sender].push(clone);

        emit NewDeployment(msg.sender, _utilityContract, msg.value, block.timestamp);

        return clone;
    }

    function addNewContract(address _contractAddress, uint256 _fee, bool _isActive) external onlyOwner{
        contractsData[_contractAddress] = ContractInfo({
            fee: _fee,
            isActive: _isActive,
            registredAt: block.timestamp
        });

        emit NewContractAdded(_contractAddress, _fee, _isActive, block.timestamp);
    }

    function updateFee(address _contractAddress, uint256 _newFee) external MustBeRegistred(_contractAddress) onlyOwner{
        uint256 _oldFee = contractsData[_contractAddress].fee;
        contractsData[_contractAddress].fee = _newFee;

        emit ContractFeeApdated(_contractAddress, _oldFee, _newFee, block.timestamp);
    }

    function deactivateContract(address _contractAddress) external MustBeRegistred(_contractAddress) onlyOwner{
        contractsData[_contractAddress].isActive = false;

        emit ContractStatusUpdated(_contractAddress, false, block.timestamp);
    }

    function activateContract(address _contractAddress) external MustBeRegistred(_contractAddress) onlyOwner{
        contractsData[_contractAddress].isActive = true;

        emit ContractStatusUpdated(_contractAddress, true, block.timestamp);
    }
}