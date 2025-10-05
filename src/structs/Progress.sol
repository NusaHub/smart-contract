// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import {ProgressType} from "../enums/ProgressType.sol";

struct Progress {
    ProgressType progressType;
    string text;
    uint256 milestoneIndex;
    uint256 amountIDRX;
    uint256 amountUSDT;
}
