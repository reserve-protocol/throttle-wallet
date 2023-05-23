// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "solmate/Ownable.sol";

contract SlowWallet is Ownable {
    uint256 public immutable withdrawPeriod;
    uint256 public withdrawPeriodStart;
    uint256 public withdrawPeriodAmount;

    constructor(uint256 _withdrawPeriod) {
        withdrawPeriod = _withdrawPeriod;
    }

    
}
