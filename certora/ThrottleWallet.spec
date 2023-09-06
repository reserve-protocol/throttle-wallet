using TokenMock as token;

methods {
    function throttledToken() external returns (address) envfree;
    function throttlePeriod() external returns (uint256) envfree;
    function amountPerPeriod() external returns (uint256) envfree;
    function timelockDuration() external returns (uint256) envfree;
    function nextNonce() external returns (uint256) envfree;
    function pendingWithdrawals(uint256) external returns (uint256, address, uint256, ThrottleWallet.WithdrawalStatus) envfree;
    function lastWithdrawalAt() external returns (uint256) envfree;
    function lastRemainingLimit() external returns (uint256) envfree;
    function totalPending() external returns (uint256) envfree;
    function admin() external returns (address) envfree;
    function user()  external returns (address) envfree;
    function token.balanceOf(address) external returns (uint256) envfree;
    function _.balanceOf(address) external => DISPATCHER(true);
    function _.transfer(address, uint256) external => DISPATCHER(true);
}

definition fourWeeksInSeconds() returns uint256 = 4 * 7 * 24 * 60 * 60;

// --- function-specific rules ---

rule check_constants() {
    assert throttledToken() == 0x320623b8E4fF03373931769A31Fc52A4E78B5d70, "throttledToken value incorrect";
    assert throttlePeriod() == fourWeeksInSeconds(), "throttlePeriod value incorrect";
    assert amountPerPeriod() == 10^27, "amountPerPeriod value incorrect";
    assert timelockDuration() == fourWeeksInSeconds(), "timelockDuration value incorrect";
}

rule availableToWithdraw() {
    env e;

    mathint timeDelta = e.block.timestamp - lastWithdrawalAt();
    mathint unlimitedAccumulatedAmount = timeDelta * amountPerPeriod() / throttlePeriod() + lastRemainingLimit();
    mathint expectedAccumulatedWithdrawalAmount = unlimitedAccumulatedAmount > to_mathint(amountPerPeriod()) ? amountPerPeriod() : unlimitedAccumulatedAmount;

    mathint accumulatedWithdrawalAmount = availableToWithdraw(e);

    assert accumulatedWithdrawalAmount == expectedAccumulatedWithdrawalAmount, "availableToWithdraw returned the wrong value";
}

rule availableToWithdraw_revert() {
    env e;

    mathint timeSinceLastWithdrawal = e.block.timestamp - lastWithdrawalAt();
    mathint product = timeSinceLastWithdrawal * amountPerPeriod();
    mathint unlimitedAccumulatedAmount = product / throttlePeriod() + lastRemainingLimit();

    availableToWithdraw@withrevert(e);

    bool revert1 = e.msg.value > 0;
    bool revert2 = timeSinceLastWithdrawal < 0;
    bool revert3 = product > max_uint256;
    bool revert4 = unlimitedAccumulatedAmount > max_uint256;
    assert revert1 => lastReverted, "revert1 falied";
    assert revert2 => lastReverted, "revert2 failed";
    assert revert3 => lastReverted, "revert3 failed";
    assert revert4 => lastReverted, "revert4 falied";
    assert lastReverted => revert1 || revert2 || revert3 || revert4, "not all reversion cases are covered";
}

