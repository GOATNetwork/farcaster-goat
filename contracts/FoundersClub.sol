// contracts/FoundersClub.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract FoundersClub is Ownable, ReentrancyGuard {
    struct Founder {
        address founderAddress;
        string[] contracts;
        uint256 points;
        uint256 rewards;
        bytes32 apiKey;
        bool isActive;
    }

    struct Contract {
        string name;
        address contractAddress;
        bytes32 abiHash;
    }

    mapping(address => Founder) public founders;
    mapping(bytes32 => address) public apiKeyToFounder;
    mapping(address => Contract) public registeredContracts;
    
    uint256 public constant MAX_API_KEYS = 1000;
    bytes32[] public availableApiKeys;
    uint256 public currentApiKeyIndex;

    event FounderRegistered(address indexed founder, bytes32 apiKey);
    event ContractRegistered(address indexed founder, address contractAddress);
    event PointsUpdated(address indexed founder, uint256 points);
    event RewardsAllocated(address indexed founder, uint256 rewards);

    constructor() {
        currentApiKeyIndex = 0;
        // Initialize API keys
        for (uint i = 0; i < MAX_API_KEYS; i++) {
            availableApiKeys.push(keccak256(abi.encodePacked(i)));
        }
    }

    function registerFounder(address _founderAddress) external onlyOwner {
        require(currentApiKeyIndex < MAX_API_KEYS, "No more API keys available");
        require(!founders[_founderAddress].isActive, "Founder already registered");

        bytes32 apiKey = availableApiKeys[currentApiKeyIndex];
        string[] memory emptyContracts;

        founders[_founderAddress] = Founder({
            founderAddress: _founderAddress,
            contracts: emptyContracts,
            points: 0,
            rewards: 0,
            apiKey: apiKey,
            isActive: true
        });

        apiKeyToFounder[apiKey] = _founderAddress;
        currentApiKeyIndex++;

        emit FounderRegistered(_founderAddress, apiKey);
    }

    function registerContract(
        address founderAddress,  // Specify the founder explicitly
        string memory _name,
        address _contractAddress,
        bytes32 _abiHash
    ) external onlyOwner {
        require(registeredContracts[_contractAddress].contractAddress == address(0), "Contract already registered");
        require(founders[founderAddress].isActive, "Founder not registered or inactive");

        // Register the contract in the mapping
        registeredContracts[_contractAddress] = Contract({
            name: _name,
            contractAddress: _contractAddress,
            abiHash: _abiHash
        });

        // Associate the contract with the specified founder's contracts array
        founders[founderAddress].contracts.push(_name);

        emit ContractRegistered(founderAddress, _contractAddress);
    }

    function updatePoints(address _founder, uint256 _points) external onlyOwner {
        require(founders[_founder].isActive, "Not a registered founder");
        founders[_founder].points = _points;
        emit PointsUpdated(_founder, _points);
    }

    function allocateRewards(address _founder, uint256 _rewards) external onlyOwner {
        require(founders[_founder].isActive, "Not a registered founder");
        founders[_founder].rewards = _rewards;
        emit RewardsAllocated(_founder, _rewards);
    }

    // Getter functions
    function getFounder(address _founder) external view returns (
        address founderAddress,
        string[] memory contracts,
        uint256 points,
        uint256 rewards,
        bytes32 apiKey,
        bool isActive
    ) {
        Founder memory founder = founders[_founder];
        return (
            founder.founderAddress,
            founder.contracts,
            founder.points,
            founder.rewards,
            founder.apiKey,
            founder.isActive
        );
    }

    function getContract(address _contractAddress) external view returns (
        string memory name,
        address contractAddress,
        bytes32 abiHash
    ) {
        Contract memory contract_ = registeredContracts[_contractAddress];
        return (
            contract_.name,
            contract_.contractAddress,
            contract_.abiHash
        );
    }
}