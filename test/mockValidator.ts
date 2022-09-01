import { setBalance } from "@nomicfoundation/hardhat-network-helpers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber } from "ethers"
import { UnbondedEvmosCraft } from "../crafts";
import { toBN } from "../scripts/utils";


interface Bond {
    amount: BigNumber
    unbondedAt: Date
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
    ){
        this.delegator = delegator;
        this.validator = validator;

        this.uEVMOS = uEVMOS;
        this.unbondedInterval = unbondedInterval;

        this.apr = 300;
        this.amount = toBN(0, 1);
        this.lastClaimedAt = new Date();
        this._bonds = [];
    }

    async stake(amount:BigNumber) {
        await this.delegator.sendTransaction({
            from: this.delegator.address,
            to: this.validator.address,
            value: amount
        });
        this.amount = this.amount.add(amount);
    }

    async unstake(amount:BigNumber) {
        this.amount = this.amount.sub(amount);
        const unbondedAt = new Date();
        unbondedAt.setDate(unbondedAt.getDate() + this.unbondedInterval);

        this._bonds.push({
            unbondedAt,
            amount
        })

        await setBalance(this.validator.address, this.amount);
    }

    async claim(){
        const timePast = (new Date().getTime() - this.lastClaimedAt.getTime()) / 1000;
        const claimAmount = this.amount.mul(this.apr).div(100).div(365).div(86400).mul(timePast);
        await setBalance(this.delegator.address, (await this.delegator.getBalance()).add(claimAmount));
        return claimAmount;
    }

    private async _unbond(){
        const bondSize = this._bonds.length;
        const today = new Date();

        let i;
        let unbonded = toBN(0, 1);
        for(i = 0; i < bondSize; i++){
            const { unbondedAt, amount } = this._bonds[i];
            if(today < unbondedAt){
                i -= 1;
                break;
            }
            unbonded = unbonded.add(amount);
        }

        await setBalance(
            this.delegator.address,
            (await this.delegator.getBalance()).add(unbonded)
        );
        
        return unbonded;

    }
}