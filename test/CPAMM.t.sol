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
        // s = dx / x * T = dy / y * T
        // s = 100 * 100 / 100 = 100
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

    function test_addLiquidityMulti() public {
        CPAMMContract.addLiquidity(100, 100);
        token0.mint(address(alice), 100);
        token1.mint(address(alice), 100);
        vm.startPrank(alice);
        token0.approve(address(CPAMMContract), 50);
        token1.approve(address(CPAMMContract), 50);
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
        // fee 0.3% ---> amountInWithFee = 19.94
        // dy = ydx / (x + dx) = (100 * 19.94) / (100 + 19.94) = 16.6249792
        emit log_named_uint("Reserve0", CPAMMContract.reserve0());
        emit log_named_uint("Reserve1", CPAMMContract.reserve1());
        emit log_named_uint("TestContractAmountOut", amountOut);
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
        // dy = ydx / (x + dx) = (100 * 19.94) / (100 + 19.94) = 16.6249792
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
        // dy = ydx / (x + dx) = (100 * 49.84) / (100 + 49.85) = 33.2665999
        uint amountOut = CPAMMContract.swap(address(token0), 50);
        emit log_named_uint("Reserve0", CPAMMContract.reserve0());
        emit log_named_uint("Reserve1", CPAMMContract.reserve1());
        emit log_named_uint("TestCotractAmountOut", amountOut); // 32
        vm.startPrank(alice);
        token1.mint(address(alice), 100);
        token1.approve(address(CPAMMContract), 100);
        uint aliceToken0preBal = token0.balanceOf(address(alice));
        uint aliceToken1preBal = token1.balanceOf(address(alice));
        uint aliceAmountIn = 100;
        // fee 0.3% ---> amountInWithFee = 99.7
        // dy = ydx / (x + dx) = (150 * 99.7) / (68 + 99.7) = 89.177102
        uint amountOutAlice = CPAMMContract.swap(
            address(token1),
            aliceAmountIn
        );
        emit log_named_uint("Reserve0", CPAMMContract.reserve0());
        emit log_named_uint("Reserve1", CPAMMContract.reserve1());
        emit log_named_uint("AliceAmountOut", amountOutAlice); // 88
        vm.stopPrank();
        vm.startPrank(bob);
        token0.mint(address(bob), 100);
        token0.approve(address(CPAMMContract), 20);
        uint bobToken0preBal = token0.balanceOf(address(bob));
        uint bobToken1preBal = token1.balanceOf(address(bob));
        uint bobAmountIn = 20;
        // fee 0.3% ---> amountInWithFee = 19.94
        // dy = ydx / (x + dx) = (168 * 19.94) / (62 + 19.94) = 40.882597
        uint amountOutBob = CPAMMContract.swap(address(token0), bobAmountIn);
        emit log_named_uint("Reserve0", CPAMMContract.reserve0());
        emit log_named_uint("Reserve1", CPAMMContract.reserve1());
        emit log_named_uint("BobAmountOut", amountOutBob); // 39
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

    function test__removeLiquidityNoShares() public {
        CPAMMContract.addLiquidity(100, 100);
        vm.expectRevert("shares cannot be zero");
        CPAMMContract.removeLiquidity(0);
    }

    function test__removeLiquidityTooManyShares() public {
        CPAMMContract.addLiquidity(100, 100);
        vm.expectRevert("invalid shares");
        CPAMMContract.removeLiquidity(101);
    }

    function test__removeLiquidity() public {
        CPAMMContract.addLiquidity(100, 100);
        uint contractPrebal0 = token0.balanceOf(address(CPAMMContract));
        uint contractPrebal1 = token1.balanceOf(address(CPAMMContract));
        uint testerPrebal0 = token0.balanceOf(address(this));
        uint testerPrebal1 = token1.balanceOf(address(this));
        (uint amount0, uint amount1) = CPAMMContract.removeLiquidity(100);
        // dx = s / T * x = (100 * 100) / 100 = 100
        // dy = s / T * y = (100 * 100) / 100 = 100
        assertEq(amount0, 100);
        assertEq(amount1, 100);
        assertEq(token0.balanceOf(address(this)), testerPrebal0 + amount0);
        assertEq(token1.balanceOf(address(this)), testerPrebal1 + amount1);
        assertEq(
            token0.balanceOf(address(CPAMMContract)),
            contractPrebal0 - amount0
        );
        assertEq(
            token1.balanceOf(address(CPAMMContract)),
            contractPrebal1 - amount1
        );
        assertEq(CPAMMContract.reserve0(), contractPrebal0 - amount0);
        assertEq(CPAMMContract.reserve1(), contractPrebal1 - amount1);
        assertEq(CPAMMContract.getShares(address(this)), 0);
    }

    function test__removeLiquidityMulti() public {
        CPAMMContract.addLiquidity(100, 100);
        vm.startPrank(alice);
        token0.mint(address(alice), 100);
        token1.mint(address(alice), 100);
        token0.approve(address(CPAMMContract), 50);
        token1.approve(address(CPAMMContract), 50);
        CPAMMContract.addLiquidity(50, 50);
        vm.stopPrank();
        vm.startPrank(bob);
        token0.mint(address(bob), 100);
        token1.mint(address(bob), 100);
        token0.approve(address(CPAMMContract), 20);
        token1.approve(address(CPAMMContract), 20);
        CPAMMContract.addLiquidity(20, 20);
        vm.stopPrank();
        uint contractPrebal0 = token0.balanceOf(address(CPAMMContract));
        uint contractPrebal1 = token1.balanceOf(address(CPAMMContract));
        uint alicePrebal0 = token0.balanceOf(address(alice));
        uint alicePrebal1 = token1.balanceOf(address(alice));
        emit log_named_uint("AliceSharesBefore", CPAMMContract.getShares(address(alice))); // 50
        uint bobPrebal0 = token0.balanceOf(address(bob));
        uint bobPrebal1 = token1.balanceOf(address(bob));
        emit log_named_uint("BobSharesBefore", CPAMMContract.getShares(address(bob))); // 20
        emit log_named_uint("TotalSupply", CPAMMContract.totalSupply()); // 170
        vm.prank(alice);
        uint aliceSharesToBurn = 30;
        (uint aliceAmount0, uint aliceAmount1) = CPAMMContract.removeLiquidity(aliceSharesToBurn);
        // dx = s / T * x = (30 * 170) / 170 = 30
        // dy = s / T * y = (30 * 170) / 170 = 30
        assertEq(aliceAmount0, 30);
        assertEq(aliceAmount1, 30);
        assertEq(token0.balanceOf(address(alice)), alicePrebal0 + aliceAmount0);
        assertEq(token1.balanceOf(address(alice)), alicePrebal1 + aliceAmount1);
        vm.prank(bob);
        uint bobSharesToBurn = 20;
        (uint bobAmount0, uint bobAmount1) = CPAMMContract.removeLiquidity(bobSharesToBurn);
        // dx = s / T * x = (20 * 140) / 140 = 20
        // dy = s / T * y = (20 * 140) / 140 = 20
        assertEq(bobAmount0, 20);
        assertEq(bobAmount1, 20);
        assertEq(token0.balanceOf(address(bob)), bobPrebal0 + bobAmount0);
        assertEq(token1.balanceOf(address(bob)), bobPrebal1 + bobAmount1);
        // Check contract updates
        emit log_named_uint("TotalSupply", CPAMMContract.totalSupply()); // 120
        assertEq(token0.balanceOf(address(CPAMMContract)), contractPrebal0 - aliceAmount0 - bobAmount0);
        assertEq(token1.balanceOf(address(CPAMMContract)), contractPrebal1 - aliceAmount1 - bobAmount1);
        assertEq(CPAMMContract.reserve0(), contractPrebal0 - aliceAmount0 - bobAmount0);
        assertEq(CPAMMContract.reserve1(), contractPrebal1 - aliceAmount1 - bobAmount1);
        assertEq(CPAMMContract.getShares(address(alice)), 50 - aliceSharesToBurn);
        assertEq(CPAMMContract.getShares(address(bob)), 20 - bobSharesToBurn);
        assertEq(CPAMMContract.totalSupply(), 170 - aliceSharesToBurn - bobSharesToBurn);
    }
}
