// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract CPAMM {
    /* ========== GLOBAL VARIABLES ========== */

    using SafeMath for uint256;
    IERC20 token; // instantiates the imported contract
    uint256 public totalLiquidity;
    mapping(address => uint256) public liquidity;

    /* ========== EVENTS ========== */

    /**
     * @notice Emitted when ethToToken() swap transacted
     */
    event EthToTokenSwap(
        address swapper,
        string txDetails,
        uint256 ethInput,
        uint256 tokenOutput
    );

    /**
     * @notice Emitted when tokenToEth() swap transacted
     */
    event TokenToEthSwap(
        address swapper,
        string txDetails,
        uint256 tokensInput,
        uint256 ethOutput
    );

    /**
     * @notice Emitted when liquidity provided to DEX and mints LPTs.
     */
    event LiquidityProvided(
        address liquidityProvider,
        uint256 tokensInput,
        uint256 ethInput,
        uint256 liquidityMinted
    );

    /**
     * @notice Emitted when liquidity removed from DEX and decreases LPT count within DEX.
     */
    event LiquidityRemoved(
        address liquidityRemover,
        uint256 tokensOutput,
        uint256 ethOutput,
        uint256 liquidityWithdrawn
    );

    /* ========== CONSTRUCTOR ========== */

    constructor(address token_addr) {
        require(token_addr != address(0), "zero address");
        token = IERC20(token_addr); //specifies the token address that will hook into the interface and be used through the variable 'token'
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function init(uint256 tokens) public payable returns (uint256) {
        require(msg.value > 0, "need to send ETH");
        require(msg.value == tokens, "incorrect exchange value");
        require(totalLiquidity == 0, "DEX already initialized");
        require(
            token.transferFrom(msg.sender, address(this), tokens),
            "transfer failed"
        );
        liquidity[msg.sender] = msg.value;
        return totalLiquidity = address(this).balance;
    }

    /**
     * @notice returns yOutput, or yDelta for xInput (or xDelta)
     */
    function price(
        uint256 xInput,
        uint256 xReserves,
        uint256 yReserves
    ) public pure returns (uint256 yOutput) {
        // 0.3% trading fee
        xInput = (xInput * 997) / 1000;
        uint256 numerator = xInput * yReserves;
        uint256 denominator = xReserves + xInput;
        return numerator / denominator;
    }

    /**
     * @notice returns liquidity for a user.
     */
    function getLiquidity(address lp) public view returns (uint256) {
        return liquidity[lp];
    }

    /**
     * @notice sends Ether to DEX in exchange for token
     */
    function ethToToken() public payable returns (uint256 tokenOutput) {
        require(msg.value > 0, "must send ETH");
        tokenOutput = price(
            msg.value,
            (address(this).balance - msg.value),
            token.balanceOf(address(this))
        );
        require(
            tokenOutput < token.balanceOf(address(this)),
            "not enough tokens"
        );
        require(token.transfer(msg.sender, tokenOutput), "transfer failed");
        emit EthToTokenSwap(
            msg.sender,
            "Eth to Balloons",
            msg.value,
            tokenOutput
        );
    }

    /**
     * @notice sends token to DEX in exchange for Ether
     */
    function tokenToEth(uint256 tokenInput) public returns (uint256 ethOutput) {
        require(tokenInput > 0, "must send tokens");
        require(
            tokenInput <= token.balanceOf(msg.sender),
            "invalid token amount"
        );
        ethOutput = price(
            tokenInput,
            token.balanceOf(address(this)),
            address(this).balance
        );
        require(ethOutput < address(this).balance, "not enough ETH");
        require(
            token.transferFrom(msg.sender, address(this), tokenInput),
            "token transfer failed"
        );
        (bool success, ) = payable(msg.sender).call{value: ethOutput}("");
        require(success, "ETH transfer failed");
        emit TokenToEthSwap(
            msg.sender,
            "Balloons to ETH",
            ethOutput,
            tokenInput
        );
    }

    /**
     * @notice allows deposits of token and ETH to liquidity pool
     */
    function deposit() public payable returns (uint256 tokensDeposited) {
        require(msg.value > 0, "need to send liquidity");
        uint256 dy = msg.value;
        uint256 x = token.balanceOf(address(this)); // token reserves
        uint256 y = address(this).balance - msg.value; // ETH reserves
        tokensDeposited = ((dy * x) / (y + dy));
        uint256 shares = (dy * totalLiquidity) / y;
        liquidity[msg.sender] += shares;
        totalLiquidity += shares;
        require(
            token.transferFrom(msg.sender, address(this), tokensDeposited),
            "token transfer failed"
        );
        emit LiquidityProvided(msg.sender, shares, msg.value, tokensDeposited);
    }

    /**
     * @notice allows withdrawal of tokens and ETH from liquidity pool
     */
    function withdraw(uint256 amount)
        public
        returns (uint256 eth_amount, uint256 token_amount)
    {
        require(liquidity[msg.sender] >= amount, "not enough shares");
        // dy = s / T * y
        // dx = s / T * X
        eth_amount = (amount / totalLiquidity) * address(this).balance;
        token_amount =
            (amount / totalLiquidity) *
            token.balanceOf(address(this));
        liquidity[msg.sender] -= amount;
        totalLiquidity -= amount;
        require(
            token.transfer(msg.sender, token_amount),
            "token transfer failed"
        );
        (bool success, ) = payable(msg.sender).call{value: eth_amount}("");
        require(success, "ETH transfer failed");
        emit LiquidityRemoved(msg.sender, amount, eth_amount, token_amount);
    }
}
