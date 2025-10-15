// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {NusaHubScript} from "../script/NusaHub.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {NusaHub} from "../src/core/NusaHub.sol";
import {NUSA} from "../src/tokens/NUSA.sol";
import {IDRX} from "../src/tokens/IDRX.sol";

import "../src/core/Imports.sol";

contract NusaHubTest is Test {
    //
    NusaHub private _nusaHub;
    NUSA private _nusaToken;

    address private constant GAME_OWNER = address(1);
    address private constant INVESTOR = address(2);

    uint256 private constant MAIN_PROJECT_ID = 1;
    string private constant PROJECT_NAME = "NusaHub Test";
    string private constant PROJECT_SYMBOL = "NUSA_T";
    uint8 private constant PAYMENT_TOKEN = 0;
    uint256 private constant FUNDING_GOAL = 1000 * (10 ** 18);

    uint256 private constant INVESTOR_FUND_AMOUNT = 100 * (10 ** 18);
    uint256 private DEADLINE = block.timestamp + 2 minutes;

    uint256[] private _timestamps;
    string[] private _targets;

    function setUp() public {
        NusaHubScript script = new NusaHubScript();
        (address nusaAddr, address nusaHubAddr) = script.run();

        _nusaHub = NusaHub(payable(nusaHubAddr));
        _nusaToken = NUSA(nusaAddr);

        _timestamps.push(block.timestamp + 1 days);
        _timestamps.push(block.timestamp + 2 days);

        _targets.push("The company met its sales target (100 X).");
        _targets.push("The company met its marketing target (200 user).");
    }

    function test_SuccessfullyDelegateWithHash() public {
        vm.startPrank(GAME_OWNER);
        _nusaToken.delegateWithHash("LOREM IPSUM");
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

    //
}
