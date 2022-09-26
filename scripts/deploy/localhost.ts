import { setBalance } from '@nomicfoundation/hardhat-network-helpers';
import { ethers } from 'hardhat';
import { deployERC20 } from '../setup/erc20';
import { deployMockSwap } from '../setup/mockswap';
import { deployStayking } from '../setup/Stayking';
import { deployTripleSlopeModel } from '../setup/triple-slope-model';
import { deployuEVMOS } from '../setup/uEVMOS';
import { deployVault } from '../setup/vault';
import { toBN } from '../utils';

async function deployLocal() {
    const [deployer, delegator] = await ethers.getSigners();

    await setBalance(deployer.address, toBN(1, 30));
    await setBalance(delegator.address, 0);

    // Deploy ERC20 tokens
    const tATOM = await deployERC20(deployer, 'Local Test ATOM', 'tATOM');
    const tUSDC = await deployERC20(deployer, 'Local Test USDC', 'tUSDC');
    const tUSDT = await deployERC20(deployer, 'Local Test USDT', 'tUSDT');

    // Deploy MockSwap & MockSwapHelper
    const swapHelper = await deployMockSwap(
        deployer,
        [tATOM, tUSDC, tUSDT],
        5000
    );

    const interestModel = await deployTripleSlopeModel(deployer);

    const uEVMOS = await deployuEVMOS(deployer);

    const Stayking = await deployStayking(
        deployer.address,
        delegator.address,
        uEVMOS.address
    );

    await uEVMOS.updateMinterStatus(Stayking.address, true);

    const ibtUSDC = await deployVault(
        deployer,
        Stayking,
        swapHelper.address,
        'interest bearing USDC Vault',
        'ibtUSDC',
        tUSDC.address,
        interestModel.address,
        1000 // 10%
    );
}

export default deployLocal;
