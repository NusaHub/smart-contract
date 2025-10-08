// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract IDRX is ERC20 {
    //
    constructor() ERC20("IDRX", "IDRX") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
    //
}
