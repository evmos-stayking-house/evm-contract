import { setBalance } from '@nomicfoundation/hardhat-network-helpers';
import { latestBlock } from '@nomicfoundation/hardhat-network-helpers/dist/src/helpers/time';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumber, ContractTransaction } from 'ethers';
import { ethers } from 'hardhat';
import { UnbondedEvmosCraft } from '../crafts';
import { toBN } from '../scripts/utils';

interface Bond {
    amount: BigNumber;
    unbondedAt: Date;
}

async function now() {
    const lastBlockNumber = await latestBlock();
    const block = await ethers.provider.getBlock(lastBlockNumber);
    return block.timestamp;
}

export class MockValidator {
    apr: number;
    lastClaimedAt: Date;
    amount: BigNumber;
    delegator: SignerWithAddress;
    validator: SignerWithAddress;
    unbondedInterval: number;
    uEVMOS: UnbondedEvmosCraft;
    private _bonds: Bond[];

    constructor(
        delegator: SignerWithAddress,
        validator: SignerWithAddress,
        uEVMOS: UnbondedEvmosCraft,
        unbondedInterval: number
    ) {
        this.delegator = delegator;
        this.validator = validator;

        this.uEVMOS = uEVMOS;
        this.unbondedInterval = unbondedInterval;

        this.apr = 300;
        this.amount = toBN(0, 1);
        this.lastClaimedAt = new Date();
        this._bonds = [];
    }

    async stake(amount: BigNumber) {
        await this.unbond();

        await this.delegator.sendTransaction({
            from: this.delegator.address,
            to: this.validator.address,
            value: amount,
        });
        this.amount = this.amount.add(amount);
    }

    async unstake(amount: BigNumber) {
        await this.unbond();

        this.amount = this.amount.sub(amount);
        const unbondedAt = (await now()) + this.unbondedInterval;

        this._bonds.push({
            unbondedAt: new Date(unbondedAt * 1000),
            amount,
        });

        await setBalance(this.validator.address, this.amount);
    }

    async claim() {
        const beforeDelegatorBalance = await this.delegator.getBalance();
        await this.unbond();

        const timePast =
            (await now()) - Math.floor(this.lastClaimedAt.getTime() / 1000);
        const claimAmount = this.amount
            .mul(this.apr)
            .div(100)
            .div(365)
            .div(86400)
            .mul(timePast);
        await setBalance(
            this.delegator.address,
            beforeDelegatorBalance.add(claimAmount)
        );
        return claimAmount;
    }

    // handle stake, unstake, accrue
    async handleTx(tx: ContractTransaction) {
        const STAKE = 'Stake(address,address,uint256,uint256)';
        const UNSTAKE = 'Unstake(address,address,uint256,uint256)';
        const ACCRUE = 'Accrue(address,uint256,uint256)';
        const signatures = [STAKE, UNSTAKE, ACCRUE];

        const event = (await tx.wait()).events?.filter(
            (e) => e.eventSignature && signatures.includes(e.eventSignature)
        );
        if (event?.length !== 1) throw Error('No stake event.');

        const sig = event[0].eventSignature;
        if (sig === STAKE) {
            const [, , amount] = event[0].args as any[];
            await this.stake(amount);
        } else if (sig === UNSTAKE) {
            const [, , amount] = event[0].args as any[];
            await this.unstake(amount);
        } else if (sig === ACCRUE) {
            const [, accrued] = event[0].args as any[];
            await this.stake(accrued);
        }
    }

    async unbond() {
        const lastBlockNumber = await latestBlock();
        const block = await ethers.provider.getBlock(lastBlockNumber);
        const now = new Date(block.timestamp * 1000);
        const bondSize = this._bonds.length;

        let i;
        let unbonded = toBN(0, 1);

        for (i = 0; i < bondSize; i++) {
            const { unbondedAt, amount } = this._bonds[i];
            if (now < unbondedAt) {
                break;
            }
            unbonded = unbonded.add(amount);
        }

        await setBalance(
            this.delegator.address,
            (await this.delegator.getBalance()).add(unbonded)
        );
        await this.uEVMOS
            .connect(this.delegator)
            .supplyUnbondedToken({ value: unbonded });

        this._bonds = this._bonds.slice(i);

        return unbonded;
    }
}
