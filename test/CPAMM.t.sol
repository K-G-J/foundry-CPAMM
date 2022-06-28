// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "solmate/test/utils/mocks/MockERC20.sol";
import "../src/CPAMM.sol";

contract CPAMMTest is Test {
    event EthToTokenSwap(
        address swapper,
        string txDetails,
        uint256 ethInput,
        uint256 tokenOutput
    );
    event TokenToEthSwap(
        address swapper,
        string txDetails,
        uint256 tokensInput,
        uint256 ethOutput
    );
    event LiquidityProvided(
        address liquidityProvider,
        uint256 tokensInput,
        uint256 ethInput,
        uint256 liquidityMinted
    );
    event LiquidityRemoved(
        address liquidityRemover,
        uint256 tokensOutput,
        uint256 ethOutput,
        uint256 liquidityWithdrawn
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
        assertEq(CPAMMContract.totalLiquidity(), address(CPAMMContract).balance);
    }
}
