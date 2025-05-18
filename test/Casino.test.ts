const { expect } = require('chai');
const { ethers } = require('hardhat');
import type {
    Casino,
    VRFCoordinatorV2Mock,
} from "../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";


describe('Casino', () => { 
    let casino: Casino;
    let vrfCoordinatorMock: VRFCoordinatorV2Mock;
    let player: SignerWithAddress;
    let owner: SignerWithAddress;

    beforeEach(async () => {
        [owner, player] = await ethers.getSigners();
        const Casino = await ethers.getContractFactory('Casino');

        vrfCoordinatorMock = await ethers.getContractFactory("VRFCoordinatorV2Mock");
        const vrfMock = await vrfCoordinatorMock.deploy(0, 0);

        casino = await Casino.deploy(
            vrfCoordinatorMock.address, // VRF Coordinator (пример)
            1,                                          // Subscription ID
            "0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc", // Key Hash
            3,                                          // Confirmations
            100000,                                     // Gas limit
            3                                           // Num words
          );

        await casino.deployed();

        it("Should accept deposits", async () => {
            await casino.connect(player).deposit({ value: ethers.utils.parseEther("1") });
            expect(await casino.balances(player.address)).to.equal(ethers.utils.parseEther("1"));
        });

        it("Should prevent playing without balance", async () => {
            await expect(casino.connect(player).playCoinFlip(ethers.utils.parseEther("0.1"), true))
            .to.be.revertedWith("Insufficient balance");
        });
        })
    })
 })