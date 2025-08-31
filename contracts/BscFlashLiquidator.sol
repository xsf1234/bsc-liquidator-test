// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/* -------------------------- Minimal Interfaces -------------------------- */

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address user) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function decimals() external view returns (uint8);

    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from,address to,uint256 value) external returns (bool);
}

interface IPancakeV3Pool {
    function token0() external view returns (address);
    function token1() external view returns (address);

    // Flash borrow both legs are supported; set one leg to 0 for single-asset flash
    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;
}

interface IPancakeV3FlashCallback {
    /// @notice Pancake v3 flash callback. The pool expects to be paid back (amount + fee)
    function pancakeV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external;
}

interface IPancakeRouter02 {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path, // e.g. [collateralUnderlying, WBNB, debtUnderlying]
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

interface IVToken {
    // Standard Compound-style interfaces
    function liquidateBorrow(address borrower, uint repayAmount, address vTokenCollateral) external returns (uint);
    function redeem(uint redeemTokens) external returns (uint);
    function redeemUnderlying(uint redeemAmount) external returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function underlying() external view returns (address);
}

interface IComptroller {
    function enterMarkets(address[] calldata vTokens) external returns (uint[] memory);
    function exitMarket(address vToken) external returns (uint);
}

/* ------------------------------ Utilities ------------------------------ */

library SafeERC20 {
    function _call(IERC20 token, bytes memory data) private returns (bytes memory) {
        (bool ok, bytes memory ret) = address(token).call(data);
        require(ok, "SAFEERC20_CALL_FAIL");
        if (ret.length > 0) require(abi.decode(ret, (bool)), "SAFEERC20_ERC20_FALSE");
        return ret;
    }

    function safeApprove(IERC20 token, address spender, uint256 amount) internal {
        _call(token, abi.encodeWithSelector(token.approve.selector, spender, amount));
    }

    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        _call(token, abi.encodeWithSelector(token.transfer.selector, to, amount));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        _call(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, amount));
    }
}

abstract contract Ownable {
    event OwnershipTransferred(address indexed prev, address indexed next);
    address public owner;
    modifier onlyOwner() { require(msg.sender == owner, "NOT_OWNER"); _; }
    constructor() { owner = msg.sender; emit OwnershipTransferred(address(0), msg.sender); }
    function transferOwnership(address next) external onlyOwner { require(next != address(0), "ZERO"); emit OwnershipTransferred(owner, next); owner = next; }
}

/* ---------------------------- Flash Liquidator ---------------------------- */

