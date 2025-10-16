// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

library ProgressError {
    //
    error IncompleteMilestone(
        uint256 projectId,
        uint256 milestoneTimestampIndex
    );
    error AlreadyWithdrawn(
        uint256 projectId,
        uint256 milestoneTimestampIndex,
        address investor
    );

    error UnauthorizedGovernor(address governor, address caller);
    //
}
