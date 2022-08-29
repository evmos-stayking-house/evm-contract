import { expect } from 'chai'
import { craftform, ethers } from 'hardhat'
import { before } from 'mocha'
import { ERC20OwnableCraft, IVaultConfig, StaykingCraft, UnbondedEvmosCraft, VaultCraft } from '../crafts'
import deployLocal from '../scripts/deploy/localhost'
import { toBN } from '../scripts/utils'
import "../crafts"
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { mine, setBalance } from '@nomicfoundation/hardhat-network-helpers'
import { UnbondedEvmos } from '../typechain-types'
import { setNextBlockTimestamp } from '@nomicfoundation/hardhat-network-helpers/dist/src/helpers/time'


const toUSDC = (usdc: number) => toBN(usdc, 18);
const toEVMOS = (evmos: number) => toBN(evmos, 18);

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

    before(async function (){
        await deployLocal();
        [deployer, delegator, lender1, staker1] = await ethers.getSigners();

        await setBalance(staker1.address, toBN(1000, 18));


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
    
    describe("2. Stayking:: Add/Change position", async function () {
        it("First add position (leverage x3)", async function (){    
            const leverage = 3;
            const equity = toEVMOS(100);
            const debtInBase = equity.mul(leverage - 1);

            const beforeEVMOS = await staker1.getBalance();
            await tUSDC.connect(staker1).approve(ibtUSDC.address, equity);
            // debt: 200 EVMOS = 400 USDC
            await Stayking.connect(staker1).addPosition(
                tUSDC.address,
                equity,
                debtInBase,
                {value: equity}
            );
            const afterEVMOS = await staker1.getBalance();

            expect(beforeEVMOS.sub(afterEVMOS)).to.approximately(equity, toBN(1, 16));
            
            const positionId = await Stayking.positionIdOf(staker1.address, ibtUSDC.address);
            expect(positionId).to.eq(1);
            const [positionValueInBase, positionDebtInBase, debt] = await Stayking.positionInfo(staker1.address, tUSDC.address);

            // equity in position
            expect(positionValueInBase.sub(positionDebtInBase)).to.equal(equity);
            // debt in EVMOS in posittion
            expect(positionDebtInBase).to.equal(debtInBase);
            expect(await ibtUSDC.getBaseIn(debt)).to.equal(debtInBase);

            expect(await ethers.provider.getBalance(ibtUSDC.address)).to.equal(0);
            expect(await ethers.provider.getBalance(Stayking.address)).to.equal(0);
            expect(await delegator.getBalance()).to.equal(positionValueInBase);
        })

        it("Add Equity", async function(){
            const extraEquity = toEVMOS(50);

            const [beforePosVaule, beforeDebtInBase, ] = await Stayking.positionInfo(staker1.address, tUSDC.address);
            const beforeTotalStaked = await delegator.getBalance();
            
            await Stayking.connect(staker1).changePosition(
                tUSDC.address,
                extraEquity,
                0,
                0,
                {value: extraEquity}
            );
            const [afterPosVaule, afterDebtInBase, ] = await Stayking.positionInfo(staker1.address, tUSDC.address);
                
            // position value should be increased
            expect(afterPosVaule.sub(beforePosVaule)).to.equal(extraEquity);
            // debt should not be changed
            expect(afterDebtInBase).to.equal(beforeDebtInBase);

            expect(await ethers.provider.getBalance(Stayking.address)).to.equal(0);
            const afterTotalStaked = await delegator.getBalance();
            expect(afterTotalStaked.sub(beforeTotalStaked)).to.equal(extraEquity);
        })

        it("Add Debt", async function(){
            const extraDebtInBase = toEVMOS(50);

            const [beforePosVaule, beforeDebtInBase, ] = await Stayking.positionInfo(staker1.address, tUSDC.address);
            const beforeTotalStaked = await delegator.getBalance();
            
            // debt: 200 EVMOS + 50 EVMOS = 400 USDC + 100 USDC = 500USDC
            await Stayking.connect(staker1).changePosition(
                tUSDC.address,
                0,
                extraDebtInBase,
                0
            );
            const [afterPosVaule, afterDebtInBase, ] = await Stayking.positionInfo(staker1.address, tUSDC.address);
                
            // position value should be increased
            expect(afterPosVaule.sub(beforePosVaule))
                .to.equal(extraDebtInBase, "Position value not increased properly");
            // debt should be increased
            expect(afterDebtInBase.sub(beforeDebtInBase))
                .to.equal(extraDebtInBase, "Debt value not increased properly");

            expect(await ethers.provider.getBalance(Stayking.address)).to.equal(0);
            const afterTotalStaked = await delegator.getBalance();
            expect(afterTotalStaked.sub(beforeTotalStaked))
                .to.equal(extraDebtInBase);
        })

        it("Cannot borrow debt over debt ratio", async function(){
            const extraDebtInBase = toEVMOS(500);

            const vaultBalance = await ibtUSDC.minReservedBps();
            await expect(
                Stayking.connect(staker1).changePosition(
                    tUSDC.address,
                    0,
                    extraDebtInBase,
                    0
                )
            ).to.be.revertedWith("changePosition: bad debt")
        })

        it("Save Utilization rate", async function(){
            const totalLended = await tUSDC.balanceOf(ibtUSDC.address);
            const userDebt = await ibtUSDC.debtAmountOf(staker1.address);
            const ur = await ibtUSDC.utilizationRateBps();
            // console.log(totalLended.div(toBN(1, 18)).toString());
            // console.log(userDebt.div(toBN(1, 18)).toString());
            // console.log(ur.toString());
        })
    })
    
    describe("3. Unbonded EVMOS(uEVMOS)", async function (){
        function toLocked(lock:UnbondedEvmos.LockedStructOutput){
            return {
                received: lock.received,
                account: lock.account,
                vault: lock.vault,
                share: lock.share.toString(),
                debtShare: lock.debtShare.toString(),
                unlockedAt: new Date(lock.unlockedAt.toNumber() * 1000)
            }
        }
        it("Remove Position", async function (){
            const [beforePosVaule, beforeDebtInBase, ] = await Stayking.positionInfo(staker1.address, tUSDC.address);
            
            const beforeUEvmos = await uEVMOS.balanceOf(staker1.address);
            expect(beforeUEvmos).to.equal(0);
            
            /**
             * Stayking check
             */
            await Stayking.connect(staker1).removePosition(tUSDC.address);
            const afterUEvmos = await uEVMOS.balanceOf(staker1.address);
            const [afterPosVaule, afterDebtInBase, ] = await Stayking.positionInfo(staker1.address, tUSDC.address);
    
            expect(afterUEvmos).to.equal(beforePosVaule);
            expect(afterPosVaule).to.equal(0);
            expect(afterDebtInBase).to.equal(beforeDebtInBase);
            
            /**
             * uEVMOS check
             */
            const uEVMOSTotalAmount = await uEVMOS.totalAmount();
            const uEVMOSTotalSupply = await uEVMOS.totalSupply();
            
            // uEVMOSTotalAmount = beforePosVaule 
            expect(uEVMOSTotalAmount).to.equal(beforePosVaule);
            // totalAmount = totalSupply since share:amount = 1:1 
            expect(uEVMOSTotalSupply).to.equal(uEVMOSTotalAmount);

        })

        it("should unlock after 14(+2) days", async function(){
            const beforeUnlockable = await uEVMOS.getUnlockable(staker1.address);
            expect(beforeUnlockable.unlockable).to.equal(0);
            expect(beforeUnlockable.debt).to.equal(0);
            const [ locked ] = await uEVMOS.lockedList(staker1.address);

            await setNextBlockTimestamp(locked.unlockedAt);
            await mine(1);

            const afterUnlockable = await uEVMOS.getUnlockable(staker1.address);
            expect(afterUnlockable.unlockable).to.equal(locked.share);

            const expectedDebtInBase = await ibtUSDC.getTokenOut(locked.debtShare);
            expect(afterUnlockable.debt).to.equal(expectedDebtInBase);
        })
        
    })
})
