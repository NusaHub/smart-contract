// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

struct Funding {
    uint256 amount;
    uint256 timestamp;
    uint256 startMilestone;
    uint256 percentagePerMilestone;
    uint256 percentageFundAmount;
}
