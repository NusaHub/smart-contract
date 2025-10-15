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
        string memory __symbol
    ) public initializer {
        __ERC20_init(__name, __symbol);
        __ERC20Permit_init(__name);
        __UUPSUpgradeable_init();
    }

    function delegateWithHash(string memory __hash) external {
        super.delegate(_msgSender());
        _identities[_msgSender()] = __hash;
    }

    function getIdentity(address __user) external view returns (string memory) {
        return _identities[__user];
    }

    function mint(address __recipient, uint256 __amount) external {
        _mint(__recipient, __amount);
    }

    function burn(address __user, uint256 __amount) external {
        _burn(__user, __amount);
    }

    function _update(
        address __from,
        address __to,
        uint256 __amount
    ) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        super._update(__from, __to, __amount);
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