contract BscFlashLiquidator is Ownable, IPancakeV3FlashCallback {
    using SafeERC20 for IERC20;

    struct FlashData {
        address pool;                // Pancake v3 pool
        bool borrowIsToken0;         // true: debt token is token0; false: token1
        uint256 flashAmount;         // amount to borrow (debt token)
        address borrower;            // target to liquidate
        address vTokenBorrow;        // debt vToken
        address vTokenCollateral;    // collateral vToken
        address router;              // Pancake v2 router for swaps
        address[] swapPath;          // path from collateralUnderlying -> ... -> debtUnderlying
        uint256 minDebtOut;          // slippage guard when swapping collateral to debt token
    }

    IComptroller public comptroller; // optional: to enter markets if needed

    constructor(address _comptroller) {
        comptroller = IComptroller(_comptroller);
    }

    /* ---------------------------- External Entrypoint ---------------------------- */

    /// @notice Execute a Venus-style liquidation using a Pancake v3 flash loan.
    /// @dev Assumes both vTokens are ERC20-based (not vBNB). Choose pool where the debt token exists.
    function executeFlashLiquidation(
        address pool,
        bool borrowIsToken0,
        uint256 flashAmount,
        address borrower,
        address vTokenBorrow,
        address vTokenCollateral,
        address router,
        address[] calldata swapPath,
        uint256 minDebtOut
    ) external onlyOwner {
        require(flashAmount > 0, "flashAmount=0");
        require(pool != address(0) && router != address(0), "bad pool/router");
        require(vTokenBorrow != address(0) && vTokenCollateral != address(0), "bad vTokens");
        require(swapPath.length >= 2, "bad path");

        // Prepare callback params
        FlashData memory data = FlashData({
            pool: pool,
            borrowIsToken0: borrowIsToken0,
            flashAmount: flashAmount,
            borrower: borrower,
            vTokenBorrow: vTokenBorrow,
            vTokenCollateral: vTokenCollateral,
            router: router,
            swapPath: swapPath,
            minDebtOut: minDebtOut
        });

        // Trigger flash; borrow at one leg
        uint amount0 = borrowIsToken0 ? flashAmount : 0;
        uint amount1 = borrowIsToken0 ? 0 : flashAmount;

        IPancakeV3Pool(pool).flash(
            address(this),
            amount0,
            amount1,
            abi.encode(data)
        );
        // After callback completes, flash is repaid. Any leftover tokens remain in this contract as profit.
    }

    /* -------------------------- Pancake v3 Flash Callback ------------------------- */

    /// @dev Called by the Pancake v3 pool after `flash`. We must pay back (amount + fee) inside this function.
    function pancakeV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata _data
    ) external override {
        FlashData memory d = abi.decode(_data, (FlashData));
        require(msg.sender == d.pool, "caller!=pool");

        // ---- scope 1: 计算债务 token 与应还金额（退出作用域释放栈槽） ----
        address debtToken;
        uint256 amountOwed;
        {
            address t0 = IPancakeV3Pool(d.pool).token0();
            address t1 = IPancakeV3Pool(d.pool).token1();
            debtToken = d.borrowIsToken0 ? t0 : t1;
            amountOwed = d.flashAmount + (d.borrowIsToken0 ? fee0 : fee1);
        }

        IVToken vBorrow = IVToken(d.vTokenBorrow);
        IVToken vColl   = IVToken(d.vTokenCollateral);

        // path 端点校验（就地使用返回值，避免额外临时变量）
        require(vColl.underlying() == d.swapPath[0], "path[0]!=collUnderlying");
        require(vBorrow.underlying() == d.swapPath[d.swapPath.length - 1], "path[end]!=debtUnderlying");
        require(vBorrow.underlying() == debtToken, "debtUnderlying!=debtToken");

        // ---- scope 2: 清算 + 赎回 ----
        {
            IERC20(debtToken).safeApprove(address(vBorrow), 0);
            IERC20(debtToken).safeApprove(address(vBorrow), d.flashAmount);
            require(vBorrow.liquidateBorrow(d.borrower, d.flashAmount, address(vColl)) == 0, "liquidate failed");

            uint256 vBal = vColl.balanceOf(address(this));
            require(vBal > 0, "no vTokenCollateral");
            require(vColl.redeem(vBal) == 0, "redeem failed");
        }

        // ---- scope 3: swap 并归还闪电贷（不保存 amounts 数组，直接用余额校验）----
        {
            address collUnderlying = d.swapPath[0];
            uint256 collBal = IERC20(collUnderlying).balanceOf(address(this));
            require(collBal > 0, "no collateral");

            IERC20(collUnderlying).safeApprove(d.router, 0);
            IERC20(collUnderlying).safeApprove(d.router, collBal);

            IPancakeRouter02(d.router).swapExactTokensForTokens(
                collBal,
                d.minDebtOut,
                d.swapPath,
                address(this),
                block.timestamp
            );

            // 直接检查余额足够偿还
            require(IERC20(debtToken).balanceOf(address(this)) >= amountOwed, "insufficient to repay");
            IERC20(debtToken).transfer(d.pool, amountOwed);
            // 剩余即利润，留在合约
        }
    }

    /* ------------------------------- Admin utils ------------------------------- */

    function enterMarkets(address[] calldata vTokens) external onlyOwner {
        comptroller.enterMarkets(vTokens);
    }

    function withdraw(address token, address to) external onlyOwner {
        uint256 bal = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(to, bal);
   }
    }