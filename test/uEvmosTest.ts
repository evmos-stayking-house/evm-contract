import { deployments, ethers, network } from 'hardhat';
import { before } from 'mocha';
import { BigNumber, Contract } from 'ethers';
import { mine } from '@nomicfoundation/hardhat-network-helpers';
import {
    latestBlock,
    setNextBlockTimestamp,
} from '@nomicfoundation/hardhat-network-helpers/dist/src/helpers/time';
import { formatEther } from 'ethers/lib/utils';

let contract: Contract;

before(() => {});

describe('uEvmos fork test', async () => {
    describe('컨트랙트', function () {
        before('EvmoSwap 컨트랙트 config 업데이트', async function () {
            contract = await ethers.getContractAt(
                'UnbondedEvmos',
                '0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6'
            );
        });
        it('getLockedList', async () => {
            let locked = await contract.getLockedList(
                '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266'
            );
            console.log(locked.length);
            console.log(locked);
        });

        // it('lockedOf', async () => {
        //     let locked = await contract.getLockedOf(
        //         '0xb9D40e433b5434fdcba80D405F906143aa354237'
        //     );
        //     console.log(locked);
        // });

        // it.skip('reset account for uEVMOS', async () => {
        //     const [deployer] = await ethers.getSigners();
        //     const result = await contract.resetAccount(
        //         '0xb9D40e433b5434fdcba80D405F906143aa354237'
        //     );
        //     console.log(`초기화 여부 : ${result}`);
        // });

        // it.skip('sweep uEVMOS', async () => {
        //     const [deployer] = await ethers.getSigners();
        //     const result = await contract.connect(deployer).sweep();
        //     console.log(`sweep 여부 : ${result}`);
        // });

        it('balance & unlockable tokens of address input', async () => {
            // await timeTravel(60 * 60 * 24 * 6); // 시간 여행 7일 후
            let balance: BigNumber = await contract.balanceOf(
                '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266'
            );
            let [unlockable, debt] = await contract.getUnlockable(
                '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266'
            );
            console.log(
                formatEther(balance),
                formatEther(unlockable),
                formatEther(debt)
            );
        });
    });
});

async function now() {
    const lastBlockNumber = await latestBlock();
    const block = await ethers.provider.getBlock(lastBlockNumber);
    return block.timestamp;
}

async function timeTravel(seconds: number) {
    const destination = new Date(((await now()) + seconds) * 1000);
    await setNextBlockTimestamp(destination);
    await mine(1);
    return destination;
}
