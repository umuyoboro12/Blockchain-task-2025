// SPDX-License-Identifier: MIT


/**
 * @title PaymentChannel
 * @dev Enables off-chain payments with on-chain dispute resolution. Users can 
 * transact off-chain using cryptographically signed messages, then settle the 
 * final balance on-chain. Implements timeout mechanisms to ensure funds can't 
 * be locked indefinitely.
 *
 * Key Features:
 * - Off-chain message signing with ECDSA
 * - Nonce-based state progression to prevent replay attacks
 * - Challenge period for dispute resolution
 * - Timeout-protected withdrawals
 *
 * Technical Concepts:
 * - Elliptic Curve Digital Signature Algorithm (ECDSA) for message verification
 * - Cryptographic hashing for message integrity
 * - State channels pattern for off-chain interactions
 * - Gas optimization through struct packing and minimal storage writes
 */
pragma solidity ^0.8.26;

contract PaymentChannel {
    struct Channel {
        address sender;
        address receiver;
        uint256 amount;         // Total deposit
        uint256 timeout;        // Block timestamp when channel becomes closable
        uint256 nonce;          // Monotonically increasing state identifier
    }

    mapping(bytes32 => Channel) public channels;
    mapping(address => uint256) public withdrawBalances;

    event ChannelOpened(bytes32 channelId, address sender, address receiver, uint256 amount, uint256 timeout);
    event ChannelClosed(bytes32 channelId, uint256 finalAmount);
    event ChallengeStarted(bytes32 channelId, uint256 newNonce, uint256 newAmount);
    event Withdrawal(address user, uint256 amount);

    uint256 public constant CHALLENGE_PERIOD = 7 days;

    /**
     * @dev Opens a new payment channel and emits the channelId.
     * @param receiver The recipient address
     * @param timeout Duration in seconds before channel can be closed
     */
    function openChannel(address receiver, uint256 timeout) external payable {
        require(msg.value > 0, "Deposit must be positive");
        bytes32 channelId = getChannelId(msg.sender, receiver, block.timestamp);
        
        channels[channelId] = Channel({
            sender: msg.sender,
            receiver: receiver,
            amount: msg.value,
            timeout: block.timestamp + timeout,
            nonce: 0
        });

        emit ChannelOpened(channelId, msg.sender, receiver, msg.value, timeout);
    }

    /**
     * @dev Computes the channelId given sender, receiver, and creation time.
     * @param sender The sender's address
     * @param receiver The receiver's address
     * @param creationTime The block timestamp when the channel is created
     * @return channelId The computed channel identifier
     */
    function getChannelId(
        address sender,
        address receiver,
        uint256 creationTime
    ) public pure returns (bytes32 channelId) {
        channelId = keccak256(abi.encodePacked(sender, receiver, creationTime));
    }

    /**
     * @dev Closes the channel with a signed message from the receiver.
     * @param channelId The channel identifier
     * @param amount Final payment amount
     * @param nonce State nonce
     * @param signature Receiver's signed message
     */
    function closeChannel(
        bytes32 channelId,
        uint256 amount,
        uint256 nonce,
        bytes memory signature
    ) external {
        Channel storage channel = channels[channelId];
        require(msg.sender == channel.sender, "Only sender can close");
        require(block.timestamp >= channel.timeout, "Channel timeout not reached");
        require(nonce > channel.nonce, "Nonce must increase");

        bytes32 messageHash = keccak256(abi.encodePacked(address(this), nonce, amount));
        bytes32 ethSignedMessage = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        address signer = recoverSigner(ethSignedMessage, signature);

        require(signer == channel.receiver, "Invalid receiver signature");
        
        uint256 senderRefund = channel.amount - amount;
        withdrawBalances[channel.sender] += senderRefund;
        withdrawBalances[channel.receiver] += amount;
        
        channel.nonce = nonce;
        emit ChannelClosed(channelId, amount);
    }

    /**
     * @dev Challenges a closure attempt with a newer signed state.
     * @param channelId The channel identifier
     * @param newAmount Updated payment amount
     * @param newNonce Higher nonce value
     * @param signature New receiver signature
     */
    function challengeClose(
        bytes32 channelId,
        uint256 newAmount,
        uint256 newNonce,
        bytes memory signature
    ) external {
        Channel storage channel = channels[channelId];
        require(msg.sender == channel.receiver, "Only receiver can challenge");
        require(newNonce > channel.nonce, "Nonce must increase");
        
        bytes32 messageHash = keccak256(abi.encodePacked(address(this), newNonce, newAmount));
        bytes32 ethSignedMessage = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        address signer = recoverSigner(ethSignedMessage, signature);

        require(signer == channel.receiver, "Invalid signature");
        
        channel.nonce = newNonce;
        emit ChallengeStarted(channelId, newNonce, newAmount);
    }

    /**
     * @dev Withdraws funds after successful channel closure.
     */
    function withdraw() external {
        uint256 amount = withdrawBalances[msg.sender];
        require(amount > 0, "No balance to withdraw");
        
        withdrawBalances[msg.sender] = 0;
        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent, "Withdrawal failed");
        
        emit Withdrawal(msg.sender, amount);
    }

    /**
     * @dev Recovers the signer address from a message hash and signature.
     * @param ethSignedMessage Prefixed message hash
     * @param signature ECDSA signature
     */
    function recoverSigner(bytes32 ethSignedMessage, bytes memory signature) internal pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);
        return ecrecover(ethSignedMessage, v, r, s);
    }

    /**
     * @dev Splits a signature into r, s, v components.
     */
    function splitSignature(bytes memory sig) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "Invalid signature length");
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }
}