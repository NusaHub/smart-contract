// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20VotesUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";

contract NUSA is
    Initializable,
    ERC20Upgradeable,
    ERC20VotesUpgradeable,
    ERC20PermitUpgradeable,
    UUPSUpgradeable
{
    //
    mapping(address => string) private _identities;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function _authorizeUpgrade(address newImplementation) internal override {}

    function initialize(
        string memory __name,
        string memory __symbol,
        uint256 __amount
    ) public initializer {
        __ERC20_init(__name, __symbol);
        __ERC20Permit_init(__name);
        __UUPSUpgradeable_init();
        _mint(msg.sender, __amount * (10 ** decimals()));
    }

    function delegate(string memory __hash) external {
        super.delegate(_msgSender());
        _identities[_msgSender()] = __hash;
    }

    function getIdentity(address __user) external view returns (string memory) {
        return _identities[__user];
    }

    function _update(
        address _from,
        address _to,
        uint256 _amount
    ) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        super._update(_from, _to, _amount);
    }

    function nonces(
        address _owner
    )
        public
        view
        override(ERC20PermitUpgradeable, NoncesUpgradeable)
        returns (uint256)
    {
        return super.nonces(_owner);
    }

    //
}
