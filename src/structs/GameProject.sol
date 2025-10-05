// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

struct GameProject {
    string name;
    address token;
    address governor;
    uint256 fundingGoal;
    uint256 fundRaisedByIDRX;
    uint256 fundRaisedByUSDT;
    address owner;
    ProjectMilestone milestone;
}

struct ProjectMilestone {
    uint256[] timestamps;
    string[] targets;
}

