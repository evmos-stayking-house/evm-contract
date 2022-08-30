import "../crafts"
import { expect } from 'chai'
import { craftform, ethers } from 'hardhat'
import { before } from 'mocha'
import { ERC20OwnableCraft, StaykingCraft, TripleSlopeModelCraft, UnbondedEvmosCraft, VaultCraft } from '../crafts'
import deployLocal from '../scripts/deploy/localhost'
import { toBN } from '../scripts/utils'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { mine, setBalance } from '@nomicfoundation/hardhat-network-helpers'
import { setNextBlockTimestamp } from '@nomicfoundation/hardhat-network-helpers/dist/src/helpers/time'
import { BigNumber } from "ethers"


const toUSDC = (usdc: number) => toBN(usdc, 18);
const toEVMOS = (evmos: number) => toBN(evmos, 18);

describe('EVMOS Hackathon Test', async () => {
    let deployer: SignerWithAddress
    let delegator: SignerWithAddress
    let lender1: SignerWithAddress
    let staker1: SignerWithAddress
    let validator: SignerWithAddress

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
        [deployer, delegator, lender1, staker1, validator] = await ethers.getSigners();

        await setBalance(staker1.address, toBN(1000, 18));
        await setBalance(validator.address, toBN(1000, 30));

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

        it("repay debt (for tUSDC), not changing position value", async function (){
            const repaidDebt = toUSDC(100);
            const repaidDebtInBase = await ibtUSDC.getBaseIn(repaidDebt);

            const [beforePosVaule, beforeDebtInBase, ] = await Stayking.positionInfo(staker1.address, tUSDC.address);
            const beforeTotalStaked = await delegator.getBalance();
            
            // mint & approve tUSDC first 
            await tUSDC.mint(staker1.address, repaidDebt);
            await tUSDC.connect(staker1).approve(Stayking.address, repaidDebt);

            // equity:  150EVMOS            -> 200EVMOS
            // debt:    250EVMOS (=500USDC) -> 200EVMOS (=400USDC)
            await Stayking.connect(staker1).changePosition(
                tUSDC.address,
                0,
                0,
                repaidDebt
            );

            const [afterPosVaule, afterDebtInBase, ] = await Stayking.positionInfo(staker1.address, tUSDC.address);
            const afterTotalStaked = await delegator.getBalance();
            // total staked amount & position value not changes
            expect(afterTotalStaked).to.equal(beforeTotalStaked);
            expect(afterPosVaule).to.equal(beforePosVaule);
            // decreased debt
            expect(beforeDebtInBase.sub(afterDebtInBase)).to.equal(repaidDebtInBase);
        })

        it("repay debt (for EVMOS), not changing position value", async function (){
            const repaidDebtInBase = toEVMOS(50);

            const [beforePosVaule, beforeDebtInBase, ] = await Stayking.positionInfo(staker1.address, tUSDC.address);
            const beforeTotalStaked = await delegator.getBalance();
            
            // equity:  200EVMOS            -> 250EVMOS
            // debt:    200EVMOS (=400USDC) -> 150EVMOS (=300USDC)
            await Stayking.connect(staker1).changePosition(
                tUSDC.address,
                0,
                0,
                0,
                {value: repaidDebtInBase}
            );

            const [afterPosVaule, afterDebtInBase, ] = await Stayking.positionInfo(staker1.address, tUSDC.address);
            const afterTotalStaked = await delegator.getBalance();
            // total staked amount & position value not changes
            expect(afterTotalStaked).to.equal(beforeTotalStaked);
            expect(afterPosVaule).to.equal(beforePosVaule);
            // decreased debt
            expect(beforeDebtInBase.sub(afterDebtInBase)).to.equal(repaidDebtInBase);
        })

        it("cannot borrow debt over debt ratio", async function(){
            const extraDebtInBase = toEVMOS(500);
            await expect(
                Stayking.connect(staker1).changePosition(
                    tUSDC.address,
                    0,
                    extraDebtInBase,
                    0
                )
            ).to.be.revertedWith("changePosition: bad debt")
        })

        it("returns utilization rate properly.", async function(){
            const totalLended = await tUSDC.balanceOf(ibtUSDC.address);
            const userDebt = await ibtUSDC.debtAmountOf(staker1.address);
            const ur = await ibtUSDC.utilizationRateBps();

            expect(userDebt.mul(1E4).div(totalLended.add(userDebt))).to.equal(ur);
        })

        it("saves utilization rate on next day.", async function(){
            const beforeYesterdayUR = await ibtUSDC.yesterdayUtilRate();
            const timestamp = new Date();

            // 1. after 12 hours
            timestamp.setHours(timestamp.getHours() + 12);
            await setNextBlockTimestamp(timestamp);
            await mine(1);
            await ibtUSDC.saveUtilizationRateBps();
            // 12 hours later, yesterday util rate not changes
            expect(await ibtUSDC.yesterdayUtilRate()).to.equal(beforeYesterdayUR)
            
            // 2. after +12 hours (after 1 day)
            timestamp.setHours(timestamp.getHours() + 12);
            await setNextBlockTimestamp(timestamp);
            await mine(1);
            await ibtUSDC.saveUtilizationRateBps();

            // 1 day later, yesterday util rate changed
            expect(await ibtUSDC.yesterdayUtilRate())
                .to.equal(await ibtUSDC.utilizationRateBps());
        })
    })

    describe("3. Lock uEVMOS", async function (){
        // function toLocked(lock:UnbondedEvmos.LockedStructOutput){
        //     return {
        //         received: lock.received,
        //         account: lock.account,
        //         vault: lock.vault,
        //         share: lock.share.toString(),
        //         debtShare: lock.debtShare.toString(),
        //         unlockedAt: new Date(lock.unlockedAt.toNumber() * 1000)
        //     }
        // }
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

    describe("4. Interest Moel: Triple Slope Model", async function (){
        let model:TripleSlopeModelCraft;
        const secondsInYear = 365 * 24 * 60 * 60;

        before(async function(){
            model = await craftform.contract("TripleSlopeModel").attach();
        })

        it("TripleSlopeModel Case 1 : debt ratio = 0%", async function (){
            const maybe0 = await model.calcInterestRate(
                0,
                toBN(100, 24)
            );
            expect(maybe0).to.eq(0);
        })

        it("TripleSlopeModel Case 2 : debt ratio = 30%", async function (){
            // x < 60 => x/3%
            const expected = toBN(10, 16).div(secondsInYear);
            const rate = await model.calcInterestRate(
                toBN(30, 24),
                toBN(70, 24)
            );
            expect(rate).to.equal(expected);
        })

        it("TripleSlopeModel Case 3 : debt ratio = 60%", async function (){
            // 60 <= x <= 90 => 20%
            const expected = toBN(20, 16).div(secondsInYear);
            const rate = await model.calcInterestRate(
                toBN(60, 24),
                toBN(40, 24)
            );
            expect(rate).to.equal(expected);
        })

        it("TripleSlopeModel Case 4 : debt ratio = 75%", async function (){
            // 60 <= x <= 90 => 20%
            const expected = toBN(20, 16).div(secondsInYear);
            const rate = await model.calcInterestRate(
                toBN(75, 24),
                toBN(25, 24)
            );
            expect(rate).to.equal(expected);
        })

        it("TripleSlopeModel Case 5 : debt ratio = 90%", async function (){
            // 60 <= x <= 90 => 20%
            const expected = toBN(20, 16).div(secondsInYear);
            const rate = await model.calcInterestRate(
                toBN(90, 24),
                toBN(10, 24)
            );
            expect(rate).to.equal(expected);
        })

        it("TripleSlopeModel Case 6 : debt ratio = 99%", async function (){
            // x > 90 => 13x - 1150
            const x = 99;
            const expected = toBN(13 * x - 1150, 16).div(secondsInYear);
            const rate = await model.calcInterestRate(
                toBN(99, 24),
                toBN( 1, 24)
            );
            expect(rate).to.equal(expected);
        })
    })

    describe("5. Delegator, accrue when auto-compounding", async function(){
        async function claim(beforeTotalStaked: BigNumber, aprBps?: number){
            if(!aprBps){
                // Random APR : 10% ~ 400%
                aprBps = Math.floor(10 + 390 * Math.random());
            }
            const reward = beforeTotalStaked.mul(aprBps).div(1E4).div(365);
            await validator.sendTransaction({
                from: validator.address,
                to: delegator.address,
                value: reward
            });
        }

        async function nextDayOf(date:Date){
            const tomorrow = new Date(date);
            tomorrow.setDate(date.getDate() + 1);

            await mine(1);
            await setNextBlockTimestamp(tomorrow);
        }

        it("calculates accumulated interest & revenue", async function(){
            const today = new Date();
            
            const interest = await ibtUSDC.getInterestInBase();
            // console.log(interest.toString());
        })
    })
})
