import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { deployments } from 'hardhat';
import { DeployResult } from 'hardhat-deploy/dist/types';

export const deployInterestModel = (
    deployer: SignerWithAddress
): Promise<DeployResult> => {
    return deployments.deploy('InterestModel', {
        contract: 'TripleSlopeModel',
        from: deployer.address,
    });
};
