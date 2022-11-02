import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { deployments, ethers } from 'hardhat';
import { DeployResult } from 'hardhat-deploy/dist/types';
import { toBN } from '../../../utils';

export const deployToken = async (
    deployer: SignerWithAddress,
    name: string,
    symbol: string
): Promise<DeployResult> => {
    return deployments.deploy(name, {
        contract: 'ERC20Ownable',
        from: deployer.address,
        args: [name, symbol],
    });
};

export const mintToken = async (
    tokenAddress: string,
    deployer: SignerWithAddress,
    initialTokenHolders: string[]
): Promise<void> => {
    const token = await ethers.getContractAt(
        'ERC20Ownable',
        tokenAddress,
        deployer
    );
    for (let i = 0; i < initialTokenHolders.length; i++) {
        if (initialTokenHolders[i].startsWith('0x'))
            await token.mint(initialTokenHolders[i], toBN(1000000, 18));
    }
};
