// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title FoundersClub
 * @dev Manages founder points and rewards with admin control and secure batch operations.
 * @custom:security-contact security@foundersclub.network
 */
contract FoundersClub is Ownable, ReentrancyGuard, Pausable {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;

    // ================================
    // ========== Structs =============
    // ================================

    struct Founder {
        address[] contracts;
        uint256 allocatedPoints;     // Total points allocated by admin
        uint256 distributedPoints;   // Points distributed to contracts
        uint256 earnedRewards;       // Claimed rewards
        bytes32 apiKey;
        bool isActive;
        string founderName;
    }

    struct ContractInfo {
        string name;
        address contractAddress;
        bytes32 abiHash;
        uint256 currentPoints;       // Current active points
        uint256 pendingRewards;      // Unconverted rewards
        uint256 claimedRewards;      // Converted rewards
        string category;
        bool isVerified;
    }

    // ================================
    // ========== State Variables =====
    // ================================
    modifier onlyAdminOrFounder() {
    require(
        msg.sender == owner() || 
        (founders[msg.sender].isActive && msg.sender != address(0)),
        "Not authorized: Neither admin nor active founder"
    );
    _;
}

    mapping(address => Founder) private founders;
    mapping(bytes32 => address) private apiKeyToFounder;
    mapping(address => ContractInfo) private registeredContracts;
    mapping(string => EnumerableSet.AddressSet) private categoryContracts;

    EnumerableSet.Bytes32Set private allApiKeys;
    EnumerableSet.AddressSet private activeFounders;

    // Constants
    uint256 public constant MAX_CONTRACTS_PER_FOUNDER = 10;
    uint256 public constant REWARDS_CONVERSION_RATE = 100; // 100 points = 1 reward

    // ================================
    // ========== Events ==============
    // ================================

    // Core Points Flow Events
    event PointsAllocated(address indexed founder, uint256 amount);
    event PointsDistributed(address indexed founder, address indexed contractAddress, uint256 amount);
    event PointsConverted(address indexed contractAddress, uint256 pointsConverted, uint256 rewardsGenerated);
    event RewardsClaimed(address indexed founder, address indexed contractAddress, uint256 amount);
    
    // Admin Management Events
    event FounderRegistered(address indexed founder, bytes32 apiKey, string name);
    event FounderApiKeyUpdated(address indexed founder, bytes32 newApiKey);
    event ContractRegistered(address indexed founder, address indexed contractAddress, string name, string category);
    event ContractVerificationChanged(address indexed contractAddress, bool verified);
    event FounderStatusChanged(address indexed founder, bool isActive);

    // ================================
    // ========== Errors ==============
    // ================================

    error FounderAlreadyRegistered(address founder);
    error FounderNotRegistered(address founder);
    error FounderNotActive(address founder);
    error InvalidApiKey(bytes32 apiKey);
    error ContractAlreadyRegistered(address contractAddress);
    error ContractNotRegistered(address contractAddress);
    error ContractNotOwnedByFounder(address founder, address contractAddress);
    error InsufficientAllocatedPoints(uint256 requested, uint256 available);
    error InsufficientPoints(uint256 requested, uint256 available);
    error NoRewardsToClaim(address contractAddress);
    error ZeroAddressNotAllowed();
    error EmptyStringNotAllowed();
    error TooManyContracts(address founder);

    // ================================
    // ========== Constructor =========
    // ================================

    constructor(address initialOwner) Ownable(initialOwner) {
        _pause(); // Start paused for safety
    }
function validateContractOwnership(
    address founderAddress,
    address contractAddress
) internal view returns (bool) {
    Founder storage founder = founders[founderAddress];
    for (uint256 i = 0; i < founder.contracts.length; i++) {
        if (founder.contracts[i] == contractAddress) {
            return true;
        }
    }
    return false;
}
    // ==================================
    // ======== Core Points Flow ========
    // ==================================

    /**
     * @dev Allocates points to a founder's total balance.
     * @param founderAddress Address of the founder.
     * @param points Number of points to allocate.
     */
    function allocatePointsToFounder(
        address founderAddress,
        uint256 points
    ) external onlyOwner whenNotPaused {
        if (points == 0) return;
        if (!founders[founderAddress].isActive) 
            revert FounderNotActive(founderAddress);

        founders[founderAddress].allocatedPoints += points;
        emit PointsAllocated(founderAddress, points);
    }

    /**
     * @dev Distributes points from founder's allocated balance to a specific contract.
     * @param founderAddress Address of the founder.
     * @param contractAddress Address of the contract.
     * @param points Number of points to distribute to the contract.
     */
    function distributePointsToContract(
        address founderAddress,
        address contractAddress,
        uint256 points
    ) external onlyOwner whenNotPaused {
        if (points == 0) return;
        
        Founder storage founder = founders[founderAddress];
        if (!founder.isActive) revert FounderNotActive(founderAddress);
        
        uint256 availablePoints = founder.allocatedPoints - founder.distributedPoints;
        if (points > availablePoints)
            revert InsufficientAllocatedPoints(points, availablePoints);

        ContractInfo storage contract_ = registeredContracts[contractAddress];
        if (contract_.contractAddress == address(0))
            revert ContractNotRegistered(contractAddress);

        founder.distributedPoints += points;
        contract_.currentPoints += points;
       
        emit PointsDistributed(founderAddress, contractAddress, points);
    }

    /**
     * @dev Converts contract points to rewards.
     * @param founderAddress Address of the founder.
     * @param contractAddress Address of the contract.
     * @param pointsToConvert Number of points to convert to rewards.
     */
    function convertPointsToRewards(
        address founderAddress,
        address contractAddress,
        uint256 pointsToConvert
    ) external onlyOwner whenNotPaused {
        require(validateContractOwnership(founderAddress, contractAddress), "Not owner");
        if (pointsToConvert == 0) return;
        
        ContractInfo storage contract_ = registeredContracts[contractAddress];
        if (contract_.contractAddress == address(0))
            revert ContractNotRegistered(contractAddress);
            
        if (pointsToConvert > contract_.currentPoints)
            revert InsufficientPoints(pointsToConvert, contract_.currentPoints);
            
        uint256 rewardsToAdd = pointsToConvert / REWARDS_CONVERSION_RATE;
        
        contract_.currentPoints -= pointsToConvert;
        contract_.pendingRewards += rewardsToAdd;
        
        emit PointsConverted(contractAddress, pointsToConvert, rewardsToAdd);
    }

    /**
     * @dev Claims pending rewards for a contract and adds them to founder's earned rewards.
     * @param founderAddress Address of the founder.
     * @param contractAddress Address of the contract.
     */
    function claimRewards(
        address founderAddress,
        address contractAddress
    ) external onlyOwner whenNotPaused {
        require(validateContractOwnership(founderAddress, contractAddress), "Not owner");

        Founder storage founder = founders[founderAddress];
        if (!founder.isActive) revert FounderNotActive(founderAddress);

        ContractInfo storage contract_ = registeredContracts[contractAddress];
        if (contract_.pendingRewards == 0) 
            revert NoRewardsToClaim(contractAddress);
        
        uint256 rewardsToClaim = contract_.pendingRewards;
        contract_.pendingRewards = 0;
        contract_.claimedRewards += rewardsToClaim;
        founder.earnedRewards += rewardsToClaim;
        
        emit RewardsClaimed(founderAddress, contractAddress, rewardsToClaim);
    }

    // ==================================
    // ======= Admin Management =========
    // ==================================

    /**
     * @dev Registers a new founder.
     * @param founderAddress Address of the founder to register.
     * @param name Name of the founder.
     */
    function registerFounder(
        address founderAddress,
        string memory name
    ) external onlyOwner whenNotPaused {
        if (founderAddress == address(0)) revert ZeroAddressNotAllowed();
        if (bytes(name).length == 0) revert EmptyStringNotAllowed();
        if (founders[founderAddress].isActive)
            revert FounderAlreadyRegistered(founderAddress);

        founders[founderAddress] = Founder({
            contracts: new address[](0),
            allocatedPoints: 0,
            distributedPoints: 0,
            earnedRewards: 0,
            apiKey: bytes32(0),
            isActive: true,
            founderName: name
        });

        activeFounders.add(founderAddress);
        emit FounderRegistered(founderAddress, bytes32(0), name);
    }

   /**
 * @dev Registers a new contract for a founder.
 * @param founderAddress Address of the founder.
 * @param name Name of the contract.
 * @param contractAddress Address of the contract.
 * @param abiHash ABI hash of the contract.
 * @param category Category of the contract.
 */
function registerContract(
    address founderAddress,
    string memory name,
    address contractAddress,
    bytes32 abiHash,
    string memory category
) external onlyOwner whenNotPaused {
    if (contractAddress == address(0)) revert ZeroAddressNotAllowed();
    if (bytes(name).length == 0) revert EmptyStringNotAllowed();
    if (!founders[founderAddress].isActive) 
        revert FounderNotActive(founderAddress);
    if (registeredContracts[contractAddress].contractAddress != address(0))
        revert ContractAlreadyRegistered(contractAddress);
    if (founders[founderAddress].contracts.length >= MAX_CONTRACTS_PER_FOUNDER)
        revert TooManyContracts(founderAddress);

    // Check for duplicate contracts across all founders
    uint256 activeFoundersCount = activeFounders.length();
    for (uint256 i = 0; i < activeFoundersCount; i++) {
        address currentFounder = activeFounders.at(i);
        Founder storage founder = founders[currentFounder];
        
        for (uint256 j = 0; j < founder.contracts.length; j++) {
            if (founder.contracts[j] == contractAddress) {
                revert ContractAlreadyRegistered(contractAddress);
            }
        }
    }

    registeredContracts[contractAddress] = ContractInfo({
        name: name,
        contractAddress: contractAddress,
        abiHash: abiHash,
        currentPoints: 0,
        pendingRewards: 0,
        claimedRewards: 0,
        category: category,
        isVerified: false
    });

    founders[founderAddress].contracts.push(contractAddress);
    if (bytes(category).length > 0) {
        categoryContracts[category].add(contractAddress);
    }

    emit ContractRegistered(founderAddress, contractAddress, name, category);
}

    /**
     * @dev Updates or sets a founder's API key.
     * @param founderAddress Address of the founder.
     * @param apiKey Existing API key of the founder.
     * @param newApiKey New API key to set.
     */
    function updateApiKey(
        address founderAddress,
        bytes32 apiKey,
        bytes32 newApiKey
    ) external onlyOwner whenNotPaused {
        if (!founders[founderAddress].isActive) 
            revert FounderNotActive(founderAddress);
if (apiKey == bytes32(0) && newApiKey == bytes32(0)) revert InvalidApiKey(apiKey);


        Founder storage founder = founders[founderAddress];

        if (founder.apiKey == bytes32(0)) {
            founder.apiKey = apiKey;
            apiKeyToFounder[apiKey] = founderAddress;
            allApiKeys.add(apiKey);
        } else {
            delete apiKeyToFounder[apiKey];
            allApiKeys.remove(apiKey);
            
            founder.apiKey = newApiKey;
            apiKeyToFounder[newApiKey] = founderAddress;
            allApiKeys.add(newApiKey);
        }

        emit FounderApiKeyUpdated(founderAddress, founder.apiKey);
    }

    // ==================================
    // ========= View Functions =========
    // ==================================

    /**
     * @dev Get founder's complete status.
     * @param founderAddress Address of the founder.
     */
    function getFounderStatus(
    address founderAddress
) external view onlyAdminOrFounder returns (
    string memory founderName,
    uint256 allocatedPoints,
    uint256 distributedPoints,
    uint256 availablePoints,
    uint256 earnedRewards,
    uint256 contractCount,
    bool isActive
) {
        Founder storage founder = founders[founderAddress];
        return (
            founder.founderName,
            founder.allocatedPoints,
            founder.distributedPoints,
            founder.allocatedPoints - founder.distributedPoints,
            founder.earnedRewards,
            founder.contracts.length,
            founder.isActive
        );
    }

    /**
     * @dev Get contract's complete status.
     * @param contractAddress Address of the contract.
     */
    function getContractStatus(
    address contractAddress
) external view onlyAdminOrFounder returns (
    string memory name,
    string memory category,
    uint256 currentPoints,
    uint256 pendingRewards,
    uint256 claimedRewards,
    bool isVerified
) {
        ContractInfo storage contract_ = registeredContracts[contractAddress];
        return (
            contract_.name,
            contract_.category,
            contract_.currentPoints,
            contract_.pendingRewards,
            contract_.claimedRewards,
            contract_.isVerified
        );
    }

    /**
     * @dev Get all contracts for a founder with their current status.
     * @param founderAddress Address of the founder.
     */
    function getFounderContracts(
    address founderAddress
) external view onlyAdminOrFounder returns (
    address[] memory contractAddresses,
    string[] memory names,
    uint256[] memory points,
    uint256[] memory pendingRewards,
    bool[] memory verificationStatus
) {
        Founder storage founder = founders[founderAddress];
        uint256 length = founder.contracts.length;
        
        contractAddresses = new address[](length);
        names = new string[](length);
        points = new uint256[](length);
        pendingRewards = new uint256[](length);
        verificationStatus = new bool[](length);
        
        for (uint256 i = 0; i < length; i++) {
            address contractAddr = founder.contracts[i];
            ContractInfo storage contractInfo = registeredContracts[contractAddr];
            
            contractAddresses[i] = contractAddr;
            names[i] = contractInfo.name;
            points[i] = contractInfo.currentPoints;
            pendingRewards[i] = contractInfo.pendingRewards;
            verificationStatus[i] = contractInfo.isVerified;
        }
    }

    /**
     * @dev Get total statistics for all active founders and verified contracts.
     */
    function getTotalStats() external view onlyAdminOrFounder returns (
    uint256 totalFounders,
    uint256 totalContracts,
    uint256 totalActiveFounders,
    uint256 totalVerifiedContracts
) {
        totalActiveFounders = activeFounders.length();
        uint256 verifiedCount = 0;
        uint256 contractCount = 0;

        for (uint256 i = 0; i < activeFounders.length(); i++) {
            address founderAddr = activeFounders.at(i);
            contractCount += founders[founderAddr].contracts.length;

            for (uint256 j = 0; j < founders[founderAddr].contracts.length; j++) {
                address contractAddr = founders[founderAddr].contracts[j];
                if (registeredContracts[contractAddr].isVerified) {
                    verifiedCount++;
                }
            }
        }

        return (
            activeFounders.length(),
            contractCount,
            totalActiveFounders,
            verifiedCount
        );
    }

    // ==================================
    // ======= Utility Functions ========
    // ==================================

    /**
     * @dev Update founder status (active/inactive).
     * @param founderAddress Address of the founder.
     * @param isActive Boolean indicating whether the founder is active.
     */
    function updateFounderStatus(
        address founderAddress,
        bool isActive
    ) external onlyOwner whenNotPaused {
        if (founders[founderAddress].apiKey == bytes32(0))
            revert FounderNotRegistered(founderAddress);

        founders[founderAddress].isActive = isActive;
        
        if (isActive) {
            activeFounders.add(founderAddress);
        } else {
            activeFounders.remove(founderAddress);
        }
        
        emit FounderStatusChanged(founderAddress, isActive);
    }

    /**
     * @dev Verify or unverify a contract.
     * @param contractAddress Address of the contract.
     * @param verified Boolean indicating verification status.
     */
    function verifyContract(
        address contractAddress,
        bool verified
    ) external onlyOwner whenNotPaused {
        ContractInfo storage contract_ = registeredContracts[contractAddress];
        if (contract_.contractAddress == address(0))
            revert ContractNotRegistered(contractAddress);

        contract_.isVerified = verified;
        emit ContractVerificationChanged(contractAddress, verified);
    }

    /**
     * @dev Emergency pause function to halt operations.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Resume contract operations after pause.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // ==================================
    // ===== Additional Utility Functions =====
    // ==================================

    /**
     * @dev Retrieve a founder's details by their API key.
     * @param apiKey The API key associated with the founder.
     * @return founderAddress The address of the founder.
     * @return founderName The name of the founder.
     * @return allocatedPoints The total points allocated to the founder.
     * @return availablePoints The available points for the founder.
     * @return earnedRewards The total rewards the founder has earned.
     * @return isActive Boolean indicating if the founder is active.
     */
    function getFounderByApiKey(
    bytes32 apiKey
) external view onlyAdminOrFounder returns (
    address founderAddress,
    string memory founderName,
    uint256 allocatedPoints,
    uint256 availablePoints,
    uint256 earnedRewards,
    bool isActive
) {
        founderAddress = apiKeyToFounder[apiKey];
        if (founderAddress == address(0)) revert InvalidApiKey(apiKey);

        Founder storage founder = founders[founderAddress];
        return (
            founderAddress,
            founder.founderName,
            founder.allocatedPoints,
            founder.allocatedPoints - founder.distributedPoints,
            founder.earnedRewards,
            founder.isActive
        );
    }

    /**
     * @dev Retrieve the list of all active founders with their basic info.
     * @return addresses Array of addresses for each active founder.
     * @return names Array of names for each active founder.
     * @return allocatedPoints Array of allocated points for each active founder.
     * @return earnedRewards Array of earned rewards for each active founder.
     */
    function getActiveFounders() external view onlyAdminOrFounder returns (
    address[] memory addresses,
    string[] memory names,
    uint256[] memory allocatedPoints,
    uint256[] memory earnedRewards
) {
        uint256 count = activeFounders.length();
        addresses = new address[](count);
        names = new string[](count);
        allocatedPoints = new uint256[](count);
        earnedRewards = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            address founderAddr = activeFounders.at(i);
            Founder storage founder = founders[founderAddr];
            
            addresses[i] = founderAddr;
            names[i] = founder.founderName;
            allocatedPoints[i] = founder.allocatedPoints;
            earnedRewards[i] = founder.earnedRewards;
        }
    }
}