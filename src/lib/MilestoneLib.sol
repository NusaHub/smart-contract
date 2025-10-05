// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

library MilestoneLib {
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
