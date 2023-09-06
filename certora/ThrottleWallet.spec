methods {
    function nextNonce() external returns (uint256) envfree;
    function pendingWithdrawals(uint256) external returns (uint256, address, uint256, ThrottleWallet.WithdrawalStatus) envfree;
    function lastWithdrawalAt() external returns (uint256) envfree;
    function lastRemainingLimit() external returns (uint256) envfree;
    function totalPending() external returns (uint256) envfree;
    function admin() external returns (address) envfree;
    function user()  external returns (address) envfree;
}

// --- function-specific rules ---

rule changeUser(address newUser) {
    env e;

    address adminBefore = admin();
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

    changeUser(e, newUser);

    assert user() == newUser, "changeUser did not set user correctly";
    assert admin() == adminBefore, "changeUser changed admin unexpectedly";
    assert nextNonceBefore == nextNonce(), "changeUser changed nextNonce unexpectedly";
    uint256 amountAfter;
    address targetAfter;
    uint256 unlockTimeAfter;
    ThrottleWallet.WithdrawalStatus statusAfter;
    amountAfter, targetAfter, unlockTimeAfter, statusAfter = pendingWithdrawals(anyUint256);
    assert amountBefore == amountAfter, "changeUser changed some withdrawal amount unexpectedly";
    assert targetBefore == targetAfter, "changeUser changed some withdrawal target unexpectedly";
    assert unlockTimeBefore == unlockTimeAfter, "changeUser changed some withdrawal unlockTime unexpectedly";
    assert statusBefore == statusAfter, "changeUser changed some withdrawal status unexpectedly";
    assert lastWithdrawalAtBefore == lastWithdrawalAt(), "changeUser changed lastWithdrawal unexpectedly";
    assert lastRemainingLimitBefore == lastRemainingLimit(), "changeUser changed lastRemainingLimit unexpectedly";
    assert totalPendingBefore == totalPending(), "changeUser changed totalPending unexpectedly";
}

rule changeUser_revert(address newUser) {
    env e;

    address adminBefore = admin();
    address userBefore  = user();

    changeUser@withrevert(e, newUser);

    bool revert1 = e.msg.value > 0;
    bool revert2 = e.msg.sender != adminBefore;
    bool revert3 = newUser == userBefore;
    assert revert1 => lastReverted, "revert1 failed";
    assert revert2 => lastReverted, "revert2 failed";
    assert revert3 => lastReverted, "revert3 failed";
    assert lastReverted => revert1 || revert2 || revert3, "not all reversion cases are covered";
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

    assert admin() == 0, "renounceAdmin did not set admin to address(0)";
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

// --- multi-function properties ---

// Note: this fails when sanity checking rules is enabled because some functions
// simply revert when admin is the zero address (and the fallback function reverts always).
rule renouncing_ownership_is_final_and_makes_user_immutable(method f) filtered {
    f -> !f.isFallback
} {
    env e;
    calldataarg args;

    require admin() == 0;  // using this as definition of "ownership renounced"
    require e.msg.sender != 0;  // exclude the 0 address as a valid sender
    address userBefore = user();

    f(e, args);

    assert admin() == 0, "admin changed after being renounced";
    assert user() == userBefore, "user changed after admin renounced";
}
