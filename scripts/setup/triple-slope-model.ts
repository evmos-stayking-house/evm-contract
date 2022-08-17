import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { craftform } from "hardhat";

export const deployTripleSlopeModel = (deployer: SignerWithAddress) => {
    return craftform.contract("TripleSlopeModel")
        .deploy(null, { from: deployer.address });
}