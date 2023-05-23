// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Owned} from "solmate/auth/Owned.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ERC20 as SolMateERC20} from "solmate/tokens/ERC20.sol";

contract ThrottledWallet is Owned {
    struct TimeLock {
        uint256 amount;
        uint256 unlockTime;
    }

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

    uint256 public throttlePeriod;
    uint256 public withdrawAmountPrPeriod;

    // Token that will be throttled, other tokens can be withdrawn freely by owner
    // If address(0) then ETH will be used
    SolMateERC20 public immutable throttedToken;

    // Timelock duration in seconds, 0 means no timelock
    uint256 public timelockDuration;

    uint256 public periodStart = 0;
    uint256 public withdrawedAmount = 0;

    // Nonce for timelocked withdrawals, incremented for each withdrawal
    // used as key in pendingWithdrawals
    // 0 is not used and returned by withdraw() if timelock is disabled
    uint256 public nonce = 1;

    mapping(uint256 => TimeLock) public pendingWithdrawals;
    uint256 public totalPending = 0;

    // Internal function to set configuration
    function _setConfig(
        uint256 _throttlePeriod,
        uint256 _withdrawAmountPrPeriod,
        uint256 _lockDuration
    ) internal {
        require(_throttlePeriod != 0, "throttlePeriod must be greater than 0");
        require(
            _withdrawAmountPrPeriod != 0,
            "withdrawAmountPrPeriod must be greater than 0"
        );
        throttlePeriod = _throttlePeriod;
        withdrawAmountPrPeriod = _withdrawAmountPrPeriod;
        timelockDuration = _lockDuration;
        emit ConfigurationUpdated(
            _throttlePeriod,
            _withdrawAmountPrPeriod,
            _lockDuration
        );
    }

    function _withdraw(SolMateERC20 token, uint256 amount) internal {
        if (address(token) == address(0)) {
            payable(owner).transfer(amount);
        } else {
            SafeTransferLib.safeTransfer(token, owner, amount);
        }
        emit Withdrawal(address(token), owner, amount);
    }

    function _balance() internal view returns (uint256) {
        if (address(throttedToken) == address(0)) {
            return address(this).balance;
        } else {
            return throttedToken.balanceOf(address(this));
        }
    }

    constructor(
        uint256 _throttlePeriod,
        uint256 _withdrawAmountPrPeriod,
        uint256 _lockDuration,
        SolMateERC20 _throttedToken
    ) Owned(msg.sender) {
        throttedToken = _throttedToken;
        _setConfig(_throttlePeriod, _withdrawAmountPrPeriod, _lockDuration);
    }

    /**
     * @notice Allows owner to update configuration
     * @param _throttlePeriod Throttle period in seconds
     * @param _withdrawAmountPrPeriod Max amount that can be withdrawn per period
     * @param _lockDuration Timelock duration in seconds, 0 means no timelock
     */
    function setConfig(
        uint256 _throttlePeriod,
        uint256 _withdrawAmountPrPeriod,
        uint256 _lockDuration
    ) external onlyOwner {
        _setConfig(_throttlePeriod, _withdrawAmountPrPeriod, _lockDuration);
    }

    /**
     * @notice Completes a timelocked withdrawal
     * @param _nonce Nonce of withdrawal to complete
     */
    function completeWithdrawal(uint256 _nonce) external onlyOwner {
        TimeLock memory timeLock = pendingWithdrawals[_nonce];
        require(timeLock.amount != 0, "Nothing to withdraw");
        require(
            timeLock.unlockTime <= block.timestamp,
            "Withdrawal is still timelocked"
        );
        pendingWithdrawals[_nonce].amount = 0;
        totalPending -= timeLock.amount;
        _withdraw(throttedToken, timeLock.amount);
    }

    /**
     * @notice Withdraws tokens from the contract
     * @param token Token to withdraw, address(0) for ETH
     * @param amount Amount to withdraw
     * @return nonce if withdrawal is timelocked, otherwise 0
     */
    function withdraw(
        SolMateERC20 token,
        uint256 amount
    ) external onlyOwner returns (uint256) {
        require(amount != 0, "amount must be greater than 0");
        require(periodStart != block.timestamp, "reentrancy");

        // Allow rescuing tokens
        if (token != throttedToken) {
            _withdraw(token, amount);
            return 0;
        }

        // Check that there is enough funds for current withdrawal and pending withdrawals
        require(_balance() >= totalPending + amount, "Not enough funds");

        uint256 timeSincePeriodStart = block.timestamp - periodStart;
        uint256 accumulatedWithdrawalAmount = (timeSincePeriodStart *
            withdrawAmountPrPeriod) / throttlePeriod;

        uint256 currentAmount = withdrawedAmount;
        if (accumulatedWithdrawalAmount > currentAmount) {
            accumulatedWithdrawalAmount = currentAmount;
        }

        currentAmount = currentAmount - accumulatedWithdrawalAmount + amount;

        // Check if withdraw amount is within limit
        require(
            currentAmount <= withdrawAmountPrPeriod,
            "Withdraw amount exceeds period limit"
        );

        periodStart = block.timestamp;
        withdrawedAmount = currentAmount;

        // If timelock is enabled, start timelock and return nonce
        if (timelockDuration != 0) {
            uint256 _nonce = nonce++;
            pendingWithdrawals[_nonce] = TimeLock({
                amount: amount,
                unlockTime: block.timestamp + timelockDuration
            });
            totalPending += amount;

            emit WithdrawalStarted(
                address(token),
                owner,
                amount,
                block.timestamp + timelockDuration,
                _nonce
            );
            return _nonce;
        } else {
            _withdraw(token, amount);
            return 0;
        }
    }

    receive() external payable {}
}
