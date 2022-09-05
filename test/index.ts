import "../crafts"
import { expect } from 'chai'
import { craftform, ethers } from 'hardhat'
import { before } from 'mocha'
import { ERC20OwnableCraft, MockSwapCraft, StaykingCraft, TripleSlopeModelCraft, UnbondedEvmosCraft, VaultCraft } from '../crafts'
import deployLocal from '../scripts/deploy/localhost'
import { toBN } from '../scripts/utils'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { mine, setBalance, SnapshotRestorer, takeSnapshot } from '@nomicfoundation/hardhat-network-helpers'
import { latestBlock, setNextBlockTimestamp } from '@nomicfoundation/hardhat-network-helpers/dist/src/helpers/time'
import { MockValidator } from "./mockValidator"


const toUSDC = (usdc: number) => toBN(usdc, 18);
const toEVMOS = (evmos: number) => toBN(evmos, 18);

describe('EVMOS Hackathon Test', async () => {
    let deployer: SignerWithAddress     // 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
    let delegator: SignerWithAddress    // 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
    let lender1: SignerWithAddress      // 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
    let staker1: SignerWithAddress      // 0x90F79bf6EB2c4f870365E785982E1f101E93b906
    let validator: SignerWithAddress    // 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65
    let killer: SignerWithAddress       // 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc
    let mockValidator: MockValidator

    let tUSDC:ERC20OwnableCraft;        // maybe 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
    let ibtUSDC:VaultCraft;             // maybe 0xc6e7DF5E7b4f2A278906862b61205850344D4e7d
    let Stayking:StaykingCraft;         // maybe 0x9A9f2CCfdE556A7E9Ff0848998Aa4a0CFD8863AE
    let uEVMOS:UnbondedEvmosCraft;      // maybe 0x0B306BF915C4d645ff596e518fAf3F9669b97016
    let mockSwap:MockSwapCraft;

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
        [deployer, delegator, lender1, staker1, validator, killer] = await ethers.getSigners();


        await setBalance(staker1.address, toBN(10000, 18));
        await setBalance(delegator.address, toBN(10000, 18));
        await setBalance(validator.address, toBN(1000, 30));

        tUSDC = await craftform.contract("ERC20Ownable").attach("tUSDC");
        ibtUSDC = await craftform.contract("Vault").attach("ibtUSDC");
        Stayking = await craftform.contract("Stayking").attach();
        uEVMOS = await craftform.contract("UnbondedEvmos").attach();
        mockSwap = await craftform.contract("MockSwap").attach();

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
            const expected = expectedIR.mul(totalStakedDebt.add(beforeAccInterest)).mul(86400).div(toBN(1, 18));
            const afterAccInterest = await ibtUSDC.accInterest();

            expect(afterAccInterest.sub(beforeAccInterest)).to.approximately(expected, expected.div(10000));
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
    })

    describe("3. Lock uEVMOS", async function (){
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

            const expectedDebtInBase = await ibtUSDC.getBaseOut(locked.debtShare);
            expect(afterUnlockable.debt).to.equal(expectedDebtInBase);
        })
        
        it("debt should increase after accrued", async function () {
            const [ locked ] = await uEVMOS.lockedList(staker1.address);

            await ibtUSDC.accrue();
            const afterUnlockable = await uEVMOS.getUnlockable(staker1.address);
    
            const expectedDebtInBase = await ibtUSDC.getBaseOut(locked.debtShare);
            expect(afterUnlockable.debt).to.greaterThan(expectedDebtInBase);
        })

        it("EVOMS should unlocked except debt", async function(){
            const beforeStakerBalance = await staker1.getBalance();
            const unlockable = await uEVMOS.getUnlockable(staker1.address);

            await mockValidator.unbond();
            const tx = await uEVMOS.connect(staker1).unlock();

            // after balance = before balance + unlocked EVMOS - gas fee
            const afterStakerBalance = await staker1.getBalance();

            expect(afterStakerBalance).to.be.approximately(
                beforeStakerBalance
                    .add(unlockable.unlockable.sub(unlockable.debt)),
                tx.gasLimit.mul(tx.gasPrice!)
            )
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
            expect(await Stayking.totalAmount()).to.equal(mockValidator.amount);
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
        it("mockValidator works well", async function (){
            const snapshot = await takeSnapshot();
            const beforeDelegatorBalance = await delegator.getBalance();
            const claimed = await mockValidator.claim();
    
            const afterClaimDelegatorBalance = await delegator.getBalance();
            expect(afterClaimDelegatorBalance).to.equal(beforeDelegatorBalance.add(claimed));

            await snapshot.restore()
        })

        it("accrues interest to vault properly.", async function(){
            const beforeStaked = mockValidator.amount;
            const claimed = await mockValidator.claim();
            const expectedAccrued = await Stayking.getAccruedValue(claimed);

            const tx = await Stayking
                .connect(delegator)
                .accrue(
                    mockValidator.amount,
                    {value: claimed}
                );

            await mockValidator.handleTx(tx);

            expect(await Stayking.totalAmount()).to.equal(mockValidator.amount);
            expect(mockValidator.amount.sub(beforeStaked)).to.approximately(expectedAccrued, toBN(1, 4));
        })

        it("After accrued, every position's debt ratio should be decreased", async function(){
            const [beforePositionValueInBase, beforePositionDebtInBase, ] = await Stayking.positionInfo(staker1.address, tUSDC.address);
            const beforeDebtRatio = beforePositionDebtInBase.mul(1E4).div(beforePositionValueInBase);
            
            const claimed = await mockValidator.claim();
            await Stayking
                .connect(delegator)
                .accrue(
                    mockValidator.amount.add(claimed),
                    {value: claimed}
                    );

            const [afterPositionValueInBase, afterPositionDebtInBase, ] = await Stayking.positionInfo(staker1.address, tUSDC.address);
            const afterDebtRatio = afterPositionDebtInBase.mul(1E4).div(afterPositionValueInBase);
            expect(afterDebtRatio).to.lessThan(beforeDebtRatio);
        })
    })

    describe("7. Advanced change position", async function(){
        let snapshot:SnapshotRestorer;
        // after each step, snapshot will be restored
        before(async function(){
            snapshot = await takeSnapshot();
        })
        afterEach(async function(){
            await snapshot.restore();
        })

        it("Case 1: Remove debt only(reverted)", async function(){
            const removedDebt = toEVMOS(50);
            const removeDebtOnly = Stayking.connect(staker1).changePosition(
                tUSDC.address,
                0,
                "-"+removedDebt.toString(),
                0
            );
            await expect(removeDebtOnly).to.be.rejectedWith('unstake: too much debt in unstaked EVMOS');
        })

        it("Case 2: Remove equity", async function(){
            // check before status
            const [beforePositionValue, beforePositionDebt, ] = await Stayking.positionInfo(staker1.address, tUSDC.address);
            const beforeLocked = await uEVMOS.balanceOf(staker1.address);
            const beforeTotalStaked = mockValidator.amount;

            const removedEquity = toEVMOS(50);
            const tx = await Stayking.connect(staker1).changePosition(
                tUSDC.address,
                "-"+removedEquity.toString(),
                0,
                0
            );
            await mockValidator.handleTx(tx);
            
            // check position value
            const [afterPositionValue, afterPositionDebt, ] = await Stayking.positionInfo(staker1.address, tUSDC.address);
            expect(afterPositionDebt).to.equal(beforePositionDebt);
            expect(afterPositionValue).to.equal(beforePositionValue.sub(removedEquity));
            
            // check uEVMOS
            const afterLocked = await uEVMOS.balanceOf(staker1.address);
            expect(afterLocked).to.equal(beforeLocked.add(removedEquity));

            // check staked amount
            const afterTotalStaked = mockValidator.amount;
            expect(afterTotalStaked).to.equal(beforeTotalStaked.sub(removedEquity));

        })

        it("Case 3: Add equity, Add debt", async function(){
            // check before status
            const [beforePositionValue, beforePositionDebt, ] = await Stayking.positionInfo(staker1.address, tUSDC.address);
            const beforeLocked = await uEVMOS.balanceOf(staker1.address);
            const beforeTotalStaked = mockValidator.amount;

            const extraEquityInBase = toEVMOS(100);
            const extraDebtInBase = toEVMOS(200);
            const tx = await Stayking.connect(staker1).changePosition(
                tUSDC.address,
                extraEquityInBase,
                extraDebtInBase,
                0,
                {value: extraEquityInBase}
            );
            await mockValidator.handleTx(tx);
            
            // check position value
            const [afterPositionValue, afterPositionDebt, ] = await Stayking.positionInfo(staker1.address, tUSDC.address);
            expect(afterPositionDebt).to.equal(beforePositionDebt.add(extraDebtInBase));
            expect(afterPositionValue).to.equal(
                beforePositionValue.add(extraEquityInBase).add(extraDebtInBase)
            );
            
            // check staked amount
            const afterTotalStaked = mockValidator.amount;
            expect(afterTotalStaked).to.equal(beforeTotalStaked.add(extraDebtInBase).add(extraEquityInBase));
        })

        it("Case 4: Add equity, Remove debt(extraEquity < removedDebt, reverted)", async function(){
            const extraEquityInBase = toEVMOS(100);
            const removedDebt = toEVMOS(150);
            const removeDebtOnly = Stayking.connect(staker1).changePosition(
                tUSDC.address,
                extraEquityInBase,
                "-"+removedDebt.toString(),
                0,
                {value: extraEquityInBase}
            );
            await expect(removeDebtOnly).to.be.rejectedWith(
                'equityInBaseChanged * debtInBaseChanged < 0'
            );
        })

        it("Case 5: Add equity, Remove debt(extraEquity >= removedDebt, eventually staked more)", async function(){
            const extraEquityInBase = toEVMOS(150);
            const removedDebtInBase = toEVMOS(100);
            const tx = Stayking.connect(staker1).changePosition(
                tUSDC.address,
                extraEquityInBase,
                "-"+removedDebtInBase.toString(),
                0,
                {value: extraEquityInBase}
            );

            await expect(tx).to.be.rejectedWith('equityInBaseChanged * debtInBaseChanged < 0');
        })
        
        it("Case 6: Remove equity, Add debt", async function(){
            const removedEquityInBase = toEVMOS(150);
            const addDebtInBase = toEVMOS(100);
            const tx = Stayking.connect(staker1).changePosition(
                tUSDC.address,
                "-"+removedEquityInBase,
                addDebtInBase.toString(),
                0
            );

            await expect(tx).to.be.rejectedWith('equityInBaseChanged * debtInBaseChanged < 0');

        })
        it("Case 7: Remove equity, Remove debt", async function(){
            // check before status
            const [beforePositionValue, beforePositionDebt, ] = await Stayking.positionInfo(staker1.address, tUSDC.address);
            const beforeLocked = await uEVMOS.balanceOf(staker1.address);
            const beforeTotalStaked = mockValidator.amount;

            const removedEquity = toEVMOS(30);
            const removedDebt = toEVMOS(50);
            const tx = await Stayking.connect(staker1).changePosition(
                tUSDC.address,
                "-"+removedEquity,
                "-"+removedDebt,
                0
            );
            await mockValidator.handleTx(tx);
            
            // check position value
            const [afterPositionValue, afterPositionDebt, ] = await Stayking.positionInfo(staker1.address, tUSDC.address);
            expect(afterPositionDebt).to.equal(beforePositionDebt.sub(removedDebt));
            expect(afterPositionValue).to.equal(
                beforePositionValue.sub(removedEquity).sub(removedDebt)
            );
            
            // check staked amount
            const afterTotalStaked = mockValidator.amount;
            expect(afterTotalStaked).to.equal(beforeTotalStaked.sub(removedDebt).sub(removedEquity));

            // check uEVMOS
            const afterLocked = await uEVMOS.balanceOf(staker1.address);
            expect(afterLocked).to.equal(beforeLocked.add(removedEquity).add(removedDebt));
        })
    })

    describe("8. Position with bad debt should be killed.", async function(){
        it("Add killer as whitelisted killer", async function(){
            await Stayking.updateWhitelistedKillerStatus(
                [killer.address],
                true
            );
            expect(await Stayking.whitelistedKiller(killer.address)).to.true;
        })

        it("As EVMOS price changes, position's debt ratio get increased and killable state may changed.", async function(){
            const evmos15 = toEVMOS(15);
            const evmos25 = toEVMOS(25);
            const usdc30 = toUSDC(30);

            const beforeUSDCPrice = await ibtUSDC.getBaseIn(usdc30);
            expect(beforeUSDCPrice).to.equal(evmos15);

            // debt ratio maybe 5500 (55%)
            const [,,,positionId] = await Stayking.positionInfo(
                staker1.address, 
                tUSDC.address
            );
            const beforeKillable = await Stayking.isKillable(tUSDC.address, positionId);
            expect(beforeKillable).to.be.false;


            // change ratio : 20000 -> 12000
            // EVMOS price : 2USDC -> 1.2USDC
            await mockSwap.changeRatio(12000);

            
            const afterUSDCPrice = await ibtUSDC.getBaseIn(usdc30);
            expect(afterUSDCPrice).to.equal(evmos25);
            
            // debt ratio maybe 9167 (91.67%)
            const afterKillable = await Stayking.isKillable(tUSDC.address, positionId);
            expect(afterKillable).to.be.true;
        })

        it("Position should be killed", async function(){
            const [beforePositionValue,,beforePositionDebt,positionId] = await Stayking.positionInfo(
                staker1.address, 
                tUSDC.address
            );
            const liqFeeBps = await Stayking.liquidationFeeBps();

            await Stayking.connect(killer).kill(tUSDC.address, positionId);

            const [positionValue, positionDebt] = await Stayking.positionInfo(
                staker1.address, 
                tUSDC.address
            );

            expect(positionValue).to.equal(0);
            expect(positionDebt).to.equal(0);

            const locked = await uEVMOS.balanceOf(staker1.address);
            const staykingLocked = await uEVMOS.balanceOf(Stayking.address);
            const pendedDebt = await ibtUSDC.getPendingDebt(staker1.address);
            
            // user's uEVMOS balance : 95% of positionValue
            expect(locked).to.approximately(
                beforePositionValue.mul(toBN(1,4).sub(liqFeeBps)).div(1E4),
                toBN(1,4)
            );
            // pended debt
            expect(pendedDebt).to.approximately(
                beforePositionDebt,
                toBN(1,4)
            );
            // Stayking's uEVMOS balance : 5% of positionValue
            expect(staykingLocked).to.approximately(
                beforePositionValue.mul(liqFeeBps).div(1E4),
                toBN(1,4)
            );

        })
    })
})
