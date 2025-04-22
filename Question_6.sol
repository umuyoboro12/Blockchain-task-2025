
/*
 * CONTRACT 6: Multi-Signature Wallet
 *
 * This Contract Purpose:
 * This contract enables multiple owners to collectively manage a shared wallet. Transactions proposed by one owner require approval from at least two out of three owners before being executed. This enhances security by preventing unauthorized access to funds.
 *
 * Key Features Used:
 * - Structs for transaction data
 * - Modifiers to restrict actions to wallet owners
 * - Mapping to track approvals
 * - Event emissions for key actions
 *
 * Technical Concepts Used:
 * - Structs to encapsulate transaction details
 * - Modifiers for access control
 * - Mappings for efficient state tracking
 * - Events to support off-chain monitoring
 */



// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
 * In this case, 3 owners are required and at least 2 must approve a transaction.
 */

contract MultiSigWallet {
    // List of wallet owners
    address[] public owners;

    // Minimum number of approvals required to execute a transaction
    uint public requiredApprovals = 2;

    // Structure to represent a transaction
    struct Transaction {
        address to;          // recipient address
        uint value;          // amount of Ether to send
        bool executed;       // whether the transaction has been executed
        uint approvalCount;  // how many owners have approved it
    }

    // Array to store all proposed transactions
    Transaction[] public transactions;

    // Mapping to track which owner has approved which transaction
    // approvals[transactionIndex][ownerAddress] = true/false
    mapping(uint => mapping(address => bool)) public approvals;

    // Modifier to allow only wallet owners to perform certain actions
    modifier onlyOwner() {
        bool isOwner = false;
        // Loop through the owners to check if the sender is one of them
        for (uint i = 0; i < owners.length; i++) {
            if (msg.sender == owners[i]) {
                isOwner = true;
                break;
            }
        }
        require(isOwner, "Not an owner");
        _; // continue execution
    }

    // Event emitted when a new transaction is proposed
    event TransactionProposed(uint txIndex, address proposer);

    // Event emitted when a transaction is approved by an owner
    event TransactionApproved(uint txIndex, address approver);

    // Event emitted when a transaction is executed (i.e., funds are sent)
    event TransactionExecuted(uint txIndex);

    // Constructor is called when the contract is first deployed
    // Accepts exactly 3 owner addresses
    constructor(address[] memory _owners) {
        require(_owners.length == 3, "Must have exactly 3 owners");
        owners = _owners;
    }

    // Function to propose a new transaction
    // Only owners can call this
    function proposeTransaction(address _to, uint _value) external onlyOwner {
        // Add the transaction to the list, initially not executed and 0 approvals
        transactions.push(Transaction({
            to: _to,
            value: _value,
            executed: false,
            approvalCount: 0
        }));

        // Emit an event so we can see on-chain that a transaction was proposed
        emit TransactionProposed(transactions.length - 1, msg.sender);
    }

    // Function to approve a transaction
    // Only owners can approve, and each owner can approve only once
    function approveTransaction(uint _txIndex) external onlyOwner {
        require(_txIndex < transactions.length, "Invalid transaction index");

        // Get the transaction from the array
        Transaction storage txn = transactions[_txIndex];

        // Make sure the transaction hasn't already been executed
        require(!txn.executed, "Transaction already executed");

        // Make sure this owner hasn't already approved
        require(!approvals[_txIndex][msg.sender], "Already approved");

        // Record the approval
        approvals[_txIndex][msg.sender] = true;

        // Increase the approval count
        txn.approvalCount++;

        // Emit an event that shows this transaction was approved
        emit TransactionApproved(_txIndex, msg.sender);

        // If enough approvals have been gathered, execute the transaction
        if (txn.approvalCount >= requiredApprovals) {
            txn.executed = true; // mark as executed
            payable(txn.to).transfer(txn.value); // send the Ether
            emit TransactionExecuted(_txIndex); // notify it was executed
        }
    }

    // This special function allows the contract to receive Ether directly
    receive() external payable {}
}
