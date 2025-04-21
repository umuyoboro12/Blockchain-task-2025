// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract UserProfile {
    // Application version (constant)
    string public constant APP_VERSION = "1.0";
    
    // Immutable deployer address
    address public immutable deployer;
    
    // User profile structure
    struct Profile {
        string name;
        uint age;
        address walletAddress;
    }
    
    // Private mapping for user profiles
    mapping(address => Profile) private _profiles;
    
    // Events
    event ProfileCreated(address indexed user, string name, uint age);
    event ProfileUpdated(address indexed user, string name, uint age);
    event NameUpdated(address indexed user, string newName);
    event ProfileDeleted(address indexed user);

    constructor() {
        deployer = msg.sender;
    }

    /**
     * @notice Create or update full user profile
     * @param name User's name (non-empty)
     * @param age User's age (must be > 0)
     */
    function setProfile(string calldata name, uint age) external {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(age > 0, "Age must be positive");
        
        bool isNew = _profiles[msg.sender].age == 0;
        _profiles[msg.sender] = Profile(name, age, msg.sender);
        
        if (isNew) {
            emit ProfileCreated(msg.sender, name, age);
        } else {
            emit ProfileUpdated(msg.sender, name, age);
        }
    }

    /**
     * @notice Update only the user's name
     * @param newName New name (non-empty)
     */
    function updateName(string calldata newName) external {
        require(bytes(newName).length > 0, "Name cannot be empty");
        require(_profiles[msg.sender].age > 0, "Profile doesn't exist");
        
        _profiles[msg.sender].name = newName;
        emit NameUpdated(msg.sender, newName);
    }

    /**
     * @notice Get complete user profile
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
     * @notice Get the keccak256 hash of a user's profile
     * @param user Address of the user
     * @return bytes32 Hash of the profile data
     */
    function getProfileHash(address user) external view returns (bytes32) {
        require(_profiles[user].age > 0, "Profile doesn't exist");
        
        // Hash the profile data (name, age, walletAddress)
        return keccak256(
            abi.encodePacked(
                _profiles[user].name,
                _profiles[user].age,
                _profiles[user].walletAddress
            )
        );
    }

    /**
     * @notice Delete user's profile
     */
    function deleteMyProfile() external {
        require(_profiles[msg.sender].age > 0, "Profile doesn't exist");
        delete _profiles[msg.sender];
        emit ProfileDeleted(msg.sender);
    }

    // Individual getters
    function getName(address user) external view returns (string memory) {
        require(_profiles[user].age > 0, "Profile doesn't exist");
        return _profiles[user].name;
    }

    function getAge(address user) external view returns (uint) {
        require(_profiles[user].age > 0, "Profile doesn't exist");
        return _profiles[user].age;
    }

    function getWalletAddress(address user) external view returns (address) {
        require(_profiles[user].age > 0, "Profile doesn't exist");
        return _profiles[user].walletAddress;
    }
}