rule initiateWithdrawal(uint256 amount, address target) {
    env e;

    mathint nextNonceBefore = nextNonce();
    mathint totalPendingBefore = totalPending();
    mathint accumulatedWithdrawalAmountBefore = availableToWithdraw(e);

    address adminBefore = admin();
    address userBefore  = user();
    uint256 otherNonce;
    require otherNonce != assert_uint256(nextNonceBefore);
    uint256 amountOtherNonceBefore;
    address targetOtherNonceBefore;
    uint256 unlockTimeOtherNonceBefore;
    ThrottleWallet.WithdrawalStatus statusOtherNonceBefore;
    amountOtherNonceBefore, targetOtherNonceBefore, unlockTimeOtherNonceBefore, statusOtherNonceBefore = pendingWithdrawals(otherNonce);

    initiateWithdrawal(e, amount, target);

    mathint accumulatedWithdrawalAmountAfter = availableToWithdraw(e);

    assert lastWithdrawalAt() == e.block.timestamp, "initiateWithdrawal did not update lastWithdrawalAt as expected";
    assert to_mathint(nextNonce()) == nextNonceBefore + 1, "initiateWithdrawal did not update nextNonce as expected";
    assert to_mathint(totalPending()) == totalPendingBefore + amount, "initiateWithdrawal did not update totalPending as expected";
    assert to_mathint(lastRemainingLimit()) == accumulatedWithdrawalAmountBefore - amount, "initiateWithdrawal did not update lastRemainingLimit as expected";
    assert accumulatedWithdrawalAmountAfter == accumulatedWithdrawalAmountBefore - amount, "accumulatedWithdrawalAmount() return value did not decrease as expected after initiateWithdrawal";
    uint256 amountNonceAfter;
    address targetNonceAfter;
    uint256 unlockTimeNonceAfter;
    ThrottleWallet.WithdrawalStatus statusNonceAfter;
    amountNonceAfter, targetNonceAfter, unlockTimeNonceAfter, statusNonceAfter = pendingWithdrawals(assert_uint256(nextNonceBefore));
    assert amountNonceAfter == amount, "initiateWithdrawal did not set the withdrawal amount correctly";
    assert targetNonceAfter == target, "initiateWithdrawal did not set the withdrawal target correctly";
    assert unlockTimeNonceAfter == assert_uint256(e.block.timestamp + timelockDuration()), "initiateWithdrawal did not set the withdrawal unlock time correctly";
    assert statusNonceAfter == ThrottleWallet.WithdrawalStatus.Pending, "initiateWithdrawal did not set the withdrawal status correctly";

    // checks for preserved values
    assert admin() == adminBefore, "initiateWithdrawal changed admin unexpectedly";
    assert user()  == userBefore, "initiateWithdrawal changed user unexpectedly";
    uint256 amountOtherNonceAfter;
    address targetOtherNonceAfter;
    uint256 unlockTimeOtherNonceAfter;
    ThrottleWallet.WithdrawalStatus statusOtherNonceAfter;
    amountOtherNonceAfter, targetOtherNonceAfter, unlockTimeOtherNonceAfter, statusOtherNonceAfter = pendingWithdrawals(otherNonce);
    assert amountOtherNonceBefore == amountOtherNonceAfter, "initiateWithdrawal changed the amount of another nonce unexpectedly";
    assert targetOtherNonceBefore == targetOtherNonceAfter, "initiateWithdrawal changed the target of another nonce unexpectedly";
    assert unlockTimeOtherNonceBefore == unlockTimeOtherNonceAfter, "initiateWithdrawal changed the unlockTime of another nonce unexpectedly";
    assert statusOtherNonceBefore == statusOtherNonceAfter, "initiateWithdrawal changed the status of another nonce unexpectedly";
}

