import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { craftform, ethers } from "hardhat"
import { ERC20OwnableCraft } from "../../crafts"
import { toBN, ZERO_ADDRESS } from "../utils"

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

    // change here
    const EVMOS_SUPPLY = 5000;

    if(token0balance.lte(toBN(1, 18))){ // less than 1 ETH
        // add liquidity to swap
        const [_, whale] = await ethers.getSigners();
        console.log(`Add liquidity to MockSwap: ${EVMOS_SUPPLY}EVMOS`);
        await whale.sendTransaction({
            from: whale.address,
            to: MockSwap.address,
            value: ethers.utils.parseEther(EVMOS_SUPPLY+"")
        })
        for await (const Token of Tokens) {
            const liquidity = (await Token.balanceOf(deployer.address)).div(2);
            console.log(`Add liquidity to MockSwap: ${liquidity.toString()}`);
            await Token.transfer(MockSwap.address, liquidity);
        }
    }
    

    return MockSwapHelper;
}