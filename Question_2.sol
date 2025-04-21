// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title UserProfile
 * @notice This smart contract is designed to manage user profile information on the blockchain.
 * It allows each user (identified by their wallet address) to create, update, retrieve, hash, or delete their own profile.
 * The profile includes essential user details such as name, age, and wallet address.
 *
 * Key Features:
 * - Immutable deployer address stored at deployment time
 * - Creation, update, and deletion of user profile records
 * - Profile data retrieval and hash generation for verification
 * - Emission of events to log state changes (profile creation, updates, deletions)
 *
 * Technical Concepts:
 * - Uses Solidity `structs` to model complex data (user profile)
 * - Employs mappings for efficient data storage and lookup
 * - Implements data validation using `require` statements to ensure data integrity
 * - Leverages `abi.encodePacked` and `keccak256` hashing for creating a unique profile fingerprint
 * - Immutable and constant variables are used for gas efficiency and fixed references
 *
 * Code Comments:
 * The code includes inline comments explaining the purpose and logic of each function, requirement, event, and data structure.
 */

contract UserProfile {
    // Application version (constant - immutable at compile time)
    string public constant APP_VERSION = "1.0";
    
    // Deployer address set only once during deployment (immutable for gas optimization)
    address public immutable deployer;
    
    // Struct to represent a user profile
    struct Profile {
        string name;
        uint age;
        address walletAddress;
    }
    
    // Mapping to store user profiles keyed by their address (private for encapsulation)
    mapping(address => Profile) private _profiles;
    
    // Event emitted when a profile is created
    event ProfileCreated(address indexed user, string name, uint age);
    
    // Event emitted when a profile is updated
    event ProfileUpdated(address indexed user, string name, uint age);
    
    // Event emitted when only the name is updated
    event NameUpdated(address indexed user, string newName);
    
    // Event emitted when a profile is deleted
    event ProfileDeleted(address indexed user);

    /**
     * @dev Constructor initializes the deployer's address
     */
    constructor() {
        deployer = msg.sender;
    }

    /**
     * @notice Create or update a complete user profile
     * @param name Name of the user (must not be empty)
     * @param age Age of the user (must be greater than 0)
     */
    function setProfile(string calldata name, uint age) external {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(age > 0, "Age must be positive");

        // Determine whether this is a new profile or an update
        bool isNew = _profiles[msg.sender].age == 0;

        // Save/update the profile
        _profiles[msg.sender] = Profile(name, age, msg.sender);

        // Emit appropriate event based on new or existing profile
        if (isNew) {
            emit ProfileCreated(msg.sender, name, age);
        } else {
            emit ProfileUpdated(msg.sender, name, age);
        }
    }

    /**
     * @notice Update only the name field of a user profile
     * @param newName New name to be set (must not be empty)
     */
    function updateName(string calldata newName) external {
        require(bytes(newName).length > 0, "Name cannot be empty");
        require(_profiles[msg.sender].age > 0, "Profile doesn't exist");

        // Update the name
        _profiles[msg.sender].name = newName;

        // Emit name update event
        emit NameUpdated(msg.sender, newName);
    }

    /**
     * @notice Retrieve the full profile of the caller
     * @return name Name of the user
     * @return age Age of the user
     * @return walletAddress Wallet address associated with the profile
     */
    function getMyProfile() external view returns (
        string memory name,
        uint age,
        address walletAddress
    ) {
        Profile memory profile = _profiles[msg.sender];
        require(profile.age > 0, "Profile doesn't exist");
        return (profile.name, profile.age, profile.walletAddress);
    }

    /**
     * @notice Generate a hash of a user's profile for integrity verification
     * @param user Address of the user
     * @return bytes32 keccak256 hash of the profile fields
     */
    function getProfileHash(address user) external view returns (bytes32) {
        require(_profiles[user].age > 0, "Profile doesn't exist");

        // Compute the hash of profile data using abi.encodePacked
        return keccak256(
            abi.encodePacked(
                _profiles[user].name,
                _profiles[user].age,
                _profiles[user].walletAddress
            )
        );
    }

    /**
     * @notice Permanently delete the caller's profile
     */
    function deleteMyProfile() external {
        require(_profiles[msg.sender].age > 0, "Profile doesn't exist");

        // Remove the profile from mapping
        delete _profiles[msg.sender];

        // Emit profile deletion event
        emit ProfileDeleted(msg.sender);
    }

    /**
     * @notice Retrieve only the name of a user's profile
     * @param user Address of the user
     * @return name of the user
     */
    function getName(address user) external view returns (string memory) {
        require(_profiles[user].age > 0, "Profile doesn't exist");
        return _profiles[user].name;
    }

    /**
     * @notice Retrieve only the age of a user's profile
     * @param user Address of the user
     * @return age of the user
     */
    function getAge(address user) external view returns (uint) {
        require(_profiles[user].age > 0, "Profile doesn't exist");
        return _profiles[user].age;
    }

    /**
     * @notice Retrieve only the wallet address associated with a user's profile
     * @param user Address of the user
     * @return wallet address stored in profile
     */
    function getWalletAddress(address user) external view returns (address) {
        require(_profiles[user].age > 0, "Profile doesn't exist");
        return _profiles[user].walletAddress;
    }
}
