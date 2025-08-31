import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("FlashLiquidatorModule", (m) => {

  const flashLiquidator = m.contract("FlashLiquidator", ["0xD99D1c33F9fC3444f8101754aBC46c52416550D1"]);

  return { flashLiquidator };
});
