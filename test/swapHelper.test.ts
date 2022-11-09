import { before } from 'mocha';
import { expect } from 'chai';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ethers } from 'hardhat';
import { deploySwapHelper } from '../scripts/deploy/setup/swapHelper';
import { toBN } from '../utils';
import { SwapHelper } from '../typechain-types/SwapHelper';
import { experimentalAddHardhatNetworkMessageTraceHook } from 'hardhat/config';
import { ERC20Upgradeable } from '../typechain-types';

/**
 * Testnet 환경 chainId 9000 에서 테스트 진행
 */

const UniswapV2Router = '0x72bd489d3cF0e9cC36af6e306Ff53E56d0f9EFb4';
const UniswapV2PairAddress = '0xe820036d36E485D5905dA18E4f17f20499824917'; // mockUSDC/WEVMOS
const mockUSDCAddress = '0xc48Efe267a31b5Af4cFDb50C8457914aadB0b875';
const wevmosAddress = '0xcc491f589B45d4a3C679016195B3FB87D7848210';
const swapHelperAddress = '0x3a7f2a0e55DA8874351693FEC66E249ac8744622';
const baseTokenAddress = ethers.constants.AddressZero;

let evmosHolder: SignerWithAddress;
let swapHelperContract: SwapHelper;
let mockUSDCContract: ERC20Upgradeable;

/**
 * 0. 컨트랙트 배포
 */
before(async () => {
    [evmosHolder] = await ethers.getSigners();
    console.log('EVMOS Holder Address : ', evmosHolder.address);
    const deployedResult = await deploySwapHelper(evmosHolder, UniswapV2Router);
    swapHelperContract = await ethers.getContractAt(
        'SwapHelper',
        // deployedResult?.address || ''
        swapHelperAddress
    );
    mockUSDCContract = await ethers.getContractAt(
        'ERC20Upgradeable',
        mockUSDCAddress
    );
    console.log('SwapHelper Address : ', swapHelperContract.address);
    console.log('mockUSDC Address : ', mockUSDCContract.address);
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

    it('3. EVMOS / mockUSDC Price Impact Bps 계산 (Vice Versa)', async () => {
        const swapTokensAmountForEvmos = toBN(20, 18);
        const swapEvmosAmountForTokens = toBN(1, 18);
        const priceImpactBps =
            await swapHelperContract.getPriceImpactFactorsFrom(
                UniswapV2PairAddress,
                0,
                swapEvmosAmountForTokens
            );

        console.log(priceImpactBps);
    });

    it('4. EVMOS -> mockUSDC exchange Test', async () => {
        const swapEvmosAmountsForTokens = toBN(1, 18); // 1 EVMOS
        // Slippage Tolerance Ratio 0.5%
        const expectedSwappedTokens = await swapHelperContract.getDy(
            baseTokenAddress,
            mockUSDCAddress,
            swapEvmosAmountsForTokens
        );

        const minDy =
            Number(ethers.utils.formatEther(expectedSwappedTokens)) * 0.995;
        console.log('EVMOS (aevmos): ', swapEvmosAmountsForTokens);
        console.log('Expected USDC :', expectedSwappedTokens);
        console.log('Slippage 적용 최소 minDy : ', toBN(minDy, 18));

        const swappedTx = await swapHelperContract
            .connect(evmosHolder)
            .exchange(
                baseTokenAddress,
                mockUSDCAddress,
                swapEvmosAmountsForTokens,
                toBN(minDy, 18),
                {
                    value: swapEvmosAmountsForTokens,
                }
            );

        console.log('txHash : ', swappedTx);
    });

    it('4. mockUSDC -> EVMOS exchange Test Approve 가 없어서 Failed 되는 상황', async () => {
        const swapUSDCTokensForEVMOS = toBN(1, 18); // 1 USDC

        await expect(
            swapHelperContract
                .connect(evmosHolder)
                .exchange(
                    mockUSDCAddress,
                    baseTokenAddress,
                    swapUSDCTokensForEVMOS,
                    toBN(0, 18)
                )
        ).to.be.rejectedWith('reverted: !safeTransferFrom');
    });

    it.only('5. mockUSDC -> EVMOS exchange Test', async () => {
        const swapUSDCTokensForEVMOS = toBN(1, 18); // 1 USDC
        const expectedSwappedEVMOS = await swapHelperContract.getDy(
            mockUSDCAddress,
            baseTokenAddress,
            swapUSDCTokensForEVMOS
        );

        const minDy =
            Number(ethers.utils.formatEther(expectedSwappedEVMOS)) * 0.995;
        console.log('USDC : ', swapUSDCTokensForEVMOS);
        console.log('Expected EVMOS :', expectedSwappedEVMOS);
        console.log('Slippage 적용 최소 minDy : ', toBN(minDy, 18));

        await mockUSDCContract
            .connect(evmosHolder)
            .approve(swapHelperAddress, swapUSDCTokensForEVMOS);

        const swappedTx = await swapHelperContract
            .connect(evmosHolder)
            .exchange(
                mockUSDCAddress,
                baseTokenAddress,
                swapUSDCTokensForEVMOS,
                toBN(0, 18),
                {
                    value: swapUSDCTokensForEVMOS,
                }
            );

        console.log('txHash : ', swappedTx);
    });
});
