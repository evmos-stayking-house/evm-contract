import { BigNumber, ethers } from 'ethers';

export const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

export const toBN = (base: number | string, decimals?: number) =>
    ethers.utils.parseUnits(base + '', decimals || 1);

export const toNum = (base: number | string, decimals?: number) =>
    ethers.utils.formatUnits(base + '', decimals);
