import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { deployments } from 'hardhat';

export const deployUnbondedEvmos = async (deployer: SignerWithAddress) => {
    const unbondingInterval = 60; //@TODO 7일로 변경해야함

    return deployments.deploy('UnbondedEvmos', {
        contract: 'UnbondedEvmos',
        from: deployer.address,
        proxy: {
            proxyContract: 'OpenZeppelinTransparentProxy',
            execute: {
                init: {
                    methodName: '__UnbondedEvmos_init',
                    args: [unbondingInterval],
                },
            },
        },
    });
};
