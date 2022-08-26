import { expect } from 'chai'
import { craftform, ethers } from 'hardhat'
import { before } from 'mocha'
import { ERC20OwnableCraft, StaykingCraft, UnbondedEvmosCraft, VaultCraft } from '../crafts'
import deployLocal from '../scripts/deploy/localhost'
import { toBN } from '../scripts/utils'
import "../crafts"
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'


const toUSDC = (usdc: number) => toBN(usdc, 18);
describe('EVMOS Hackathon', async () => {
    let deployer: SignerWithAddress
    let delegator: SignerWithAddress
    let lender1: SignerWithAddress
    let staker1: SignerWithAddress

    let tUSDC:ERC20OwnableCraft;
    let ibtUSDC:VaultCraft;
    let Stayking:StaykingCraft;
    let uEVMOS:UnbondedEvmosCraft;

    // returns balance of tUSDC & ibtUSDC
    async function getBalances(address: string){
        const usdc = await tUSDC.balanceOf(address);
        const ibUsdc = await ibtUSDC.balanceOf(address);
        return [usdc, ibUsdc]
    }

    before(async () => {
        await deployLocal();
        const [deployer, delegator, lender1, staker1] = await ethers.getSigners();
        tUSDC = await craftform.contract("ERC20Ownable").attach("tUSDC");
        ibtUSDC = await craftform.contract("Vault").attach("ibtUSDC");
        Stayking = await craftform.contract("Stayking").attach();
        uEVMOS = await craftform.contract("UnbondedEvmos").attach();

        await tUSDC.mint(lender1.address, toUSDC(100000));
        await tUSDC.mint(staker1.address, toUSDC(100000));
    })

    describe("1. Vault:: initial deployed", async function (){
        it("config settings", async function () {
            const staykingInVault = await ibtUSDC.stayking();
            expect(staykingInVault).to.eq(Stayking.address);
        })

        it("First time deposit & withdraw", async function () {
            /**
             * step 0 : before start
             * step 1 : deposit   5 USDC
             * step 2 : withdraw  5 USDC
             * step 3 : deposit   10000 USDC (initial liquidity)
             */
            
            const depositAmount = toUSDC(5);
    
            // Step 0 balance status
            const [step0Amount, step0Share] = await getBalances(lender1.address);
    
            // Step 1. deposit (approve first)
            await tUSDC.connect(lender1).approve(ibtUSDC.address, depositAmount);
            await ibtUSDC.connect(lender1).deposit(depositAmount);
    
            // after Step 1 balance status
            // at initial deposit, USDC : ibUSDC ratio = 1
            const [step1Amount, step1Share] = await getBalances(lender1.address);
            expect(step0Amount.sub(step1Amount)).eq(depositAmount);
            expect(step1Share.sub(step0Share)).eq(depositAmount);
    
            // Step 2. withdraw
            await ibtUSDC.connect(lender1).withdraw(step1Share);
    
            // after Step 2 balance status
            const [step2Amount, step2Share] = await getBalances(lender1.address);
            expect(step2Share).eq(0);
            expect(step2Amount.sub(step0Amount));
    
            // Step 3. deposit again (initial liquidity)
            const liquidity = toUSDC(10000);
            await tUSDC.connect(lender1).approve(ibtUSDC.address, liquidity);
            await ibtUSDC.connect(lender1).deposit(liquidity);
    
            // after Step 1 balance status
            // at initial deposit, USDC : ibUSDC ratio = 1
            const [step3Amount, step3Share] = await getBalances(lender1.address);
            expect(step2Amount.sub(step3Amount)).eq(liquidity);
            expect(step3Share.sub(step2Share)).eq(liquidity);
        })

        it("Interest should be ZERO.", async function (){            
            const ir = await ibtUSDC.getInterestRate();
            // interest rate should be 0 (since total debt: 0)
            expect(ir).eq(0)
        })
    
    })
    
    describe("2. Stayking:: Add/Handle position", async function () {
        it("Add Position x3 leverage", async function (){    
            const leverage = 3;
            const equity = toUSDC(100);
            const debtInBase = equity.mul(leverage - 1);

            await tUSDC.connect(staker1).approve(ibtUSDC.address, equity);
            await Stayking.connect(staker1).addPosition(
                tUSDC.address,
                equity,
                debtInBase,
                {value: equity}
            );
        })
    })
})
