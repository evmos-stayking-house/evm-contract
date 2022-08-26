import { craftform, ethers } from "hardhat";
import deployLocal from "../scripts/deploy/localhost"
import { toBN } from "../scripts/utils";
import "../crafts"

describe("EVMOS Hackathon", async function (){
    before("base setup", async function (){
        await deployLocal();
    })
    
    it("add position", async function(){
        const [signer] = await ethers.getSigners();
        const tATOM = await craftform.contract("ERC20Ownable").attach("tATOM");
        const ibtATOM = await craftform.contract("Vault").attach("ibtATOM");
        const Stayking = await craftform.contract("Stayking").attach();
        // console.log(await tATOM.balanceOf(signer.address));

        await tATOM.approve(ibtATOM.address, toBN(500, 38));
        await ibtATOM.deposit(toBN(300, 26));
        

        await tATOM.approve(Stayking.address, toBN(100, 18));
        await Stayking.addPosition(
            tATOM.address,
            toBN(100, 18),
            toBN(200, 18),
            {value: toBN(100, 18)}
        )
        
        
    })
})