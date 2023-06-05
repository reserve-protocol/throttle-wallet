// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { ThrottledWallet } from "../src/ThrottledWallet_old.sol";
import { ERC20 as SolMateERC20 } from "solmate/tokens/ERC20.sol";

contract ERC20 is SolMateERC20 {
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) SolMateERC20(_name, _symbol, _decimals) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract SlowWalletTest is Test {
    event Withdrawal(address indexed token, address indexed to, uint256 amount);
    event ConfigurationUpdated(
        uint256 throttlePeriod,
        uint256 withdrawAmountPrPeriod,
        uint256 newTimelockDuration
    );
    event WithdrawalStarted(
        address indexed token,
        address indexed to,
        uint256 amount,
        uint256 unlockTime,
        uint256 nonce
    );
    ThrottledWallet public slowWallet;
    ERC20 public token;
    ERC20 public token2;

    function setUp() public {
        token = new ERC20("USDC", "USDC", 18);
        token2 = new ERC20("USDT", "USDT", 18);
        slowWallet = new ThrottledWallet(1 days, 100 ether, 0, token);
        vm.deal(address(slowWallet), 1 ether);
        token.mint(address(slowWallet), 1000 ether);
        token2.mint(address(slowWallet), 1000 ether);
    }

    function test_Withdraw() public {
        vm.expectEmit();
        emit Withdrawal(address(token), address(this), 100 ether);
        slowWallet.withdraw(token, 100 ether);
        assertEq(token.balanceOf(address(slowWallet)), 900 ether);
        assertEq(token.balanceOf(address(this)), 100 ether);
    }

    function test_LinearWithdrawalLimitAccumulation() public {
        slowWallet.withdraw(token, 50 ether);
        assertEq(token.balanceOf(address(slowWallet)), 950 ether);
        assertEq(token.balanceOf(address(this)), 50 ether);

        vm.expectRevert();
        slowWallet.withdraw(token, 100 ether);

        // 50 was withdrawed, waiting 25% of time period replenishes 25. 50 + 25 = 75
        vm.warp(block.timestamp + (1 days) / 4);

        vm.expectRevert();
        slowWallet.withdraw(token, 76 ether);

        slowWallet.withdraw(token, 75 ether);
        assertEq(token.balanceOf(address(slowWallet)), 875 ether);
        assertEq(token.balanceOf(address(this)), 125 ether);
    }

    function test_TimeLock() public {
        vm.expectEmit();
        emit ConfigurationUpdated(1 days, 100 ether, 1 days);
        slowWallet.setConfig(1 days, 100 ether, 1 days);
        vm.expectEmit();
        emit WithdrawalStarted(
            address(token),
            address(this),
            100 ether,
            block.timestamp + 1 days,
            1
        );
        uint256 nonce = slowWallet.withdraw(token, 100 ether);
        assertEq(nonce, 1);
        assertEq(token.balanceOf(address(slowWallet)), 1000 ether);
        assertEq(token.balanceOf(address(this)), 0 ether);

        vm.expectRevert();
        slowWallet.completeWithdrawal(nonce);

        vm.warp(block.timestamp + 1 days);
        vm.expectEmit();
        emit Withdrawal(address(token), address(this), 100 ether);
        slowWallet.completeWithdrawal(nonce);
        assertEq(token.balanceOf(address(slowWallet)), 900 ether);
        assertEq(token.balanceOf(address(this)), 100 ether);
    }

    function test_RevertIf_TimeLockedPending() public {
        // Prevent withdrawals beyond current holdings
        slowWallet.setConfig(1 days, 1000 ether, 10 days);
        uint256 nonce = slowWallet.withdraw(token, 1000 ether);
        assertEq(nonce, 1);
        vm.warp(block.timestamp + 1 days);

        // pendingWithdrawals + balance < amount to withdraw
        vm.expectRevert();
        slowWallet.withdraw(token, 1000 ether);

        vm.warp(block.timestamp + 9 days);

        slowWallet.completeWithdrawal(nonce);
        assertEq(token.balanceOf(address(slowWallet)), 0 ether);
        assertEq(token.balanceOf(address(this)), 1000 ether);
    }

    function test_RevertIf_Throttled() public {
        vm.expectRevert();
        slowWallet.withdraw(token, 101 ether);

        slowWallet.withdraw(token, 20 ether);
        assertEq(token.balanceOf(address(slowWallet)), 980 ether);
        assertEq(token.balanceOf(address(this)), 20 ether);

        vm.expectRevert();
        slowWallet.withdraw(token, 81 ether);
    }

    function test_PeriodReset() public {
        slowWallet.withdraw(token, 100 ether);

        vm.expectRevert();
        slowWallet.withdraw(token, 1 ether);

        vm.warp(block.timestamp + 2 days);
        slowWallet.withdraw(token, 1 ether);
        assertEq(token.balanceOf(address(slowWallet)), 899 ether);
        assertEq(token.balanceOf(address(this)), 101 ether);
    }

    function test_RevertIf_CalledByNonOwner() public {
        vm.prank(address(1));
        vm.expectRevert();
        slowWallet.withdraw(token, 100 ether);
    }

    function test_RevertIf_ConfigBad() public {
        vm.expectRevert();
        slowWallet = new ThrottledWallet(0 days, 100 ether, 0, token);
        vm.expectRevert();
        slowWallet = new ThrottledWallet(1 days, 0 ether, 0, token);
    }

    function test_RescuingTokensPossible() public {
        slowWallet.withdraw(token2, 100 ether);
        slowWallet.withdraw(token2, 100 ether);

        assertEq(token2.balanceOf(address(slowWallet)), 800 ether);
        assertEq(token2.balanceOf(address(this)), 200 ether);

        assertEq(address(slowWallet).balance, 1 ether);
        slowWallet.withdraw(SolMateERC20(address(0)), 1 ether);
        assertEq(address(slowWallet).balance, 0 ether);
    }

    receive() external payable {}
}
