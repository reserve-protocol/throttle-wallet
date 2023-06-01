// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Owned} from "solmate/auth/Owned.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ERC20 as SolMateERC20} from "solmate/tokens/ERC20.sol";

contract ThrottledWallet is Owned {
    event Withdrawal(address indexed token, address indexed to, uint256 amount);

    uint256 public withdrawAmountPrPeriod;

    // Token that will be throttled, other tokens can be withdrawn freely by owner
    SolMateERC20 public immutable throttedToken;
    uint256 public immutable throttlePeriod;

    uint256 public periodStart = 0;
    uint256 public withdrawedAmount = 0;

    constructor(
        uint256 _throttlePeriod,
        uint256 _withdrawAmountPrPeriod,
        SolMateERC20 _throttedToken
    ) Owned(msg.sender) {
        require(
            _throttedToken != SolMateERC20(address(0)),
            "Token must be set"
        );
        require(_throttlePeriod != 0, "Period cannot be 0");
        require(_withdrawAmountPrPeriod != 0, "Withdraw amount cannot be 0");
        throttlePeriod = _throttlePeriod;
        withdrawAmountPrPeriod = _withdrawAmountPrPeriod;
        throttedToken = _throttedToken;
    }

    /**
     * @notice Withdraws tokens from the throttled wallet. Only callable by owner, token and amount must be non-zero.
     * Amount must be within the withdraw limit for the current period and accumulates linearly over time.
     * @param token Token to withdraw
     * @param amount Amount to withdraw
     */
    function withdraw(SolMateERC20 token, uint256 amount) external onlyOwner {
        require(amount != 0, "amount must be greater than 0");
        require(address(token) != address(0), "token must be set");

        if (token == throttedToken) {
            uint256 timeSincePeriodStart = block.timestamp - periodStart;
            uint256 accumulatedWithdrawalAmount = (timeSincePeriodStart *
                withdrawAmountPrPeriod) / throttlePeriod;

            uint256 currentAmount = withdrawedAmount;
            if (accumulatedWithdrawalAmount > currentAmount) {
                accumulatedWithdrawalAmount = currentAmount;
            }

            currentAmount =
                currentAmount -
                accumulatedWithdrawalAmount +
                amount;

            // Check if withdraw amount is within limit
            require(
                currentAmount <= withdrawAmountPrPeriod,
                "Withdraw amount exceeds period limit"
            );

            periodStart = block.timestamp;
            withdrawedAmount = currentAmount;
        }

        SafeTransferLib.safeTransfer(token, owner, amount);
        emit Withdrawal(address(token), owner, amount);
    }
}
