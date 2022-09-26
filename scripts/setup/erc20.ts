import { craftform } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { toBN } from '../utils';

export const deployERC20 = async (
    deployer: SignerWithAddress,
    name: string,
    symbol: string
) => {
    const Token = await craftform.contract('ERC20Ownable').deploy(symbol, {
        from: deployer.address,
        args: [name, symbol],
    });

    // self mint token
    const deployerBalance = await Token.balanceOf(deployer.address);
    if (deployerBalance.toString() === '0') {
        await Token.mint(deployer.address, toBN(1, 24)); // 1E50
        await Token.mint(
            '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
            toBN(1, 24)
        ); // 1E50
        await Token.mint(
            '0x00967DaA192F23663eD0Ca2E4D4C923DD47B0101',
            toBN(1, 24)
        ); // 1E50
        await Token.mint(
            '0xb9D40e433b5434fdcba80D405F906143aa354237',
            toBN(1, 24)
        ); // 1E50
        // await Token.mint(deployer.address, toBN(1, 50));
    }
    return Token;
};
