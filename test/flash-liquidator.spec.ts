import { expect } from "chai";
import { ethers } from "hardhat";

describe("BscFlashLiquidator - mock end-to-end", function () {
  it("should execute flash liquidation and repay flash loan with profit >= 0", async () => {
    const [owner] = await ethers.getSigners();

    // 1) 部署两种代币：debtToken & collateralUnderlying
    const ERC20 = await ethers.getContractFactory("MockERC20");
    const debt = await ERC20.deploy("DebtToken", "DEBT", 18);
    const coll = await ERC20.deploy("CollToken", "COLL", 18);

    // 给“池子”准备足够的可借出余额
    const POOL_LIQ = ethers.parseEther("100000");
    await debt.mint(owner.address, POOL_LIQ);            // 给 owner 先铸
    // 部署 pool 后把钱转进去
    const Pool = await ethers.getContractFactory("MockPancakeV3Pool");
    const pool = await Pool.deploy(await debt.getAddress(), await coll.getAddress());
    await debt.transfer(await pool.getAddress(), POOL_LIQ);

    // 2) 部署 vTokens（均为 ERC20 underlying 的 vToken）
    const VToken = await ethers.getContractFactory("MockVToken");
    const vDebt = await VToken.deploy(await debt.getAddress());
    const vColl = await VToken.deploy(await coll.getAddress());

    // 3) 部署路由
    const Router = await ethers.getContractFactory("MockRouter");
    const router = await Router.deploy();

    // 4) 部署你的清算合约（把 Comptroller 传个占位地址即可）
    const Liquidator = await ethers.getContractFactory("BscFlashLiquidator");
    const liq = await Liquidator.deploy(ethers.ZeroAddress);

    // 5) 预铸一些抵押“底层资产”到清算合约，以便 redeem 后可 swap（模拟被 seize 的抵押）
    //    实际上 seize 发生在 liquidateBorrow 调用，这里流程会得到 vColl，再 redeem 成 coll
    //    但为了确保 redeem 后合约确实有 coll，这里额外给 vColl 的 redeem 流程提供库存：
    await coll.mint(await vColl.getAddress(), ethers.parseEther("1000000"));

    // 6) 准备执行参数
    const borrowIsToken0 = true;                     // 我们让 token0=debt
    const flashAmount = ethers.parseEther("1000");   // 借 1000 个 debt
    const borrower = ethers.Wallet.createRandom().address; // 随机 borrower 即可（mock 不依赖它）

    // swap path: coll -> debt
    const path = [await coll.getAddress(), await debt.getAddress()];
    const minDebtOut = ethers.parseEther("900");     // 模拟滑点保护

    // 7) 执行：需要先给 vDebt 批准清算时从本合约拉走 debt
    //    注意：批准发生在 callback 内逻辑里，这里只保证我们有足够余额（来自 flash）
    // 8) 触发 flash + 清算全流程
    await liq.executeFlashLiquidation(
      await pool.getAddress(),
      borrowIsToken0,
      flashAmount,
      borrower,
      await vDebt.getAddress(),
      await vColl.getAddress(),
      await router.getAddress(),
      path,
      minDebtOut
    );

    // 9) 校验：池子应已收到 “借款+手续费”
    const fee = flashAmount * 5n / 10000n; // 0.05%
    const need = flashAmount + fee;
    const poolDebtBal = await debt.balanceOf(await pool.getAddress());
    expect(poolDebtBal).to.be.greaterThanOrEqual(POOL_LIQ + need - 1n); // 近似判断

    // 10) 清算合约剩余的债务 token 作为利润（可能为 0）
    const liqDebtLeft = await debt.balanceOf(await liq.getAddress());
    expect(liqDebtLeft).to.be.greaterThanOrEqual(0n);
  });
});
