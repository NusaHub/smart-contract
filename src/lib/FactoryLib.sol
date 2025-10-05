// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import {ProjectDAO} from "../dao/ProjectDAO.sol";
import {Project} from "../token/Project.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

library FactoryLib {
    //
    function generateProjectToken(
        string memory __name,
        string memory __symbol,
        uint256 __amount
    ) internal returns (address) {
        Project implementation = new Project();
        bytes memory data = abi.encodeWithSelector(
            Project.initialize.selector,
            __name,
            __symbol,
            __amount
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);

        return address(proxy);
    }

    function generateProjectDAO(
        address __tokenProxy,
        string memory __governorName
    ) internal returns (address) {
        ProjectDAO implementation = new ProjectDAO();
        bytes memory data = abi.encodeWithSelector(
            ProjectDAO.initialize.selector,
            __governorName,
            __tokenProxy
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);

        return address(proxy);
    }
    //
}
