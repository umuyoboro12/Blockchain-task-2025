// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/*
New Branch
Contract Name: DecentralizedIdentity
1. Contract Purpose:
   The DecentralizedIdentity contract enables users to store and manage verifiable credentials (represented as document hashes) on-chain. These credentials can be signed by trusted issuers such as government agencies or institutions, ensuring authenticity and preventing tampering. Issuers can also revoke credentials if needed.

2. Key Features Used:
   - Users can link document hashes to their identity.
   - Trusted issuers can issue (sign) credentials.
   - Issuers can also revoke previously issued credentials.
   - Mapping is used to associate users with their credentials and to track credential validity.

3. Technical Concepts Used:
   - Use of mappings for efficient credential lookup and status tracking.
   - Modifier-based access control for trusted issuer permissions.
   - Events to log credential issuance and revocation actions for transparency.
   - `uint256` is used to store hashed credentials, enabling gas-efficient and tamper-proof storage.

4. Code Comments:
   All key logic is thoroughly explained with inline comments, including credential management, trusted issuer control, and revoke logic.
*/

contract DecentralizedIdentity {
    // Owner of the contract
    address public owner;

    // Mapping of credential hash to issuer address
    mapping(address => mapping(uint256 => address)) public credentials;

    // Mapping of trusted issuers
    mapping(address => bool) public trustedIssuers;

    // Mapping to track revoked credentials
    mapping(uint256 => bool) public revoked;

    // Events
    event CredentialIssued(address indexed user, uint256 indexed credentialHash, address indexed issuer);
    event CredentialRevoked(uint256 indexed credentialHash, address indexed issuer);
    event IssuerAdded(address indexed issuer);
    event IssuerRemoved(address indexed issuer);

    // Modifier to restrict to contract owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Not contract owner");
        _;
    }

    // Modifier to restrict to trusted issuers
    modifier onlyTrustedIssuer() {
        require(trustedIssuers[msg.sender], "Not a trusted issuer");
        _;
    }

    // Constructor sets the deployer as the owner
    constructor() {
        owner = msg.sender;
    }

    // Function to add a trusted issuer
    function addIssuer(address issuer) external onlyOwner {
        trustedIssuers[issuer] = true;
        emit IssuerAdded(issuer);
    }

    // Function to remove a trusted issuer
    function removeIssuer(address issuer) external onlyOwner {
        trustedIssuers[issuer] = false;
        emit IssuerRemoved(issuer);
    }

    // Function for an issuer to issue (sign) a credential to a user
    function issueCredential(address user, uint256 credentialHash) external onlyTrustedIssuer {
        require(!revoked[credentialHash], "Credential is revoked");
        credentials[user][credentialHash] = msg.sender;
        emit CredentialIssued(user, credentialHash, msg.sender);
    }

    // Function to revoke a credential by the original issuer
    function revokeCredential(uint256 credentialHash, address user) external onlyTrustedIssuer {
        require(credentials[user][credentialHash] == msg.sender, "Not the issuer of this credential");
        revoked[credentialHash] = true;
        emit CredentialRevoked(credentialHash, msg.sender);
    }

    // Function to check if a credential is valid (not revoked)
    function isCredentialValid(address user, uint256 credentialHash) external view returns (bool) {
        return credentials[user][credentialHash] != address(0) && !revoked[credentialHash];
    }
}