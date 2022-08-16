import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { craftform } from "hardhat"

export const deployStayking = (
    deployer: SignerWithAddress,
    swapHelper: string
) => {
    return craftform.contract("Stayking")
        .deploy(null, {
            from: deployer.address,
            proxy: {
                proxyContract: "OpenZeppelinTransparentProxy",
                execute: {
                    init: {
                        methodName: "__Stayking_init",
                        args: [swapHelper]
                    }
                }
            }
        })
}