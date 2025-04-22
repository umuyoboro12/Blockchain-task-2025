// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * Contract Purpose:
 * The MerkleAirdrop contract is designed to securely and efficiently distribute tokens to eligible users using Merkle proofs.
 * It ensures that only users who are included in a predefined Merkle Tree can claim their airdrop. This approach saves significant
 * storage and gas costs by not storing every eligible address on-chain. Instead, a Merkle root is stored and used for verification.

 * Key Features Used:
 * - Merkle Tree: Uses Merkle proofs to verify airdrop eligibility.
 * - Merkle Root Storage: Stores the root hash on-chain for future proof verification.
 * - Claim Tracking: A mapping is used to ensure each address can only claim once.
 * - Keccak256 Hashing: Provides cryptographic hashing for secure proof validation.
 * - Event Emission: Logs successful claims for transparency and potential auditing.

 * Technical Concepts Used:
 * - Merkle Proof Verification: Each user must present a valid proof path leading to the stored Merkle root.
 * - Gas Optimization Techniques: Minimal storage is used (only root and claim map), and memory variables are prioritized during execution.
 * - Mapping for Claim Status: Efficiently tracks which addresses have claimed, preventing double-spending.
 * - Read/Write Access Patterns: Uses `calldata` for input arrays to reduce gas consumption.

*/

contract MerkleAirdrop {
    address public immutable owner;
    bytes32 public merkleRoot;

    // Mapping to keep track of which addresses have claimed
    mapping(address => bool) public hasClaimed;

    // Event to emit when a claim is successful
    event Claimed(address indexed claimant, uint256 amount);

    // Modifier to restrict function to the contract owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Not contract owner");
        _;
    }

    // Set contract owner on deployment
    constructor(bytes32 _merkleRoot) {
        owner = msg.sender;
        merkleRoot = _merkleRoot;
    }

    /// @notice Allows the owner to update the Merkle root (e.g., for future rounds)
    /// @param _newRoot New Merkle root hash
    function updateMerkleRoot(bytes32 _newRoot) external onlyOwner {
        merkleRoot = _newRoot;
    }

    /// @notice Claim tokens using a valid Merkle proof
    /// @param amount Amount of tokens the user is eligible to claim
    /// @param merkleProof Array of sibling hashes from leaf to root
    function claim(uint256 amount, bytes32[] calldata merkleProof) external {
        require(!hasClaimed[msg.sender], "Already claimed");

        // Create the leaf node from sender and amount
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amount));

        require(verifyProof(merkleProof, leaf), "Invalid Merkle Proof");

        hasClaimed[msg.sender] = true;

        // Emit an event instead of sending tokens directly for simplicity (assumes off-chain transfer or a separate contract handles sending)
        emit Claimed(msg.sender, amount);
    }

    /// @notice Internal function to verify a Merkle proof
    /// @param proof Array of sibling hashes from leaf to root
    /// @param leaf The leaf node hash to validate
    /// @return Returns true if the leaf is part of the Merkle Tree
    function verifyProof(bytes32[] calldata proof, bytes32 leaf) internal view returns (bool) {
        bytes32 computedHash = leaf;

        // Efficient memory-based loop to compute the hash from leaf to root
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            // Gas-efficient branchless ordering using conditional operator
            if (computedHash < proofElement) {
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        return computedHash == merkleRoot;
    }

    /// @notice Check if an address has already claimed
    /// @param user Address to check
    /// @return True if already claimed, false otherwise
    function isClaimed(address user) external view returns (bool) {
        return hasClaimed[user];
    }
}
