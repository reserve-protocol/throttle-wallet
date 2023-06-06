// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import { ThrottleWallet } from "../src/ThrottleWallet.sol";
import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

contract MintableERC20 is ERC20 {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract ThrottleWalletTest is Test {
    address user_admin = address(0x1);
    address user_user = address(0x2);

    address user_target = address(0x3);

    event WithdrawalInitiated(
        uint256 indexed nonce,
        address indexed to,
        uint256 amount,
        uint256 unlockTime
    );
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

        vm.warp(1686000000);
    }

    function test_Withdraw() public {
        vm.startPrank(user_user);
        vm.expectEmit();

        emit WithdrawalInitiated(0, user_target, 1_000 ether, block.timestamp + 4 weeks);
        throttleWallet.initiateWithdrawal(1_000 ether, user_target);

        assertEq(token.balanceOf(address(throttleWallet)), 2_000_000_000 ether);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(throttleWallet.totalPending(), 1_000 ether);
    }

    function test_WithdrawalTimelock() public {
        vm.startPrank(user_user);
        vm.expectEmit();

        emit WithdrawalInitiated(0, user_target, 1_000 ether, block.timestamp + 4 weeks);
        throttleWallet.initiateWithdrawal(1_000 ether, user_target);

        // Test if Timelock is enforced
        vm.warp(1686000000 + 4 weeks - 1);
        vm.expectRevert();
        throttleWallet.completeWithdrawal(0);

        vm.warp(1686000000 + 4 weeks);
        vm.expectEmit();
        emit WithdrawalCompleted(0);
        throttleWallet.completeWithdrawal(0);

        assertEq(token.balanceOf(address(throttleWallet)), 1_999_999_000 ether);
        assertEq(token.balanceOf(user_target), 1_000 ether);

        vm.expectRevert();
        throttleWallet.completeWithdrawal(0);

        assertEq(token.balanceOf(address(throttleWallet)), 1_999_999_000 ether);
        assertEq(token.balanceOf(user_target), 1_000 ether);
    }

    function test_WithdrawalCancellation() public {
        vm.startPrank(user_user);
        vm.expectEmit();

        emit WithdrawalInitiated(0, user_target, 1_000 ether, block.timestamp + 4 weeks);
        throttleWallet.initiateWithdrawal(1_000 ether, user_target);

        // Test if Timelock is enforced
        vm.warp(1686000000 + 4 weeks - 1);
        vm.expectRevert();
        throttleWallet.completeWithdrawal(0);

        vm.startPrank(user_admin);
        vm.expectEmit();
        emit WithdrawalCancelled(0);
        throttleWallet.cancelWithdrawal(0);

        // Unable to withdraw cancelled request
        vm.warp(1686000000 + 4 weeks);
        vm.expectRevert();
        throttleWallet.completeWithdrawal(0);

        assertEq(token.balanceOf(address(throttleWallet)), 2_000_000_000 ether);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(throttleWallet.totalPending(), 0);
    }

    function test_AccessControl() public {
        vm.startPrank(address(4));
        vm.expectRevert();

        throttleWallet.initiateWithdrawal(1_000 ether, user_target);

        // Still expected to fail since admin can NOT create withdrawals
        vm.startPrank(user_admin);
        vm.expectRevert();
        throttleWallet.initiateWithdrawal(1_000 ether, user_target);

        assertEq(token.balanceOf(address(throttleWallet)), 2_000_000_000 ether);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(throttleWallet.totalPending(), 0);

        // ...but user can!
        vm.startPrank(user_user);
        throttleWallet.initiateWithdrawal(1_000 ether, user_target);

        assertEq(token.balanceOf(address(throttleWallet)), 2_000_000_000 ether);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(throttleWallet.totalPending(), 1_000 ether);
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
        vm.warp(1686000000 + 2 weeks);
        throttleWallet.initiateWithdrawal(500_000_000 ether, user_target);

        assertEq(token.balanceOf(address(throttleWallet)), 2_000_000_000 ether);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(throttleWallet.totalPending(), 1_500_000_000 ether);

        // 4 weeks in, we should be able to withdraw the first one.
        vm.warp(1686000000 + 4 weeks);
        throttleWallet.completeWithdrawal(0);

        // ...but not the second one
        vm.expectRevert();
        throttleWallet.completeWithdrawal(1);

        // Another week in, throttle is not fully charged yet.
        vm.warp(1686000000 + 4 weeks + 1 weeks);
        assertEq(throttleWallet.availableToWithdraw(), 750_000_000 ether);

        // Now we can complete the second one.
        vm.warp(1686000000 + 4 weeks + 2 weeks);
        throttleWallet.completeWithdrawal(1);

        // The throttle is now full charged
        assertEq(throttleWallet.availableToWithdraw(), 1_000_000_000 ether);
    }

    function test_AccessControl_AdminLimits() public {
        vm.startPrank(user_admin);

        bytes32 DEFAULT_ADMIN_ROLE = 0x00;
        bytes32 USER_ROLE = keccak256("USER_ROLE");

        vm.expectRevert();
        throttleWallet.grantRole(DEFAULT_ADMIN_ROLE, address(4));
        vm.expectRevert();
        throttleWallet.revokeRole(DEFAULT_ADMIN_ROLE, address(4));
        vm.expectRevert();
        throttleWallet.renounceRole(DEFAULT_ADMIN_ROLE, address(4));

        // But everyting is ok for user role
        throttleWallet.grantRole(USER_ROLE, address(4));
        throttleWallet.revokeRole(USER_ROLE, address(4));

        throttleWallet.grantRole(USER_ROLE, address(4));
        vm.startPrank(address(4));
        throttleWallet.renounceRole(USER_ROLE, address(4));

        // Another user with no perms.
        vm.startPrank(address(5));
        vm.expectRevert();
        throttleWallet.revokeRole(USER_ROLE, address(4));
        vm.expectRevert();
        throttleWallet.renounceRole(USER_ROLE, address(4));

        // User can't do anything to the admin either.
        vm.startPrank(user_user);
        vm.expectRevert();
        throttleWallet.grantRole(DEFAULT_ADMIN_ROLE, address(4));
        vm.expectRevert();
        throttleWallet.revokeRole(DEFAULT_ADMIN_ROLE, address(4));
        vm.expectRevert();
        throttleWallet.revokeRole(DEFAULT_ADMIN_ROLE, user_admin);
        vm.expectRevert();
        throttleWallet.renounceRole(DEFAULT_ADMIN_ROLE, address(4));
    }
}
