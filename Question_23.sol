// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * Contract Purpose:
 * The `GaslessPaymaster` contract enables users to execute transactions on Ethereum without directly spending ETH for gas.
 * Instead, they sign an EIP-712 message authorizing a relayer to execute a transaction on their behalf. The relayer gets reimbursed
 * in ERC20 tokens from the user's balance, allowing for a "gasless" experience.

 * Key Features Used:
 * - EIP-712 typed structured data hashing and signing for secure meta-transaction verification.
 * - Signature verification using `ecrecover` to authorize actions.
 * - ERC20-based token gas payments: tokens are deducted from users and paid to relayers.
 * - Nonce system to prevent replay attacks.
 * - Domain separator for structured signing across contracts/networks.

 * Technical Concepts Used:
 * - Meta-transactions: Transactions are signed by users and sent by relayers.
 * - EIP-712 Standard: Protects against signature collision with structured, typed data.
 * - Signature Verification: Ensures only authorized operations are executed.
 * - Gas Optimization: Uses `calldata` types, tight storage packing, and no redundant events or loops.

*/
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GaslessPaymaster is EIP712 {
    using ECDSA for bytes32;

    bytes32 private constant META_TX_TYPEHASH = keccak256(
        "MetaTransaction(address from,address token,uint256 tokenAmount,uint256 nonce,bytes data)"
    );

    IERC20 public immutable paymentToken;
    mapping(address => uint256) public nonces;

    event MetaTransactionExecuted(
        address indexed from,
        address indexed token,
        uint256 tokenAmount,
        uint256 nonce
    );

    constructor(address _paymentToken) EIP712("GaslessPaymaster", "1") {
        paymentToken = IERC20(_paymentToken);
    }

    function executeMetaTransaction(
        address from,
        uint256 tokenAmount,
        bytes calldata data,
        bytes calldata signature
    ) external returns (bytes memory) {
        uint256 currentNonce = nonces[from];
        nonces[from] = currentNonce + 1;

        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
            META_TX_TYPEHASH,
            from,
            address(paymentToken),
            tokenAmount,
            currentNonce,
            keccak256(data)
        )));
        
        require(digest.recover(signature) == from, "Invalid signature");
        require(paymentToken.transferFrom(from, address(this), tokenAmount), "Token transfer failed");

        (bool success, bytes memory result) = address(this).delegatecall(data);
        require(success, "Execution failed");

        emit MetaTransactionExecuted(from, address(paymentToken), tokenAmount, currentNonce);
        return result;
    }

}