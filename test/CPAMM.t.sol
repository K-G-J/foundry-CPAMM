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
        assertEq(CPAMMContract.reserve0(), token0.balanceOf(address(CPAMMContract)));
        assertEq(CPAMMContract.reserve1(), token1.balanceOf(address(CPAMMContract)));
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
        assertEq(CPAMMContract.reserve0(), token0.balanceOf(address(CPAMMContract)));
        assertEq(CPAMMContract.reserve1(), token1.balanceOf(address(CPAMMContract)));
        assertEq(CPAMMContract.reserve0(), 150);
        assertEq(CPAMMContract.reserve1(), 150);
        assertEq(CPAMMContract.totalSupply(), 150);
    }
}
