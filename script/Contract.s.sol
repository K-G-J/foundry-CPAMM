// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {CPAMM} from "src/CPAMM.sol";

contract ContractScript is Script {

    address constant token = 0x07865c6E87B9F70255377e024ace6630C1Eaa37F; // USDC Goerli mock token

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        new CPAMM(token);
        vm.stopBroadcast();
    }
}
