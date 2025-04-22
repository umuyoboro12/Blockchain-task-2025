// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title Logic Contract V1
 * @dev Simple logic to store and get value
 */
contract LogicV1 {
    // slot 0: proxy admin
    // slot 1: proxy implementation
    // slot 2: storedValue (we use this one)

    function setValue(uint256 _val) public {
        assembly {
            sstore(2, _val) // store at slot 2
        }
    }

    function getValue() public view returns (uint256 val) {
        assembly {
            val := sload(2) // load from slot 2
        }
    }
}