import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { craftform } from "hardhat"
import { address } from "hardhat-craftform/dist/core"

export const deployStayking = async (
    deployer: address,
    delegator: address,
    uEVMOS: address
) => {
    return craftform.contract("Stayking")
        .deploy(null, {
            from: deployer,
            proxy: {
                proxyContract: "OpenZeppelinTransparentProxy",
                execute: {
                    init: {
                        methodName: "__Stayking_init",
                        args: [delegator, uEVMOS]
                    }
                }
            }
        })
}