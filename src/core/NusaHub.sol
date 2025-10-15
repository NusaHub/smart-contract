// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import "./Imports.sol";

contract NusaHub is
    Initializable,
    GovernorUpgradeable,
    GovernorSettingsUpgradeable,
    GovernorCountingSimpleUpgradeable,
    GovernorVotesUpgradeable,
    GovernorVotesQuorumFractionUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    //
    using SafeERC20 for IERC20;
    using ProgressLib for mapping(uint256 => mapping(uint256 => bool));

    address private _nusa;

    mapping(PaymentToken => address) private _paymentToken;
    mapping(uint256 => GameProject) _project;
    mapping(uint256 => mapping(address => Funding)) _fundings;
    mapping(uint256 => mapping(uint256 => Progress)) _progresses;

    mapping(uint256 => mapping(address => bool)) _investorStatus;
    mapping(uint256 => mapping(uint256 => bool)) _milestoneStatus;
    mapping(uint256 => mapping(uint256 => mapping(address => bool))) _hasWithdrawn;
    mapping(uint256 => mapping(uint256 => uint256)) _fundRaisedPerMilestone;

    modifier onlyNonRegisteredProject(uint256 __projectId) {
        GameProject memory project = _project[__projectId];
        require(
            project.fundingGoal == 0 && project.token == address(0),
            GameProjectError.GameProjectAlreadyRegistered(__projectId)
        );
        _;
    }

    modifier onlyRegisteredProject(uint256 __projectId) {
        GameProject memory project = _project[__projectId];
        require(
            project.fundingGoal != 0 && project.token != address(0),
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

    modifier onlyIfMilestoneDone(uint256 __projectId) {
        uint256 milestoneTimestampIndex = _milestoneStatus.search(
            __projectId,
            _projectTimestamps(__projectId)
        );
        bool milestoneStatus = _milestoneStatus[__projectId][
            milestoneTimestampIndex
        ];
        require(
            milestoneStatus,
            ProgressError.IncompleteMilestone(
                __projectId,
                milestoneTimestampIndex
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

    function initialize(IVotes __token) public initializer {
        __Governor_init("NusaHub Governor");
        __GovernorSettings_init(5, 25, 0);
        __GovernorCountingSimple_init();
        __GovernorVotes_init(__token);
        __GovernorVotesQuorumFraction_init(1);
        __UUPSUpgradeable_init();

        IDRX idrx = new IDRX();
        USDT usdt = new USDT();

        _paymentToken[PaymentToken.IDRX] = address(idrx);
        _paymentToken[PaymentToken.USDT] = address(usdt);

        _nusa = address(__token);
    }

    function _authorizeUpgrade(address newImplementation) internal override {}

    function postProject(
        uint256 __projectId,
        string calldata __projectName,
        string calldata __projectSymbol,
        PaymentToken __paymentToken,
        uint256 __fundingGoal,
        uint256[] calldata __timestamps,
        string[] calldata __targets
    ) external onlyNonRegisteredProject(__projectId) {
        address tokenAddress = FactoryLib.generateProjectToken(
            __projectName,
            __projectSymbol,
            __fundingGoal
        );

        GameProjectLib.addToProject(
            _project,
            __projectId,
            __projectName,
            __paymentToken,
            tokenAddress,
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
        GameProject memory project = _project[__projectId];
        address projectToken = project.token;

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
            _projectPaymentToken(__projectId)
        );
        FundingLib.transferTokenFromContract(
            __fundAmount,
            projectToken,
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
        ProgressType __type,
        address[] memory __targets,
        uint256[] memory __values,
        bytes[] memory __calldatas,
        string memory __description
    )
        external
        onlyRegisteredProject(__projectId)
        onlyProjectCreator(__projectId, _msgSender())
    {
        uint256 proposalId = propose(
            __targets,
            __values,
            __calldatas,
            __description
        );

        ProgressLib.addProgress(
            _progresses,
            _milestoneStatus,
            _projectTimestamps(__projectId),
            __projectId,
            __type,
            __description,
            __amount,
            proposalId
        );

        if (__amount != 0) {
            GameProject memory project = _project[__projectId];
            address paymentToken = _paymentToken[project.paymentToken];

            FundingLib.escrowFundsToken(__amount, paymentToken);
        }

        emit ProgressEvent.ProgressUpdated(
            __projectId,
            __amount,
            proposalId,
            _blockTimestamp()
        );
    }

    function voteMilestone(
        uint256 __projectId,
        uint8 __vote
    )
        external
        onlyRegisteredProject(__projectId)
        onlyProjectInvestor(__projectId, _msgSender())
        returns (uint256)
    {
        uint256 milestoneTimestampIndex = _milestoneStatus.search(
            __projectId,
            _projectTimestamps(__projectId)
        );
        uint256 proposalId = _progresses[__projectId][milestoneTimestampIndex]
            .proposalId;

        emit ProgressEvent.VoteCasted(__projectId, __vote);

        return super.castVote(proposalId, __vote);
    }

    function processProgress(uint256 __projectId) external onlyGovernance {
        _withdrawFundsForDev(__projectId);

        emit ProgressEvent.ProgressProcessed(__projectId);
    }

    function withdrawFundsForInvestor(
        uint256 __projectId,
        uint256 __milestoneTimestampIndex
    )
        external
        onlyRegisteredProject(__projectId)
        onlyIfMilestoneDone(__projectId)
        onlyProjectInvestor(__projectId, _msgSender())
        onlyOnceWithdraw(__projectId, __milestoneTimestampIndex, _msgSender())
    {
        uint256 withdrawAmount = FundingLib.calculateWithdrawAmount(
            __projectId,
            _msgSender(),
            __milestoneTimestampIndex,
            _fundings,
            _progresses
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

    function getProgresses(
        uint256 __projectId,
        uint256 __milestoneTimestampIndex
    ) external view returns (Progress memory) {
        return _progresses[__projectId][__milestoneTimestampIndex];
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

    function getPaymentToken(
        uint256 __projectId
    ) public view returns (PaymentToken) {
        return _project[__projectId].paymentToken;
    }

    function _msgSender()
        internal
        view
        override(ContextUpgradeable)
        returns (address)
    {
        return super._msgSender();
    }

    function proposalThreshold()
        public
        view
        override(GovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        return super.proposalThreshold();
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

    function _withdrawFundsForDev(uint256 __projectId) private {
        uint256 milestoneTimestampIndex = _milestoneStatus.search(
            __projectId,
            _projectTimestamps(__projectId)
        );

        uint256 fundAmount = getFundRaisedPerMilestone(
            __projectId,
            milestoneTimestampIndex
        );

        FundingLib.transferTokenFromContract(
            fundAmount,
            _projectPaymentToken(__projectId),
            _msgSender()
        );

        _milestoneStatus[__projectId][milestoneTimestampIndex] = true;
    }

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
