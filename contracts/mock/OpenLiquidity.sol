// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./libraries/FixedMath.sol";

abstract contract OpenLiquidity {
    using FixedMath for *;

    event LiquidityAdded(address indexed account, uint256 amount);
    event LiquidityWithdrawn(address indexed account, uint256 amount);

    error InsufficientLiquidity();
    error InsufficientLiquidityProvided();
    error InsufficientAvailableLiquidity();

    IERC20 public token;

    uint256 public liquidity;
    uint256 public liquidityLocked;
    uint256 public totalProvidedLiquidity;
    mapping(address => uint256) public providedLiquidity;

    function addLiquidity(uint128 amount) external {
        token.transferFrom(msg.sender, address(this), amount);
        liquidity += amount;
        totalProvidedLiquidity += amount;
        providedLiquidity[msg.sender] += amount;
        emit LiquidityAdded(msg.sender, amount);
    }

    function withdrawLiquidity(uint128 percent) external {
        if (liquidity == 0) revert InsufficientLiquidity();

        uint256 _providedLiquidity = providedLiquidity[msg.sender];

        if (_providedLiquidity == 0) revert InsufficientLiquidityProvided();

        uint256 reduceLP = _providedLiquidity.mul(percent);
        uint256 amount = liquidity.mul(reduceLP).div(totalProvidedLiquidity);

        if (liquidity - liquidityLocked < amount)
            revert InsufficientAvailableLiquidity();

        totalProvidedLiquidity -= reduceLP;
        providedLiquidity[msg.sender] -= reduceLP;

        liquidity -= amount;
        token.transfer(msg.sender, amount);

        emit LiquidityWithdrawn(msg.sender, amount);
    }

    function _lockLiquidity(
        address account,
        uint256 amount,
        uint256 winMultiplier
    ) internal {
        liquidity += amount;
        liquidityLocked += amount.mul(winMultiplier);
        if (liquidityLocked > liquidity) revert InsufficientLiquidity();
        token.transferFrom(account, address(this), amount);
    }

    function _unlockLiquidity(uint256 amount, uint256 winMultiplier) internal {
        liquidityLocked -= amount.mul(winMultiplier);
        token.transfer(msg.sender, amount.mul(winMultiplier));
    }

    function _setToken(address token_) internal {
        token = IERC20(token_);
    }
}
