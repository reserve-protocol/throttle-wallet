// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import { ThrottleWallet } from "../src/ThrottleWallet.sol";
import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

address constant ADDRESS_ADMIN = 0x27e6DC36e7F05d64B6ab284338243982b0e26d78;
address constant ADDRESS_USER = 0x7cc1bfAB73bE4E02BB53814d1059A98cF7e49644;

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        string memory seedPhrase = vm.readFile(".secret");
        uint256 privateKey = vm.deriveKey(seedPhrase, 0);

        vm.startBroadcast(privateKey);

        ThrottleWallet throttleWallet = new ThrottleWallet(ADDRESS_ADMIN, ADDRESS_USER);

        console2.log(throttleWallet.lastWithdrawalAt());
        console2.log(throttleWallet.nextNonce());

        vm.stopBroadcast();
    }
}
