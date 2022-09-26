import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { craftform } from 'hardhat';

export const deployTripleSlopeModel = async (deployer: SignerWithAddress) => {
    return craftform
        .contract('TripleSlopeModel')
        .deploy(null, { from: deployer.address });
};
