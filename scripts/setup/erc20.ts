import { craftform } from "hardhat"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { toBN } from "../utils"

export const deployERC20 = async (deployer: SignerWithAddress, name: string, symbol: string) => {
    const Token = await craftform.contract("ERC20Ownable")
        .deploy(
            symbol, 
            {
                from: deployer.address,
                args: [name, symbol]
            }
        );
    
    // self mint token
    const deployerBalance = await Token.balanceOf(deployer.address)
    if(deployerBalance.toString() === "0") {
        await Token.mint(deployer.address, toBN(1, 24));    // 1E50
        // await Token.mint(deployer.address, toBN(1, 50));
    }
    return Token
}