rule initiateWithdrawal_revert(uint256 amount, address target) {
    require throttledToken() == token;

    address user_ = user();
    mathint tokenBalance = token.balanceOf(currentContract);
    mathint totalPending_ = totalPending();
    mathint nonce = nextNonce();
    mathint timelockDuration_ = timelockDuration();

    env e;

    mathint timeSinceLastWithdrawal = e.block.timestamp - lastWithdrawalAt();
    mathint product = timeSinceLastWithdrawal * amountPerPeriod();
    mathint unlimitedAccumulatedWithdrawalAmount = product / throttlePeriod() + lastRemainingLimit();
    mathint accumulatedWithdrawalAmount = unlimitedAccumulatedWithdrawalAmount > to_mathint(amountPerPeriod()) ? amountPerPeriod() : unlimitedAccumulatedWithdrawalAmount;

    initiateWithdrawal@withrevert(e, amount, target);

    bool revert1  = e.msg.value  != 0;
    bool revert2  = e.msg.sender != user_;
    bool revert3  = amount == 0;
    bool revert4  = totalPending_ + amount > max_uint256;
    bool revert5  = tokenBalance < totalPending_ + amount;
    bool revert6  = timeSinceLastWithdrawal < 0;
    bool revert7  = product > max_uint256;
    bool revert8  = unlimitedAccumulatedWithdrawalAmount > max_uint256;
    bool revert9  = accumulatedWithdrawalAmount < to_mathint(amount);
    bool revert10 = nonce == max_uint256;
    bool revert11 = e.block.timestamp + timelockDuration_ > max_uint256;
    assert revert1  => lastReverted, "revert1  failed";
    assert revert2  => lastReverted, "revert2  failed";
    assert revert3  => lastReverted, "revert3  failed";
    assert revert4  => lastReverted, "revert4  failed";
    assert revert5  => lastReverted, "revert5  failed";
    assert revert6  => lastReverted, "revert6  failed";
    assert revert7  => lastReverted, "revert7  failed";
    assert revert8  => lastReverted, "revert8  failed";
    assert revert9  => lastReverted, "revert9  failed";
    assert revert10 => lastReverted, "revert10 failed";
    assert revert11 => lastReverted, "revert11 failed";
    assert lastReverted => revert1 || revert2  || revert3   || revert4 ||
                           revert5 || revert6  || revert7   || revert8 ||
                           revert9 || revert10 || revert11, "not all reversion cases are covered";
}

// Technically covered by initiateWithdrawal_revert, but this is a good property to make explicit.
rule single_withdrawal_cannot_exceed_amountPerPeriod(uint256 amount, address target) {
    uint256 amountPerPeriod_ = amountPerPeriod();
    env e;
    initiateWithdrawal@withrevert(e, amount, target);
    assert amount > amountPerPeriod_ => lastReverted, "initiateWithdrawal did not revert when amount > amountPerPeriod";
}

rule completeWithdrawal(uint256 nonce) {
    mathint totalPendingBefore = totalPending();
    address adminBefore = admin();
    address userBefore  = user();
    uint256 lastWithdrawalAtBefore = lastWithdrawalAt();
    uint256 lastRemainingLimitBefore = lastRemainingLimit();
    uint256 nextNonceBefore = nextNonce();
    uint256 amountNonceBefore;
    address targetNonceBefore;
    uint256 unlockTimeNonceBefore;
    ThrottleWallet.WithdrawalStatus statusNonceBefore;  // unused
    amountNonceBefore, targetNonceBefore, unlockTimeNonceBefore, statusNonceBefore = pendingWithdrawals(nonce);
    uint256 otherNonce;
    require otherNonce != nonce;
    uint256 amountOtherNonceBefore;
    address targetOtherNonceBefore;
    uint256 unlockTimeOtherNonceBefore;
    ThrottleWallet.WithdrawalStatus statusOtherNonceBefore;
    amountOtherNonceBefore, targetOtherNonceBefore, unlockTimeOtherNonceBefore, statusOtherNonceBefore = pendingWithdrawals(otherNonce);

    env e;
    completeWithdrawal(e, nonce);

    uint256 amountNonceAfter;
    address targetNonceAfter;
    uint256 unlockTimeNonceAfter;
    ThrottleWallet.WithdrawalStatus statusNonceAfter;
    amountNonceAfter, targetNonceAfter, unlockTimeNonceAfter, statusNonceAfter = pendingWithdrawals(nonce);

    // checks for modified values
    assert to_mathint(totalPending()) == totalPendingBefore - amountNonceBefore, "completeWithdrawal did not update totalPending as expected";
    assert statusNonceAfter == ThrottleWallet.WithdrawalStatus.Completed, "completeWithdrawal did not set the withdrawal status correctly";

    // checks for preserved values
    assert amountNonceAfter == amountNonceBefore, "completeWithdrawal changed the withdrawal amount unexpectedly";
    assert targetNonceAfter == targetNonceBefore, "completeWithdrawal changed the withdrawal target unexpectedly";
    assert unlockTimeNonceAfter == unlockTimeNonceBefore, "completeWithdrawal changed the withdrawal unlock time unexpectedly";
    assert admin() == adminBefore, "completeWithdrawal changed admin unexpectedly";
    assert user()  == userBefore, "completeWithdrawal changed user unexpectedly";
    assert lastWithdrawalAt() == lastWithdrawalAtBefore , "completeWithdrawal changed lastWithdrawalAt unexpectedly";
    assert lastRemainingLimit() == lastRemainingLimitBefore , "completeWithdrawal changed lastRemainingLimit unexpectedly";
    assert nextNonce() == nextNonceBefore, "completeWithdrawal changed nextNonce expectedly";
    uint256 amountOtherNonceAfter;
    address targetOtherNonceAfter;
    uint256 unlockTimeOtherNonceAfter;
    ThrottleWallet.WithdrawalStatus statusOtherNonceAfter;
    amountOtherNonceAfter, targetOtherNonceAfter, unlockTimeOtherNonceAfter, statusOtherNonceAfter = pendingWithdrawals(otherNonce);
    assert amountOtherNonceBefore == amountOtherNonceAfter, "completeWithdrawal changed the amount of another nonce unexpectedly";
    assert targetOtherNonceBefore == targetOtherNonceAfter, "completeWithdrawal changed the target of another nonce unexpectedly";
    assert unlockTimeOtherNonceBefore == unlockTimeOtherNonceAfter, "completeWithdrawal changed the unlockTime of another nonce unexpectedly";
    assert statusOtherNonceBefore == statusOtherNonceAfter, "completeWithdrawal changed the status of another nonce unexpectedly";
}

