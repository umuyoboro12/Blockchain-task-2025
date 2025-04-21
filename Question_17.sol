// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * Contract Purpose:
 * The `MultiTokenMarketplace` contract enables the decentralized exchange of multiple ERC20 tokens. It allows users to trade tokens directly, 
 * execute atomic swaps securely, and perform batch transfers efficiently. The contract serves as a minimal and gas-optimized token marketplace 
 * where trades can occur trustlessly without intermediaries.

 * Key Features Used:
 * - ERC20 Token Support: Interacts with any compliant ERC20 token contracts using standard interface.
 * - Batch Transfers: Allows users to send multiple tokens to multiple recipients in a single transaction.
 * - Atomic Swaps: Enables trustless token-for-token trades in a single operation that must fully succeed or revert.
 * - Access Control: Validates input parameters and ensures proper ownership and allowance.

 * Technical Concepts Used:
 * - Atomic Transactions: Uses Solidity's transaction atomicity principle, where if any step of a trade fails, the whole transaction reverts.
 * - Interface-based Design: Interacts with ERC20 tokens via `IERC20` interface, promoting reusability and flexibility.
 * - Gas Optimization: Uses `unchecked` increments, `calldata` for external calls, minimal storage, and reentrancy guards where needed.

 */

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MultiTokenMarketplace is ReentrancyGuard {
    address public immutable owner;

    event BatchTransfer(
        address indexed sender,
        address[] tokens,
        address[] recipients,
        uint256[] amounts
    );

    event AtomicSwap(
        address indexed initiator,
        address indexed party1,
        address token1,
        uint256 amount1,
        address indexed party2,
        address token2,
        uint256 amount2
    );

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Unauthorized");
        _;
    }

    /**
     * @dev Execute batch transfers in a single transaction
     * @param tokens Array of token addresses
     * @param recipients Array of recipient addresses
     * @param amounts Array of amounts to transfer
     */
    function batchTransfer(
        address[] calldata tokens,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external nonReentrant {
        require(
            tokens.length == recipients.length && 
            recipients.length == amounts.length,
            "Invalid input lengths"
        );

        for (uint256 i = 0; i < tokens.length; ) {
            require(tokens[i] != address(0), "Invalid token address");
            require(recipients[i] != address(0), "Invalid recipient");
            
            bool success = IERC20(tokens[i]).transferFrom(
                msg.sender,
                recipients[i],
                amounts[i]
            );
            require(success, "Transfer failed");

            unchecked { ++i; }
        }

        emit BatchTransfer(msg.sender, tokens, recipients, amounts);
    }

    /**
     * @dev Execute atomic token swap between two parties
     * @param token1 First token address
     * @param amount1 First token amount
     * @param party2 Counterparty address
     * @param token2 Second token address
     * @param amount2 Second token amount
     */
    function atomicSwap(
        address token1,
        uint256 amount1,
        address party2,
        address token2,
        uint256 amount2
    ) external nonReentrant {
        require(token1 != token2, "Duplicate tokens");
        require(token1 != address(0) && token2 != address(0), "Invalid token");
        require(party2 != address(0), "Invalid counterparty");
        require(msg.sender != party2, "Cannot swap with self");

        // Transfer token1 from msg.sender to party2
        bool success1 = IERC20(token1).transferFrom(
            msg.sender,
            party2,
            amount1
        );
        require(success1, "Token1 transfer failed");

        // Transfer token2 from party2 to msg.sender
        bool success2 = IERC20(token2).transferFrom(
            party2,
            msg.sender,
            amount2
        );
        require(success2, "Token2 transfer failed");

        emit AtomicSwap(
            msg.sender,
            msg.sender,
            token1,
            amount1,
            party2,
            token2,
            amount2
        );
    }

    /**
     * @dev Emergency function to recover ERC20 tokens
     */
    function recoverERC20(address token, uint256 amount) external onlyOwner {
        require(token != address(0), "Invalid token");
        IERC20(token).transfer(owner, amount);
    }
}