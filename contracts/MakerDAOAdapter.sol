// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// MakerDAO Interface
interface IMakerDAO {
    function flap(address cdp) external;
    function supply(address cdp, uint256 amount) external;
}

// MakerDAO Adapter Contract
contract MakerDAOAdapter {
    IMakerDAO makerDao;

    constructor(address _makerDao) {
        makerDao = IMakerDAO(_makerDao);
    }

    function liquidateMakerBorrow(address cdp) external {
        makerDao.flap(cdp);
    }
}
