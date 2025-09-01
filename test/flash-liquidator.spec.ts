const { expect } = require("chai");
const { ethers } = require("hardhat");
const { BscFlashLiquidator, MockERC20, MockVToken } = require("../typechain-types");

describe("BscFlashLiquidator Venus Liquidation Tests", () => {
  let liquidator, mockToken, mockVToken, owner;

  beforeEach(async () => {
    [owner] = await ethers.getSigners();
    const MockERC20Factory = await ethers.getContractFactory("MockERC20");
    mockToken = await MockERC20Factory.deploy("MockUSDT", "USDT");

    const MockVTokenFactory = await ethers.getContractFactory("MockVToken");
    mockVToken = await MockVTokenFactory.deploy(mockToken.address);

    const LiquidatorFactory = await ethers.getContractFactory("BscFlashLiquidator");
    liquidator = await LiquidatorFactory.deploy(/* Venus params */);

    // 模拟借款/不足抵押
    await mockToken.mint(owner.address, ethers.utils.parseEther("1000"));
    await mockToken.approve(mockVToken.address, ethers.utils.parseEther("1000"));
    await mockVToken.mockBorrow(owner.address, ethers.utils.parseEther("500"));  // 模拟借款
  });

  it("Should liquidate undercollateralized position", async () => {
    // 模拟清算条件
    await mockVToken.setUndercollateralized(owner.address, true);

    // 执行清算
    await liquidator.liquidate(owner.address, mockVToken.address, ethers.utils.parseEther("250"));

    expect(await mockVToken.balanceOf(liquidator.address)).to.be.gt(0);  // 清算获利
  });
});
