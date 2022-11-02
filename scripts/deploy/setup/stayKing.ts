import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { deployments } from 'hardhat';

export const deployStayKing = async (
    deployer: SignerWithAddress,
    delegator: string,
    uEVMOSAddress: string
) => {
    return deployments.deploy('Stayking', {
        contract: 'Stayking',
        from: deployer.address,
        proxy: {
            proxyContract: 'OpenZeppelinTransparentProxy',
            execute: {
                init: {
                    methodName: '__Stayking_init',
                    args: [delegator, uEVMOSAddress],
                },
            },
        },
    });
};
