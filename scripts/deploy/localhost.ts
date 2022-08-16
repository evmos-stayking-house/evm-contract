import { ethers } from "hardhat";
import { useCraftform } from "hardhat-craftform"
import { deployERC20 } from "../setup/erc20";
import { deployMockSwap } from "../setup/mockswap";
import { deployStayking } from "../setup/Stayking";
import { deployTripleSlopeModel } from "../setup/triple-slope-model";
import { deployVault } from "../setup/vault";

async function deployLocal() {
  await useCraftform()
  const [deployer] = await ethers.getSigners();

  // Deploy ERC20 tokens
  const tATOM = await deployERC20(deployer, "Local Test ATOM", "tATOM");
  const tUSDC = await deployERC20(deployer, "Local Test USDC", "tUSDC");
  const tUSDT = await deployERC20(deployer, "Local Test USDT", "tUSDT");

  // Deploy MockSwap & MockSwapHelper
  const swapHelper = await deployMockSwap(deployer, [
    tATOM,
    tUSDC,
    tUSDT,
  ]);

  const interestModel = await deployTripleSlopeModel(deployer);

  const Stayking = await deployStayking(deployer, swapHelper.address)
  
  const ibtATOM = await deployVault(
    deployer,
    Stayking,
    "interest bearing tATOM Vault",
    "ibtATOM",
    tATOM.address,
    interestModel.address,
    1000  // 10%
  );

}

export default deployLocal;