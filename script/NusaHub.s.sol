// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import {Script} from "forge-std/Script.sol";
import {NusaHub} from "../src/core/NusaHub.sol";
import {NusaGovernor} from "../src/core/NusaGovernor.sol";
import {NUSA} from "../src/tokens/NUSA.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import "../src/tokens/TokenImports.sol";

contract NusaHubScript is Script {
    //
    function run()
        external
        returns (address, address, address, address, address)
    {
        // uint256 privKey = vm.envUint("PRIVATE_KEY");
        // address pubKey = vm.addr(privKey);

        vm.startBroadcast();
        IDRX idrx = new IDRX();
        USDT usdt = new USDT();

        NUSA nusaImpl = new NUSA();
        bytes memory nusaData = abi.encodeWithSelector(
            NUSA.initialize.selector,
            "Nusa Vote Token",
            "NUSA"
        );
        ERC1967Proxy nusaProxy = new ERC1967Proxy(address(nusaImpl), nusaData);

        IVotes nusaVotes = IVotes(address(nusaProxy));

        NusaGovernor nusaGovernorImpl = new NusaGovernor();
        bytes memory nusaGovernorData = abi.encodeWithSelector(
            NusaGovernor.initialize.selector,
            nusaVotes
        );
        ERC1967Proxy nusaGovernorProxy = new ERC1967Proxy(
            address(nusaGovernorImpl),
            nusaGovernorData
        );

        NusaHub nusaHubImpl = new NusaHub();
        bytes memory nusaHubData = abi.encodeWithSelector(
            NusaHub.initialize.selector,
            address(idrx),
            address(usdt),
            address(nusaProxy),
            address(nusaGovernorProxy)
        );
        ERC1967Proxy nusaHubProxy = new ERC1967Proxy(
            address(nusaHubImpl),
            nusaHubData
        );
        vm.stopBroadcast();

        return (
            address(nusaProxy),
            address(idrx),
            address(usdt),
            address(nusaHubProxy),
            address(nusaGovernorProxy)
        );
    }
    //
}
