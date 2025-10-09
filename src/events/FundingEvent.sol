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
    //
}