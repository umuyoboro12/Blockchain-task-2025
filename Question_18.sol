// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Flash Loan Contract
 * @dev A secure implementation of flash loan functionality in Solidity
 * 
 * Contract Purpose:
 * This contract enables users to borrow assets without collateral for the duration of a single transaction,
 * with the requirement that the borrowed amount plus a fee is repaid within that same transaction.
 * It's designed for DeFi applications that need temporary liquidity for arbitrage, collateral swapping,
 * or other financial operations.
 *
 * Key Features:
 * - Non-collateralized instant loans
 * - Same-transaction repayment enforcement
 * - Reentrancy protection
 * - Configurable fee structure
 * - Liquidity provider management
 *
 * Technical Concepts Used:
 * - Flash loans (uncollateralized same-block loans)
 * - Reentrancy guards (security pattern)
 * - ERC20 token interactions
 * - Callback pattern (for borrower operations)
 * - Gas optimization techniques
 */

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract FlashLoan is ReentrancyGuard {
    // Using uint256 for token balances (most efficient for EVM)
    mapping(address => uint256) public tokenBalances;
    
    // Fee basis points (1 = 0.01%, 100 = 1%). Using uint8 would be too small for meaningful fees.
    uint256 public feeBasisPoints;
    
    // Constants for gas optimization
    address private constant ETH_ADDRESS = address(0);
    uint256 private constant BASIS_POINTS = 10000;
    
    event LoanExecuted(address indexed borrower, address indexed token, uint256 amount, uint256 fee);
    event FundsDeposited(address indexed depositor, address indexed token, uint256 amount);
    event FundsWithdrawn(address indexed withdrawer, address indexed token, uint256 amount);
    
    /**
     * @dev Constructor sets the initial fee percentage
     * @param _feeBasisPoints Fee percentage in basis points (1 = 0.01%)
     */
    constructor(uint256 _feeBasisPoints) {
        require(_feeBasisPoints <= 100, "Fee too high"); // Max 1% fee
        feeBasisPoints = _feeBasisPoints;
    }
    
    /**
     * @notice Deposit tokens to enable flash loans
     * @param _token Token contract address
     * @param _amount Amount to deposit
     */
    function depositTokens(address _token, uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be positive");
        require(_token != ETH_ADDRESS, "ETH not supported");
        
        uint256 balanceBefore = IERC20(_token).balanceOf(address(this));
        require(IERC20(_token).transferFrom(msg.sender, address(this), _amount), "Transfer failed");
        uint256 balanceAfter = IERC20(_token).balanceOf(address(this));
        
        // Handle tokens with transfer fees
        uint256 actualAmount = balanceAfter - balanceBefore;
        tokenBalances[_token] += actualAmount;
        
        emit FundsDeposited(msg.sender, _token, actualAmount);
    }
    
    /**
     * @notice Withdraw deposited tokens
     * @param _token Token contract address
     * @param _amount Amount to withdraw
     */
    function withdrawTokens(address _token, uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be positive");
        require(tokenBalances[_token] >= _amount, "Insufficient balance");
        
        tokenBalances[_token] -= _amount;
        require(IERC20(_token).transfer(msg.sender, _amount), "Transfer failed");
        
        emit FundsWithdrawn(msg.sender, _token, _amount);
    }
    
    /**
     * @notice Execute a flash loan
     * @param _token Token to borrow
     * @param _amount Amount to borrow
     * @param _data Encoded function call for borrower
     */
    function executeFlashLoan(
        address _token,
        uint256 _amount,
        bytes calldata _data
    ) external nonReentrant {
        require(_amount > 0, "Amount must be positive");
        require(tokenBalances[_token] >= _amount, "Insufficient liquidity");
        
        uint256 balanceBefore = IERC20(_token).balanceOf(address(this));
        uint256 fee = (_amount * feeBasisPoints) / BASIS_POINTS;
        
        // Transfer tokens to borrower - using low-level call for gas efficiency
        (bool transferSuccess, ) = _token.call(
            abi.encodeWithSelector(
                IERC20.transfer.selector,
                msg.sender,
                _amount
            )
        );
        require(transferSuccess, "Loan transfer failed");
        
        // Execute borrower's operation
        (bool operationSuccess, ) = msg.sender.call(_data);
        require(operationSuccess, "Borrower operation failed");
        
        // Verify repayment using balance check rather than transfer back (saves gas)
        uint256 balanceAfter = IERC20(_token).balanceOf(address(this));
        require(balanceAfter >= balanceBefore + fee, "Loan not repaid");
        
        emit LoanExecuted(msg.sender, _token, _amount, fee);
    }
    
    /**
     * @notice Update the fee percentage
     * @param _newFeeBasisPoints New fee in basis points (1 = 0.01%)
     */
    function setFeeBasisPoints(uint256 _newFeeBasisPoints) external {
        require(_newFeeBasisPoints <= 100, "Fee too high"); // Max 1% fee
        feeBasisPoints = _newFeeBasisPoints;
    }
}