// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title Logic Contract V2 (Upgraded)
 * @dev Adds multiplication feature to previous logic
 */
contract LogicV2 {
    function setValue(uint256 _val) public {
        assembly {
            sstore(2, _val)
        }
    }

    function getValue() public view returns (uint256 val) {
        assembly {
            val := sload(2)
        }
    }

    function doubleValue() public {
        assembly {
            let val := sload(2)
            sstore(2, mul(val, 2))
        }
    }
}