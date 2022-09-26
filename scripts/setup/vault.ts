import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { craftform } from 'hardhat';
import { address } from 'hardhat-craftform/dist/core';
import { StaykingCraft } from '../../crafts';

export const deployVault = async (
    deployer: SignerWithAddress,
    Stayking: StaykingCraft,
    swapHelper: address,
    name: string,
    symbol: string,
    token: string,
    interestModel: string,
    minReservedBps: number
) => {
    const vault = await craftform.contract('Vault').deploy(symbol, {
        from: deployer.address,
        proxy: {
            proxyContract: 'OpenZeppelinTransparentProxy',
            execute: {
                init: {
                    methodName: '__Vault_init',
                    args: [
                        name,
                        symbol,
                        swapHelper,
                        Stayking.address,
                        token,
                        interestModel,
                        minReservedBps,
                    ],
                },
            },
        },
    });

    // add vault to Stayking contract
    await Stayking.updateVault(token, vault.address);
    return vault;
};
