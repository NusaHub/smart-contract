// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import {ProgressType} from "../enums/ProgressType.sol";

struct Progress {
    string text;
    uint256 amount;
    uint256 proposalId;
}
