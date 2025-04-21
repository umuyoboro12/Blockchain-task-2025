// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract HelloWorld {
    // State variable to store the greeting message
    string public greeting;

    // Event to emit when the greeting is updated
    event GreetingUpdated(string oldGreeting, string newGreeting, address updatedBy);

    // Constructor to set the initial greeting message
    constructor(string memory initialGreeting) {
        greeting = initialGreeting;
    }
    // Function to update the greeting message
    function setGreeting(string memory message) public {
        string memory oldGreeting = greeting;
        greeting = message;
        emit GreetingUpdated(oldGreeting, message, msg.sender);
    }

    // Function to retrieve the current greeting message
    function getGreeting() public view returns (string memory) {
        return greeting;
    }
}
