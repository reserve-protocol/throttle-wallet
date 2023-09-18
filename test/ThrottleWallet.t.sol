// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import { ThrottleWallet } from "../src/ThrottleWallet.sol";
import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

contract MintableERC20 is ERC20 {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) { }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

uint256 constant START_TIME = 1686000000;

contract ThrottleWalletTest is Test {
    address user_admin = address(0x1);
    address user_user = address(0x2);

    address user_target = address(0x3);

    event WithdrawalInitiated(uint256 indexed nonce, address indexed to, uint256 amount, uint256 unlockTime);
    event WithdrawalCompleted(uint256 indexed nonce);
    event WithdrawalCancelled(uint256 indexed nonce);

    ThrottleWallet public throttleWallet;
    MintableERC20 public token;

    function setUp() public {
        MintableERC20 _token = new MintableERC20("RSR", "RSR");
        vm.etch(0x320623b8E4fF03373931769A31Fc52A4E78B5d70, address(_token).code);

        throttleWallet = new ThrottleWallet(user_admin, user_user);

        token = MintableERC20(0x320623b8E4fF03373931769A31Fc52A4E78B5d70);
        token.mint(address(throttleWallet), 2_000_000_000 ether);

        vm.warp(START_TIME);
    }

    function test_Withdraw() public {
        vm.startPrank(user_user);

        vm.expectRevert("amount must be greater than 0");
        throttleWallet.initiateWithdrawal(0, user_target);

        vm.expectRevert("target cannot be 0x0");
        throttleWallet.initiateWithdrawal(1_000 ether, address(0));

        vm.expectRevert("insufficient funds");
        throttleWallet.initiateWithdrawal(3_000_000_000 ether, user_target);

        vm.expectEmit();
        emit WithdrawalInitiated(0, user_target, 1_000 ether, block.timestamp + 4 weeks);
        throttleWallet.initiateWithdrawal(1_000 ether, user_target);

        assertEq(token.balanceOf(address(throttleWallet)), 2_000_000_000 ether);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(throttleWallet.totalPending(), 1_000 ether);
        vm.stopPrank();
    }

    function test_completeWithdraw() public {
        vm.startPrank(user_user);

        throttleWallet.initiateWithdrawal(1_000 ether, user_target);

        vm.warp(START_TIME + 4 weeks);
        throttleWallet.completeWithdrawal(0);

        vm.stopPrank();

        vm.startPrank(user_admin);
        
        vm.expectRevert("withdrawal is not pending");
        throttleWallet.cancelWithdrawal(0);

        vm.stopPrank();
    }

    function test_WithdrawalTimelock() public {
        vm.startPrank(user_user);
        vm.expectEmit();

        emit WithdrawalInitiated(0, user_target, 1_000 ether, block.timestamp + 4 weeks);
        throttleWallet.initiateWithdrawal(1_000 ether, user_target);

        // Test if Timelock is enforced
        vm.warp(START_TIME + 4 weeks - 1);
        vm.expectRevert();
        throttleWallet.completeWithdrawal(0);

        vm.warp(START_TIME + 4 weeks);
        vm.expectEmit();
        emit WithdrawalCompleted(0);
        throttleWallet.completeWithdrawal(0);

        assertEq(token.balanceOf(address(throttleWallet)), 1_999_999_000 ether);
        assertEq(token.balanceOf(user_target), 1_000 ether);

        vm.expectRevert();
        throttleWallet.completeWithdrawal(0);

        assertEq(token.balanceOf(address(throttleWallet)), 1_999_999_000 ether);
        assertEq(token.balanceOf(user_target), 1_000 ether);
        vm.stopPrank();
    }

    function test_WithdrawalCancellation() public {
        vm.startPrank(user_user);
        vm.expectEmit();

        emit WithdrawalInitiated(0, user_target, 1_000 ether, block.timestamp + 4 weeks);
        throttleWallet.initiateWithdrawal(1_000 ether, user_target);

        // Test if Timelock is enforced
        vm.warp(START_TIME + 4 weeks - 1);
        vm.expectRevert();
        throttleWallet.completeWithdrawal(0);
        vm.stopPrank();

        vm.startPrank(user_user);
        vm.expectRevert();
        throttleWallet.cancelWithdrawal(0);
        vm.stopPrank();

        vm.startPrank(user_admin);
        vm.expectEmit();
        emit WithdrawalCancelled(0);
        throttleWallet.cancelWithdrawal(0);

        // Unable to withdraw cancelled request
        vm.warp(START_TIME + 4 weeks);
        vm.expectRevert();
        throttleWallet.completeWithdrawal(0);

        assertEq(token.balanceOf(address(throttleWallet)), 2_000_000_000 ether);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(throttleWallet.totalPending(), 0);
        vm.stopPrank();
    }

    function test_AccessControl() public {
        vm.startPrank(address(4));

        vm.expectRevert();
        throttleWallet.initiateWithdrawal(1_000 ether, user_target);
        vm.stopPrank();

        // Still expected to fail since admin can NOT create withdrawals
        vm.startPrank(user_admin);
        vm.expectRevert();
        throttleWallet.initiateWithdrawal(1_000 ether, user_target);

        assertEq(token.balanceOf(address(throttleWallet)), 2_000_000_000 ether);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(throttleWallet.totalPending(), 0);
        vm.stopPrank();

        // ...but user can!
        vm.startPrank(user_user);
        throttleWallet.initiateWithdrawal(1_000 ether, user_target);

        assertEq(token.balanceOf(address(throttleWallet)), 2_000_000_000 ether);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(throttleWallet.totalPending(), 1_000 ether);
        vm.stopPrank();
    }

    function test_LinearAccumulator() public {
        vm.startPrank(user_user);

        // Drain the entire throttle!
        throttleWallet.initiateWithdrawal(1_000_000_000 ether, user_target);

        assertEq(token.balanceOf(address(throttleWallet)), 2_000_000_000 ether);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(throttleWallet.totalPending(), 1_000_000_000 ether);

        // Withdrawing a single token should still fail!
        vm.expectRevert();
        throttleWallet.initiateWithdrawal(1, user_target);

        // 2 weeks in, we should be able to withdraw half of it.
        vm.warp(START_TIME + 2 weeks);
        throttleWallet.initiateWithdrawal(500_000_000 ether, user_target);

        assertEq(token.balanceOf(address(throttleWallet)), 2_000_000_000 ether);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(throttleWallet.totalPending(), 1_500_000_000 ether);

        // 4 weeks in, we should be able to withdraw the first one.
        vm.warp(START_TIME + 4 weeks);
        throttleWallet.completeWithdrawal(0);

        // ...but not the second one
        vm.expectRevert();
        throttleWallet.completeWithdrawal(1);

        // Another week in, throttle is not fully charged yet.
        vm.warp(START_TIME + 4 weeks + 1 weeks);
        assertEq(throttleWallet.availableToWithdraw(), 750_000_000 ether);

        // Now we can complete the second one.
        vm.warp(START_TIME + 4 weeks + 2 weeks);
        throttleWallet.completeWithdrawal(1);

        // The throttle is now full charged
        assertEq(throttleWallet.availableToWithdraw(), 500_000_000 ether);
        vm.stopPrank();
    }

    function test_AccessControl_ChangeUser() public {
        vm.startPrank(user_admin);

        // No change for user, already user_user
        vm.expectRevert();
        throttleWallet.changeUser(user_user);

        // Change user
        throttleWallet.changeUser(address(5));
        vm.stopPrank();

        vm.prank(address(5));

        // But user can't change user.
        vm.expectRevert();
        throttleWallet.changeUser(address(4));

        vm.prank(user_admin);
        throttleWallet.changeUser(user_user);

        assertEq(throttleWallet.user(), user_user);

        // Random person can't do anything.
        vm.prank(address(6));
        vm.expectRevert();
        throttleWallet.changeUser(address(6));

        // Renounce Admin
        vm.prank(user_admin);
        throttleWallet.renounceAdmin();
        vm.expectRevert();
        throttleWallet.changeUser(address(6));
    }

    function test_availableToWithdrawBalance() public {
        vm.startPrank(user_user);

        // Drain the entire throttle!
        throttleWallet.initiateWithdrawal(1_000_000_000 ether, user_target);
        vm.warp(START_TIME + 4 weeks);
        throttleWallet.completeWithdrawal(0);

        throttleWallet.initiateWithdrawal(500_000_000 ether, user_target);
        vm.warp(START_TIME + 8 weeks);
        throttleWallet.completeWithdrawal(1);

        assertEq(throttleWallet.availableToWithdraw(), 500_000_000 ether);

        vm.stopPrank();
    }

    function test_rescueFunds() public {
        MintableERC20 lostToken = new MintableERC20("LOST", "LOST");
        lostToken.mint(address(throttleWallet), 1_000_000_000 ether);

        vm.expectRevert("cannot rescue throttled token");
        throttleWallet.rescueFunds(address(token));

        throttleWallet.rescueFunds(address(lostToken));

        assertEq(lostToken.balanceOf(address(user_admin)), 1_000_000_000 ether);
        assertEq(lostToken.balanceOf(address(throttleWallet)), 0);

        vm.startPrank(user_admin);
        throttleWallet.renounceAdmin();

        deal(address(throttleWallet), 10 ether);

        throttleWallet.rescueFunds(address(0));

        assertEq(user_user.balance, 10 ether);
        assertEq(address(throttleWallet).balance, 0);
        vm.stopPrank();
    }

    function test_badNonce() public {
        vm.startPrank(user_user);

        // Drain the entire throttle!
        throttleWallet.initiateWithdrawal(1_000_000_000 ether, user_target);

        vm.stopPrank();

        vm.startPrank(user_admin);
        vm.expectRevert("invalid nonce");
        throttleWallet.cancelWithdrawal(1);

        vm.stopPrank();

        vm.startPrank(user_user);
        vm.warp(START_TIME + 4 weeks);
        vm.expectRevert("invalid nonce");
        throttleWallet.completeWithdrawal(1);

        vm.stopPrank();
    }
}
