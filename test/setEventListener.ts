import { BigNumber } from "ethers";
import { StaykingCraft } from "../crafts";
import { MockValidator } from "./mockValidator";

export const setEventListener = (Stayking: StaykingCraft, mockValidator: MockValidator) => {
    Stayking
        .on("Stake", async function(
            delegator: string,
            user: string,
            amount: BigNumber,
            share: BigNumber,
        ){
            console.log("adsads");
            console.log(amount.toNumber())
            await mockValidator.stake(amount);
        })
        .on("Unstake", async function(
            delegator: string,
            user: string,
            amount: BigNumber,
            share: BigNumber,
        ){
            await mockValidator.unstake(amount);
        })
}