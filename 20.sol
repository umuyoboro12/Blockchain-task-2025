// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RockPaperScissors {
    enum Move { None, Rock, Paper, Scissors }
    enum Stage { Commit, Reveal, Complete }

    struct Player {
        address addr;
        bytes32 commitment;
        Move move;
        bool revealed;
    }

    Player[2] public players;
    uint256 public commitDeadline;
    uint256 public revealDeadline;
    uint256 public stake;
    Stage public gameStage;

    constructor(uint256 _commitDuration, uint256 _revealDuration, uint256 _stake) {
        commitDeadline = block.timestamp + _commitDuration;
        revealDeadline = commitDeadline + _revealDuration;
        stake = _stake;
        gameStage = Stage.Commit;
    }

    modifier onlyDuringCommit() {
        require(gameStage == Stage.Commit && block.timestamp <= commitDeadline, "Not commit stage");
        _;
    }

    modifier onlyDuringReveal() {
        require(gameStage == Stage.Reveal && block.timestamp <= revealDeadline, "Not reveal stage");
        _;
    }

    function joinGame(bytes32 _commitment) external payable onlyDuringCommit {
        require(msg.value == stake, "Incorrect stake");
        require(players[0].addr == address(0) || players[1].addr == address(0), "Game full");

        if (players[0].addr == address(0)) {
            players[0] = Player(msg.sender, _commitment, Move.None, false);
        } else {
            players[1] = Player(msg.sender, _commitment, Move.None, false);
            gameStage = Stage.Reveal; // Start reveal phase
        }
    }

    function revealMove(Move _move, string calldata _salt) external onlyDuringReveal {
        require(_move == Move.Rock || _move == Move.Paper || _move == Move.Scissors, "Invalid move");

        bytes32 calculatedCommitment = keccak256(abi.encodePacked(_move, _salt));
        uint index = msg.sender == players[0].addr ? 0 : msg.sender == players[1].addr ? 1 : 2;
        require(index < 2, "Not a player");

        Player storage player = players[index];
        require(!player.revealed, "Already revealed");
        require(player.commitment == calculatedCommitment, "Commitment mismatch");

        player.move = _move;
        player.revealed = true;

        // Check if both players have revealed
        if (players[0].revealed && players[1].revealed) {
            _determineWinner();
        }
    }

    function _determineWinner() internal {
        gameStage = Stage.Complete;

        Move p1 = players[0].move;
        Move p2 = players[1].move;

        address payable winner;
        if (p1 == p2) {
            // Draw, refund both
            payable(players[0].addr).transfer(stake);
            payable(players[1].addr).transfer(stake);
            return;
        }

        if (
            (p1 == Move.Rock && p2 == Move.Scissors) ||
            (p1 == Move.Paper && p2 == Move.Rock) ||
            (p1 == Move.Scissors && p2 == Move.Paper)
        ) {
            winner = payable(players[0].addr);
        } else {
            winner = payable(players[1].addr);
        }

        winner.transfer(address(this).balance);
    }

    function forfeitUnrevealed() external {
        require(block.timestamp > revealDeadline, "Reveal phase not over");
        require(gameStage == Stage.Reveal, "Not in reveal stage");
        gameStage = Stage.Complete;

        if (players[0].revealed && !players[1].revealed) {
            payable(players[0].addr).transfer(address(this).balance);
        } else if (!players[0].revealed && players[1].revealed) {
            payable(players[1].addr).transfer(address(this).balance);
        } else {
            // Neither revealed, refund both
            payable(players[0].addr).transfer(stake);
            payable(players[1].addr).transfer(stake);
        }
    }
}

// 1. Add an option for all players to play simultaneously. 
//2. Allow the admin to view detailed game information. 
//3. Ensure that each player receives the game results after the match.
