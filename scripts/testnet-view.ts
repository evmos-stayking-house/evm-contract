import { parseEther } from 'ethers/lib/utils';
import { deployments, ethers } from 'hardhat';
import { toBN } from './utils';

const StaykingAddress = '0x5c16AD45ec86A50a59b4fe7d9B205aCa2100de2f';
const VaultAddress = '0xa6c036c12b65703Bd7C0e4F42Dc0E75f74675C64';

export const redeploy = async () => {
    const stayking = await ethers.getContractAt('Stayking', StaykingAddress);
    const vault = await ethers.getContractAt('Vault', VaultAddress);
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
    const [base, bonus] = await vault.getAccruedRateBps();
    // console.log(base.toString());
    // console.log(bonus.toString());
    // console.log(
    //     base.div(parseEther("1")).toNumber() +
    //     bonus.toNumber() * 1.8
    // )

    await stayking.updateConfigs(
        toBN(1, 16), // minDebtInBase (0.01EVMOS)
        3000, // reservedBps
        2000, // vaultRewardBps
        7500, // killFactorBps
        7500, // liquidateDebtFactorBps
        500 // liquidationFeeBps
    );

    // console.log(base.div(parseEther("1")).toNumber())
    // console.log(bonus.toNumber() * 1.8)
    // const totalDebt = await vault.totalDebtAmount();
    // console.log(base.toString())
    // console.log(bonus.toString())
    // const realbase = (
    //     await vault.getInterestRate()
    // ).mul(1E4).mul(totalDebt).mul(365*86400).div(await vault.totalAmount()).div(parseEther("1"));
    // console.log((await vault.utilizationRateBps()).toString());
    // console.log(realbase.toString());
    // console.log(
    //     realbase.toNumber()
    //     + bonus.toNumber() * 1.8 * 365)
};

redeploy();
