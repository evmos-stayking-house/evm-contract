import { before } from 'mocha';
import { expect } from 'chai';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ethers } from 'hardhat';
import { deploySwapHelper } from '../scripts/deploy/setup/swapHelper';
import { toBN } from '../utils';
import { SwapHelper } from '../typechain-types/SwapHelper';
import { experimentalAddHardhatNetworkMessageTraceHook } from 'hardhat/config';

/**
 * Testnet 환경 chainId 9000 에서 테스트 진행
 */

const UniswapV2Router = '0x72bd489d3cF0e9cC36af6e306Ff53E56d0f9EFb4';
const UniswapV2PairAddress = '0xe820036d36E485D5905dA18E4f17f20499824917'; // mockUSDC/WEVMOS
const mockUSDCAddress = '0xc48Efe267a31b5Af4cFDb50C8457914aadB0b875';
const wevmosAddress = '0xcc491f589B45d4a3C679016195B3FB87D7848210';
const swapHelperAddress = '0xB92807A22EE7294B8759F339be800c923d4374dd';
const baseTokenAddress = ethers.constants.AddressZero;
let evmosHolder: SignerWithAddress;
let swapHelperContract: SwapHelper;

/**
 * 0. 컨트랙트 배포
 */
before(async () => {
    [evmosHolder] = await ethers.getSigners();
    console.log('EVMOS Holder Address : ', evmosHolder.address);
    // const deployedResult = await deploySwapHelper(evmosHolder, UniswapV2Router);
    swapHelperContract = await ethers.getContractAt(
        'SwapHelper',
        swapHelperAddress
    );
    console.log('SwapHelper Address : ', swapHelperContract.address);
});

describe('SwapHelper 테스트 : ', async () => {
    it('1. 1 EVMOS to ? mockUSDC 예상 수량 변환하여 확인하기', async () => {
        const swapEvmosAmountsForTokens = toBN(1, 18);
        const swappedTokens = await swapHelperContract.getDy(
            baseTokenAddress,
            mockUSDCAddress,
            swapEvmosAmountsForTokens
        );
        console.log('Token Out 수량 : ', swappedTokens);
        expect(swappedTokens).to.be.greaterThan(0);
    });

    it('2. 1 mockUSDC to ? EVMOS 예상 수량 변환하여 확인하기', async () => {
        const swapTokensAmountForEvmos = toBN(1, 18);
        const swappedEVMOS = await swapHelperContract.getDy(
            mockUSDCAddress,
            baseTokenAddress,
            swapTokensAmountForEvmos
        );
        console.log('EVMOS Out 수량 : ', swappedEVMOS);
        expect(swappedEVMOS).to.be.greaterThan(0);
    });
});
