// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import "./Imports.sol";

// import {NusaGovernor} from "./NusaGovernor.sol";

contract NusaHub is Initializable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    //
    using SafeERC20 for IERC20;
    using ProgressLib for mapping(uint256 => mapping(uint256 => bool));

    address private _nusa;
    address private _governor;

    mapping(PaymentToken => address) private _paymentToken;
    mapping(uint256 => GameProject) private _project;
    mapping(uint256 => mapping(address => Funding)) private _fundings;
    mapping(uint256 => mapping(uint256 => Progress)) private _progresses;

    mapping(uint256 => mapping(address => bool)) private _investorStatus;
    mapping(uint256 => mapping(uint256 => bool)) private _milestoneStatus;
    mapping(uint256 => mapping(uint256 => mapping(address => bool)))
        private _hasWithdrawn;
    mapping(uint256 => mapping(uint256 => uint256))
        private _fundRaisedPerMilestone;

    modifier onlyGovernance(address __caller) {
        require(
            __caller == _governor,
            ProgressError.UnauthorizedGovernor(_governor, __caller)
        );
        _;
    }

    modifier onlyNonRegisteredProject(uint256 __projectId) {
        GameProject memory project = _project[__projectId];
        require(
            project.fundingGoal == 0,
            GameProjectError.GameProjectAlreadyRegistered(__projectId)
        );
        _;
    }

    modifier onlyRegisteredProject(uint256 __projectId) {
        GameProject memory project = _project[__projectId];
        require(
            project.fundingGoal != 0,
            GameProjectError.GameProjectNotRegistered()
        );
        _;
    }

    modifier onlyProjectCreator(uint256 __projectId, address __caller) {
        GameProject memory project = _project[__projectId];
        require(
            project.owner == __caller,
            GameProjectError.UnauthorizedCaller(__projectId, __caller)
        );
        _;
    }

    modifier onlyProjectInvestor(uint256 __projectId, address __caller) {
        bool investorStatus = _investorStatus[__projectId][__caller];
        require(
            investorStatus,
            GameProjectError.UnauthorizedCaller(__projectId, __caller)
        );
        _;
    }

    modifier onlyIfMilestoneDone(
        uint256 __projectId,
        uint256 __milestoneTimestampIndex
    ) {
        bool milestoneStatus = _milestoneStatus[__projectId][
            __milestoneTimestampIndex
        ];
        require(
            milestoneStatus,
            ProgressError.IncompleteMilestone(
                __projectId,
                __milestoneTimestampIndex
            )
        );
        _;
    }

    modifier onlyOnceWithdraw(
        uint256 __projectId,
        uint256 __milestoneTimestampIndex,
        address __caller
    ) {
        bool withdrawStatus = _hasWithdrawn[__projectId][
            __milestoneTimestampIndex
        ][__caller];
        require(
            !withdrawStatus,
            ProgressError.AlreadyWithdrawn(
                __projectId,
                __milestoneTimestampIndex,
                __caller
            )
        );
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address __idrx,
        address __usdt,
        address __token,
        address __governor
    ) public initializer {
        __UUPSUpgradeable_init();

        _paymentToken[PaymentToken.IDRX] = __idrx;
        _paymentToken[PaymentToken.USDT] = __usdt;

        _nusa = address(__token);
        _governor = __governor;
    }

    function _authorizeUpgrade(address newImplementation) internal override {}

    function postProject(
        uint256 __projectId,
        string calldata __projectName,
        uint8 __paymentToken,
        uint256 __fundingGoal,
        uint256[] calldata __timestamps,
        string[] calldata __targets
    ) external onlyNonRegisteredProject(__projectId) {
        GameProjectLib.addToProject(
            _project,
            __projectId,
            __projectName,
            PaymentToken(__paymentToken),
            __fundingGoal,
            __timestamps,
            __targets,
            _msgSender()
        );

        emit GameProjectEvent.ProjectPosted(
            __projectId,
            _msgSender(),
            __projectName,
            __fundingGoal
        );
    }

    function fundProject(
        uint256 __projectId,
        uint256 __fundAmount
    ) external onlyRegisteredProject(__projectId) {
        FundingLib.addFundings(
            _project,
            _fundings,
            _milestoneStatus,
            _fundRaisedPerMilestone,
            __projectId,
            __fundAmount,
            _msgSender()
        );

        FundingLib.escrowFundsToken(
            __fundAmount,
            _projectPaymentToken(__projectId),
            _msgSender()
        );

        _mintNusa(_msgSender(), __fundAmount);

        _investorStatus[__projectId][_msgSender()] = true;

        emit FundingEvent.ProjectFunded(
            __projectId,
            _msgSender(),
            __fundAmount,
            _blockTimestamp()
        );
    }

    function updateProgress(
        uint256 __projectId,
        uint256 __amount,
        uint256 __proposalId,
        string memory __description
    )
        external
        onlyRegisteredProject(__projectId)
        onlyProjectCreator(__projectId, _msgSender())
    {
        ProgressLib.addProgress(
            _progresses,
            _milestoneStatus,
            _projectTimestamps(__projectId),
            __projectId,
            __description,
            __amount,
            __proposalId
        );

        if (__amount != 0) {
            FundingLib.escrowFundsToken(
                __amount,
                _projectPaymentToken(__projectId),
                _msgSender()
            );
        }

        emit ProgressEvent.ProgressUpdated(
            __projectId,
            __amount,
            __proposalId,
            _blockTimestamp()
        );
    }

    function processProgress(
        uint256 __projectId
    ) external onlyGovernance(_msgSender()) {
        _withdrawFundsForDev(__projectId);

        emit ProgressEvent.ProgressProcessed(__projectId);
    }

    function withdrawFundsForInvestor(
        uint256 __projectId,
        uint256 __milestoneTimestampIndex
    )
        external
        onlyRegisteredProject(__projectId)
        onlyIfMilestoneDone(__projectId, __milestoneTimestampIndex)
        onlyProjectInvestor(__projectId, _msgSender())
        onlyOnceWithdraw(__projectId, __milestoneTimestampIndex, _msgSender())
    {
        uint256 fundAmount = _progresses[__projectId][__milestoneTimestampIndex]
            .amount;

        uint256 withdrawAmount = FundingLib.calculateWithdrawAmount(
            __projectId,
            _msgSender(),
            _fundings,
            fundAmount
        );

        FundingLib.transferTokenFromContract(
            withdrawAmount,
            _projectPaymentToken(__projectId),
            _msgSender()
        );

        _burnNusa(_msgSender(), withdrawAmount);

        _hasWithdrawn[__projectId][__milestoneTimestampIndex][
            _msgSender()
        ] = true;

        emit FundingEvent.FundsWithdrawn(
            __projectId,
            _msgSender(),
            withdrawAmount
        );
    }

    function cashOut(
        uint256 __projectId
    )
        external
        onlyRegisteredProject(__projectId)
        onlyProjectInvestor(__projectId, _msgSender())
    {
        uint256 cashOutAmount = FundingLib.calculateCashOutAmount(
            __projectId,
            _msgSender(),
            _projectTimestamps(__projectId),
            _fundings,
            _project,
            _milestoneStatus
        );

        FundingLib.transferTokenFromContract(
            cashOutAmount,
            _projectPaymentToken(__projectId),
            _msgSender()
        );

        _burnNusa(_msgSender(), cashOutAmount);

        _investorStatus[__projectId][_msgSender()] = false;

        emit FundingEvent.CashedOut(__projectId, _msgSender(), cashOutAmount);
    }

    function getProject(
        uint256 __projectId
    ) external view returns (GameProject memory) {
        return _project[__projectId];
    }

    function getFundingByUser(
        uint256 __projectId,
        address __user
    ) external view returns (Funding memory) {
        return _fundings[__projectId][__user];
    }

    function getInvestorStatus(
        uint256 __projectId,
        address __user
    ) external view returns (bool) {
        return _investorStatus[__projectId][__user];
    }

    function getMilestoneStatus(
        uint256 __projectId,
        uint256 __milestoneTimestampIndex
    ) external view returns (bool) {
        return _milestoneStatus[__projectId][__milestoneTimestampIndex];
    }

    function hasWithdrawnStatus(
        uint256 __projectId,
        uint256 __milestoneTimestampIndex,
        address __user
    ) external view returns (bool) {
        return _hasWithdrawn[__projectId][__milestoneTimestampIndex][__user];
    }

    function getFundRaisedPerMilestone(
        uint256 __projectId,
        uint256 __milestoneTimestampIndex
    ) public view returns (uint256) {
        return _fundRaisedPerMilestone[__projectId][__milestoneTimestampIndex];
    }

    function getProgresses(
        uint256 __projectId,
        uint256 __milestoneTimestampIndex
    ) external view returns (Progress memory) {
        return _progresses[__projectId][__milestoneTimestampIndex];
    }

    function getAvailablePaymentToken()
        external
        view
        returns (address, address)
    {
        address idrx = _paymentToken[PaymentToken.IDRX];
        address usdt = _paymentToken[PaymentToken.USDT];

        return (idrx, usdt);
    }

    function _msgSender() private view returns (address) {
        return msg.sender;
    }

    function _withdrawFundsForDev(uint256 __projectId) private {
        uint256 milestoneTimestampIndex = _milestoneStatus.search(
            __projectId,
            _projectTimestamps(__projectId)
        );

        uint256 fundAmount = getFundRaisedPerMilestone(
            __projectId,
            milestoneTimestampIndex
        );

        address gameOwner = _project[__projectId].owner;

        FundingLib.transferTokenFromContract(
            fundAmount,
            _projectPaymentToken(__projectId),
            gameOwner
        );

        _milestoneStatus[__projectId][milestoneTimestampIndex] = true;
    }

    function _mintNusa(
        address __recipient,
        uint256 __amount
    ) private nonReentrant {
        NUSA(_nusa).mint(__recipient, __amount);
    }

    function _burnNusa(address __user, uint256 __amount) private nonReentrant {
        NUSA(_nusa).burn(__user, __amount);
    }

    // function _withdrawFundsForDev(uint256 __projectId) private {
    //     uint256 milestoneTimestampIndex = _milestoneStatus.search(
    //         __projectId,
    //         _projectTimestamps(__projectId)
    //     );

    //     uint256 fundAmount = getFundRaisedPerMilestone(
    //         __projectId,
    //         milestoneTimestampIndex
    //     );

    //     address gameOwner = _project[__projectId].owner;

    //     FundingLib.transferTokenFromContract(
    //         fundAmount,
    //         _projectPaymentToken(__projectId),
    //         gameOwner
    //     );

    //     _milestoneStatus[__projectId][milestoneTimestampIndex] = true;
    // }

    function _blockTimestamp() private view returns (uint256) {
        return block.timestamp;
    }

    function _projectTimestamps(
        uint256 __projectId
    ) private view returns (uint256[] storage) {
        return _project[__projectId].milestone.timestamps;
    }

    function _projectPaymentToken(
        uint256 __projectId
    ) private view returns (address) {
        PaymentToken paymentToken = _project[__projectId].paymentToken;
        return _paymentToken[paymentToken];
    }

    //
}
