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
    UUPSUpgradeable
{
    //
    using SafeERC20 for IERC20;
    using MilestoneLib for mapping(uint256 => mapping(uint256 => bool));

    address private _idrx;
    address private _usdt;

    mapping(uint256 => mapping(uint256 => bool)) private _milestoneStatus;

    mapping(uint256 => GameProject) private _project;
    mapping(uint256 => mapping(address => Funding[])) private _fundings;
    mapping(uint256 => mapping(uint256 => uint256))
        private _fundRaisedPerMilestone;
    mapping(uint256 => mapping(uint256 => Progress)) private _progresses;

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

        _idrx = address(idrx);
        _usdt = address(usdt);
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
    ) external {
        address tokenAddress = FactoryLib.generateProjectToken(
            __projectName,
            __projectSymbol,
            __fundingGoal
        );

        _addToProject(
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

    function fundProject(uint256 __projectId, uint256 __fundAmount) external {
        GameProject memory project = _project[__projectId];
        address projectToken = project.token;
        PaymentToken token = project.paymentToken;

        _addFundings(__projectId, __fundAmount, _msgSender());
        _escrowFundsToken(__fundAmount, token);
        _transferTokenFromContract(__fundAmount, projectToken, _msgSender());

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
    ) external {
        uint256 proposalId = propose(
            __targets,
            __values,
            __calldatas,
            __description
        );

        _addProgress(__projectId, __type, __description, __amount, proposalId);

        if (__amount != 0) {
            PaymentToken token = _project[__projectId].paymentToken;
            _escrowFundsToken(__amount, token);
        }

        emit ProgressEvent.ProgressUpdated(
            __projectId,
            __amount,
            proposalId,
            _blockTimestamp()
        );
    }

    // cek ini escrow funds token karena dipanggil oleh kontrak
    function processProgress(uint256 __projectId) external onlyGovernance {
        _withdrawFundsForDev(__projectId);

        emit ProgressEvent.ProgressProcessed(__projectId);
    }

    function withdrawFundsForInvestor(uint256 __projectId) external {
        for (
            uint256 i = 0;
            i < _fundings[__projectId][_msgSender()].length;
            i++
        ) {
            Funding memory funding = _fundings[__projectId][_msgSender()][i];

            uint256 milestoneTimestampIndex = _milestoneStatus.search(
                __projectId,
                _projectTimestamps(__projectId)
            );

            uint256 amount = _progresses[__projectId][milestoneTimestampIndex]
                .amount;

            uint256 withdrawAmount = (funding.percentageFundAmount * amount) /
                100;
            PaymentToken token = _project[__projectId].paymentToken;

            _transferTokenFromContract(
                withdrawAmount,
                _getPaymentTokenAddress(token),
                _msgSender()
            );
        }
    }

    function _withdrawFundsForDev(uint256 __projectId) private {
        uint256 milestoneIndex = _milestoneStatus.search(
            __projectId,
            _projectTimestamps(__projectId)
        );

        uint256 fundAmount = getFundRaisedPerMilestone(
            __projectId,
            milestoneIndex
        );

        PaymentToken token = _project[__projectId].paymentToken;

        _transferTokenFromContract(
            fundAmount,
            _getPaymentTokenAddress(token),
            _msgSender()
        );

        _milestoneStatus[__projectId][milestoneIndex] = true;
    }

    function cashOut(uint256 __projectId) external {
        PaymentToken token = _project[__projectId].paymentToken;
        uint256 totalMilestone = _project[__projectId]
            .milestone
            .timestamps
            .length;
        uint256 milestoneIndex = _milestoneStatus.search(
            __projectId,
            _projectTimestamps(__projectId)
        );
        uint256 remainingMilestone = totalMilestone - milestoneIndex;

        for (
            uint256 i = 0;
            i < _fundings[__projectId][_msgSender()].length;
            i++
        ) {
            Funding memory funding = _fundings[__projectId][_msgSender()][i];

            uint256 cashOutAmount = funding.fundPerMilestone *
                remainingMilestone;

            _transferTokenFromContract(
                cashOutAmount,
                _getPaymentTokenAddress(token),
                _msgSender()
            );
        }
    }

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

    function getFundRaisedPerMilestone(
        uint256 __projectId,
        uint256 __milestoneIndex
    ) public view returns (uint256) {
        return _fundRaisedPerMilestone[__projectId][__milestoneIndex];
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

    function _transferTokenFromContract(
        uint256 __fundAmount,
        address __token,
        address __receiver
    ) private {
        IERC20(__token).safeTransferFrom(
            address(this),
            __receiver,
            __fundAmount
        );
    }

    function _escrowFundsToken(
        uint256 __fundAmount,
        PaymentToken __token
    ) private {
        address paymentToken = _getPaymentTokenAddress(__token);
        IERC20(paymentToken).safeTransfer(address(this), __fundAmount);
    }

    function _addFundings(
        uint256 __projectId,
        uint256 __fundAmount,
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
            fundPerMilestone
        );

        _fundings[__projectId][__funder].push(
            Funding({
                amount: __fundAmount,
                timestamp: _blockTimestamp(),
                startMilestone: currentMilestoneIndex,
                fundPerMilestone: fundPerMilestone,
                percentagePerMilestone: percentagePerMilestone,
                percentageFundAmount: percentageFundAmount
            })
        );

        _project[__projectId].fundRaised += __fundAmount;
    }

    function _addToProject(
        uint256 __projectId,
        string memory __projectName,
        PaymentToken __paymentToken,
        address __token,
        uint256 __fundingGoal,
        uint256[] memory __timestamps,
        string[] memory __targets,
        address __owner
    ) private {
        _project[__projectId] = GameProject({
            name: __projectName,
            token: __token,
            paymentToken: __paymentToken,
            fundingGoal: __fundingGoal,
            fundRaised: 0,
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
        uint256 __amount,
        uint256 __proposalId
    ) private {
        uint256 milestoneTimestampIndex = _milestoneStatus.search(
            __projectId,
            _projectTimestamps(__projectId)
        );

        _progresses[__projectId][milestoneTimestampIndex] = Progress({
            progressType: __type,
            text: __text,
            amount: __amount,
            proposalId: __proposalId
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
