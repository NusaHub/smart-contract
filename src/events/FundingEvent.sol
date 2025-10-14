// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

library FundingEvent {
    //
    event ProjectFunded(
        uint256 indexed projectId,
        address indexed funder,
        uint256 fundAmount,
        uint256 timestamp
    );

    event CashedOut(
        uint256 indexed projectId,
        address indexed funder,
        uint256 amount
    );

    event FundsWithdrawn(
        uint256 indexed projectId,
        address indexed withdrawer,
        uint256 amount
    );
    //
}
