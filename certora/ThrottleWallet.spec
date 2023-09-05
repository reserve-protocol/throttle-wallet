methods {
    function nextNonce() external returns (uint256) envfree;
    function pendingWithdrawals(uint256) external returns (uint256, address, uint256, ThrottleWallet.WithdrawalStatus) envfree;
    function lastWithdrawalAt() external returns (uint256) envfree;
    function lastRemainingLimit() external returns (uint256) envfree;
    function totalPending() external returns (uint256) envfree;
    function admin() external returns (address) envfree;
    function user()  external returns (address) envfree;
}

rule renounceAdmin() {
    env e;

    address userBefore = user();
    uint256 nextNonceBefore = nextNonce();
    uint256 anyUint256;
    uint256 amountBefore;
    address targetBefore;
    uint256 unlockTimeBefore;
    ThrottleWallet.WithdrawalStatus statusBefore;
    amountBefore, targetBefore, unlockTimeBefore, statusBefore = pendingWithdrawals(anyUint256);
    uint256 lastWithdrawalAtBefore = lastWithdrawalAt();
    uint256 lastRemainingLimitBefore = lastRemainingLimit();
    uint256 totalPendingBefore = totalPending();

    renounceAdmin(e);

    address adminAfter = admin();
    assert adminAfter == 0, "renounceAdmin did not set admin to address(0)";
    assert userBefore == user(), "renounceAdmin changed user unexpectedly";
    assert nextNonceBefore == nextNonce(), "renounceAdmin changed nextNonce unexpectedly";
    uint256 amountAfter;
    address targetAfter;
    uint256 unlockTimeAfter;
    ThrottleWallet.WithdrawalStatus statusAfter;
    amountAfter, targetAfter, unlockTimeAfter, statusAfter = pendingWithdrawals(anyUint256);
    assert amountBefore == amountAfter, "renounceAdmin changed some withdrawal amount unexpectedly";
    assert targetBefore == targetAfter, "renounceAdmin changed some withdrawal target unexpectedly";
    assert unlockTimeBefore == unlockTimeAfter, "renounceAdmin changed some withdrawal unlockTime unexpectedly";
    assert statusBefore == statusAfter, "renounceAdmin changed some withdrawal status unexpectedly";
    assert lastWithdrawalAtBefore == lastWithdrawalAt(), "renounceAdmin changed lastWithdrawal unexpectedly";
    assert lastRemainingLimitBefore == lastRemainingLimit(), "renounceAdmin changed lastRemainingLimit unexpectedly";
    assert totalPendingBefore == totalPending(), "renounceAdmin changed totalPending unexpectedly";
}

rule renounceAdmin_revert() {
    env e;

    address adminBefore = admin();

    renounceAdmin@withrevert(e);

    bool revert1 = e.msg.value > 0;
    bool revert2 = e.msg.sender != adminBefore;

    assert revert1 => lastReverted, "revert1 falied";
    assert revert2 => lastReverted, "revert2 failed";
    assert lastReverted => revert1 || revert2, "not all reversion cases are covered";
}
