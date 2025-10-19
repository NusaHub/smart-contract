// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

abstract contract Payment is ERC20 {
    //
    constructor(
        string memory __name,
        string memory __symbol
    ) ERC20(__name, __symbol) {}

    function mint(address __to, uint256 __amount) external {
        _mint(__to, __amount);
    }

    function burn(address __user, uint256 __amount) external {
        _burn(__user, __amount);
    }
    //
}
