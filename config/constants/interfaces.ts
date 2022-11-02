import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

export interface DeployedContractAddress {
    Tokens: string[];
    SwapHelper: string;
    InterestModel: string;
    UnbondedEVMOS: string;
    StayKing: string;
    Vault: string;
    Actors: SignerWithAddress[];
}
