import { ContractTransaction, ethers } from 'ethers';

export const toBN = (base: number | string, decimals?: number) =>
    ethers.utils.parseUnits(base + '', decimals || 1);

export async function txEventHandler(
    tx: ContractTransaction,
    signature: string
): Promise<any[]> {
    const event = (await tx.wait()).events?.filter(
        (e) => signature === e.eventSignature
    );
    if (event?.length !== 1) throw Error('No event.');

    return event[0].args as any[];
}
