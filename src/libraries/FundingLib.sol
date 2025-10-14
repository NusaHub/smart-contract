// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import {GameProject} from "../structs/GameProject.sol";
import {MilestoneLib} from "../libraries/MilestoneLib.sol";
import {PaymentToken} from "../enums/PaymentToken.sol";

library FundingLib {
    //
    using MilestoneLib for mapping(uint256 => mapping(uint256 => bool));

    function calculateFunding(
        mapping(uint256 => GameProject) storage __project,
        mapping(uint256 => mapping(uint256 => bool)) storage __milestoneStatus,
        uint256 __projectId,
        uint256 __fundAmount
    ) internal view returns (uint256, uint256, uint256) {
        GameProject memory project = __project[__projectId];

        uint256 fundingGoal = project.fundingGoal;
        uint256[] memory timestamps = project.milestone.timestamps;
        uint256 totalMilestone = timestamps.length;

        uint256 currentMilestoneTimestampIndex = __milestoneStatus.search(
            __projectId,
            timestamps
        );

        uint256 remainingMilestones = totalMilestone -
            currentMilestoneTimestampIndex;
        uint256 percentagePerMilestone = 100 / remainingMilestones;

        uint256 fundPerMilestone = (__fundAmount * percentagePerMilestone) /
            100;
        uint256 percentageFundAmount = (__fundAmount * 100) / fundingGoal;

        return (
            currentMilestoneTimestampIndex,
            fundPerMilestone,
            percentageFundAmount
        );
    }

    function distributeFunding(
        mapping(uint256 => GameProject) storage __project,
        mapping(uint256 => mapping(uint256 => uint256))
            storage __fundRaisedPerMilestone,
        uint256 __projectId,
        uint256 __currentMilestoneIndex,
        uint256 __fundPerMilestone
    ) internal {
        uint256[] memory timestamps = __project[__projectId]
            .milestone
            .timestamps;
        uint256 totalMilestone = timestamps.length;

        for (uint256 j = __currentMilestoneIndex; j < totalMilestone; j++) {
            __fundRaisedPerMilestone[__projectId][j] += __fundPerMilestone;
        }
    }
    //
}
