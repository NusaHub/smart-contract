// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import {Progress} from "../structs/Progress.sol";
import {ProgressType} from "../enums/ProgressType.sol";

// import {NusaHub} from "../core/NusaHub.sol";

library ProgressLib {
    //
    // function searchWithTimestamp(
    //     mapping(uint256 => mapping(uint256 => bool)) storage __milestoneStatus,
    //     uint256 projectId,
    //     uint256[] memory timestamps,
    //     uint256 timestamp
    // ) internal view returns (uint256) {
    //     for (uint256 i = 0; i < timestamps.length; i++) {
    //         if (timestamp < timestamps[i] && !__milestoneStatus[projectId][i]) {
    //             return i;
    //         }
    //     }
    //     return timestamps.length - 1;
    // }

    function addProgress(
        mapping(uint256 => mapping(uint256 => Progress)) storage __progresses,
        mapping(uint256 => mapping(uint256 => bool)) storage __milestoneStatus,
        uint256[] storage __timestamps,
        uint256 __projectId,
        ProgressType __type,
        string memory __text,
        uint256 __amount,
        uint256 __proposalId
    ) internal {
        uint256 milestoneTimestampIndex = search(
            __milestoneStatus,
            __projectId,
            __timestamps
        );

        __progresses[__projectId][milestoneTimestampIndex] = Progress({
            progressType: __type,
            text: __text,
            amount: __amount,
            proposalId: __proposalId
        });
    }

    function search(
        mapping(uint256 => mapping(uint256 => bool)) storage __milestoneStatus,
        uint256 projectId,
        uint256[] memory timestamps
    ) internal view returns (uint256) {
        for (uint256 i = 0; i < timestamps.length; i++) {
            if (!__milestoneStatus[projectId][i]) {
                return i;
            }
        }
        return timestamps.length - 1;
    }
    //
}
