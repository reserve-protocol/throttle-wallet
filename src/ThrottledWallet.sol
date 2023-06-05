// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { AccessControl } from "@openzeppelin/access/AccessControl.sol";

contract ThrottledWallet2 is AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant USER_ROLE = keccak256("USER_ROLE");

    /**
     * @notice Structs
     */
    enum WithdrawalStatus {
        Pending,
        Completed,
        Cancelled
    }

    struct WithdrawalRequest {
        uint256 amount;
        address target;
        uint256 unlockTime;
        WithdrawalStatus status;
    }

    /**
     * @notice Events
     */
    event WithdrawalInitiated(
        uint256 indexed nonce,
        address indexed to,
        uint256 amount,
        uint256 unlockTime
    );
    event WithdrawalCompleted(uint256 indexed nonce);
    event WithdrawalCancelled(uint256 indexed nonce);

    /**
     * @notice Parameters
     * @dev Intentionally hardcoded
     */
    IERC20 public constant throttledToken = IERC20(0x320623b8E4fF03373931769A31Fc52A4E78B5d70); // RSR
    uint256 public constant throttlePeriod = 30 days;
    uint256 public constant amountPerPeriod = 1_000_000_000 * 10 ** 18; // (at most) 1B every 30 days, throttled
    uint256 public constant timelockDuration = 4 weeks;

    uint256 public nextNonce;
    mapping(uint256 nonce => WithdrawalRequest request) public pendingWithdrawals;

    uint256 public lastWithdrawalAt;
    uint256 public lastRemainingLimit;
    uint256 public totalPending;

    constructor(address _admin, address _user) {
        require(_admin != address(0), "admin must be set");
        require(_user != address(0), "user must be set");

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(USER_ROLE, _user);
    }

    /**
     * @notice Initiate Withdrawal with a specific amount and target.
     *         The amount is immediately blocked but can only be withdrawn
     *         after the timelock period has passed.
     */
    function initiateWithdrawal(
        uint256 amount,
        address target
    ) external onlyRole(USER_ROLE) returns (uint256) {
        require(amount != 0, "amount must be greater than 0");
        require(amount <= amountPerPeriod, "amount must be less than max");
        require(
            throttledToken.balanceOf(address(this)) >= totalPending + amount,
            "insufficient funds"
        );

        uint256 accumulatedWithdrawalAmount = ((block.timestamp - lastWithdrawalAt) *
            amountPerPeriod) /
            throttlePeriod +
            lastRemainingLimit;

        if (accumulatedWithdrawalAmount > amountPerPeriod) {
            accumulatedWithdrawalAmount = amountPerPeriod;
        }

        lastWithdrawalAt = block.timestamp;
        lastRemainingLimit = accumulatedWithdrawalAmount - amount;

        uint256 _nonce = nextNonce++;
        pendingWithdrawals[_nonce] = WithdrawalRequest({
            amount: amount,
            target: target,
            unlockTime: block.timestamp + timelockDuration,
            status: WithdrawalStatus.Pending
        });
        totalPending += amount;

        emit WithdrawalInitiated(_nonce, target, amount, block.timestamp + timelockDuration);

        return _nonce;
    }

    /**
     * @notice Allows completing a withdrawal after the timelock period has passed.
     *         Only the user can complete a withdrawal.
     * @dev Does not impact the throttle.
     */
    function completeWithdrawal(uint256 _nonce) external onlyRole(USER_ROLE) {
        require(_nonce < nextNonce, "invalid nonce");

        WithdrawalRequest storage withdrawal = pendingWithdrawals[_nonce];

        require(withdrawal.amount != 0, "withdrawal does not exist");
        require(withdrawal.unlockTime <= block.timestamp, "withdrawal is still locked");
        require(withdrawal.status == WithdrawalStatus.Pending, "withdrawal is not pending");

        totalPending -= withdrawal.amount;
        withdrawal.status = WithdrawalStatus.Completed;

        throttledToken.safeTransfer(withdrawal.target, withdrawal.amount);

        emit WithdrawalCompleted(_nonce);
    }

    /**
     * @notice Allows cancelling a withdrawal if it has not been completed already.
     *         Only the admin can cancel a withdrawal.
     * @dev The throttle is NOT recharged on cancellation.
     */
    function cancelWithdrawal(uint256 _nonce) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_nonce < nextNonce, "invalid nonce");

        WithdrawalRequest storage withdrawal = pendingWithdrawals[_nonce];

        require(withdrawal.status == WithdrawalStatus.Pending, "withdrawal is not pending");

        totalPending -= withdrawal.amount;
        withdrawal.status = WithdrawalStatus.Cancelled;

        emit WithdrawalCancelled(_nonce);
    }
}