rule completeWithdrawal_revert(uint256 nonce) {
    require throttledToken() == token;
    uint256 tokenBalance = token.balanceOf(currentContract);
    uint256 nextNonce_ = nextNonce();
    uint256 totalPending_ = totalPending();
    uint256 amount;
    address target;
    uint256 unlockTime;
    ThrottleWallet.WithdrawalStatus status;
    amount, target, unlockTime, status = pendingWithdrawals(nonce);

    env e;
    completeWithdrawal@withrevert(e, nonce);

    bool revert1 = e.msg.value > 0;
    bool revert2 = nonce >= nextNonce_;
    bool revert3 = amount == 0;
    bool revert4 = unlockTime > e.block.timestamp;
    bool revert5 = status != ThrottleWallet.WithdrawalStatus.Pending;
    bool revert6 = totalPending_ < amount;
    bool revert7 = tokenBalance < amount;
    assert revert1 => lastReverted, "revert1  failed";
    assert revert2 => lastReverted, "revert2  failed";
    assert revert3 => lastReverted, "revert3  failed";
    assert revert4 => lastReverted, "revert4  failed";
    assert revert5 => lastReverted, "revert5  failed";
    assert revert6 => lastReverted, "revert6  failed";
    assert revert7 => lastReverted, "revert7  failed";
    assert lastReverted => revert1 || revert2  || revert3   || revert4 ||
                           revert5 || revert6  || revert7, "not all reversion cases are covered";
}

