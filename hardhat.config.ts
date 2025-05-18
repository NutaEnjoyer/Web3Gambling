import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@typechain/hardhat";

const config: HardhatUserConfig = {
  solidity: "0.8.28",
  paths: {
    artifacts: "./artifacts",
    sources: "./contracts",
    tests: "./test",
    cache: "./cache"
  },
  typechain: {
    outDir: "types",
    target: "ethers-v6",
  }
};

export default config;
