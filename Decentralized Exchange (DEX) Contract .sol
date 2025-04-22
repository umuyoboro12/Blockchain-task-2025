// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Decentralized Exchange (DEX) Contract
 * @dev Implements an Automated Market Maker (AMM) with constant product formula
 * 
 * Contract Purpose:
 * This contract creates a decentralized exchange that allows users to:
 * 1. Swap ERC20 tokens without needing traditional order books
 * 2. Provide liquidity to token pairs and earn fees
 * 3. Remove liquidity and claim their proportional share
 * The DEX uses the x*y=k constant product formula (popularized by Uniswap) 
 * to determine prices algorithmically based on available liquidity.
 */

// Import OpenZeppelin contracts
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract DEX is ReentrancyGuard {
    /* ========== KEY FEATURES ========== 
    1. Automated Market Making (AMM) using x*y=k formula
    2. 0.3% swap fee (997/1000 ratio)
    3. Liquidity provider shares system
    4. Reentrancy protection for all state-changing functions
    5. Proper token ratio enforcement
    6. Comprehensive event logging
    */

    /* ========== TECHNICAL CONCEPTS USED ==========
    1. Constant Product Market Maker Model (x*y=k)
    2. Liquidity Pool Reserves Management
    3. ERC20 Token Standards Compliance
    4. Reentrancy Guards for Security
    5. Fixed-point Arithmetic
    6. Square Root Calculation for Initial Liquidity
    */

    // Track liquidity amounts for each token pair
    mapping(address => mapping(address => uint256)) public liquidity;
    
    // Track total liquidity shares for each token pair
    mapping(address => mapping(address => uint256)) public totalShares;
    
    // Track individual LP shares per user per pair
    mapping(address => mapping(address => mapping(address => uint256))) public shares;
    
    // Events for important contract actions
    event LiquidityAdded(
        address indexed provider,
        address indexed tokenA,
        address indexed tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 shares
    );
    
    event LiquidityRemoved(
        address indexed provider,
        address indexed tokenA,
        address indexed tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 shares
    );
    
    event TokenSwapped(
        address indexed sender,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    /**
     * @dev Adds liquidity to a token pair pool
     * @param tokenA Address of first token in the pair
     * @param tokenB Address of second token in the pair
     * @param amountA Amount of tokenA to deposit
     * @param amountB Amount of tokenB to deposit
     * Requirements:
     * - Tokens must be different
     * - Amounts must be positive
     * - For existing pools, must maintain reserve ratio
     */
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) external nonReentrant {
        // Validate inputs
        require(tokenA != tokenB, "DEX: identical tokens");
        require(amountA > 0 && amountB > 0, "DEX: amounts must be > 0");
        
        // Sort tokens to ensure consistent storage (avoid duplicate pools)
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        (uint256 amount0, uint256 amount1) = tokenA < tokenB ? (amountA, amountB) : (amountB, amountA);
        
        // Transfer tokens from user to contract
        require(IERC20(token0).transferFrom(msg.sender, address(this), amount0), "Transfer failed");
        require(IERC20(token1).transferFrom(msg.sender, address(this), amount1), "Transfer failed");
        
        uint256 share;
        if (totalShares[token0][token1] == 0) {
            // Initial liquidity - shares = sqrt(amount0 * amount1)
            // This ensures fair initial distribution regardless of ratio
            share = sqrt(amount0 * amount1);
        } else {
            // For existing pools, must maintain current reserve ratio
            // amount0/amount1 should equal reserve0/reserve1
            require(
                amount0 * liquidity[token1][token0] == amount1 * liquidity[token0][token1],
                "DEX: invalid ratio"
            );
            // Calculate shares proportional to existing pool
            share = (amount0 * totalShares[token0][token1]) / liquidity[token0][token1];
        }
        
        require(share > 0, "DEX: invalid share");
        
        // Update liquidity reserves and shares
        liquidity[token0][token1] += amount0;
        liquidity[token1][token0] += amount1;
        totalShares[token0][token1] += share;
        shares[token0][token1][msg.sender] += share;
        
        emit LiquidityAdded(msg.sender, token0, token1, amount0, amount1, share);
    }
    
    /**
     * @dev Removes liquidity from a token pair pool
     * @param tokenA Address of first token in the pair
     * @param tokenB Address of second token in the pair
     * @param share Amount of LP shares to burn
     * Requirements:
     * - Must have sufficient shares
     * - Tokens must be different
     * - Share amount must be positive
     */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 share
    ) external nonReentrant {
        require(tokenA != tokenB, "DEX: identical tokens");
        require(share > 0, "DEX: share must be > 0");
        
        // Sort tokens for consistent lookup
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        
        require(shares[token0][token1][msg.sender] >= share, "DEX: insufficient shares");
        
        // Calculate proportional amount of each token to withdraw
        uint256 amount0 = (share * liquidity[token0][token1]) / totalShares[token0][token1];
        uint256 amount1 = (share * liquidity[token1][token0]) / totalShares[token0][token1];
        
        require(amount0 > 0 && amount1 > 0, "DEX: insufficient liquidity");
        
        // Update reserves and shares
        liquidity[token0][token1] -= amount0;
        liquidity[token1][token0] -= amount1;
        totalShares[token0][token1] -= share;
        shares[token0][token1][msg.sender] -= share;
        
        // Transfer tokens back to user
        require(IERC20(token0).transfer(msg.sender, amount0), "Transfer failed");
        require(IERC20(token1).transfer(msg.sender, amount1), "Transfer failed");
        
        emit LiquidityRemoved(msg.sender, token0, token1, amount0, amount1, share);
    }
    
    /**
     * @dev Swaps one token for another using the AMM formula
     * @param tokenIn Token to swap from
     * @param tokenOut Token to swap to
     * @param amountIn Amount of tokenIn to swap
     * @param minAmountOut Minimum amount of tokenOut to accept (slippage protection)
     * Requirements:
     * - Tokens must be different
     * - Amount must be positive
     * - Sufficient liquidity must exist
     * - Output must meet minimum requirement
     */
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) external nonReentrant {
        require(tokenIn != tokenOut, "DEX: identical tokens");
        require(amountIn > 0, "DEX: amountIn must be > 0");
        
        // Sort tokens for consistent reserve tracking
        (address token0, ) = tokenIn < tokenOut ? (tokenIn, tokenOut) : (tokenOut, tokenIn);
        
        // Get current reserves
        uint256 reserveIn = liquidity[tokenIn][tokenOut];
        uint256 reserveOut = liquidity[tokenOut][tokenIn];
        require(reserveIn > 0 && reserveOut > 0, "DEX: insufficient liquidity");
        
        // Calculate amount out with 0.3% fee
        // Fee is deducted by multiplying input amount by 997/1000
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        uint256 amountOut = numerator / denominator;
        
        require(amountOut >= minAmountOut, "DEX: insufficient output amount");
        
        // Transfer input tokens from user
        require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "Transfer failed");
        
        // Update reserves
        liquidity[tokenIn][tokenOut] += amountIn;
        liquidity[tokenOut][tokenIn] -= amountOut;
        
        // Transfer output tokens to user
        require(IERC20(tokenOut).transfer(msg.sender, amountOut), "Transfer failed");
        
        emit TokenSwapped(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }
    
    /**
     * @dev Calculates the expected output amount for a swap
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @param amountIn Amount of input tokens
     * @return amountOut Expected amount of output tokens
     */
    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) public view returns (uint256) {
        require(tokenIn != tokenOut, "DEX: identical tokens");
        uint256 reserveIn = liquidity[tokenIn][tokenOut];
        uint256 reserveOut = liquidity[tokenOut][tokenIn];
        if (reserveIn == 0 || reserveOut == 0) return 0;
        return (amountIn * 997 * reserveOut) / (reserveIn * 1000 + amountIn * 997);
    }
    
    /**
     * @dev Calculates the square root of a number (Babylonian method)
     * @param x Number to calculate square root of
     * @return y Square root result
     * Used for calculating initial LP shares
     */
    function sqrt(uint256 x) private pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}