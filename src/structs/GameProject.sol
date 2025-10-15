// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import {PaymentToken} from "../enums/PaymentToken.sol";
import {ProjectMilestone} from "./ProjectMilestone.sol";

struct GameProject {
    string name;
    uint256 fundingGoal;
    PaymentToken paymentToken;
    uint256 fundRaised;
    address owner;
    ProjectMilestone milestone;
}
