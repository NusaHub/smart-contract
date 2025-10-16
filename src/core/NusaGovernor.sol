// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import "./Imports.sol";
import {NusaHub} from "./NusaHub.sol";

contract NusaGovernor is
    Initializable,
    GovernorUpgradeable,
    GovernorSettingsUpgradeable,
    GovernorCountingSimpleUpgradeable,
    GovernorVotesUpgradeable,
    GovernorVotesQuorumFractionUpgradeable,
    UUPSUpgradeable
{
    //
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function _authorizeUpgrade(address newImplementation) internal override {}

    function initialize(IVotes __token) public initializer {
        __Governor_init("NusaHub Governor");
        __GovernorSettings_init(150, 150, 0);
        __GovernorCountingSimple_init();
        __GovernorVotes_init(__token);
        __GovernorVotesQuorumFraction_init(1);
        __UUPSUpgradeable_init();
    }

    function proposalThreshold()
        public
        view
        override(GovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    function proposeProgress(
        address[] memory __targets,
        uint256[] memory __values,
        bytes[] memory __calldatas,
        string memory __description
    ) external returns (uint256) {
        return super.propose(__targets, __values, __calldatas, __description);
    }

    function voteProgress(
        uint256 __proposalId,
        uint8 __vote
    ) external returns (uint256) {
        return super.castVote(__proposalId, __vote);
    }

    //
}
