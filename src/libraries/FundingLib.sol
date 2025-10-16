// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import {GameProject} from "../structs/GameProject.sol";
import {Funding} from "../structs/Funding.sol";
import {Progress} from "../structs/Progress.sol";
import {ProgressLib} from "../libraries/ProgressLib.sol";
import {PaymentToken} from "../enums/PaymentToken.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {console} from "forge-std/console.sol";

library FundingLib {
    //
    using ProgressLib for mapping(uint256 => mapping(uint256 => bool));
    using SafeERC20 for IERC20;

    function addFundings(
        mapping(uint256 => GameProject) storage __project,
        mapping(uint256 => mapping(address => Funding)) storage __fundings,
        mapping(uint256 => mapping(uint256 => bool)) storage __milestoneStatus,
        mapping(uint256 => mapping(uint256 => uint256))
            storage __fundRaisedPerMilestone,
        uint256 __projectId,
        uint256 __fundAmount,
        address __funder
    ) internal {
        (
            uint256 currentmilestoneTimestampIndex,
            uint256 fundPerMilestone,
            uint256 percentageFundAmount
        ) = calculateFunding(
                __project,
                __milestoneStatus,
                __projectId,
                __fundAmount
            );

        distributeFunding(
            __project,
            __fundRaisedPerMilestone,
            __projectId,
            currentmilestoneTimestampIndex,
            fundPerMilestone
        );

        __project[__projectId].fundRaised += __fundAmount;

        Funding storage funding = __fundings[__projectId][__funder];

        funding.fundPerMilestone += fundPerMilestone;
        funding.percentageFundAmount += percentageFundAmount;
        funding.amount += __fundAmount;
    }

    function calculateFunding(
        mapping(uint256 => GameProject) storage __project,
        mapping(uint256 => mapping(uint256 => bool)) storage __milestoneStatus,
        uint256 __projectId,
        uint256 __fundAmount
    ) private view returns (uint256, uint256, uint256) {
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
    ) private {
        uint256[] memory timestamps = __project[__projectId]
            .milestone
            .timestamps;
        uint256 totalMilestone = timestamps.length;

        for (uint256 j = __currentMilestoneIndex; j < totalMilestone; j++) {
            __fundRaisedPerMilestone[__projectId][j] += __fundPerMilestone;
        }
    }

    function calculateWithdrawAmount(
        uint256 __projectId,
        address __user,
        // uint256 __milestoneTimestampIndex,
        mapping(uint256 => mapping(address => Funding)) storage __fundings,
        uint256 __amount
        // mapping(uint256 => mapping(uint256 => Progress)) storage __progresses
    ) internal view returns (uint256) {
        Funding memory funding = __fundings[__projectId][__user];

        // uint256 amount = __progresses[__projectId][__milestoneTimestampIndex]
        //     .amount;

        return (funding.percentageFundAmount * __amount) / 100;
    }

    function calculateCashOutAmount(
        uint256 __projectId,
        address __user,
        uint256[] storage __timestamps,
        mapping(uint256 => mapping(address => Funding)) storage __fundings,
        mapping(uint256 => GameProject) storage __project,
        mapping(uint256 => mapping(uint256 => bool)) storage __milestoneStatus
    ) internal view returns (uint256) {
        Funding memory funding = __fundings[__projectId][__user];

        uint256 totalMilestone = __project[__projectId]
            .milestone
            .timestamps
            .length;
        uint256 milestoneTimestampIndex = ProgressLib.search(
            __milestoneStatus,
            __projectId,
            __timestamps
        );
        uint256 remainingMilestone = totalMilestone - milestoneTimestampIndex;
        return (funding.fundPerMilestone * remainingMilestone);
    }

    function escrowFundsToken(
        uint256 __fundAmount,
        address __paymentToken,
        address __caller
    ) internal {
        IERC20(__paymentToken).safeTransferFrom(
            __caller,
            address(this),
            __fundAmount
        );
    }

    function transferTokenFromContract(
        uint256 __fundAmount,
        address __token,
        address __receiver
    ) internal {
        IERC20(__token).safeTransfer(__receiver, __fundAmount);
    }
    //
}
