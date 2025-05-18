import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("🚀 Deploying contracts with:", deployer.address);

  const VRFMockFactory = await ethers.getContractFactory("VRFCoordinatorV2Mock");
  const vrfCoordinatorMock = await VRFMockFactory.deploy();
  await vrfCoordinatorMock.waitForDeployment();
  const vrfAddress = await vrfCoordinatorMock.getAddress();
  console.log("✅ VRFCoordinatorV2Mock deployed to:", vrfAddress);

  const subTx = await vrfCoordinatorMock.createSubscription();
  await subTx.wait();

  const subId = await vrfCoordinatorMock.s_currentSubId();
  console.log("📦 Subscription ID:", subId.toString());

  // 4. Deploy Casino contract
  const CasinoFactory = await ethers.getContractFactory("Casino");
  const casino = await CasinoFactory.deploy(
    vrfAddress, 
    subId, 
    "0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc", // Key Hash
    3,      
    100000, 
    3       
  );
  await casino.waitForDeployment();
  const casinoAddress = await casino.getAddress();
  console.log("🎰 Casino deployed to:", casinoAddress);

  // 5. Add casino as consumer
  const addConsumerTx = await vrfCoordinatorMock.addConsumer(subId, casinoAddress);
  await addConsumerTx.wait();
  console.log("✅ Casino added as consumer to VRF");
}

main().catch((error) => {
  console.error("❌ Deployment failed:", error);
  process.exitCode = 1;
});