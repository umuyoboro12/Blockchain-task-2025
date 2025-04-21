// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title EtherWallet
 * @dev 
 * 1. Contract Purpose:
 *    The EtherWallet contract is designed to securely store Ether (ETH) on behalf of the contract owner 
 *    and facilitate controlled withdrawals. It allows any user to deposit ETH into the wallet, but only 
 *    the owner can withdraw funds. This contract simulates a basic personal wallet on the Ethereum blockchain.
 *
 * 2. Key Features Used:
 *    - Payable function (`deposit`) to accept ETH from users.
 *    - Access control using the `onlyOwner` modifier to restrict sensitive functions.
 *    - Three different withdrawal methods: `transfer`, `send`, and `call` for ETH transfers.
 *    - Public getter to check contract balance.
 *
 * 3. Technical Concepts Used:
 *    - `msg.sender` and `msg.value` to identify the caller and the value sent with a transaction.
 *    - Payable functions to receive Ether.
 *    - Function modifiers for access restriction.
 *    - ETH transfer techniques (`transfer`, `send`, `call`) and their differences in gas forwarding and error handling.
 *    - Solidity's visibility specifiers (`public`, `view`, `returns`).
 *
 * 4. Code Comments:
 *    - Inline comments are included throughout the contract to explain the logic of each function and operation.
 */

contract EtherWallet {
    // State variable to store the owner's address
    address public owner;

    /**
     * @dev Constructor sets the contract deployer as the wallet owner.
     */
    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Modifier to allow only the contract owner to execute certain functions.
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Not contract owner");
        _;
    }

    /**
     * @dev Public payable function to accept ETH deposits.
     *      Anyone can send ETH using this function. The ETH will be stored in the contract.
     *      A non-zero amount of ETH must be sent, or the transaction will revert.
     */
    function deposit() public payable {
        require(msg.value > 0, "Must send ETH");
        // ETH sent with this function is automatically stored in the contract's balance
    }

    /**
     * @dev Allows the owner to withdraw ETH using the `transfer` method.
     *      This method sends 2300 gas and reverts automatically on failure.
     * @param amount The amount of ETH (in wei) to withdraw.
     */
    function withdrawUsingTransfer(uint amount) public onlyOwner {
        payable(msg.sender).transfer(amount);
    }

    /**
     * @dev Allows the owner to withdraw ETH using the `send` method.
     *      This method returns a boolean indicating success and must be checked manually.
     * @param amount The amount of ETH (in wei) to withdraw.
     * @return A boolean indicating whether the transfer was successful.
     */
    function withdrawUsingSend(uint amount) public onlyOwner returns (bool) {
        bool sent = payable(msg.sender).send(amount);
        require(sent, "Send failed");
        return sent;
    }

    /**
     * @dev Allows the owner to withdraw ETH using the `call` method.
     *      This is the recommended way for sending ETH due to its flexibility and gas handling.
     * @param amount The amount of ETH (in wei) to withdraw.
     * @return A boolean indicating whether the transfer was successful.
     */
    function withdrawUsingCall(uint amount) public onlyOwner returns (bool) {
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Call failed");
        return success;
    }

    /**
     * @dev Returns the current balance of the contract in wei.
     *      This function is read-only and does not consume gas when called externally.
     * @return The balance of the contract in wei.
     */
    function getBalance() public view returns (uint) {
        return address(this).balance;
    }
}
