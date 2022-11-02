import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { deployments } from 'hardhat';

export interface VaultInitArgs {
    shareTokenName: string;
    shareTokenSymbol: string;
    swapHelperAddress: string;
    stayKingAddress: string;
    vaultTokenAddress: string;
    interestModelAddress: string;
    minReservedBps: number;
}

export const deployVault = (
    deployer: SignerWithAddress,
    args: VaultInitArgs
) => {
    return deployments.deploy('Vault', {
        from: deployer.address,
        proxy: {
            proxyContract: 'OpenZeppelinTransparentProxy',
            execute: {
                init: {
                    methodName: '__Vault_init',
                    args: Object.values(args),
                },
            },
        },
    });
};
