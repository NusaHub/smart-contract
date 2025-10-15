// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import {Payment} from "./Payment.sol";

contract IDRX is Payment {
    //
    constructor() Payment("IDRX", "IDRX") {}
    //
}
