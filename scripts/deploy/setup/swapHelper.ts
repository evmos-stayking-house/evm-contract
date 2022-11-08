import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { deployments, ethers } from 'hardhat';
import { DeployResult } from 'hardhat-deploy/dist/types';

//@TODO 임시 MockSwap 을 사용하여 나중에는 변경해야 함
export const deployMockSwapHelper = async (
    deployer: SignerWithAddress,
    supportedTokenAddresses: string[]
): Promise<DeployResult> => {
    return deployments.deploy('MockSwap', {
        contract: 'MockSwap',
        from: deployer.address,
        args: [supportedTokenAddresses],
    });
};

export const deploySwapHelper = async (
    deployer: SignerWithAddress,
    routerAddress: string
): Promise<DeployResult | null> => {
    let deployedResult: DeployResult | null = null;
    try {
        deployedResult = await deployments.deploy('SwapHelper', {
            contract: 'SwapHelper',
            from: deployer.address,
            args: [routerAddress],
        });
    } catch (err) {
        console.log('ERROR: ', err);
    } finally {
        return deployedResult;
    }
};
