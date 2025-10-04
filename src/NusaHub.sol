// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import {Project} from "./token/Project.sol";
import {USDT} from "./token/USDT.sol";
import {IDRX} from "./token/IDRX.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract NusaHub is Ownable {
    //
    using SafeERC20 for IERC20;

    address private _idrx;
    address private _usdt;

    mapping(address => string) private _identities;
    mapping(uint256 => mapping(uint256 => bool)) private _milestoneStatus;

    mapping(uint256 => GameProject) private _project;
    mapping(uint256 => mapping(address => Funding[])) private _fundings;
    // mapping(uint256 => mapping(address => Allocation)) private _allocations;

    enum PaymentToken {
        USDT,
        IDRX
    }

    struct Funding {
        PaymentToken token;
        uint256 amount;
        uint256 timestamp;
        uint256 percentage;
    }

    // struct Allocation {
    //     uint256 percentage;
    //     uint256 milestoneStart;
    //     uint256 currentMilestone;
    // }

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
        uint256[] timestamps;
        string[] targets;
    }

    constructor(address __owner) Ownable(__owner) {
        IDRX idrx = new IDRX();
        USDT usdt = new USDT();

        _idrx = address(idrx);
        _usdt = address(usdt);
    }

    function verifyIdentity(string memory __hash) external {
        _identities[_getMsgSender()] = __hash;
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
            _getMsgSender()
        );

        _addToProject(
            __projectId,
            __projectName,
            tokenAddress,
            __fundingGoal,
            __timestamps,
            __targets,
            _getMsgSender()
        );
    }

    function fundProject(
        uint256 __projectId,
        uint256 __fundAmount,
        PaymentToken __token
    ) external {
        address projectToken = _project[__projectId].token;

        _transferFundsToken(__fundAmount, __token);
        _transferProjectToken(__fundAmount, projectToken, _getMsgSender());
        _addFundings(__projectId, __fundAmount, __token, _getMsgSender());
    }

    function updateProgress(uint256 __projectId, uint256 __a) external {}

    function withdrawFunds(uint256 __projectId) external {}

    function cashOut(uint256 __projectId, uint256 __amount) external {}

    function getProject(
        uint256 __projectId
    ) external view returns (GameProject memory) {
        return _project[__projectId];
    }

    function getFundingByUser(
        uint256 __projectId,
        address __user
    ) external view returns (Funding[] memory) {
        return _fundings[__projectId][__user];
    }

    function getIdentity(address __user) external view returns (string memory) {
        return _identities[__user];
    }

    function _generateProjectToken(
        string memory __name,
        string memory __symbol,
        uint256 __amount,
        address __owner
    ) private returns (address) {
        Project token = new Project(__name, __symbol, __amount, __owner);
        return address(token);
    }

    function _transferProjectToken(
        uint256 __fundAmount,
        address __projectToken,
        address __receiver
    ) private {
        IERC20(__projectToken).safeTransferFrom(
            address(this),
            __receiver,
            __fundAmount
        );
    }

    function _transferFundsToken(
        uint256 __fundAmount,
        PaymentToken __token
    ) private {
        address paymentToken = _getPaymentTokenAddress(__token);
        IERC20(paymentToken).safeTransfer(address(this), __fundAmount);
    }

    function _addFundings(
        uint256 __projectId,
        uint256 __fundAmount,
        PaymentToken __token,
        address __funder
    ) private {
        uint256 percentage = _calculatePercentage(
            __projectId,
            _getBlockTimestamp(),
            __fundAmount
        );

        _fundings[__projectId][__funder].push(
            Funding({
                token: __token,
                amount: __fundAmount,
                timestamp: _getBlockTimestamp(),
                percentage: percentage
            })
        );
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
            milestone: Milestone({timestamps: __timestamps, targets: __targets})
        });
    }

    function _calculatePercentage(
        uint256 __projectId,
        uint256 __timestamp,
        uint256 __fundAmount
    ) private view returns (uint256) {
        GameProject memory project = _project[__projectId];

        uint256[] memory timestamps = project.milestone.timestamps;
        uint256 totalMilestone = timestamps.length;
        uint256 currentMilestone = 0;

        for (uint256 i = 0; i < timestamps.length; i++) {
            if (__timestamp < timestamps[i]) {
                if (!_milestoneStatus[__projectId][i]) {
                    currentMilestone = i;
                    break;
                }
            }
        }

        uint256 percentage = __fundAmount / (totalMilestone - currentMilestone);

        return percentage;
    }

    function _getPaymentTokenAddress(
        PaymentToken __token
    ) private view returns (address) {
        return uint16(__token) == 0 ? address(_usdt) : address(_idrx);
    }

    function _getBlockTimestamp() private view returns (uint256) {
        return block.timestamp;
    }

    function _getMsgSender() private view returns (address) {
        return msg.sender;
    }
    //
}
