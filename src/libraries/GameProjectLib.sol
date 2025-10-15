// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import {PaymentToken} from "../enums/PaymentToken.sol";
import {GameProject} from "../structs/GameProject.sol";
import {ProjectMilestone} from "../structs/ProjectMilestone.sol";

library GameProjectLib {
    //
    function addToProject(
        mapping(uint256 => GameProject) storage __project,
        uint256 __projectId,
        string memory __projectName,
        PaymentToken __paymentToken,
        address __token,
        uint256 __fundingGoal,
        uint256[] memory __timestamps,
        string[] memory __targets,
        address __owner
    ) internal {
        __project[__projectId] = GameProject({
            name: __projectName,
            token: __token,
            paymentToken: __paymentToken,
            fundingGoal: __fundingGoal,
            fundRaised: 0,
            owner: __owner,
            milestone: ProjectMilestone({
                timestamps: __timestamps,
                targets: __targets
            })
        });
    }
    //
}
