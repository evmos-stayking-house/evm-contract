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

export interface DiffuisionContractAddress {
    factory: string;
    weth9: string;
    router: string;
    multicall2: string;
    mockUSDC?: string;
    mockEVMOS?: string;
    mockATOM?: string;
    mockOSMOSIS?: string;
}
