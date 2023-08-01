// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

interface ISlowWallet {
    event TransferProposed(
        uint256 index,
        address indexed destination,
        uint256 value,
        uint256 delayUntil,
        string notes
    );
    event TransferConfirmed(
        uint256 index,
        address indexed destination,
        uint256 value,
        string notes
    );
    event TransferCancelled(
        uint256 index,
        address indexed destination,
        uint256 value,
        string notes
    );
    event AllTransfersCancelled();

    function token() external view returns (IERC20);

    function owner() external view returns (address);

    function delay() external view returns (uint256);

    function propose(address destination, uint256 value, string calldata notes) external;

    function cancel(uint256 index, address addr, uint256 value) external;

    function voidAll() external;

    function confirm(uint256 index, address destination, uint256 value) external;
}
