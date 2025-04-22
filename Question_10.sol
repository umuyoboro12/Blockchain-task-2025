// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title Upgradeable Proxy Contract
 * 
 * @notice 
 * 1. Contract Purpose:
 *    The UpgradeableProxy contract is designed to enable the deployment of upgradeable smart contracts.
 *    It separates contract logic from data storage, allowing the underlying logic (implementation) to be changed
 *    without losing the stored state. This is crucial for long-term smart contract systems that may require upgrades
 *    due to bugs, new features, or improvements.
 * 
 * 2. Key Features Used:
 *    - Proxy pattern using delegatecall for executing logic contract functions in the context of the proxy.
 *    - Admin-controlled upgrade mechanism to point to new logic contracts.
 *    - Preservation of data across upgrades.
 *    - Fallback and receive functions to redirect all calls to the current logic implementation.
 * 
 * 3. Technical Concepts Used:
 *    - `delegatecall`: Low-level Solidity operation that allows a contract to call another contract's code
 *      while keeping the context (storage, balance, msg.sender) of the calling contract.
 *    - Proxy Design Pattern: A smart contract pattern that separates contract state (storage) from contract logic.
 *    - Admin Access Control: Only the admin can upgrade the contract to a new implementation.
 *    - Low-level assembly: Used in fallback function to handle `delegatecall` mechanics.
 * 
 * 4. Code Comments:
 *    The code is thoroughly commented with clear explanations of the logic for proxy delegation, upgrade mechanism,
 *    and storage handling.
 */

contract UpgradeableProxy {
    address public admin;
    address public implementation; // Logic contract address

    // Storage variable to demonstrate persistence
    uint256 public storedValue;

    event Upgraded(address indexed newImplementation);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    constructor(address _implementation) {
        admin = msg.sender;
        implementation = _implementation;
    }

    function upgradeTo(address _newImplementation) external onlyAdmin {
        require(_newImplementation != address(0), "Invalid address");
        implementation = _newImplementation;
        emit Upgraded(_newImplementation);
    }

    fallback() external payable {
        _delegate(implementation);
    }

    receive() external payable {
        _delegate(implementation);
    }

    function _delegate(address _impl) internal {
        require(_impl != address(0), "No implementation set");

        assembly {
            // Copy msg.data to memory
            calldatacopy(0, 0, calldatasize())

            // Delegate call to the implementation
            let result := delegatecall(gas(), _impl, 0, calldatasize(), 0, 0)

            // Copy returned data
            returndatacopy(0, 0, returndatasize())

            switch result
            case 0 {
                // Revert if call failed
                revert(0, returndatasize())
            }
            default {
                // Return data if successful
                return(0, returndatasize())
            }
        }
    }
}