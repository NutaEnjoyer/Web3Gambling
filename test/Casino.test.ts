const { expect } = require('chai');
const { ethers } = require('hardhat');
import { Interface, id } from "ethers";
import type {
    Casino,
    VRFCoordinatorV2Mock
} from "../types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";


describe('Casino', () => { 
    let casino: Casino;
    let vrfCoordinatorMock: VRFCoordinatorV2Mock;
    let player: SignerWithAddress;
    let owner: SignerWithAddress;

    beforeEach(async () => {
        [owner, player] = await ethers.getSigners();
        const Casino = await ethers.getContractFactory('Casino');

        const VRFMockFactory = await ethers.getContractFactory("VRFCoordinatorV2Mock");
        vrfCoordinatorMock = await VRFMockFactory.deploy();
        await vrfCoordinatorMock.waitForDeployment();
        const vtfAddress = await vrfCoordinatorMock.getAddress();

        const vrfInterface = new Interface([
            "event SubscriptionCreated(uint64 subId, address owner)"
          ]);
        const tx = await vrfCoordinatorMock.createSubscription();
        const receipt = await tx.wait();
        const topic0 = id("SubscriptionCreated(uint64,address)");
        const log = receipt?.logs.find(log => log.topics[0] === topic0);

        if (!log) throw new Error("SubscriptionCreated event not found");

        const parsed = vrfInterface.parseLog(log);
        const subscriptionId = parsed?.args.subId;

        const CasinoFactory = await ethers.getContractFactory('Casino');
        casino = await CasinoFactory.deploy(
            vtfAddress, // VRF Coordinator (пример)
            subscriptionId,                                          // Subscription ID
            "0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc", // Key Hash
            3,                                          // Confirmations
            100000,                                     // Gas limit
            3                                           // Num words
          );
          await casino.waitForDeployment();

          await vrfCoordinatorMock.addConsumer(subscriptionId, await casino.getAddress());
        });

    
        it("Test describe", async () => {
            expect(1).to.equal(1);
        })
        it("Should accept deposits", async () => {
            await casino.connect(player).deposit({ value: ethers.utils.parseEther("1") });
            expect(await casino.balances(player.address)).to.equal(ethers.utils.parseEther("1"));
        });

        it("Should prevent playing without balance", async () => {
            await expect(casino.connect(player).playCoinFlip(ethers.utils.parseEther("0.1"), true))
            .to.be.revertedWith("Insufficient balance");
        });
})