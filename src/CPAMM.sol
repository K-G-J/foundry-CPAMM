// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "./interfaces/IERC20.sol";

contract CPAMM {
    /* XY = K */

    IERC20 public immutable token0;
    IERC20 public immutable token1;

    uint public reserve0;
    uint public reserve1;

    uint public totalSupply; // total shares
    mapping(address => uint) public balanceOf;

    constructor(address _token0, address _token1) {
        require(_token0 != address(0) && _token1 != address(0), "zero address");
        require(_token0 != _token1, "duplicate address");
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }

    function _mint(address _to, uint _amount) private {
        balanceOf[_to] += _amount;
        totalSupply += _amount;
    }

    function _burn(address _from, uint _amount) private {
        balanceOf[_from] -= _amount;
        totalSupply -= _amount;
    }

    function _update(uint _reserve0, uint _reserve1) private {
        reserve0 = _reserve0;
        reserve1 = _reserve1;
    }

    function swap(address _tokenIn, uint _amountIn)
        external
        returns (uint amountOut)
    {
        require(
            _tokenIn == address(token0) || _tokenIn == address(token1),
            "invalid token"
        );
        require(_amountIn > 0, "amount cannot be zero");
        bool isToken0 = _tokenIn == address(token0);
        // determine if tokenIn is token0 or token1
        (
            IERC20 tokenIn,
            IERC20 tokenOut,
            uint reserveIn,
            uint reserveOut
        ) = isToken0
                ? (token0, token1, reserve0, reserve1)
                : (token1, token0, reserve1, reserve0);
        // pull in token for swap (approve first)
        tokenIn.transferFrom(msg.sender, address(this), _amountIn);
        // fee 0.3%
        // dy = ydx / (x + dx)
        uint amountInWithFee = (_amountIn * 997) / 100;
        amountOut =
            (reserveOut * amountInWithFee) /
            (reserveIn + amountInWithFee);
        // transfer swap amount out
        tokenOut.transfer(msg.sender, amountOut);
        // update reserves
        _update(
            token0.balanceOf(address(this)),
            token1.balanceOf(address(this))
        );
    }

    function addLiquidity(uint _amount0, uint _amount1)
        external
        returns (uint shares)
    {
        // pull in liquidity tokens (approve first)
        token0.transferFrom(msg.sender, address(this), _amount0);
        token1.transferFrom(msg.sender, address(this), _amount1);
        // dy / dx = y / x
        // dy * x = dx * y
        if (reserve0 > 0 || reserve1 > 0) {
            require(
                reserve0 * _amount1 == reserve1 * _amount0,
                "dy / dx != y / x"
            );
        }

        // f(x, y) = value of liquidity = sqrt(xy)
        // s = dx / x * T = dy / y * T
        if (totalSupply == 0) {
            shares = _sqrt(_amount0 * _amount1);
        } else {
            shares = _min(
                (_amount0 * totalSupply) / reserve0,
                (_amount1 * totalSupply) / reserve1
            );
        }
        require(shares > 0, "shares = 0");
        // mint shares
        _mint(msg.sender, shares);
        // update reserves
        _update(
            token0.balanceOf(address(this)),
            token1.balanceOf(address(this))
        );
    }

    function removeLiquidity(uint _shares)
        external
        returns (uint amount0, uint amount1)
    {
        // calculate amount0 and amount1 to withdraw
        // dx = s / T * x
        // dy = s / T * y
        uint bal0 = token0.balanceOf(address(this));
        uint bal1 = token1.balanceOf(address(this));

        amount0 = (_shares * bal0) / totalSupply;
        amount1 = (_shares * bal1) / totalSupply;
        require(amount0 > 0 && amount1 > 0, "ammount0 or amount1 = 0");

        // burn shares
        _burn(msg.sender, _shares);
        // update reserves
        _update(bal0 - amount0, bal1 - amount1);
        // transfer tokens to msg.sender
        token0.transfer(msg.sender, amount0);
        token1.transfer(msg.sender, amount1);
    }

    function _sqrt(uint y) private pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function _min(uint x, uint y) private pure returns (uint) {
        return x <= y ? x : y;
    }

    function getShares(address _lp) external view returns (uint) {
        return balanceOf[_lp];
    }
}
