import { ethers } from 'hardhat';
import { ERC20Upgradeable } from '../typechain-types';
import { TypedEventFilter } from '../typechain-types/common';
import { TransferEvent } from '../typechain-types/UnbondedEvmos';

const TARGET_USDC_CONTRACT_ADDRESS =
    '0x9218b75D53612212137890354B1a16163Abb9DE3';
const DEPLOYED_BLOCK_HEIGHT = 5912207;
// const DEPLOYED_BLOCK_HEIGHT = 7080000;
let targetContract: ERC20Upgradeable;

before(async () => {
    targetContract = await ethers.getContractAt(
        'ERC20Upgradeable',
        TARGET_USDC_CONTRACT_ADDRESS
    );
});

describe('mockUSDC : ', () => {
    it('Transfer Event', async () => {
        const _blockHeight = await ethers.provider.getBlockNumber();
        const vaultAddress = '0xa6c036c12b65703Bd7C0e4F42Dc0E75f74675C64';
        const filter = await targetContract.filters[
            'Transfer(address,address,uint256)'
        ](null, vaultAddress);
        const result = await searchEvent(filter, _blockHeight);
        console.log(result);
    });
});

const searchEvent = async (
    filter: TypedEventFilter<TransferEvent>,
    _startBlockNum: number,
    interval = 9000
): Promise<any> => {
    if (_startBlockNum < DEPLOYED_BLOCK_HEIGHT) return [];
    console.log(`blocknum ${_startBlockNum - 9000} ~ ${_startBlockNum}`);
    const result = await targetContract.queryFilter(
        filter,
        _startBlockNum - 9000,
        _startBlockNum
    );
    return [...result, ...(await searchEvent(filter, _startBlockNum - 9000))];
};
