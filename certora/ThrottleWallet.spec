methods {
    function nextNonce() external returns (uint256) envfree;
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
    uint256 lastWithdrawalAtBefore = lastWithdrawalAt();
    uint256 lastRemainingLimitBefore = lastRemainingLimit();
    uint256 totalPendingBefore = totalPending();

    renounceAdmin(e);

    address adminAfter = admin();
    assert adminAfter == 0, "renounceAdmin did not set admin to address(0)";
    assert userBefore == user(), "renounceAdmin changed user unexpectedly";
    assert nextNonceBefore == nextNonce(), "renounceAdmin changed nextNonce unexpectedly";
    assert lastWithdrawalAtBefore == lastWithdrawalAt(), "renounceAdmin changed lastWithdrawalBefore unexpectedly";
    assert lastRemainingLimitBefore == lastRemainingLimit(), "renounceAdmin changed lastRemainingLimit unexpectedly";
    assert totalPendingBefore == totalPending(), "renounceAdmin changed totalPending unexpectedly";
}
