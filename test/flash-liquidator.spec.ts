import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { BscFlashLiquidator, MockERC20, MockVToken } from "../typechain-types";  // 调整如果路径错

describe("BscFlashLiquidator Tests", () => {
  async function deployFixture() {
    const [owner] = await ethers.getSigners();

    // Mock USDT
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    const usdt = await MockERC20.deploy("USDT", "USDT", 18);

    // Mock vUSDT (Venus-like)
    const MockVToken = await ethers.getContractFactory("MockVToken");
    const vUSDT = await MockVToken.deploy(usdt.address);

    // Mock Collateral Token (e.g., vBNB for liquidation)
    const bnb = await MockERC20.deploy("BNB", "BNB", 18);
    const vBNB = await MockVToken.deploy(bnb.address);

    // Deploy Liquidator (假设无参构造函数；调整如果需Venus Comptroller/Pool地址)
    const BscFlashLiquidator = await ethers.getContractFactory("BscFlashLiquidator");
    const liquidator = await BscFlashLiquidator.deploy();
    await liquidator.waitForDeployment();

    // 模拟不良贷款：owner抵押500 USDT，借600（over-borrow，假设mock中borrow允许）
    await usdt.mint(owner.address, ethers.parseUnits("1000", 18));
    await usdt.connect(owner).approve(vUSDT.address, ethers.parseUnits("500", 18));
    await vUSDT.connect(owner).mint(ethers.parseUnits("500", 18));  // 抵押
    await bnb.mint(vUSDT.address, ethers.parseUnits("1000", 18));  // mock流动性
    await vUSDT.connect(owner).borrow(ethers.parseUnits("600", 18));  // 过借，模拟shortfall

    // 批准liquidator使用token（如果需flash/liquidate）
    await usdt.connect(owner).approve(liquidator.address, ethers.parseUnits("1000", 18));

    return { liquidator, owner, vUSDT, vBNB };
  }

  it("Should simulate bad loan and check liquidity", async () => {
    const { owner, vUSDT } = await loadFixture(deployFixture);
    const balance = await vUSDT.borrowBalanceStored(owner.address);
    expect(balance).to.be.gt(ethers.parseUnits("500", 18));  // 确认借额 > 抵押，模拟不良
  });

  it("Should execute flash liquidation successfully", async () => {
    const { liquidator, owner, vUSDT, vBNB } = await loadFixture(deployFixture);
    const initialBorrow = await vUSDT.borrowBalanceStored(owner.address);

    // 调用清算（假设liquidate函数：borrower, vTokenBorrowed, vTokenCollateral, repayAmount；调整为您的签名）
    await liquidator.liquidate(owner.address, vUSDT.address, vBNB.address, ethers.parseUnits("300", 18));

    const finalBorrow = await vUSDT.borrowBalanceStored(owner.address);
    expect(finalBorrow).to.be.lt(initialBorrow);  // 确认清算减少借额
  });
});
