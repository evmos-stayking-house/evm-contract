import { craftform, ethers } from "hardhat";
import { deployStayking } from "../setup/Stayking";
import { deployTripleSlopeModel } from "../setup/triple-slope-model";
import { deployuEVMOS } from "../setup/uEVMOS";
import { deployVault } from "../setup/vault";
import { toBN } from "../utils";
import "../../crafts";

const ROUTER_ADDRESS = "0xb6b801Aa59970A9247F662F322a5B231503BF126"
const TOKEN_ADDRESS = {
    // tATOM: "",
    mockUSDC: "0xae95d4890bf4471501E0066b6c6244E1CAaEe791",
    mockUSDT: "0x397F8aBd481B7c00883fb70da2ea5Ae70999c37c",
    mockDAI: "0x7c4a1D38A755a7Ce5521260e874C009ad9e4Bf9c",
    mockWEVMOS: "0x3d486E0fBa11f6F929E99a47037A5cd615636E17",
    EVMOS: ethers.constants.AddressZero,
}

async function deployTestnetWithEvmoswap() {
    const [deployer] = await ethers.getSigners();
    console.log("deployer value: ", (await deployer.getBalance()).div(toBN(1, 18)).toString())

    const EvmoSwapHelper = await craftform.contract("EvmoSwapHelper").deploy(
        null,
        {
            from: deployer.address,
            args: [ROUTER_ADDRESS]
        }
    )

    // ERC20 tokens
    const mockUSDT = await craftform.contract("ERC20").upsertConfig({
        alias: "mockUSDT",
        address: TOKEN_ADDRESS.mockUSDT
    });

    // const mockUSDC = await craftform.contract("ERC20").upsertConfig({
    //     alias: "mockUSDC",
    //     address: TOKEN_ADDRESS.mockUSDC
    // });

    const interestModel = await deployTripleSlopeModel(deployer);

    const uEVMOS = await deployuEVMOS(deployer);

    const Stayking = await deployStayking(deployer.address, deployer.address, uEVMOS.address);

    await uEVMOS.updateMinterStatus(Stayking.address, true);
    
    const ibmockUSDT = await deployVault(
        deployer,
        Stayking,
        EvmoSwapHelper.address,
        "interest bearing mockUSDT Vault",
        "ibmockUSDT",
        mockUSDT.address,
        interestModel.address,
        1000  // 10%
    );

}

export default deployTestnetWithEvmoswap;