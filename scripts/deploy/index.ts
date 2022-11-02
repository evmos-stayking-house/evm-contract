import { setBalance } from '@nomicfoundation/hardhat-network-helpers';
import { ethers } from 'hardhat';
import { toBN } from '../../utils';
import { deployStayKing } from './setup/stayKing';
import { deployToken, mintToken } from './setup/token';
import { deployUnbondedEvmos } from './setup/UnbondedEvmos';

const main = async () => {
    // 0. setup deployer address from harthat configuration
    const [deployer] = await ethers.getSigners();

    /**
     * 1. Deploy & Mint Token
     */
    // const tokenName = 'USDC Stable Coin';
    // const tokenSymbol = 'USDC';
    // const initialTokenHolders: string[] = []; // 초기 토큰 민팅 대상
    // const tokenDeployedResult = await deployToken(
    //     deployer,
    //     tokenName,
    //     tokenSymbol
    // );

    // await mintToken(tokenDeployedResult.address, deployer, initialTokenHolders);

    // console.log('deployed token address: ', tokenDeployedResult.address);
    // console.log('deployed token txHash: ', tokenDeployedResult.transactionHash);

    /**
     * 2. Deploy UEvmos Contract
     */

    const ucontract = await deployUnbondedEvmos(deployer);
    const uEvmos = await ethers.getContractAt(
        'UnbondedEvmos',
        ucontract.address
    );

    // await setBalance(uEvmos.address, toBN(1, 30));

    // await uEvmos.updateMinterStatus(
    //     '0x5c16AD45ec86A50a59b4fe7d9B205aCa2100de2f',
    //     true
    // );
    // const contract = await deployStayKing(
    //     deployer,
    //     '0xFCD4140BCeE04C2E0468d00a5b7DFd28Df41784e',
    //     '0xbC8c3C9fa35A00aC40f3c6729C4AC8b52433eAC1'
    // );
    console.log(`ucontract address: ${ucontract.address}`);
    // console.log(`contract address: ${contract.address}`);
};

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
