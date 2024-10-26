// contracts/FoundersClub.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract FoundersClub is Ownable, ReentrancyGuard {
    struct Founder {
        address founderAddress;
        address[] contracts; // Array of contract addresses registered by the founder
        uint256 totalPoints; // Total points associated with the founder
        uint256 earnedRewards; // Total rewards associated with the founder
        bytes32 apiKey;
        bool isActive;
    }

    struct Contract {
        string name;
        address contractAddress;
        bytes32 abiHash;
        uint256 points; // Points associated with this specific contract
        uint256 rewards; // Rewards associated with this specific contract
    }

    mapping(address => Founder) public founders;
    mapping(bytes32 => address) public apiKeyToFounder;
    mapping(address => Contract) public registeredContracts;
    
    uint256 public constant MAX_API_KEYS = 1000;
    bytes32[] public availableApiKeys;
    uint256 public currentApiKeyIndex;

    event FounderRegistered(address indexed founder, bytes32 apiKey);
    event ContractRegistered(address indexed founder, address contractAddress);
    event PointsUpdated(address indexed founder, uint256 totalPoints);
    event RewardsAllocated(address indexed founder, uint256 earnedRewards);

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

        founders[_founderAddress] = Founder({
            founderAddress: _founderAddress,
            contracts: new address , // Initialize an empty array of contract addresses
            totalPoints: 0,
            earnedRewards: 0,
            apiKey: apiKey,
            isActive: true
        });

        apiKeyToFounder[apiKey] = _founderAddress;
        currentApiKeyIndex++;

        emit FounderRegistered(_founderAddress, apiKey);
    }

    function registerContract(
        address founderAddress,
        string memory _name,
        address _contractAddress,
        bytes32 _abiHash,
        uint256 _points,
        uint256 _rewards
    ) external onlyOwner {
        require(registeredContracts[_contractAddress].contractAddress == address(0), "Contract already registered");
        require(founders[founderAddress].isActive, "Founder not registered or inactive");

        // Register the contract in the mapping
        registeredContracts[_contractAddress] = Contract({
            name: _name,
            contractAddress: _contractAddress,
            abiHash: _abiHash,
            points: _points,
            rewards: _rewards
        });

        // Associate the contract with the specified founder's contracts array
        founders[founderAddress].contracts.push(_contractAddress);

        emit ContractRegistered(founderAddress, _contractAddress);
    }

    // Function to update total points and earned rewards for a specific founder, resetting contract points and rewards to zero
    function updateTotalPointsAndRewards(address _founderAddress) public {
        require(founders[_founderAddress].isActive, "Not a registered founder");

        uint256 totalPoints = 0;
        uint256 earnedRewards = 0;

        // Sum up points and rewards from each contract associated with the founder, then reset them to zero
        for (uint i = 0; i < founders[_founderAddress].contracts.length; i++) {
            address contractAddress = founders[_founderAddress].contracts[i];
            Contract storage contractData = registeredContracts[contractAddress];
            totalPoints += contractData.points;
            earnedRewards += contractData.rewards;

            // Reset the contract's points and rewards to zero after adding them to the founder's totals
            contractData.points = 0;
            contractData.rewards = 0;
        }

        // Update the founder's total points and earned rewards
        founders[_founderAddress].totalPoints += totalPoints;
        founders[_founderAddress].earnedRewards += earnedRewards;

        emit PointsUpdated(_founderAddress, founders[_founderAddress].totalPoints);
        emit RewardsAllocated(_founderAddress, founders[_founderAddress].earnedRewards);
    }

    // Function to update points and rewards for a specific contract, adding to founder’s totals and resetting the contract
    function updatePointsAndRewardsForContract(address _founderAddress, address _contractAddress) public {
        require(founders[_founderAddress].isActive, "Not a registered founder");
        require(registeredContracts[_contractAddress].contractAddress != address(0), "Contract not registered");

        Contract storage contractData = registeredContracts[_contractAddress];

        // Add the contract's points and rewards to the founder's totals
        founders[_founderAddress].totalPoints += contractData.points;
        founders[_founderAddress].earnedRewards += contractData.rewards;

        // Reset the contract's points and rewards to zero
        contractData.points = 0;
        contractData.rewards = 0;

        emit PointsUpdated(_founderAddress, founders[_founderAddress].totalPoints);
        emit RewardsAllocated(_founderAddress, founders[_founderAddress].earnedRewards);
    }

    // Getter functions
    function getFounder(address _founder) external view returns (
        address founderAddress,
        address[] memory contracts,
        uint256 totalPoints,
        uint256 earnedRewards,
        bytes32 apiKey,
        bool isActive
    ) {
        Founder memory founder = founders[_founder];
        return (
            founder.founderAddress,
            founder.contracts,
            founder.totalPoints,
            founder.earnedRewards,
            founder.apiKey,
            founder.isActive
        );
    }

    function getContract(address _contractAddress) external view returns (
        string memory name,
        address contractAddress,
        bytes32 abiHash,
        uint256 points,
        uint256 rewards
    ) {
        Contract memory contract_ = registeredContracts[_contractAddress];
        return (
            contract_.name,
            contract_.contractAddress,
            contract_.abiHash,
            contract_.points,
            contract_.rewards
        );
    }
}