// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import {Project} from "./token/Project.sol";
import {USDT} from "./token/USDT.sol";
import {IDRX} from "./token/IDRX.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract NusaHub is Ownable {
    //
    address private _idrx;
    address private _usdt;

    mapping(uint256 => GameProject) private _project;
    mapping(address => string) private _identities;
    mapping(uint256 => mapping(uint256 => bool)) private _milestoneStatus;

    struct GameProject {
        string name;
        address token;
        uint256 fundingGoal;
        uint256 fundsRaisedByUSDT;
        uint256 fundsRaisedByIDRX;
        address owner;
        Milestone milestone;
    }

    struct Milestone {
        uint256[] timestamp;
        string[] targets;
    }

    constructor(address __owner) Ownable(__owner) {
        IDRX idrx = new IDRX();
        USDT usdt = new USDT();

        _idrx = address(idrx);
        _usdt = address(usdt);
    }

    function verifyIdentity(string memory __hash) external {
        _identities[msg.sender] = __hash;
    }

    function postProject(
        uint256 __projectId,
        string memory __projectName,
        string memory __projectSymbol,
        uint256 __fundingGoal,
        uint256[] memory __timestamps,
        string[] memory __targets
    ) external {
        address tokenAddress = _generateProjectToken(
            __projectName,
            __projectSymbol,
            __fundingGoal,
            msg.sender
        );
        _addToProject(
            __projectId,
            __projectName,
            tokenAddress,
            __fundingGoal,
            __timestamps,
            __targets,
            msg.sender
        );
    }

    function fundProject(
        uint256 __projectId,
        uint256 __fundAmount,
        address __paymentToken
    ) external {}

    function _generateProjectToken(
        string memory __name,
        string memory __symbol,
        uint256 __amount,
        address __owner
    ) private returns (address) {
        Project token = new Project(__name, __symbol, __amount, __owner);
        return address(token);
    }

    function _addToProject(
        uint256 __projectId,
        string memory __projectName,
        address __token,
        uint256 __fundingGoal,
        uint256[] memory __timestamps,
        string[] memory __targets,
        address __owner
    ) private {
        _project[__projectId] = GameProject({
            name: __projectName,
            token: __token,
            fundingGoal: __fundingGoal,
            fundsRaisedByUSDT: 0,
            fundsRaisedByIDRX: 0,
            owner: __owner,
            milestone: Milestone({timestamp: __timestamps, targets: __targets})
        });
    }
    //
}
