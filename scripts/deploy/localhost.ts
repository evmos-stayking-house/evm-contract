import { setBalance } from '@nomicfoundation/hardhat-network-helpers';
import { ethers } from 'hardhat';
import { DeployedContractAddress } from '../../config/constants/interfaces';
import { toBN } from '../../utils';
import { deployInterestModel } from './setup/interestModel';
import { deployStayKing } from './setup/stayKing';
import { deployMockSwapHelper } from './setup/swapHelper';
import { deployToken, mintToken } from './setup/token';
import { deployUnbondedEvmos } from './setup/UnbondedEvmos';
import { deployVault } from './setup/vault';

export async function deployLocal(): Promise<DeployedContractAddress> {
    // 0. hardhat 계정 불러오기
    const [deployer, lender, staker, delegator] = await ethers.getSigners();

    // 1. Deploy ERC20 tokens for vaults
    const tUSDC = await deployToken(deployer, 'USDC', 'tUSDC');

    // 2. Deploy MockSwap & MockSwapHelper
    const swapHelper = await deployMockSwapHelper(deployer, [
        ethers.constants.AddressZero,
        tUSDC.address,
    ]);

    // 3. Mint & Distribute Token assets to both users and related contract as the Swap Contract
    await mintToken(tUSDC.address, deployer, [
        deployer.address,
        lender.address,
        swapHelper.address,
    ]);

    // 4. Deploy Interest Model Contract ( implementaion : TripleSlopeModel )
    const interestModel = await deployInterestModel(deployer);

    // 5. Deploy uEVMOS Contract
    const uEVMOS = await deployUnbondedEvmos(deployer);

    // 6. Distribute EVMOS Coin to both users and related contract such as the Swap Contract
    const balanceOf = await ethers.provider.getBalance(deployer.address);
    // if balance eq 0 then set balance
    if (balanceOf.eq(0)) {
        await setBalance(deployer.address, toBN(1, 30));
        await setBalance(staker.address, toBN(1, 30));
        await setBalance(lender.address, toBN(1, 30));
        await setBalance(delegator.address, toBN(1, 30));
        await setBalance(uEVMOS.address, toBN(1, 30));
        await setBalance(swapHelper.address, toBN(1, 30));
    }

    // 7. Deploy Stayking Contract
    const stayking = await deployStayKing(
        deployer,
        delegator.address, // Delegator
        uEVMOS.address
    );

    // 8. Execute the updateMinterStatus function of UnbondedEvmos Contract with the Stayking Contract deployed
    (await ethers.getContractAt('UnbondedEvmos', uEVMOS.address))
        .connect(deployer)
        .updateMinterStatus(stayking.address, true);

    // 9. Deploy Vault Contract
    const ibtUSDC = await deployVault(deployer, {
        shareTokenName: 'interest bearing USDC Vault',
        shareTokenSymbol: 'ibtUSDC',
        swapHelperAddress: swapHelper.address,
        stayKingAddress: stayking.address,
        vaultTokenAddress: tUSDC.address,
        interestModelAddress: interestModel.address,
        minReservedBps: 1000, // Loan 시 Vault 에 남겨놓을 최소 비율 10% (만분률 사용)
    });

    // 10. Execute the updateVault function of Stayking Contract with the Vault contract deployed
    (await ethers.getContractAt('Stayking', stayking.address))
        .connect(deployer)
        .updateVault(tUSDC.address, ibtUSDC.address);

    // Print deployed Contract Address List
    console.log('tUSDC(Vault Token): ', tUSDC.address);
    console.log('SwapHelper(MockSwap): ', swapHelper.address);
    console.log('InterestModel(TripleSlopeModel): ', interestModel.address);
    console.log('uEVMOS: ', uEVMOS.address);
    console.log('Stayking: ', stayking.address);
    console.log('Vault: ', ibtUSDC.address);

    return {
        Tokens: [tUSDC.address],
        SwapHelper: swapHelper.address,
        InterestModel: interestModel.address,
        UnbondedEVMOS: uEVMOS.address,
        StayKing: stayking.address,
        Vault: ibtUSDC.address,
        Actors: [deployer, lender, staker, delegator],
    };
}

deployLocal().catch((error) => {
    console.log('[LOCALHOST DEPLOY ERROR] : ', error);
});
