import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { craftform } from "hardhat"
import { StaykingCraft } from "../../crafts";

export const deployVault = async (
    deployer: SignerWithAddress,
    Stayking: StaykingCraft,
    name: string,
    symbol: string,
    token: string,
    interestModel: string,
    minReservedBps: number
) => {
    const vault = await craftform.contract("Vault")
        .deploy(symbol, {
            from: deployer.address,
            proxy: {
                proxyContract: "OpenZeppelinTransparentProxy",
                execute: {
                    init: {
                        methodName: "__Vault_init",
                        args: [
                            name,
                            symbol,
                            Stayking.address,
                            token,
                            interestModel,
                            minReservedBps
                        ]
                    }
                }
            }
        });

    // add vault to Stayking contract
    await Stayking.setVault(token, vault.address);
    return vault;
}