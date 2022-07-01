// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "solmate/test/utils/mocks/MockERC20.sol";
import "../src/CPAMM.sol";

contract CPAMMTest is Test {
    address alice = address(0x1337);
    address bob = address(0x133702);
    CPAMM CPAMMContract;
    MockERC20 token0;
    MockERC20 token1;

    function setUp() public {
        vm.label(address(this), "TestContract");
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(address(CPAMMContract), "CPAMM");
        vm.label(address(token0), "token0");
        vm.label(address(token1), "token1");

        token0 = new MockERC20("Token0", "T0", 18);
        token1 = new MockERC20("Token1", "T1", 18);
        CPAMMContract = new CPAMM(address(token0), address(token1));

        token0.mint(address(this), 200);
        token0.approve(address(CPAMMContract), 200);
        token1.mint(address(this), 200);
        token1.approve(address(CPAMMContract), 200);
    }

    function test__constructorNonZero() public {
        vm.expectRevert("zero address");
        new CPAMM(address(0), address(token1));
        vm.expectRevert("zero address");
        new CPAMM(address(token0), address(0));
        vm.expectRevert("zero address");
        new CPAMM(address(0), address(0));
    }

    function test_constructorDuplicateAddress() public {
        vm.expectRevert("duplicate address");
        new CPAMM(address(token0), address(token0));
    }

    function test__addLiquidityInit() public {
        CPAMMContract.addLiquidity(100, 100);
        assertEq(CPAMMContract.getShares(address(this)), 100);
        assertEq(CPAMMContract.totalSupply(), 100);
        assertEq(
            CPAMMContract.reserve0(),
            token0.balanceOf(address(CPAMMContract))
        );
        assertEq(
            CPAMMContract.reserve1(),
            token1.balanceOf(address(CPAMMContract))
        );
    }

    function test__addLiquidityBadAmount() public {
        CPAMMContract.addLiquidity(100, 100);
        vm.expectRevert("dy / dx != y / x");
        CPAMMContract.addLiquidity(20, 50);
    }

    function test_addLiquidityAlice() public {
        CPAMMContract.addLiquidity(100, 100);
        token0.mint(address(alice), 100);
        token1.mint(address(alice), 100);
        vm.startPrank(alice);
        token0.approve(address(CPAMMContract), 100);
        token1.approve(address(CPAMMContract), 100);
        CPAMMContract.addLiquidity(50, 50);
        vm.stopPrank();
        // s = dx / x * T = dy / y * T
        // s = 50 * 100 / 100 = 50
        assertEq(CPAMMContract.getShares(address(alice)), 50);
        assertEq(
            CPAMMContract.reserve0(),
            token0.balanceOf(address(CPAMMContract))
        );
        assertEq(
            CPAMMContract.reserve1(),
            token1.balanceOf(address(CPAMMContract))
        );
        assertEq(CPAMMContract.reserve0(), 150);
        assertEq(CPAMMContract.reserve1(), 150);
        assertEq(CPAMMContract.totalSupply(), 150);
    }

    function test__swapInvalidToken() public {
        CPAMMContract.addLiquidity(100, 100);
        vm.expectRevert("invalid token");
        CPAMMContract.swap(address(0x1234), 20);
    }

    function test__swapNoAmount() public {
        CPAMMContract.addLiquidity(100, 100);
        vm.expectRevert("amount cannot be zero");
        CPAMMContract.swap(address(token0), 0);
    }

    function test__swapToken0() public {
        CPAMMContract.addLiquidity(100, 100);
        uint tokenOutPrebal = token1.balanceOf(address(this));
        uint tokenInPrebal = token0.balanceOf(address(this));
        uint amountIn = 20;
        uint amountOut = CPAMMContract.swap(address(token0), amountIn);
        // fee 0.3% ---> amountInWithFee = 19
        // dy = ydx / (x + dx) = (100 * 19) / (100 + 19) = 15
        assertEq(token1.balanceOf(address(this)), tokenOutPrebal + amountOut);
        assertEq(token0.balanceOf(address(this)), tokenInPrebal - amountIn);
        assertEq(CPAMMContract.reserve0(), 100 + amountIn);
        assertEq(CPAMMContract.reserve1(), 100 - amountOut);
        assertEq(
            CPAMMContract.reserve0(),
            token0.balanceOf(address(CPAMMContract))
        );
        assertEq(
            CPAMMContract.reserve1(),
            token1.balanceOf(address(CPAMMContract))
        );
    }

    function test__swapToken1() public {
        CPAMMContract.addLiquidity(100, 100);
        uint tokenOutPrebal = token0.balanceOf(address(this));
        uint tokenInPrebal = token1.balanceOf(address(this));
        uint amountIn = 20;
        uint amountOut = CPAMMContract.swap(address(token1), amountIn);
        // fee 0.3% ---> amountInWithFee = 19.94
        // dy = ydx / (x + dx) = (100 * 19.94) / (100 + 19.94) = 16
        emit log_named_uint("Reserve0", CPAMMContract.reserve0());
        emit log_named_uint("Reserve1", CPAMMContract.reserve1());
        emit log_named_uint("TestContractAmountOut", amountOut);
        assertEq(token0.balanceOf(address(this)), tokenOutPrebal + amountOut);
        assertEq(token1.balanceOf(address(this)), tokenInPrebal - amountIn);
        assertEq(CPAMMContract.reserve1(), 100 + amountIn);
        assertEq(CPAMMContract.reserve0(), 100 - amountOut);
        assertEq(
            CPAMMContract.reserve0(),
            token0.balanceOf(address(CPAMMContract))
        );
        assertEq(
            CPAMMContract.reserve1(),
            token1.balanceOf(address(CPAMMContract))
        );
    }

    function test__swapMulti() public {
        CPAMMContract.addLiquidity(100, 100);
        // fee 0.3% ---> amountInWithFee = 49.85
        // dy = ydx / (x + dx) = (100 * 49.84) / (100 + 49.85) = 33
        uint amountOut = CPAMMContract.swap(address(token0), 50);
        emit log_named_uint("Reserve0", CPAMMContract.reserve0());
        emit log_named_uint("Reserve1", CPAMMContract.reserve1());
        emit log_named_uint("TestCotractAmountOut", amountOut);
        vm.startPrank(alice);
        token1.mint(address(alice), 100);
        token1.approve(address(CPAMMContract), 100);
        uint aliceToken0preBal = token0.balanceOf(address(alice));
        uint aliceToken1preBal = token1.balanceOf(address(alice));
        uint aliceAmountIn = 100;
        // fee 0.3% ---> amountInWithFee = 99.7
        // dy = ydx / (x + dx) = (150 * 99.7) / (17 + 99.7) = 128
        uint amountOutAlice = CPAMMContract.swap(
            address(token1),
            aliceAmountIn
        );
        emit log_named_uint("Reserve0", CPAMMContract.reserve0());
        emit log_named_uint("Reserve1", CPAMMContract.reserve1());
        emit log_named_uint("AliceAmountOut", amountOutAlice); // 147
        vm.stopPrank();
        vm.startPrank(bob);
        token0.mint(address(bob), 100);
        token0.approve(address(CPAMMContract), 100);
        uint bobToken0preBal = token0.balanceOf(address(bob));
        uint bobToken1preBal = token1.balanceOf(address(bob));
        uint bobAmountIn = 20;
        // fee 0.3% ---> amountInWithFee = 19.94
        // dy = ydx / (x + dx) = (117 * 19.94) / (3 + 19.94) = 101
        uint amountOutBob = CPAMMContract.swap(address(token0), bobAmountIn);
        emit log_named_uint("Reserve0", CPAMMContract.reserve0());
        emit log_named_uint("Reserve1", CPAMMContract.reserve1());
        emit log_named_uint("BobAmountOut", amountOutBob); // 115
        vm.stopPrank();
        assertEq(
            token1.balanceOf(address(alice)),
            aliceToken1preBal - aliceAmountIn
        );
        assertEq(
            token0.balanceOf(address(alice)),
            aliceToken0preBal + amountOutAlice
        );
        assertEq(token0.balanceOf(address(bob)), bobToken0preBal - bobAmountIn);
        assertEq(
            token1.balanceOf(address(bob)),
            bobToken1preBal + amountOutBob
        );
        assertEq(
            CPAMMContract.reserve0(),
            token0.balanceOf(address(CPAMMContract))
        );
        assertEq(
            CPAMMContract.reserve1(),
            token1.balanceOf(address(CPAMMContract))
        );
    }
}
