// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {CPAMM} from "src/CPAMM.sol";

contract ContractScript is Script {

    address constant token0 = 0x07865c6E87B9F70255377e024ace6630C1Eaa37F; // USDC Goerli mock token
    address constant token1 = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6; // WETH9 Goerli mock token

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        new CPAMM(token0, token1);
        vm.stopBroadcast();
    }
}
