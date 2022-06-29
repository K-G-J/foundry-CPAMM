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

        token0.mint(address(this), 100);
        token0.approve(address(CPAMMContract), 100);
        token1.mint(address(this), 100);
        token1.approve(address(CPAMMContract), 100);
    }

    function test__TestExample() public {
        assertTrue(true);
    }
}
