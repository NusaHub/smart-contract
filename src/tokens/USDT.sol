// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import {Payment} from "./Payment.sol";

contract USDT is Payment {
    //
    constructor() Payment("Tether USD", "USDT") {}
    //
}
