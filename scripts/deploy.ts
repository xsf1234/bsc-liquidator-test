import hre from "hardhat";

async function main() {
  console.log("hre.ethers 是否可用:", !!hre.ethers);

  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying from:", deployer.address);

  const FlashLiquidator = await hre.ethers.getContractFactory("FlashLiquidator");
  const contract = await FlashLiquidator.deploy(/* 参数，如 "0xPancakeRouterAddress" */);
  await contract.waitForDeployment();
  const address = await contract.getAddress();
  console.log(`FlashLiquidator deployed to: ${address}`);

  await new Promise(resolve => setTimeout(resolve, 10000));

  console.log("Verifying contract on BscScan...");
  await hre.run("verify:verify", {
    address,
    constructorArguments: [/* 参数数组 */],
  });
  console.log("Verified!");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
