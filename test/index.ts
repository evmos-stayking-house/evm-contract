import "../crafts"
import { expect } from 'chai'
import { craftform, ethers } from 'hardhat'
import { before } from 'mocha'
import { ERC20OwnableCraft, StaykingCraft, TripleSlopeModelCraft, UnbondedEvmosCraft, VaultCraft } from '../crafts'
import deployLocal from '../scripts/deploy/localhost'
import { toBN } from '../scripts/utils'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { mine, setBalance } from '@nomicfoundation/hardhat-network-helpers'
import { latestBlock, setNextBlockTimestamp } from '@nomicfoundation/hardhat-network-helpers/dist/src/helpers/time'
import { MockValidator } from "./mockValidator"


const toUSDC = (usdc: number) => toBN(usdc, 18);
const toEVMOS = (evmos: number) => toBN(evmos, 18);

describe('EVMOS Hackathon Test', async () => {
    let deployer: SignerWithAddress
    let delegator: SignerWithAddress
    let lender1: SignerWithAddress
    let staker1: SignerWithAddress
    let validator: SignerWithAddress
    let locker: SignerWithAddress
    let mockValidator: MockValidator

    let tUSDC:ERC20OwnableCraft;
    let ibtUSDC:VaultCraft;
    let Stayking:StaykingCraft;
    let uEVMOS:UnbondedEvmosCraft;

    async function now(){
        const lastBlockNumber = await latestBlock();
        const block = await ethers.provider.getBlock(lastBlockNumber);
        return block.timestamp;
    }
    async function timeTravel(seconds: number){
        const destination = new Date((await now() + seconds) * 1000);
        await mine(1);
        await setNextBlockTimestamp(destination);
        return destination;
    }
    async function toNextDay(){
        return timeTravel(86400);
    }
    async function toNextHour(){
        return timeTravel(3600);
    }

    before(async function (){
        await deployLocal();
        [deployer, delegator, lender1, staker1, validator, locker] = await ethers.getSigners();

        await setBalance(staker1.address, toBN(10000, 18));
        await setBalance(delegator.address, toBN(10000, 18));
        await setBalance(validator.address, toBN(1000, 30));

        tUSDC = await craftform.contract("ERC20Ownable").attach("tUSDC");
        ibtUSDC = await craftform.contract("Vault").attach("ibtUSDC");
        Stayking = await craftform.contract("Stayking").attach();
        uEVMOS = await craftform.contract("UnbondedEvmos").attach();

        const unbondedInterval = await uEVMOS.unbondingInterval();
        
        mockValidator = new MockValidator(
            delegator,
            validator,
            uEVMOS,
            unbondedInterval.toNumber()
        );

        await Stayking.changeDelegator(delegator.address);

        await tUSDC.mint(lender1.address, toUSDC(100000));
        await tUSDC.mint(staker1.address, toUSDC(100000));
    })


    describe("1. Vault:: initial deployed", async function (){
        it("config settings", async function () {
            const staykingInVault = await ibtUSDC.stayking();
            expect(staykingInVault).to.eq(Stayking.address);

            expect(await Stayking.delegator()).to.equal(delegator.address);
        })

        it("First time deposit & withdraw", async function () {
            // returns balance of tUSDC & ibtUSDC
            async function getBalances(address: string){
                const usdc = await tUSDC.balanceOf(address);
                const ibUsdc = await ibtUSDC.balanceOf(address);
                return [usdc, ibUsdc]
            }
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
            const tx = await Stayking.connect(staker1).addPosition(
                tUSDC.address,
                equity,
                debtInBase,
                {value: equity}
            );

            await mockValidator.handleTx(tx);

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

            expect(mockValidator.amount).to.equal(positionValueInBase);
        })

        it("accrued interest on next day is valid", async function (){
            // before interest : approximately 0
            const beforeAccInterest = await ibtUSDC.accInterest();

            await toNextDay();
            await ibtUSDC.accrue(); // +1 sec

            // maybe 4E18
            const totalStakedDebt = await ibtUSDC.totalStakedDebtAmount();

            // maybe 400 (4%)
            const ur = await ibtUSDC.utilizationRateBps();

            // expected interest = (1E18 / 365) x * 1E14 * (x/3) / 365
            const expectedIR = toBN(1, 18).mul(ur).div(1E4).div(3).div(365 * 86400);
            const ir = await ibtUSDC.getInterestRate();
            expect(ir).to.equal(expectedIR);

            // => x/3 : interest rate
            const expected = expectedIR.mul(totalStakedDebt.add(beforeAccInterest)).mul(86400+1).div(toBN(1, 18));
            const afterAccInterest = await ibtUSDC.accInterest();

            expect(afterAccInterest.sub(beforeAccInterest)).to.equal(expected);
        })

        it("Add Equity", async function(){
            const extraEquity = toEVMOS(50);

            const [beforePosVaule, beforeDebtInBase, ] = await Stayking.positionInfo(staker1.address, tUSDC.address);
            const beforeTotalStaked = mockValidator.amount;
            
            const tx = await Stayking.connect(staker1).changePosition(
                tUSDC.address,
                extraEquity,
                0,
                0,
                {value: extraEquity}
            );
            await mockValidator.handleTx(tx);


            const [afterPosVaule, afterDebtInBase, ] = await Stayking.positionInfo(staker1.address, tUSDC.address);
                
            // position value should be increased
            expect(afterPosVaule.sub(beforePosVaule)).to.equal(extraEquity);
            // debt should not be changed
            expect(afterDebtInBase).to.equal(beforeDebtInBase);

            expect(await ethers.provider.getBalance(Stayking.address)).to.equal(0);
            expect(mockValidator.amount).to.equal(beforeTotalStaked.add(extraEquity));
        })

        it("Add Debt", async function(){
            const extraDebtInBase = toEVMOS(50);

            const [beforePosVaule, beforeDebtInBase, ] = await Stayking.positionInfo(staker1.address, tUSDC.address);
            const beforeTotalStaked = mockValidator.amount;
            
            // debt: 200 EVMOS + 50 EVMOS = 400 USDC + 100 USDC = 500USDC
            const tx = await Stayking.connect(staker1).changePosition(
                tUSDC.address,
                0,
                extraDebtInBase,
                0
            );
            await mockValidator.handleTx(tx);

            const [afterPosVaule, afterDebtInBase, ] = await Stayking.positionInfo(staker1.address, tUSDC.address);
                
            // position value should be increased
            expect(afterPosVaule.sub(beforePosVaule))
                .to.equal(extraDebtInBase, "Position value not increased properly");
            // debt should be increased
            expect(afterDebtInBase.sub(beforeDebtInBase))
                .to.equal(extraDebtInBase, "Debt value not increased properly");

            const isKillable = await Stayking.isKillable(tUSDC.address, 1);
            expect(isKillable).to.false;

            expect(await ethers.provider.getBalance(Stayking.address)).to.equal(0);
            expect(mockValidator.amount)
                .to.equal(beforeTotalStaked.add(extraDebtInBase));
        })

        it("Cannot borrow debt over debt ratio", async function(){
            const extraDebtInBase = toEVMOS(1000);
            await expect(
                Stayking.connect(staker1).changePosition(
                    tUSDC.address,
                    0,
                    extraDebtInBase,
                    0
                )
            ).to.be.revertedWith("changePosition: bad debt");
        })

        it("returns utilization rate properly.", async function(){
            const totalLended = await tUSDC.balanceOf(ibtUSDC.address);
            const userDebt = await ibtUSDC.debtAmountOf(staker1.address);
            const ur = await ibtUSDC.utilizationRateBps();

            expect(userDebt.mul(1E4).div(totalLended.add(userDebt))).to.equal(ur);
        })

        it("saves utilization rate on next day.", async function(){
            const beforeYesterdayUR = await ibtUSDC.yesterdayUtilRate();

            // 1. after 1 hour
            await toNextHour()
            await ibtUSDC.saveUtilizationRateBps();
            // 1 hour later, yesterday util rate not changes
            expect(await ibtUSDC.yesterdayUtilRate()).to.equal(beforeYesterdayUR)
            
            // 2. after +12 hours (after 1 day)
            await timeTravel(43200);
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
            const tx = await Stayking.connect(staker1).removePosition(tUSDC.address);
            await mockValidator.handleTx(tx);

            const afterUEvmos = await uEVMOS.balanceOf(staker1.address);
            const [afterPosVaule, afterDebtInBase, ] = await Stayking.positionInfo(staker1.address, tUSDC.address);
            const pendingDebt = await ibtUSDC.getPendingDebtInBase(staker1.address);
    
            expect(afterUEvmos).to.equal(beforePosVaule);
            expect(afterPosVaule).to.equal(0);
            expect(afterDebtInBase).to.equal(0);    // debt: 0 / pendingDebt = real debt
            expect(pendingDebt).to.equal(beforeDebtInBase);

            /**
             * uEVMOS check
             */
            const uEVMOSTotalAmount = await uEVMOS.totalSupply();
            
            // uEVMOSTotalAmount = beforePosVaule 
            expect(uEVMOSTotalAmount).to.equal(beforePosVaule);

        })

        it("should unlock after 14(+2) days", async function(){
            const beforeUnlockable = await uEVMOS.getUnlockable(staker1.address);
            expect(beforeUnlockable.unlockable).to.equal(0);
            expect(beforeUnlockable.debt).to.equal(0);
            const [ locked ] = await uEVMOS.lockedList(staker1.address);

            await setNextBlockTimestamp(locked.unlockedAt);
            await mine(1);

            const afterUnlockable = await uEVMOS.getUnlockable(staker1.address);
            expect(afterUnlockable.unlockable).to.equal(locked.amount);

            const expectedDebtInBase = await ibtUSDC.getTokenOut(locked.debtShare);
            expect(afterUnlockable.debt).to.equal(expectedDebtInBase);
        })
    })

    describe("4. Add/Handle position after first time", async function (){
        it("Re-add position (x3 leverage)", async function(){
            const leverage = 3;
            const equity = toEVMOS(100);
            const debtInBase = equity.mul(leverage - 1);

            const beforeEVMOS = await staker1.getBalance();
            const beforeStakedAmount = mockValidator.amount;

            await tUSDC.connect(staker1).approve(ibtUSDC.address, equity);
            // debt: 200 EVMOS = 400 USDC
            const tx = await Stayking.connect(staker1).addPosition(
                tUSDC.address,
                equity,
                debtInBase,
                {value: equity}
            );
            await mockValidator.handleTx(tx);
            const afterEVMOS = await staker1.getBalance();

            expect(beforeEVMOS.sub(afterEVMOS)).to.approximately(equity, toBN(1, 16));
            
            const positionId = await Stayking.positionIdOf(staker1.address, ibtUSDC.address);
            expect(positionId).to.eq(2);
            const [positionValueInBase, positionDebtInBase, debt] = await Stayking.positionInfo(staker1.address, tUSDC.address);

            // equity in position
            expect(positionValueInBase.sub(positionDebtInBase)).to.equal(equity);
            // debt in EVMOS in posittion
            expect(positionDebtInBase).to.equal(debtInBase);
            expect(await ibtUSDC.getBaseIn(debt)).to.equal(debtInBase);

            expect(await ethers.provider.getBalance(ibtUSDC.address)).to.equal(0);
            expect(await ethers.provider.getBalance(Stayking.address)).to.equal(0);
            expect(mockValidator.amount)
                .to.equal(beforeStakedAmount.add(positionValueInBase));
        })
    })

    describe("5. Interest Moel: Triple Slope Model", async function (){
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

    describe("6. Delegator accrues when auto-compounding", async function(){

        it("accrues interest to vault properly.", async function(){
            const beforeDelegatorBalance = await delegator.getBalance();
            const claimed = await mockValidator.claim();

            const afterClaimDelegatorBalance = await delegator.getBalance();
            expect(afterClaimDelegatorBalance).to.equal(beforeDelegatorBalance.add(claimed));

            const accrued = await Stayking.getAccruedValue(mockValidator.amount.add(claimed));

            const tx = await Stayking
                .connect(delegator)
                .accrue(
                    mockValidator.amount.add(claimed),
                    {value: claimed}
                );
            const txGasFee = tx.gasLimit.mul(tx.gasPrice!);

            const afterAccrueDelegatorBalance = await delegator.getBalance();

            expect(afterClaimDelegatorBalance.sub(afterAccrueDelegatorBalance))
                .approximately(accrued, txGasFee);
        })

        it("After accrued, every position's debt ratio should be decreased", async function(){
            
        })
    })

    describe("7. Advanced change position", async function(){
        it("Case 1: Remove equity", async function(){
            const [positionValueInBase, positionDebtInBase, debt] = await Stayking.positionInfo(staker1.address, tUSDC.address);
            console.log(positionValueInBase.toString())
            console.log(positionDebtInBase.toString())
            // const removedEquity = 
            
        })
        it("Case 2: Remove debt", async function(){

        })

        it("Case 3: Add equity, Add debt", async function(){
            
        })
        it("Case 4: Add equity, Remove debt", async function(){

        })
        
        it("Case 5: Remove equity, Add debt", async function(){

        })
        it("Case 6: Remove equity, Remove debt", async function(){

        })
    })
})
