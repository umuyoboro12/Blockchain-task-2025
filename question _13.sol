// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Interface to interact with the ERC20 token contract
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

// Main contract for DAO Governance
contract DAOGovernanceContract {
    // Reference to the governance token (ERC20)
    IERC20 public governanceToken;

    // Counter to keep track of proposals
    uint public proposalCount;

    // Quorum percentage required to execute a proposal
    uint public quorumPercentage = 25; // 25% quorum required

    // Struct to store each proposal's information
    struct Proposal {
        uint id; // Unique ID of the proposal
        string description; // Description of the proposal
        uint voteCount; // Total number of votes received
        uint startTime; // Start time of voting
        uint endTime; // End time of voting
        bool executed; // Flag to check if proposal has been executed
        mapping(address => bool) voted; // Tracks whether an address has voted
    }

    // Mapping of proposal ID to Proposal
    mapping(uint => Proposal) public proposals;

    // Event triggered when a proposal is created
    event ProposalCreated(uint id, string description);

    // Event triggered when someone votes
    event Voted(address indexed voter, uint proposalId);

    // Event triggered when a proposal is executed
    event ProposalExecuted(uint id);

    // Constructor to initialize the governance token
    constructor(address _tokenAddress) {
        governanceToken = IERC20(_tokenAddress); // Assign the token contract
    }

    // Function to create a new proposal
    function createProposal(string calldata _description, uint _durationSeconds) external {
        proposalCount++; // Increment proposal counter

        // Create a new proposal and set its properties
        Proposal storage newProposal = proposals[proposalCount];
        newProposal.id = proposalCount;
        newProposal.description = _description;
        newProposal.startTime = block.timestamp;
        newProposal.endTime = block.timestamp + _durationSeconds;

        // Emit event for tracking
        emit ProposalCreated(proposalCount, _description);
    }

    // Function to vote on a proposal
    function vote(uint _proposalId) external {
        Proposal storage proposal = proposals[_proposalId]; // Get proposal

        // Check if voting is open
        require(block.timestamp >= proposal.startTime && block.timestamp <= proposal.endTime, "Voting not allowed");

        // Check if the voter has already voted
        require(!proposal.voted[msg.sender], "Already voted");

        // Get the balance of governance tokens the sender holds
        uint voterBalance = governanceToken.balanceOf(msg.sender);

        // Ensure the voter has at least some tokens
        require(voterBalance > 0, "Must hold tokens to vote");

        // Add votes to the proposal (token-weighted)
        proposal.voteCount += voterBalance;

        // Mark sender as having voted
        proposal.voted[msg.sender] = true;

        // Emit voting event
        emit Voted(msg.sender, _proposalId);
    }

    // Function to execute a proposal if quorum is met
    function executeProposal(uint _proposalId) external {
        Proposal storage proposal = proposals[_proposalId]; // Get proposal

        // Ensure voting period has ended
        require(block.timestamp > proposal.endTime, "Voting still ongoing");

        // Ensure it hasn't already been executed
        require(!proposal.executed, "Already executed");

        // Total token supply — set manually here (you should use totalSupply() or snapshot in a real project)
        uint totalSupply = 1000; // Dummy value for example purposes

        // Check if the proposal has reached the required quorum
        require(proposal.voteCount * 100 / totalSupply >= quorumPercentage, "Quorum not reached");

        // Mark the proposal as executed
        proposal.executed = true;

        // Execute proposal logic (empty in this example)
        // You can add real logic like calling other contracts or changing variables

        // Emit execution event
        emit ProposalExecuted(_proposalId);
    }

    // View function to check if a voter has already voted on a proposal
    function hasVoted(uint _proposalId, address _voter) external view returns (bool) {
        return proposals[_proposalId].voted[_voter];
    }

    // View function to get proposal details
    function getProposal(uint _proposalId) external view returns (
        uint id,
        string memory description,
        uint voteCount,
        uint startTime,
        uint endTime,
        bool executed
    ) {
        Proposal storage p = proposals[_proposalId];
        return (p.id, p.description, p.voteCount, p.startTime, p.endTime, p.executed);
    }
}
