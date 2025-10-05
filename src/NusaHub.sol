// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import {ProjectDAO} from "./dao/ProjectDAO.sol";
import {Project} from "./token/Project.sol";
import {USDT} from "./token/USDT.sol";
import {IDRX} from "./token/IDRX.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {FactoryLib} from "./lib/FactoryLib.sol";
import {MilestoneLib} from "./lib/MilestoneLib.sol";
import {FundingLib} from "./lib/FundingLib.sol";
import {Funding} from "./structs/Funding.sol";
import {GameProject, ProjectMilestone} from "./structs/GameProject.sol";
import {Progress} from "./structs/Progress.sol";
import {PaymentToken} from "./enums/PaymentToken.sol";
import {ProgressType} from "./enums/ProgressType.sol";

contract NusaHub is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    //
    using SafeERC20 for IERC20;
    using MilestoneLib for mapping(uint256 => mapping(uint256 => bool));

    address private _idrx;
    address private _usdt;

    mapping(address => string) private _identities;
    mapping(uint256 => mapping(uint256 => bool)) private _milestoneStatus;

    mapping(uint256 => GameProject) private _project;
    mapping(uint256 => mapping(address => mapping(PaymentToken => Funding[])))
        private _fundings;
    mapping(uint256 => mapping(uint256 => mapping(PaymentToken => uint256)))
        private _fundRaisedPerMilestone;
    mapping(uint256 => mapping(uint256 => Progress)) private _progresses;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address __owner) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init(__owner);

        IDRX idrx = new IDRX();
        USDT usdt = new USDT();

        _idrx = address(idrx);
        _usdt = address(usdt);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function verifyIdentity(string memory __hash) external {
        _identities[_msgSender()] = __hash;
    }

    function postProject(
        uint256 __projectId,
        string memory __projectName,
        string memory __projectSymbol,
        uint256 __fundingGoal,
        uint256[] memory __timestamps,
        string[] memory __targets
    ) external {
        address tokenAddress = FactoryLib.generateProjectToken(
            __projectName,
            __projectSymbol,
            __fundingGoal
        );

        address governorAddress = FactoryLib.generateProjectDAO(
            tokenAddress,
            string.concat(__projectName, " DAO")
        );

        _addToProject(
            __projectId,
            __projectName,
            tokenAddress,
            governorAddress,
            __fundingGoal,
            __timestamps,
            __targets,
            _msgSender()
        );
    }

    function fundProject(
        uint256 __projectId,
        uint256 __fundAmount,
        PaymentToken __token
    ) external {
        address projectToken = _project[__projectId].token;

        _addFundings(__projectId, __fundAmount, __token, _msgSender());
        _transferFundsToken(__fundAmount, __token);
        _transferProjectToken(__fundAmount, projectToken, _msgSender());
    }

    function updateProgress(
        uint256 __projectId,
        string memory __text,
        uint256 __amountIDRX,
        uint256 __amountUSDT,
        ProgressType __type,
        address[] memory __targets,
        uint256[] memory __values,
        bytes[] memory __calldatas,
        string memory __description
    ) external {
        _addProgress(__projectId, __type, __text, __amountIDRX, __amountUSDT);

        address payable dao = payable(_project[__projectId].governor);

        uint256 proposalId = ProjectDAO(dao).propose(
            __targets,
            __values,
            __calldatas,
            __description
        );

        // uint256 proposalId = propose();
    }

    function withdrawFundsForDev(uint256 __projectId) external {
        uint256 milestoneIndex = _milestoneStatus.search(
            __projectId,
            _projectTimestamps(__projectId)
        );

        uint256 fundAmountByIDRX = getFundRaisedPerMilestone(
            __projectId,
            milestoneIndex,
            PaymentToken.IDRX
        );
        uint256 fundAmountByUSDT = getFundRaisedPerMilestone(
            __projectId,
            milestoneIndex,
            PaymentToken.USDT
        );

        _milestoneStatus[__projectId][milestoneIndex] = true;

        if (fundAmountByIDRX != 0) {
            // _transferFundsToken(fundAmountByIDRX, PaymentToken.IDRX);
        }

        if (fundAmountByUSDT != 0) {
            // _transferFundsToken(fundAmountByUSDT, PaymentToken.USDT);
        }
    }

    function withdrawFundsForInvestor(uint256 __projectId) external {}

    function cashOut(uint256 __projectId, uint256 __amount) external {}

    function getProject(
        uint256 __projectId
    ) external view returns (GameProject memory) {
        return _project[__projectId];
    }

    function getFundingByUser(
        uint256 __projectId,
        address __user,
        PaymentToken __token
    ) external view returns (Funding[] memory) {
        return _fundings[__projectId][__user][__token];
    }

    function getIdentity(address __user) external view returns (string memory) {
        return _identities[__user];
    }

    function getFundRaisedPerMilestone(
        uint256 __projectId,
        uint256 __milestoneIndex,
        PaymentToken __token
    ) public view returns (uint256) {
        return _fundRaisedPerMilestone[__projectId][__milestoneIndex][__token];
    }

    function _msgSender()
        internal
        view
        override(ContextUpgradeable)
        returns (address)
    {
        return super._msgSender();
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
        (
            uint256 currentMilestoneIndex,
            uint256 percentagePerMilestone,
            uint256 fundPerMilestone,
            uint256 percentageFundAmount
        ) = FundingLib.calculateFunding(
                _project,
                _milestoneStatus,
                __projectId,
                __fundAmount
            );

        FundingLib.distributeFunding(
            _project,
            _fundRaisedPerMilestone,
            __projectId,
            currentMilestoneIndex,
            fundPerMilestone,
            __token
        );

        _fundings[__projectId][__funder][__token].push(
            Funding({
                amount: __fundAmount,
                timestamp: _blockTimestamp(),
                startMilestone: currentMilestoneIndex,
                percentagePerMilestone: percentagePerMilestone,
                percentageFundAmount: percentageFundAmount
            })
        );

        __token == PaymentToken.IDRX
            ? _project[__projectId].fundRaisedByIDRX += __fundAmount
            : _project[__projectId].fundRaisedByUSDT += __fundAmount;
    }

    function _addToProject(
        uint256 __projectId,
        string memory __projectName,
        address __token,
        address __governor,
        uint256 __fundingGoal,
        uint256[] memory __timestamps,
        string[] memory __targets,
        address __owner
    ) private {
        _project[__projectId] = GameProject({
            name: __projectName,
            token: __token,
            governor: __governor,
            fundingGoal: __fundingGoal,
            fundRaisedByIDRX: 0,
            fundRaisedByUSDT: 0,
            owner: __owner,
            milestone: ProjectMilestone({
                timestamps: __timestamps,
                targets: __targets
            })
        });
    }

    function _addProgress(
        uint256 __projectId,
        ProgressType __type,
        string memory __text,
        uint256 __amountIDRX,
        uint256 __amountUSDT
    ) private {
        uint256 milestoneTimestampIndex = _milestoneStatus.search(
            __projectId,
            _projectTimestamps(__projectId)
        );

        _progresses[__projectId][milestoneTimestampIndex] = Progress({
            progressType: __type,
            text: __text,
            milestoneIndex: milestoneTimestampIndex,
            amountIDRX: __amountIDRX,
            amountUSDT: __amountUSDT
        });
    }

    function _getPaymentTokenAddress(
        PaymentToken __token
    ) private view returns (address) {
        return uint16(__token) == 0 ? address(_usdt) : address(_idrx);
    }

    function _blockTimestamp() private view returns (uint256) {
        return block.timestamp;
    }

    function _projectTimestamps(
        uint256 __projectId
    ) private view returns (uint256[] memory) {
        return _project[__projectId].milestone.timestamps;
    }
    //
}
