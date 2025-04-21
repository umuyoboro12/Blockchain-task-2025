// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Interface for interacting with an ERC20 token contract
interface IERC20 {
     // Function to transfer tokens to a recipient
     function transfer(address recipient , uint256 amount) external returns(bool);
     
     // Function to transfer tokens from one address to another, with approval
     function transferfrom(address sender , address recipient , uint256 amount) external returns(bool);
}

// Crowdfunding contract
contract Crowdfund {
    IERC20 public token; // Declare the ERC20 token to be used for contributions
    address public owner; // Address of the campaign owner
    uint256 public goal; // The funding goal for the campaign
    uint256 public deadline; // Deadline timestamp for the campaign
    uint256 public totalRaised; // The total amount of tokens raised so far
    bool public goalReached; // Flag to indicate if the goal has been reached
    bool public refunded; // Flag to indicate if refunds have been processed

    // Mapping to track individual contributions
    mapping(address => uint256) public contributions;
    
    // Events to log important actions
    event contributed(address indexed contributor, uint256 amount);
    event Refunded(address indexed contributor, uint256 amount);
    event GoalReached(uint256 totalamount);

    // Modifier to allow function execution only before the deadline
    modifier onlyBeforeDeadline() {
        require(block.timestamp < deadline, "campaign has ended please");
        _; // Continue with function execution
    }

    // Modifier to allow function execution only after the deadline
    modifier onlyAfterDeadline() {
        require(block.timestamp >= deadline, "campaign is still ongoing");
        _; // Continue with function execution
    }

    // Modifier to allow function execution only by the owner
    modifier onlyOwner() {
        require(msg.sender == owner, "sorry not allowed");
        _; // Continue with function execution
    }

    // Constructor to initialize the contract with a token, goal, and campaign duration
    constructor(
        address _tokenAddress, // Address of the ERC20 token contract
        uint256 _goal,         // The fundraising goal
        uint256 _durationInSeconds // Duration of the campaign in seconds
    ) {
        token = IERC20(_tokenAddress); // Set the token contract address
        owner = msg.sender; // Set the contract creator as the owner
        goal = _goal; // Set the goal for the campaign
        deadline = block.timestamp + _durationInSeconds; // Set the deadline for the campaign
    }

    // Function for contributors to send tokens to the campaign before the deadline
    function contribute(uint256 _amount) external onlyBeforeDeadline {
        require(_amount > 0, "you must contribute more than 0"); // Ensure a non-zero contribution
        require(token.transferfrom(msg.sender, address(this), _amount), "failed to send token"); // Transfer the tokens from the contributor to the contract
        contributions[msg.sender] += _amount; // Record the contribution amount
        totalRaised += _amount; // Update the total raised amount
        emit contributed(msg.sender, _amount); // Emit the contribution event
    }

    // Function for contributors to claim refunds after the deadline if the goal was not met
    function claimRefund() external onlyAfterDeadline {
        require(totalRaised < goal, "goal was met no refunds"); // Refund is only allowed if the goal was not met
        require(contributions[msg.sender] > 0, "No contributions to refund"); // Ensure the contributor has made a contribution
        uint256 amount = contributions[msg.sender]; // Get the contribution amount for the sender
        contributions[msg.sender] = 0; // Reset the contribution for the sender
        require(token.transfer(msg.sender, amount), "failed to send token"); // Refund the tokens to the contributor
        emit Refunded(msg.sender, amount); // Emit the refund event
    }

    // Function for the owner to withdraw the funds after the deadline if the goal was met
    function withdrawFunds() external onlyOwner onlyAfterDeadline {
        require(totalRaised >= goal, "goal not met"); // Ensure the goal was met before allowing withdrawal
        uint256 amount = totalRaised; // Get the total raised amount
        totalRaised = 0; // Reset the total raised amount
        require(token.transfer(owner, amount), "failed to send token"); // Transfer the funds to the owner
        goalReached = true; // Set the goalReached flag to true
        emit GoalReached(amount); // Emit the GoalReached event
    }
}
