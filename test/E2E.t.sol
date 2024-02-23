// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import { ISlowWallet } from "./interfaces/ISlowWallet.sol";
import { SlowerWallet } from "../src/SlowerWallet.sol";
import { IERC20, ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

// End-2-end Test for Wallet Migration for RSR
contract E2ETest is Test {
    IERC20 private constant RSR = IERC20(0x320623b8E4fF03373931769A31Fc52A4E78B5d70);
    ISlowWallet private constant slowWallet = ISlowWallet(0x6bab6EB87Aa5a1e4A8310C73bDAAA8A5dAAd81C1);

    SlowerWallet private slowerWallet;
    address old_owner;

    address user_admin = address(0x27e6DC36e7F05d64B6ab284338243982b0e26d78);
    address user_user1 = address(0x7cc1bfAB73bE4E02BB53814d1059A98cF7e49644);
    address user_user2 = address(0x3);

    address withdrawTarget = address(0xC0FFEE);
    address tw = 0x0774dF07205a5E9261771b19afa62B6e757f7eF8;

    function setUp() public {
        vm.createSelectFork("https://mainnet.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161", 19144204);

        slowerWallet = SlowerWallet(tw);
        old_owner = slowWallet.owner();
    }

    function test_Migration() public {
        uint256 rsrBalance = RSR.balanceOf(address(slowWallet));
        assertTrue(rsrBalance > 0);

        // Let's start by creating the migration
        vm.startPrank(old_owner);
        slowWallet.propose(address(slowerWallet), rsrBalance, "Migrate to SlowerWallet");

        vm.expectRevert();
        slowWallet.confirm(0, address(slowerWallet), rsrBalance);

        // Jump forward 4 weeks and confirm the transfer.
        vm.warp(block.timestamp + 4 weeks + 1 seconds);
        slowWallet.confirm(0, address(slowerWallet), rsrBalance);

        assertEq(RSR.balanceOf(address(slowWallet)), 0);
        assertEq(RSR.balanceOf(address(slowerWallet)), rsrBalance);
    }

    function test_Actions1() public {
        test_Migration();

        // User actions
        vm.startPrank(user_user1);

        // 1.5b withdrawal
        vm.expectRevert();
        slowerWallet.initiateWithdrawal(1_500_000_000 ether, withdrawTarget);

        // 1b withdrawal
        slowerWallet.initiateWithdrawal(1_000_000_000 ether, withdrawTarget);

        // throttle, 2 weeks in.
        vm.warp(block.timestamp + 2 weeks);
        vm.expectRevert();
        slowerWallet.completeWithdrawal(0);

        // throttle, another 2 weeks + 1 second in.
        vm.warp(block.timestamp + 2 weeks + 1);
        slowerWallet.completeWithdrawal(0);
    }

    function test_Actions2() public {
        test_Migration();

        // User actions
        vm.startPrank(user_user1);
        slowerWallet.initiateWithdrawal(1_000_000_000 ether, withdrawTarget);

        // Owner cancels withdraw
        vm.startPrank(user_admin);
        slowerWallet.cancelWithdrawal(0);
        vm.startPrank(user_user1);

        vm.expectRevert();
        slowerWallet.completeWithdrawal(0);

        vm.warp(block.timestamp + 2 weeks + 1);
        vm.expectRevert();
        slowerWallet.completeWithdrawal(0);

        // Owner changes user
        vm.startPrank(user_admin);
        slowerWallet.changeUser(user_user2);

        vm.startPrank(user_user1);
        vm.expectRevert();
        slowerWallet.initiateWithdrawal(500_000_000 ether, withdrawTarget);

        vm.startPrank(user_user2);
        slowerWallet.initiateWithdrawal(500_000_000 ether, withdrawTarget);

        vm.warp(block.timestamp + 4 weeks + 1);
        slowerWallet.completeWithdrawal(1);
    }
}
