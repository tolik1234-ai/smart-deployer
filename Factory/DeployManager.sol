// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./IUtilityContract.sol";

contract DeployManager is Ownable {

    event NewContractAdd(
        address _contractAddress,
        uint256 _fee, 
        bool _isActive, 
        uint256 _timestamp);

    event ContractFeeUpdated(
        address _contractAddress, 
        uint256 _oldFee, 
        uint256 _newFee, 
        uint256 _timestamp);

    event ConrtactStatusUpdated(
        address _cotractAddress, 
        bool _isActive, 
        uint256 _timestamp);

    event NewDeployment(
        address _deployer,
        address _contactAddress,
        uint256 _fee,
        uint256 _timestamp);

    constructor() Ownable(msg.sender) {

    }

    struct ContractInfo{
        uint256 fee;
        bool isActive;
        uint256 registredAt;
    }

    mapping(address => address[]) public deployedContracts;
    mapping(address => ContractInfo) public contractsData;

    error ContractNotActive();
    error NotEnougthFunds();
    error ContactDoesNotRegisterd();
    error InitializationFailed();

    function deploy(
        address _utilityContract, 
        bytes calldata _initData
        ) external payable returns (address) {
            
            ContractInfo memory info = contractsData[_utilityContract];

            require(info.isActive, ContractNotActive());
            require(msg.value >= info.fee, NotEnougthFunds());
            require(info.registredAt > 0, ContactDoesNotRegisterd());

            address clone = Clones.clone(_utilityContract);

            require(IUtilityContract(clone).initialize(_initData), InitializationFailed());

            payable(owner()).transfer(msg.value);

            deployedContracts[msg.sender].push(clone);

            emit NewDeployment(msg.sender, clone, msg.value, block.timestamp);

            return payable(clone);
    }

    function addNewContract(
        address _contractAddress, 
        uint256 _fee, 
        bool _isActive
        ) external onlyOwner {
            contractsData[_contractAddress] = ContractInfo({
                fee: _fee, 
                isActive: _isActive,
                registredAt: block.timestamp
            });

            emit NewContractAdd(_contractAddress, _fee, _isActive, block.timestamp);
    }

    function updateFee(
        address _contractAddress, 
        uint256 _newFee
        ) external onlyOwner {
            require(contractsData[_contractAddress].registredAt > 0, ContactDoesNotRegisterd());

            uint256 _oldFee = contractsData[_contractAddress].fee;
            contractsData[_contractAddress].fee = _newFee;

            emit ContractFeeUpdated(_contractAddress, _oldFee, _newFee, block.timestamp);
    }

    function deactivateContract(
         address _contractAddress
         ) external onlyOwner {
            require(contractsData[_contractAddress].registredAt > 0, ContactDoesNotRegisterd());

            contractsData[_contractAddress].isActive = false;

            emit ConrtactStatusUpdated(_contractAddress, false, block.timestamp);
    }

    function activateContract(
        address _contractAddress
        ) external onlyOwner {
            require(contractsData[_contractAddress].registredAt > 0, ContactDoesNotRegisterd());

            contractsData[_contractAddress].isActive = true;

            emit ConrtactStatusUpdated(_contractAddress, true, block.timestamp);
    }

}