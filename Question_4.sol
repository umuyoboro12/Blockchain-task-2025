// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract VotingSystem {
    struct Candidate {
        string name;
        uint32 votes;
        bool exists;
    }

    struct Voter {
        address voterAddress;
        uint32 votedFor;
    }

    mapping(uint256 => Candidate) public candidates;
    uint256[] private candidateIds;

    mapping(address => bool) public hasVoted;
    Voter[] private voters;

    uint8 private constant ELECTION_OPEN = 1 << 0;
    uint8 private constant ELECTION_CLOSED = 1 << 1;
    uint8 public electionStatus;

    constructor() {
        electionStatus = ELECTION_OPEN;
    }

    /// 1. Add a new candidate
    function addCandidate(uint256 candidateId, string memory name) external {
        require(!candidates[candidateId].exists, "Candidate already exists");
        candidates[candidateId] = Candidate(name, 0, true);
        candidateIds.push(candidateId);
    }

    /// 2. Show all added candidates
    function getAllCandidates() external view returns (Candidate[] memory) {
        Candidate[] memory all = new Candidate[](candidateIds.length);
        for (uint256 i = 0; i < candidateIds.length; i++) {
            all[i] = candidates[candidateIds[i]];
        }
        return all;
    }

    /// 3. Vote for a candidate
    function vote(uint256 candidateId) external {
        require(electionStatus & ELECTION_OPEN != 0, "Election is closed");
        require(!hasVoted[msg.sender], "Already voted");
        require(candidates[candidateId].exists, "Invalid candidate");

        unchecked {
            candidates[candidateId].votes++;
        }

        hasVoted[msg.sender] = true;
        voters.push(Voter(msg.sender, uint32(candidateId)));
    }

    /// 4. Check votes for a candidate
    function getCandidateVotes(uint256 candidateId) external view returns (string memory name, uint256 votes) {
        require(candidates[candidateId].exists, "Candidate does not exist");
        Candidate memory c = candidates[candidateId];
        return (c.name, c.votes);
    }

    /// 5. Get total votes for all candidates
    function getTotalVotes() external view returns (uint256 total) {
        for (uint256 i = 0; i < candidateIds.length; i++) {
            total += candidates[candidateIds[i]].votes;
        }
    }

    /// 6. Close the election
    function closeElection() external {
        require(electionStatus & ELECTION_OPEN != 0, "Election already closed");
        electionStatus = ELECTION_CLOSED;
    }
}
