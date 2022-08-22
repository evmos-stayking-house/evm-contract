import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { craftform, ethers } from "hardhat"
import { ERC20OwnableCraft } from "../../crafts"
import { ZERO_ADDRESS } from "../utils"

export const deployMockSwap = async (deployer: SignerWithAddress, Tokens: ERC20OwnableCraft[]) => {
    const MockSwap = await craftform.contract("MockSwap")
        .deploy(null, {
            from: deployer.address,
            args: [
                [ZERO_ADDRESS, ...Tokens.map(t => t.address)]
            ]
        })

    const MockSwapHelper = await craftform.contract("MockSwapHelper")
        .deploy(null, {
            from: deployer.address,
            args: [MockSwap.address]
        })
    
    // check balance of MockSwap in Tokens[0]
    // if MockSwap has balance => liquidity has already been added.
    const token0balance = await Tokens[0].balanceOf(MockSwap.address);

    if(token0balance.toString() === "0"){
        // add liquidity to swap
        const [_, whale] = await ethers.getSigners();
        console.log(`Add liquidity to MockSwap: 5000EVMOS`);
        await whale.sendTransaction({
            from: whale.address,
            to: MockSwap.address,
            value: ethers.utils.parseEther("5000")
        })
        for await (const Token of Tokens) {
            const liquidity = (await Token.balanceOf(deployer.address)).div(2);
            console.log(`Add liquidity to MockSwap: ${liquidity.toString()}`);
            await Token.transfer(MockSwap.address, liquidity);
        }
    }
    

    return MockSwapHelper;
}