import { craftform, ethers } from "hardhat";
import { deployERC20 } from "../setup/erc20";
import { deployMockSwap } from "../setup/mockswap";
import { deployStayking } from "../setup/Stayking";
import { deployTripleSlopeModel } from "../setup/triple-slope-model";
import { deployuEVMOS } from "../setup/uEVMOS";
import { deployVault } from "../setup/vault";
import "../../crafts";
import { toBN } from "../utils";

const TOKEN_ADDRESS = {
    // tATOM: "",
    mockUSDC: "0xae95d4890bf4471501E0066b6c6244E1CAaEe791",
    mockUSDT: "0x397F8aBd481B7c00883fb70da2ea5Ae70999c37c",
    mockDAI: "0x7c4a1D38A755a7Ce5521260e874C009ad9e4Bf9c",
    mockWEVMOS: "0x3d486E0fBa11f6F929E99a47037A5cd615636E17"
}

async function deployTestnet() {

    const EVMOSwap = await craftform.contract("EvmoSwapRouter").upsertConfig({
        address: "0xb6b801Aa59970A9247F662F322a5B231503BF126",
        alias: "EvmoSwapRouter"
    });

    const val = await EVMOSwap.getAmountsOut(
        toBN(1, 6), 
        [
            TOKEN_ADDRESS.mockUSDC,
            TOKEN_ADDRESS.mockUSDT,
        ]
    )


    // const [deployer, delegator] = await ethers.getSigners();


    // // Deploy ERC20 tokens
    // const tATOM = await craftform.contract("ERC20").upsertConfig({
    //     alias: "tATOM",
    //     address: ""
    // })
    // const tUSDC = await deployERC20(deployer, "Local Test USDC", "tUSDC");
    // const tUSDT = await deployERC20(deployer, "Local Test USDT", "tUSDT");

    // // Deploy MockSwap & MockSwapHelper
    // const swapHelper = await deployMockSwap(deployer, [
    //     tATOM,
    //     tUSDC,
    //     tUSDT,
    // ]);

    // const interestModel = await deployTripleSlopeModel(deployer);

    // const uEVMOS = await deployuEVMOS(deployer);

    // const Stayking = await deployStayking(deployer.address, delegator.address, uEVMOS.address);

    // await uEVMOS.updateMinterStatus(uEVMOS.address, true);
    
    // const ibtATOM = await deployVault(
    //     deployer,
    //     Stayking,
    //     swapHelper.address,
    //     "interest bearing tATOM Vault",
    //     "ibtATOM",
    //     tATOM.address,
    //     interestModel.address,
    //     1000  // 10%
    // );

}

export default deployTestnet;