import { deployments, ethers } from "hardhat"
import { toBN } from "./utils";

const StaykingAddress = "0x5c16AD45ec86A50a59b4fe7d9B205aCa2100de2f"
const VaultAddress = "0xa6c036c12b65703Bd7C0e4F42Dc0E75f74675C64"

export const redeploy = async () => {
    const stayking = await ethers.getContractAt("Stayking", StaykingAddress);
    const vault = await ethers.getContractAt("Vault", VaultAddress);
    const [deployer] = await ethers.getSigners();

    // await stayking.updateWhitelistedKillerStatus(
    //     ["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"],
    //     true
    // );
    // const deploy = await deployments.deploy("Vault", {
    //     contract: "Vault",
    //     from: deployer.address,
    //     proxy: {
    //         proxyContract: 'OpenZeppelinTransparentProxy',
    //         owner: deployer.address,
    //       }
    // });

}

redeploy()