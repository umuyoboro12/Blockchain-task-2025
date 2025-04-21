// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
*New Branch
 * Contract Name: Lottery
 *
 * 1. Contract Purpose:
 *    This contract implements a decentralized lottery system where users can buy tickets using Ether.
 *    After the lottery ends, Chainlink VRF is used to randomly select a winner in a fair and verifiable way.
 *    The winner automatically receives the entire balance as the prize.
 *
 * 2. Key Features Used:
 *    - Users buy tickets with Ether (fixed price).
 *    - Chainlink VRF for provable randomness.
 *    - Automatic prize distribution to the winner.
 *    - Owner-controlled lottery lifecycle (start, end).
 *
 * 3. Technical Concepts Used:
 *    - Chainlink VRFv2 for secure and verifiable randomness.
 *    - Enums for state management.
 *    - Events for transparency.
 *    - Access control using a modifier.
 *    - Dynamic array for tracking participants.
 *
 * 4. Code Comments:
 *    Major components and function logic are explained using comments.
 */

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

contract Lottery is VRFConsumerBaseV2 {
    // Chainlink VRF variables
    VRFCoordinatorV2Interface private immutable vrfCoordinator;
    bytes32 private immutable keyHash;
    uint64 private immutable subscriptionId;
    uint32 private constant callbackGasLimit = 100000;
    uint16 private constant requestConfirmations = 3;
    uint32 private constant numWords = 1;

    // Lottery State
    enum LotteryState { OPEN, CALCULATING }
    LotteryState public lotteryState;

    // Participants
    address payable[] public participants;

    // Winner
    address public recentWinner;

    // Owner
    address public owner;

    // Ticket Price (0.01 ETH)
    uint256 public ticketPrice = 10000000000000000 wei;

    // Events
    event TicketPurchased(address indexed player);
    event LotteryEnded();
    event WinnerPicked(address indexed winner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this");
        _;
    }

    constructor(
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint64 _subscriptionId
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        owner = msg.sender;
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        keyHash = _keyHash;
        subscriptionId = _subscriptionId;
        lotteryState = LotteryState.OPEN;
    }

    /// @notice Buy a lottery ticket by sending the exact ticket price
    function buyTicket() external payable {
        require(lotteryState == LotteryState.OPEN, "Lottery is not open");
        require(msg.value == ticketPrice, "Incorrect ticket price");

        participants.push(payable(msg.sender));
        emit TicketPurchased(msg.sender);
    }

    /// @notice End the lottery and trigger random winner selection
    function endLottery() external onlyOwner {
        require(lotteryState == LotteryState.OPEN, "Lottery not open");
        require(participants.length > 0, "No participants");
        lotteryState = LotteryState.CALCULATING;

        emit LotteryEnded();

        vrfCoordinator.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
    }

    /// @notice Called by Chainlink VRF to provide random number
    function fulfillRandomWords(uint256, uint256[] memory randomWords) internal override {
        require(lotteryState == LotteryState.CALCULATING, "Not calculating");

        uint256 winnerIndex = randomWords[0] % participants.length;
        address payable winner = participants[winnerIndex];
        recentWinner = winner;

        // Transfer balance to winner
        winner.transfer(address(this).balance);

        emit WinnerPicked(winner);

        // Reset
        delete participants;
        lotteryState = LotteryState.OPEN;
        recentWinner = address(0);
    }

    /// @notice Get current participants
    function getParticipants() external view returns (address payable[] memory) {
        return participants;
    }

    /// @notice Get current lottery state as string
    function getLotteryState() external view returns (string memory) {
        return lotteryState == LotteryState.OPEN ? "OPEN" : "CALCULATING";
    }

    /// @notice Prevent direct ETH transfer to contract
    receive() external payable {
        revert("Use buyTicket()");
    }

    fallback() external payable {
        revert("Use buyTicket()");
    }
}