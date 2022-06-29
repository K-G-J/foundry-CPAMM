// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "solmate/test/utils/mocks/MockERC20.sol";
import "../src/CPAMM.sol";

contract CPAMMTest is Test {
    event EthToTokenSwap(
        address indexed swapper,
        uint256 indexed ethInput,
        uint256 indexed tokenOutput
    );
    event TokenToEthSwap(
        address indexed swapper,
        uint256 indexed tokensInput,
        uint256 indexed ethOutput
    );
    event LiquidityProvided(
        address liquidityProvider,
        uint256 indexed tokensInput,
        uint256 indexed ethInput,
        uint256 indexed liquidityMinted
    );
    event LiquidityRemoved(
        address liquidityRemover,
        uint256 indexed tokensOutput,
        uint256 indexed ethOutput,
        uint256 indexed liquidityWithdrawn
    );

    address alice = address(0x1337);
    address bob = address(0x133702);
    CPAMM CPAMMContract;
    MockERC20 token;

    function setUp() public {
        vm.label(address(this), "TestContract");
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(address(CPAMMContract), "CPAMM");
        vm.label(address(token), "Token");

        token = new MockERC20("MockToken", "MT", 18);
        CPAMMContract = new CPAMM(address(token));

        token.mint(address(this), 100);
        token.approve(address(CPAMMContract), 100);
    }

    receive() external payable {}

    function test__constructorNonZero() public {
        vm.expectRevert("zero address");
        new CPAMM(address(0));
    }

    function test__initBadValues() public {
        vm.expectRevert("need to send ETH");
        CPAMMContract.init(10);
        vm.expectRevert("incorrect exchange value");
        CPAMMContract.init{value: 100}(10);
    }

    function test__initAlreadyInitialized() public {
        CPAMMContract.init{value: 50}(50);
        vm.expectRevert("DEX already initialized");
        CPAMMContract.init{value: 50}(50);
    }

    function test_init() public {
        CPAMMContract.init{value: 100}(100);
        assertEq(token.balanceOf(address(CPAMMContract)), 100);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(address(CPAMMContract).balance, 100);
        assertEq(CPAMMContract.getLiquidity(address(this)), 100);
        assertEq(
            CPAMMContract.totalLiquidity(),
            address(CPAMMContract).balance
        );
    }

    function test__ethToTokenNoValueRevert() public {
        CPAMMContract.init{value: 100}(100);
        vm.expectRevert("must send ETH");
        CPAMMContract.ethToToken();
    }

    function test__ethToToken() public {
        CPAMMContract.init{value: 100}(100);
        uint tokenPrebalance = token.balanceOf(address(this));
        uint contractEthPrebalance = address(CPAMMContract).balance;
        uint priceFunctionOutput = CPAMMContract.price(100, 100, 100);
        uint tokenOutput = CPAMMContract.ethToToken{value: 100}();
        assertEq(priceFunctionOutput, 49);
        assertEq(tokenOutput, priceFunctionOutput);
        assertEq(token.balanceOf(address(this)), tokenPrebalance + tokenOutput);
        assertEq(address(CPAMMContract).balance, contractEthPrebalance + 100);
    }

    function test__ethToTokenEvent() public {
        // CPAMMContract.init{value: 100}(100);
        // vm.expectEmit(true, true, true, true);
        // uint tokenOutput = CPAMMContract.ethToToken{value: 100}();
        // emit EthToTokenSwap(address(this), 100, tokenOutput);
    }

    function test__tokenToEthBadAmmount() public {
        CPAMMContract.init{value: 100}(100);
        token.mint(address(this), 100);
        token.approve(address(this), 100);
        vm.expectRevert("must send tokens");
        CPAMMContract.tokenToEth(0);
        vm.expectRevert("invalid token amount");
        CPAMMContract.tokenToEth(101);
    }

    function test__tokenToEth() public {
        CPAMMContract.init{value: 100}(100);
        token.mint(address(this), 100);
        token.approve(address(CPAMMContract), 100);
        uint tokenPrebalance = token.balanceOf(address(CPAMMContract));
        uint ethPrebalance = address(this).balance;
        uint ethOutput = CPAMMContract.tokenToEth(50);
        uint priceFunctionOutput = CPAMMContract.price(50, 100, 100);
        assertEq(priceFunctionOutput, 32);
        assertEq(ethOutput, priceFunctionOutput);
        assertEq(token.balanceOf(address(CPAMMContract)), tokenPrebalance + 50);
        assertEq(address(this).balance, ethPrebalance + ethOutput);
    }

    // function test__tokenToEthEvent() public {
    //     CPAMMContract.init{value: 100}(100);
    //     token.mint(address(this), 100);
    //     token.approve(address(CPAMMContract), 100);
    //     vm.expectEmit(true, true, true, true);
    //     uint ethOutput = CPAMMContract.tokenToEth(50);
    //     emit TokenToEthSwap(address(this), 50, ethOutput);
    // }
}
