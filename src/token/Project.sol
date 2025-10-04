// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Project is ERC20, Ownable {
    //
    constructor(
        string memory __name,
        string memory __symbol,
        uint256 __amount,
        address __owner
    ) ERC20(__name, __symbol) Ownable(__owner) {
        _mint(msg.sender, __amount * 10 ** decimals());
    }
    //
}
