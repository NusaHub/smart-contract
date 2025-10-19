// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {NusaHubScript} from "../script/NusaHub.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {NusaHub} from "../src/core/NusaHub.sol";
import {NusaGovernor} from "../src/core/NusaGovernor.sol";
import {NUSA} from "../src/tokens/NUSA.sol";
import {IDRX} from "../src/tokens/IDRX.sol";
import "../src/core/Imports.sol";

contract NusaHubTest is Test {
    //
    NusaHub private _nusaHub;
    NUSA private _nusaToken;
    NusaGovernor private _nusaGovernor;

    address private constant GAME_OWNER = address(1);
    address private constant INVESTOR = address(2);

    uint256 private constant MAIN_PROJECT_ID = 1;
    string private constant PROJECT_NAME = "NusaHub Test";
    string private constant PROJECT_SYMBOL = "NUSA_T";
    uint8 private constant PAYMENT_TOKEN = 0;
    uint256 private constant FUNDING_GOAL = 1000 * (10 ** 18);

    uint256 private constant INVESTOR_FUND_AMOUNT = 100 * (10 ** 18);
    uint256 private constant PROGRESS_FUND = 200 * (10 ** 18);
    uint256 private DEADLINE = block.timestamp + 2 minutes;

    uint256[] private _timestamps;
    string[] private _targets;

    address[] private _targetAddr;
    uint256[] private _values;
    bytes[] private _calldatas;
    string private _desc;

    function setUp() public {
        NusaHubScript script = new NusaHubScript();
        (
            address nusaAddr,
            address nusaHubAddr,
            address nusaGovernorAddr
        ) = script.run();

        _nusaHub = NusaHub(nusaHubAddr);
        _nusaToken = NUSA(nusaAddr);
        _nusaGovernor = NusaGovernor(payable(nusaGovernorAddr));

        _timestamps.push(block.timestamp + 1 days);
        _timestamps.push(block.timestamp + 2 days);

        _targets.push("The company met its sales target (100 X).");
        _targets.push("The company met its marketing target (200 user).");

        _targetAddr.push(nusaHubAddr);
        _values.push(0);
        _calldatas.push(
            abi.encodeWithSignature("processProgress(uint256)", MAIN_PROJECT_ID)
        );
        _desc = "sit amet ipsum dolor";
    }

    function test_SuccessfullyDelegateWithHash() public {
        vm.startPrank(GAME_OWNER);
        _nusaToken.delegate(GAME_OWNER);
        console.log(_nusaToken.delegates(address(0x3)));
        _nusaToken.registerIdentity("LOREM IPSUM");
        vm.stopPrank();

        string memory expectedHash = "LOREM IPSUM";
        string memory actualHash = _nusaToken.getIdentity(GAME_OWNER);

        assertEq(
            keccak256(abi.encodePacked(expectedHash)),
            keccak256(abi.encodePacked(actualHash))
        );
    }

    function test_SuccessfullyPostProject() public {
        vm.startPrank(GAME_OWNER);
        _nusaHub.postProject(
            MAIN_PROJECT_ID,
            PROJECT_NAME,
            PAYMENT_TOKEN,
            FUNDING_GOAL,
            _timestamps,
            _targets
        );
        vm.stopPrank();

        GameProject memory project = _nusaHub.getProject(MAIN_PROJECT_ID);

        assertEq(
            keccak256(abi.encodePacked(PROJECT_NAME)),
            keccak256(abi.encodePacked(project.name))
        );
        assertEq(PAYMENT_TOKEN, uint8(project.paymentToken));
        assertEq(FUNDING_GOAL, project.fundingGoal);
        assertEq(_timestamps.length, project.milestone.timestamps.length);
        assertEq(_targets.length, project.milestone.targets.length);
        assertEq(GAME_OWNER, project.owner);
    }

    function test_RevertIfGameProjectAlreadyRegistered() public {
        vm.startPrank(GAME_OWNER);
        _nusaHub.postProject(
            MAIN_PROJECT_ID,
            PROJECT_NAME,
            PAYMENT_TOKEN,
            FUNDING_GOAL,
            _timestamps,
            _targets
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                GameProjectError.GameProjectAlreadyRegistered.selector,
                MAIN_PROJECT_ID
            )
        );
        _nusaHub.postProject(
            MAIN_PROJECT_ID,
            PROJECT_NAME,
            PAYMENT_TOKEN,
            FUNDING_GOAL,
            _timestamps,
            _targets
        );
        vm.stopPrank();
    }

    function test_SuccessfullyFundProject() public {
        vm.startPrank(GAME_OWNER);
        _nusaHub.postProject(
            MAIN_PROJECT_ID,
            PROJECT_NAME,
            PAYMENT_TOKEN,
            FUNDING_GOAL,
            _timestamps,
            _targets
        );
        vm.stopPrank();

        vm.startPrank(INVESTOR);
        (address idrx, ) = _nusaHub.getAvailablePaymentToken();
        Payment(idrx).mint(INVESTOR, INVESTOR_FUND_AMOUNT);
        Payment(idrx).approve(address(_nusaHub), INVESTOR_FUND_AMOUNT);

        _nusaHub.fundProject(MAIN_PROJECT_ID, INVESTOR_FUND_AMOUNT);

        Funding memory funding = _nusaHub.getFundingByUser(
            MAIN_PROJECT_ID,
            INVESTOR
        );

        uint256 expectedFundPerMilestone = 50 * (10 ** 18);
        uint256 expectedFundPercentage = 10;

        assertEq(
            Payment(idrx).balanceOf(address(_nusaHub)),
            INVESTOR_FUND_AMOUNT
        );
        assertEq(NUSA(_nusaToken).balanceOf(INVESTOR), INVESTOR_FUND_AMOUNT);
        assertEq(funding.fundPerMilestone, expectedFundPerMilestone);
        assertEq(funding.percentageFundAmount, expectedFundPercentage);
        assertEq(_nusaHub.getInvestorStatus(MAIN_PROJECT_ID, INVESTOR), true);

        vm.stopPrank();
    }

    function test_RevertIfGameProjectNotRegistered() public {
        vm.startPrank(INVESTOR);
        vm.expectRevert(GameProjectError.GameProjectNotRegistered.selector);
        _nusaHub.fundProject(MAIN_PROJECT_ID, INVESTOR_FUND_AMOUNT);
        vm.stopPrank();
    }

    function test_SuccessfullyUpdateProgress() public {
        vm.startPrank(GAME_OWNER);
        _nusaHub.postProject(
            MAIN_PROJECT_ID,
            PROJECT_NAME,
            PAYMENT_TOKEN,
            FUNDING_GOAL,
            _timestamps,
            _targets
        );
        vm.stopPrank();

        vm.startPrank(INVESTOR);
        (address idrx, ) = _nusaHub.getAvailablePaymentToken();

        Payment(idrx).mint(INVESTOR, INVESTOR_FUND_AMOUNT);
        Payment(idrx).approve(address(_nusaHub), INVESTOR_FUND_AMOUNT);

        _nusaHub.fundProject(MAIN_PROJECT_ID, INVESTOR_FUND_AMOUNT);
        vm.stopPrank();

        vm.startPrank(GAME_OWNER);
        Payment(idrx).mint(GAME_OWNER, PROGRESS_FUND);
        Payment(idrx).approve(address(_nusaHub), PROGRESS_FUND);

        uint256 proposalId = _nusaGovernor.proposeProgress(
            _targetAddr,
            _values,
            _calldatas,
            _desc
        );
        _nusaHub.updateProgress(
            MAIN_PROJECT_ID,
            PROGRESS_FUND,
            proposalId,
            // _targetAddr,
            // _values,
            // _calldatas,
            _desc
        );
        vm.stopPrank();

        Progress memory progress = _nusaHub.getProgresses(MAIN_PROJECT_ID, 0);

        assertEq(
            Payment(idrx).balanceOf(address(_nusaHub)),
            PROGRESS_FUND + INVESTOR_FUND_AMOUNT
        );
        assertEq(Payment(idrx).balanceOf(GAME_OWNER), 0);
        assertEq(progress.amount, PROGRESS_FUND);
        assertEq(
            progress.proposalId,
            _nusaGovernor.getProposalId(
                _targetAddr,
                _values,
                _calldatas,
                keccak256(bytes(_desc))
            )
        );
        assertEq(
            keccak256(abi.encodePacked(progress.text)),
            keccak256(abi.encodePacked(_desc))
        );
    }

    function test_RevertIfUnauthorizedCaller() public {
        vm.startPrank(GAME_OWNER);
        _nusaHub.postProject(
            MAIN_PROJECT_ID,
            PROJECT_NAME,
            PAYMENT_TOKEN,
            FUNDING_GOAL,
            _timestamps,
            _targets
        );
        vm.stopPrank();

        vm.startPrank(INVESTOR);
        uint256 proposalId = _nusaGovernor.proposeProgress(
            _targetAddr,
            _values,
            _calldatas,
            _desc
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                GameProjectError.UnauthorizedCaller.selector,
                MAIN_PROJECT_ID,
                INVESTOR
            )
        );
        _nusaHub.updateProgress(
            MAIN_PROJECT_ID,
            PROGRESS_FUND,
            proposalId,
            // _targetAddr,
            // _values,
            // _calldatas,
            _desc
        );
        vm.stopPrank();
    }

    function test_SuccessfullyVoteMilestone() public {
        vm.startPrank(GAME_OWNER);
        _nusaHub.postProject(
            MAIN_PROJECT_ID,
            PROJECT_NAME,
            PAYMENT_TOKEN,
            FUNDING_GOAL,
            _timestamps,
            _targets
        );
        vm.stopPrank();

        vm.startPrank(INVESTOR);
        (address idrx, ) = _nusaHub.getAvailablePaymentToken();

        Payment(idrx).mint(INVESTOR, INVESTOR_FUND_AMOUNT);
        Payment(idrx).approve(address(_nusaHub), INVESTOR_FUND_AMOUNT);

        _nusaHub.fundProject(MAIN_PROJECT_ID, INVESTOR_FUND_AMOUNT);
        _nusaToken.delegate(INVESTOR);
        vm.stopPrank();

        vm.roll(block.number + 1);

        vm.startPrank(GAME_OWNER);
        Payment(idrx).mint(GAME_OWNER, PROGRESS_FUND);
        Payment(idrx).approve(address(_nusaHub), PROGRESS_FUND);

        uint256 proposalId = _nusaGovernor.proposeProgress(
            _targetAddr,
            _values,
            _calldatas,
            _desc
        );
        _nusaHub.updateProgress(
            MAIN_PROJECT_ID,
            PROGRESS_FUND,
            proposalId,
            // _targetAddr,
            // _values,
            // _calldatas,
            _desc
        );
        vm.stopPrank();

        // uint256 proposalIdentifier = _nusaHub
        //     .getProgresses(MAIN_PROJECT_ID, 0)
        //     .proposalId;
        uint256 voteStart = _nusaGovernor.proposalSnapshot(proposalId);

        vm.roll(voteStart + 1);

        vm.startPrank(INVESTOR);
        _nusaGovernor.voteProgress(proposalId, 1);
        vm.stopPrank();

        uint256 expectedAgainstVotes = 0;
        uint256 expectedForVotes = Payment(address(_nusaToken)).balanceOf(
            INVESTOR
        );

        (uint256 actualAgainstVotes, uint256 actualForVotes, ) = _nusaGovernor
            .proposalVotes(proposalId);

        assertEq(expectedAgainstVotes, actualAgainstVotes);
        assertEq(expectedForVotes, actualForVotes);
    }

    function test_SuccessfullyProcessProgress() public {
        vm.startPrank(GAME_OWNER);
        _nusaHub.postProject(
            MAIN_PROJECT_ID,
            PROJECT_NAME,
            PAYMENT_TOKEN,
            FUNDING_GOAL,
            _timestamps,
            _targets
        );
        vm.stopPrank();

        vm.startPrank(INVESTOR);
        (address idrx, ) = _nusaHub.getAvailablePaymentToken();

        Payment(idrx).mint(INVESTOR, INVESTOR_FUND_AMOUNT);
        Payment(idrx).approve(address(_nusaHub), INVESTOR_FUND_AMOUNT);

        _nusaHub.fundProject(MAIN_PROJECT_ID, INVESTOR_FUND_AMOUNT);
        _nusaToken.delegate(INVESTOR);
        vm.stopPrank();

        vm.roll(block.number + 1);

        vm.startPrank(GAME_OWNER);
        Payment(idrx).mint(GAME_OWNER, PROGRESS_FUND);
        Payment(idrx).approve(address(_nusaHub), PROGRESS_FUND);

        uint256 proposalId = _nusaGovernor.proposeProgress(
            _targetAddr,
            _values,
            _calldatas,
            _desc
        );
        _nusaHub.updateProgress(
            MAIN_PROJECT_ID,
            PROGRESS_FUND,
            proposalId,
            // _targetAddr,
            // _values,
            // _calldatas,
            _desc
        );
        vm.stopPrank();

        // uint256 proposalId = _nusaHub
        //     .getProgresses(MAIN_PROJECT_ID, 0)
        //     .proposalId;
        uint256 voteStart = _nusaGovernor.proposalSnapshot(proposalId);

        vm.roll(voteStart + 1);

        vm.startPrank(INVESTOR);
        _nusaGovernor.voteProgress(proposalId, 1);
        vm.stopPrank();

        vm.roll(block.number + _nusaGovernor.votingPeriod() + 1);

        _nusaGovernor.execute(
            _targetAddr,
            _values,
            _calldatas,
            keccak256(bytes(_desc))
        );

        bool expectedMilestoneStatus = true;
        bool actualMilestoneStatus = _nusaHub.getMilestoneStatus(
            MAIN_PROJECT_ID,
            0
        );

        uint256 actualFundReceived = Payment(idrx).balanceOf(GAME_OWNER);
        uint256 expectedFundReceived = INVESTOR_FUND_AMOUNT / 2;

        assertEq(expectedMilestoneStatus, actualMilestoneStatus);
        assertEq(expectedFundReceived, actualFundReceived);
    }

    function test_SuccessfullyWithdrawForInvestor() public {
        vm.startPrank(GAME_OWNER);
        _nusaHub.postProject(
            MAIN_PROJECT_ID,
            PROJECT_NAME,
            PAYMENT_TOKEN,
            FUNDING_GOAL, // 1000
            _timestamps,
            _targets
        );
        vm.stopPrank();

        vm.startPrank(INVESTOR);
        (address idrx, ) = _nusaHub.getAvailablePaymentToken();

        Payment(idrx).mint(INVESTOR, INVESTOR_FUND_AMOUNT); // 100
        Payment(idrx).approve(address(_nusaHub), INVESTOR_FUND_AMOUNT);

        console.log(
            "NUSAHUB: ",
            Payment(idrx).balanceOf(address(_nusaHub)) / 10 ** 18
        );
        console.log(
            "user: ",
            Payment(idrx).balanceOf(address(INVESTOR)) / 10 ** 18
        );

        _nusaHub.fundProject(MAIN_PROJECT_ID, INVESTOR_FUND_AMOUNT);
        _nusaToken.delegate(INVESTOR);
        vm.stopPrank();

        // console.log(Payment(idrx).balanceOf(INVESTOR));
        console.log(
            "NUSAHUB: ",
            Payment(idrx).balanceOf(address(_nusaHub)) / 10 ** 18
        );
        console.log(
            "user: ",
            Payment(idrx).balanceOf(address(INVESTOR)) / 10 ** 18
        );
        vm.roll(block.number + 1);

        vm.startPrank(GAME_OWNER);
        Payment(idrx).mint(GAME_OWNER, PROGRESS_FUND); // 200
        Payment(idrx).approve(address(_nusaHub), PROGRESS_FUND);

        uint256 proposalId = _nusaGovernor.proposeProgress(
            _targetAddr,
            _values,
            _calldatas,
            _desc
        );
        _nusaHub.updateProgress(
            MAIN_PROJECT_ID,
            PROGRESS_FUND,
            proposalId,
            // _targetAddr,
            // _values,
            // _calldatas,
            _desc
        );
        vm.stopPrank();

        console.log(
            "NUSAHUB: ",
            Payment(idrx).balanceOf(address(_nusaHub)) / 10 ** 18
        );
        console.log(
            "user: ",
            Payment(idrx).balanceOf(address(INVESTOR)) / 10 ** 18
        );

        // uint256 proposalId = _nusaHub
        //     .getProgresses(MAIN_PROJECT_ID, 0)
        //     .proposalId;
        uint256 voteStart = _nusaGovernor.proposalSnapshot(proposalId);

        vm.roll(voteStart + 1);

        vm.startPrank(INVESTOR);
        _nusaGovernor.voteProgress(proposalId, 1);
        vm.stopPrank();

        vm.roll(block.number + _nusaGovernor.votingPeriod() + 1);

        _nusaGovernor.execute(
            _targetAddr,
            _values,
            _calldatas,
            keccak256(bytes(_desc))
        );
        console.log(
            "NUSAHUB: ",
            Payment(idrx).balanceOf(address(_nusaHub)) / 10 ** 18
        );
        console.log(
            "user: ",
            Payment(idrx).balanceOf(address(INVESTOR)) / 10 ** 18
        );

        vm.startPrank(INVESTOR);
        _nusaHub.withdrawFundsForInvestor(MAIN_PROJECT_ID, 0);
        vm.stopPrank();
        console.log(
            "NUSAHUB: ",
            Payment(idrx).balanceOf(address(_nusaHub)) / 10 ** 18
        );
        console.log(
            "user: ",
            Payment(idrx).balanceOf(address(INVESTOR)) / 10 ** 18
        );
        bool expectedWithdrawnStatus = true;
        bool actualWithdrawnStatus = _nusaHub.hasWithdrawnStatus(
            MAIN_PROJECT_ID,
            0,
            INVESTOR
        );

        uint256 expectedWithdrawAmount = (PROGRESS_FUND * 10) / 100;
        uint256 actualWithdrawAmount = Payment(idrx).balanceOf(INVESTOR);

        assertEq(expectedWithdrawnStatus, actualWithdrawnStatus);
        assertEq(expectedWithdrawAmount, actualWithdrawAmount);
    }

    function test_RevertIfAlreadyWithdrawn() public {
        vm.startPrank(GAME_OWNER);
        _nusaHub.postProject(
            MAIN_PROJECT_ID,
            PROJECT_NAME,
            PAYMENT_TOKEN,
            FUNDING_GOAL,
            _timestamps,
            _targets
        );
        vm.stopPrank();

        vm.startPrank(INVESTOR);
        (address idrx, ) = _nusaHub.getAvailablePaymentToken();

        Payment(idrx).mint(INVESTOR, INVESTOR_FUND_AMOUNT);
        Payment(idrx).approve(address(_nusaHub), INVESTOR_FUND_AMOUNT);

        _nusaHub.fundProject(MAIN_PROJECT_ID, INVESTOR_FUND_AMOUNT);
        _nusaToken.delegate(INVESTOR);
        vm.stopPrank();

        vm.roll(block.number + 1);

        vm.startPrank(GAME_OWNER);
        Payment(idrx).mint(GAME_OWNER, PROGRESS_FUND);
        Payment(idrx).approve(address(_nusaHub), PROGRESS_FUND);

        uint256 proposalId = _nusaGovernor.proposeProgress(
            _targetAddr,
            _values,
            _calldatas,
            _desc
        );
        _nusaHub.updateProgress(
            MAIN_PROJECT_ID,
            PROGRESS_FUND,
            proposalId,
            // _targetAddr,
            // _values,
            // _calldatas,
            _desc
        );
        vm.stopPrank();

        // uint256 proposalId = _nusaHub
        //     .getProgresses(MAIN_PROJECT_ID, 0)
        //     .proposalId;
        uint256 voteStart = _nusaGovernor.proposalSnapshot(proposalId);

        vm.roll(voteStart + 1);

        vm.startPrank(INVESTOR);
        _nusaGovernor.voteProgress(proposalId, 1);
        vm.stopPrank();

        vm.roll(block.number + _nusaGovernor.votingPeriod() + 1);

        _nusaGovernor.execute(
            _targetAddr,
            _values,
            _calldatas,
            keccak256(bytes(_desc))
        );

        vm.startPrank(INVESTOR);
        _nusaHub.withdrawFundsForInvestor(MAIN_PROJECT_ID, 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                ProgressError.AlreadyWithdrawn.selector,
                MAIN_PROJECT_ID,
                0,
                INVESTOR
            )
        );
        _nusaHub.withdrawFundsForInvestor(MAIN_PROJECT_ID, 0);
        vm.stopPrank();
    }

    function test_RevertIfIncompleteMilestone() public {
        vm.startPrank(GAME_OWNER);
        _nusaHub.postProject(
            MAIN_PROJECT_ID,
            PROJECT_NAME,
            PAYMENT_TOKEN,
            FUNDING_GOAL,
            _timestamps,
            _targets
        );
        vm.stopPrank();

        vm.startPrank(INVESTOR);
        (address idrx, ) = _nusaHub.getAvailablePaymentToken();

        Payment(idrx).mint(INVESTOR, INVESTOR_FUND_AMOUNT);
        Payment(idrx).approve(address(_nusaHub), INVESTOR_FUND_AMOUNT);

        _nusaHub.fundProject(MAIN_PROJECT_ID, INVESTOR_FUND_AMOUNT);
        _nusaToken.delegate(INVESTOR);
        vm.stopPrank();

        vm.roll(block.number + 1);

        vm.startPrank(GAME_OWNER);
        Payment(idrx).mint(GAME_OWNER, PROGRESS_FUND);
        Payment(idrx).approve(address(_nusaHub), PROGRESS_FUND);

        uint256 proposalId = _nusaGovernor.proposeProgress(
            _targetAddr,
            _values,
            _calldatas,
            _desc
        );
        _nusaHub.updateProgress(
            MAIN_PROJECT_ID,
            PROGRESS_FUND,
            proposalId,
            // _targetAddr,
            // _values,
            // _calldatas,
            _desc
        );
        vm.stopPrank();

        // uint256 proposalId = _nusaHub
        //     .getProgresses(MAIN_PROJECT_ID, 0)
        //     .proposalId;
        uint256 voteStart = _nusaGovernor.proposalSnapshot(proposalId);

        vm.roll(voteStart + 1);

        vm.startPrank(INVESTOR);
        _nusaGovernor.voteProgress(proposalId, 1);
        vm.stopPrank();

        vm.roll(block.number + _nusaGovernor.votingPeriod() + 1);

        _nusaGovernor.execute(
            _targetAddr,
            _values,
            _calldatas,
            keccak256(bytes(_desc))
        );

        vm.startPrank(INVESTOR);
        vm.expectRevert(
            abi.encodeWithSelector(
                ProgressError.IncompleteMilestone.selector,
                MAIN_PROJECT_ID,
                1
            )
        );
        _nusaHub.withdrawFundsForInvestor(MAIN_PROJECT_ID, 1);
        vm.stopPrank();
    }

    function test_SuccessfullyCashOut() public {
        vm.startPrank(GAME_OWNER);
        _nusaHub.postProject(
            MAIN_PROJECT_ID,
            PROJECT_NAME,
            PAYMENT_TOKEN,
            FUNDING_GOAL,
            _timestamps,
            _targets
        );
        vm.stopPrank();

        vm.startPrank(INVESTOR);
        (address idrx, ) = _nusaHub.getAvailablePaymentToken();

        Payment(idrx).mint(INVESTOR, INVESTOR_FUND_AMOUNT);
        Payment(idrx).approve(address(_nusaHub), INVESTOR_FUND_AMOUNT);

        _nusaHub.fundProject(MAIN_PROJECT_ID, INVESTOR_FUND_AMOUNT);
        _nusaToken.delegate(INVESTOR);
        vm.stopPrank();

        vm.roll(block.number + 1);

        vm.startPrank(GAME_OWNER);
        Payment(idrx).mint(GAME_OWNER, PROGRESS_FUND);
        Payment(idrx).approve(address(_nusaHub), PROGRESS_FUND);

        uint256 proposalId = _nusaGovernor.proposeProgress(
            _targetAddr,
            _values,
            _calldatas,
            _desc
        );
        _nusaHub.updateProgress(
            MAIN_PROJECT_ID,
            PROGRESS_FUND,
            proposalId,
            // _targetAddr,
            // _values,
            // _calldatas,
            _desc
        );
        vm.stopPrank();

        // uint256 proposalId = _nusaHub
        //     .getProgresses(MAIN_PROJECT_ID, 0)
        //     .proposalId;
        uint256 voteStart = _nusaGovernor.proposalSnapshot(proposalId);

        vm.roll(voteStart + 1);

        vm.startPrank(INVESTOR);
        _nusaGovernor.voteProgress(proposalId, 1);
        vm.stopPrank();

        vm.roll(block.number + _nusaGovernor.votingPeriod() + 1);

        _nusaGovernor.execute(
            _targetAddr,
            _values,
            _calldatas,
            keccak256(bytes(_desc))
        );

        vm.startPrank(INVESTOR);
        _nusaHub.withdrawFundsForInvestor(MAIN_PROJECT_ID, 0);
        _nusaHub.cashOut(MAIN_PROJECT_ID);
        vm.stopPrank();

        uint256 expectedCashOutAmount = 50 * (10 ** 18);
        uint256 actualCashOutAmount = Payment(idrx).balanceOf(INVESTOR) -
            ((PROGRESS_FUND * 10) / 100);

        uint256 actualNusaBalance = _nusaToken.balanceOf(INVESTOR);

        assertEq(expectedCashOutAmount, actualCashOutAmount);
        assertEq(actualNusaBalance, 0);
    }

    //
}
