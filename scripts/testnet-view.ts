import { ethers } from "hardhat"
import { toBN } from "./utils";

export const testnetView = async () => {
    const stayking = await ethers.getContractAt("Stayking", "0x18A1Af12338d5a0fFF6aADb4364dBd8efF58f3f6");
    const vault = await ethers.getContractAt("Vault", "0x33061E03aa8082d03f0aA66cDCf8159c976fc806");
    // console.log(await ethers.provider.getBalance(stayking.address));

    // console.log((await vault.lastAccruedAt()).toNumber());
    // console.log((await vault.lastAnnualRateBps()).toNumber());
    // console.log(new Date().getTime() / 1000);

    // const ur = await vault.utilizationRateBps();
    // console.log('ur', ur.toString());
    // const ir = await vault.getInterestRate();
    // console.log('ir', ir.toString());
    // const totalAmount = await vault.totalAmount();
    // console.log(
    //     'base Interest',
    //     ir.mul(100 * 60 * 60 * 24 * 365).toString()
    // )
    // console.log('TotalAmount', (await vault.totalAmount()).toString());
    // console.log('Debt Amount', (await vault.totalDebtAmount()).toString());

    // console.log(
    //     (await vault.totalDebtAmount()).mul(1825400).div(10).div(
    //         await vault.totalAmount()
    //     ).toString()
    // );

    const mockToken = await vault.token();
    const jen = "0xb9D40e433b5434fdcba80D405F906143aa354237";
    const danny = "0xc6Ffa5c7aD9c7f46A6f61c04B495c4cc7c77cD33";
    console.log(mockToken.toString());
    const info = await stayking.positionInfo(
        jen, mockToken
    )

    console.log(await stayking.positionIdOf(danny, vault.address));
    console.log(await stayking.positionsLengthOf(vault.address));
    console.log(await stayking.positions(vault.address, '0x0d'));
    console.log(
        await stayking.positionInfo(danny, mockToken)
    )

    console.log(await stayking.totalShare());
    console.log(await stayking.totalAmount());
    
}

testnetView()