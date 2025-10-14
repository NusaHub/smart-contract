// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

library ProgressEvent {
    //
    event ProgressUpdated(
        uint256 indexed projectId,
        uint256 amount,
        uint256 proposalId,
        uint256 timestamp
    );
    event ProgressProcessed(uint256 projectId);
    event VoteCasted(uint256 projectId, uint8 vote);
    //
}
