import { craftform, ethers } from "hardhat";
import { deployStayking } from "../setup/Stayking";
import { deployTripleSlopeModel } from "../setup/triple-slope-model";
import { deployuEVMOS } from "../setup/uEVMOS";
import { deployVault } from "../setup/vault";
import { toBN } from "../utils";
import "../../crafts";
import { deployMockSwap } from "../setup/mockswap";
import { deployERC20 } from "../setup/erc20";

const ROUTER_ADDRESS = "0xb6b801Aa59970A9247F662F322a5B231503BF126"
const TOKEN_ADDRESS = {
    // tATOM: "",
    mockUSDC: "0xae95d4890bf4471501E0066b6c6244E1CAaEe791",
    mockUSDT: "0x397F8aBd481B7c00883fb70da2ea5Ae70999c37c",
    mockDAI: "0x7c4a1D38A755a7Ce5521260e874C009ad9e4Bf9c",
    mockWEVMOS: "0x3d486E0fBa11f6F929E99a47037A5cd615636E17",
    EVMOS: ethers.constants.AddressZero,
}

async function deployTestnetWithMockswap() {
    const [deployer, delegator] = await ethers.getSigners();

    console.log("deployer value: ", (await deployer.getBalance()).toString());
    console.log("delegator value: ", (await delegator.getBalance()).toString());

    // ERC20 tokens
    // const mockUSDT = await craftform.contract("ERC20").upsertConfig({
    //     alias: "mockUSDT",
    //     address: TOKEN_ADDRESS.mockUSDT
    // });

    const mockUSDC = await deployERC20(deployer, "Mock USDC", "mockUSDC");

    // Deploy MockSwap & MockSwapHelper
    // set evmos_supply here
    const swapHelper = await deployMockSwap(deployer, [mockUSDC], 200);

    const interestModel = await deployTripleSlopeModel(deployer);

    const uEVMOS = await deployuEVMOS(deployer);

    const Stayking = await deployStayking(deployer.address, delegator.address, uEVMOS.address);

    await uEVMOS.updateMinterStatus(Stayking.address, true);

    const ibmockUSDC = await deployVault(
        deployer,
        Stayking,
        swapHelper.address,
        "interest bearing mockUSDC Vault",
        "ibmockUSDC",
        mockUSDC.address,
        interestModel.address,
        1000  // 10%
    );

}

export default deployTestnetWithMockswap;
