// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.9;

/// @title Fixed-point math tools
library FixedMath {
    uint256 constant ONE = 1e12;

    function mul(uint256 self, uint256 other) internal pure returns (uint256) {
        return (self * other) / ONE;
    }

    function div(uint256 self, uint256 other) internal pure returns (uint256) {
        return (self * ONE) / other;
    }

    /**
     * @notice Implementation of the sigmoid function.
     * @notice The sigmoid function is commonly used in machine learning to limit output values within a range of 0 to 1.
     */
    function sigmoid(uint256 self) internal pure returns (uint256) {
        return (self * ONE) / (self + ONE);
    }
}
