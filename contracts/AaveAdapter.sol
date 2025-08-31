// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Aave Interface
interface IAaveLendingPool {
    function liquidationCall(
        address collateralAsset,
        address debtAsset,
        address user,
        uint256 debtToCover,
        bool receiveAToken
    ) external;
}

// Aave Adapter Contract
contract AaveAdapter {
    IAaveLendingPool lendingPool;

    constructor(address _lendingPool) {
        lendingPool = IAaveLendingPool(_lendingPool);
    }

    function liquidateAaveBorrow(
        address borrower,
        uint256 debtToCover,
        address debtAsset,
        address collateralAsset
    ) external {
        lendingPool.liquidationCall(
            collateralAsset,
            debtAsset,
            borrower,
            debtToCover,
            false
        );
    }
}
