import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { craftform } from "hardhat"

export const deployuEVMOS = (deployer: SignerWithAddress) => {
    // @TODO maybe 16 days?
    const unbondingInterval = 16 * 24 * 60 * 60;

    return craftform.contract("UnbondedEvmos")
        .deploy(null, 
            {
                from: deployer.address,
                proxy: {
                    proxyContract: "OpenZeppelinTransparentProxy",
                    execute: {
                        init: {
                            methodName: "__UnbondedEvmos_init",
                            args: [unbondingInterval]
                        }
                    }
                }
            }
        )
}