rule cancelWithdrawal(uint256 nonce) {
    mathint totalPendingBefore = totalPending();
    address adminBefore = admin();
    address userBefore  = user();
    uint256 lastWithdrawalAtBefore = lastWithdrawalAt();
    uint256 lastRemainingLimitBefore = lastRemainingLimit();
    uint256 nextNonceBefore = nextNonce();
    uint256 amountNonceBefore;
    address targetNonceBefore;
    uint256 unlockTimeNonceBefore;
    ThrottleWallet.WithdrawalStatus statusNonceBefore;  // unused
    amountNonceBefore, targetNonceBefore, unlockTimeNonceBefore, statusNonceBefore = pendingWithdrawals(nonce);
    uint256 otherNonce;
    require otherNonce != nonce;
    uint256 amountOtherNonceBefore;
    address targetOtherNonceBefore;
    uint256 unlockTimeOtherNonceBefore;
    ThrottleWallet.WithdrawalStatus statusOtherNonceBefore;
    amountOtherNonceBefore, targetOtherNonceBefore, unlockTimeOtherNonceBefore, statusOtherNonceBefore = pendingWithdrawals(otherNonce);

    env e;
    cancelWithdrawal(e, nonce);

    uint256 amountNonceAfter;
    address targetNonceAfter;
    uint256 unlockTimeNonceAfter;
    ThrottleWallet.WithdrawalStatus statusNonceAfter;
    amountNonceAfter, targetNonceAfter, unlockTimeNonceAfter, statusNonceAfter = pendingWithdrawals(nonce);

    // checks for modified values
    assert to_mathint(totalPending()) == totalPendingBefore - amountNonceBefore, "cancelWithdrawal did not update totalPending as expected";
    assert statusNonceAfter == ThrottleWallet.WithdrawalStatus.Cancelled, "cancelWithdrawal did not update withdrawal status as expected";

    // checks for preserved values
    assert amountNonceAfter == amountNonceBefore, "cancelWithdrawal changed the withdrawal amount unexpectedly";
    assert targetNonceAfter == targetNonceBefore, "cancelWithdrawal changed the withdrawal target unexpectedly";
    assert unlockTimeNonceAfter == unlockTimeNonceBefore, "cancelWithdrawal changed the withdrawal unlock time unexpectedly";
    assert admin() == adminBefore, "cancelWithdrawal changed admin unexpectedly";
    assert user()  == userBefore, "cancelWithdrawal changed user unexpectedly";
    assert lastWithdrawalAt() == lastWithdrawalAtBefore , "cancelWithdrawal changed lastWithdrawalAt unexpectedly";
    assert lastRemainingLimit() == lastRemainingLimitBefore , "cancelWithdrawal changed lastRemainingLimit unexpectedly";
    assert nextNonce() == nextNonceBefore, "cancelWithdrawal changed nextNonce expectedly";
    uint256 amountOtherNonceAfter;
    address targetOtherNonceAfter;
    uint256 unlockTimeOtherNonceAfter;
    ThrottleWallet.WithdrawalStatus statusOtherNonceAfter;
    amountOtherNonceAfter, targetOtherNonceAfter, unlockTimeOtherNonceAfter, statusOtherNonceAfter = pendingWithdrawals(otherNonce);
    assert amountOtherNonceBefore == amountOtherNonceAfter, "cancelWithdrawal changed the amount of another nonce unexpectedly";
    assert targetOtherNonceBefore == targetOtherNonceAfter, "cancelWithdrawal changed the target of another nonce unexpectedly";
    assert unlockTimeOtherNonceBefore == unlockTimeOtherNonceAfter, "cancelWithdrawal changed the unlockTime of another nonce unexpectedly";
    assert statusOtherNonceBefore == statusOtherNonceAfter, "cancelWithdrawal changed the status of another nonce unexpectedly";
}

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
    assert lastWithdrawalAtBefore == lastWithdrawalAt(), "changeUser changed lastWithdrawalAt unexpectedly";
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
    assert lastWithdrawalAtBefore == lastWithdrawalAt(), "renounceAdmin changed lastWithdrawalAt unexpectedly";
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
// simply revert when admin is the zero address.
rule renouncing_ownership_is_final_and_makes_user_immutable(method f) {
    env e;
    calldataarg args;

    require admin() == 0;  // using this as definition of "ownership renounced"; covered by renounceAdmin rule
    require e.msg.sender != 0;  // exclude the 0 address as a valid sender
    address userBefore = user();

    f(e, args);
    assert admin() == 0, "admin changed after being renounced";
    assert user() == userBefore, "user changed after admin renounced";
}

invariant lastRemainingLimit_bounded_by_amountPerPeriod()
    lastRemainingLimit() < amountPerPeriod();
