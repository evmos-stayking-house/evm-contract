import { setBalance } from '@nomicfoundation/hardhat-network-helpers';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { Signer } from 'ethers';
import { ethers } from 'hardhat';
import { before } from 'mocha';
import { deployInterestModel } from '../scripts/deploy/setup/interestModel';
import { deployStayKing } from '../scripts/deploy/setup/stayKing';
import {
    deployMockSwapHelper,
    deploySwapHelper,
} from '../scripts/deploy/setup/swapHelper';
import { deployToken, mintToken } from '../scripts/deploy/setup/token';
import { deployVault } from '../scripts/deploy/setup/vault';
import { ERC20Ownable, MockSwap, Stayking, Vault } from '../typechain-types';
import { toBN, txEventHandler } from '../utils';

let deployer: SignerWithAddress;
let lender: SignerWithAddress;
let staker: SignerWithAddress;
let delegator: SignerWithAddress;

let usdc: ERC20Ownable;
let vault: Vault;
let mockSwap: MockSwap;
let stayKing: Stayking;

const mintTokenAmount = toBN(1000000, 18);
/**
 * 0. 컨트랙트 배포
 */
before(async () => {
    [deployer, lender, staker, delegator] = await ethers.getSigners();

    const deployedResult = await deployContracts('USDC');

    usdc = await ethers.getContractAt(
        'ERC20Ownable',
        deployedResult.tokenAddress
    );
    vault = await ethers.getContractAt('Vault', deployedResult.vaultAddress);
    stayKing = await ethers.getContractAt(
        'Stayking',
        deployedResult.stayKingAddress
    );
    mockSwap = await ethers.getContractAt(
        'MockSwap',
        deployedResult.mockSwapAddress
    );
});

describe('초기화 : ', async () => {
    it('Vault 설정 셋업: ', async () => {
        const token = await vault.token();
        expect(token).to.be.contain('0x');
    });

    it('EVMOS 가 유저 계정 Lender, Staker, Delegator 그리고 Contract MockSwap, StayKing 에 분배가 되었는지 확인함', async () => {
        const balanceOfLender = await ethers.provider.getBalance(
            lender.address
        );
        const balanceOfStaker = await ethers.provider.getBalance(
            staker.address
        );
        const balanceOfDelegator = await ethers.provider.getBalance(
            staker.address
        );
        const balanceOfMockSwap = await ethers.provider.getBalance(
            mockSwap.address
        );
        const balanceOfStayking = await ethers.provider.getBalance(
            stayKing.address
        );
        expect(balanceOfLender).to.greaterThan(0);
        expect(balanceOfStaker).to.greaterThan(0);
        expect(balanceOfDelegator).to.greaterThan(0);
        expect(balanceOfMockSwap).to.greaterThan(0);
        expect(balanceOfStayking).to.greaterThan(0);
    });

    it('USDC 발행하고 Lender, Staker 에게 그리고 Contract MockSwap, StayKing 에 분배가 되었는지 확인함', async () => {
        const balanceOfDeployer = await usdc.balanceOf(lender.address);
        const balanceOfLender = await usdc.balanceOf(staker.address);
        const balanceOfMockSwap = await usdc.balanceOf(mockSwap.address);
        const balanceOfStayking = await usdc.balanceOf(stayKing.address);

        expect(balanceOfDeployer).to.be.equal(mintTokenAmount);
        expect(balanceOfLender).to.be.equal(mintTokenAmount);
        expect(balanceOfMockSwap).to.be.equal(mintTokenAmount);
        expect(balanceOfStayking).to.be.equal(mintTokenAmount);
    });
});

describe('입금(Deposit) : ', async () => {
    const depositAmount = toBN(100, 18);

    it('[실패] Lender 의 Approve 없이 Deposit 하는 경우', async () => {
        await expect(
            vault.connect(lender).deposit(depositAmount)
        ).to.revertedWith('!safeTransferFrom');
    });

    it('[실패] Lender 의 자금이 부족한 상황에서 Deposit 하는 경우', async () => {
        const balanceOf = await usdc.balanceOf(lender.address);
        const overBalance = balanceOf.add(depositAmount);
        await usdc.connect(lender).approve(vault.address, overBalance);
        await expect(
            vault.connect(lender).deposit(overBalance)
        ).to.revertedWith('!safeTransferFrom');
    });

    it('[성공] Lender 가 토큰 approve 이후 Vault 에 자금을 맡기는 경우', async () => {
        await usdc.connect(lender).approve(vault.address, depositAmount);
        const depositTx = await vault.connect(lender).deposit(depositAmount);
        const [lenderOfEvent, depositAmountOfVault, shareOfEvent] =
            await txEventHandler(depositTx, 'Deposit(address,uint256,uint256)');
        const amountOfShare = await vault
            .connect(lender)
            .shareToAmount(shareOfEvent);

        const balanceOfUSDC = await usdc.balanceOf(lender.address);

        expect(balanceOfUSDC).eq(mintTokenAmount.sub(depositAmount));
        expect(lenderOfEvent).to.be.eq(lender.address);
        expect(depositAmountOfVault).to.be.eq(depositAmount);
        expect(amountOfShare).to.be.eq(depositAmountOfVault);
    });
});

describe('출금(Withdraw) : ', async () => {
    it('[실패] Lender 가 Vault에 입금한 금액보다 더 많은 돈을 출금할 경우', async () => {
        const shareOfLender = await vault.balanceOf(lender.address);
        await expect(
            vault.connect(lender).withdraw(shareOfLender.add(1))
        ).to.revertedWith('ERC20: burn amount exceeds balance');
    });

    it('[성공] Lender 가 Vault에 입금한 모든 금액을 출금하는 경우', async () => {
        const shareOfLender = await vault.balanceOf(lender.address);
        const withdrawAmouunt = await vault.shareToAmount(shareOfLender);
        const withdrawTx = await vault.connect(lender).withdraw(shareOfLender);

        const [, amountOfEvent, shareOfEvent] = await txEventHandler(
            withdrawTx,
            'Withdraw(address,uint256,uint256)'
        );

        const shareAfterWithdraw = await vault.balanceOf(lender.address);

        expect(amountOfEvent).to.be.eq(withdrawAmouunt);
        expect(shareAfterWithdraw).to.be.eq(0);
    });
});

describe('대출(Loan): ', () => {
    const depositAmount = toBN(10000, 18);
    let minReservedBps = 0;
    let beforeVaultTokenQty = 0;
    let beforeVaultEvmosQty = 0;
    let vaultBufferTokenQty = 0;
    let vaultBufferEvmosQty = 0;

    before(async () => {
        await usdc.connect(lender).approve(vault.address, depositAmount);
        await vault.connect(lender).deposit(depositAmount);

        minReservedBps = (await vault.minReservedBps()).toNumber() / 10000;

        beforeVaultTokenQty = Number(
            ethers.utils.formatUnits((await vault.totalAmount()).toString(), 18)
        );
        beforeVaultEvmosQty = Number(
            await vault.getBaseIn(beforeVaultTokenQty)
        );

        vaultBufferTokenQty = beforeVaultTokenQty * minReservedBps;
        vaultBufferEvmosQty = (
            await vault.getBaseIn(vaultBufferTokenQty)
        ).toNumber();

        console.log(
            minReservedBps,
            beforeVaultTokenQty,
            beforeVaultEvmosQty,
            vaultBufferTokenQty,
            vaultBufferEvmosQty
        );
    });

    it('[실패] 대출하는 유저 계정이 0x0 일 경우', async () => {
        await expect(
            vault
                .connect(staker)
                .loan(ethers.constants.AddressZero, toBN(1, 18))
        ).to.revertedWith('loan: zero address cannot loan.');
    });

    it('[실패] 대출을 실행하는 주체가 Vault 에 등록된 Stayking address 가 아닐 경우', async () => {
        await expect(
            vault
                .connect(lender)
                .loan(ethers.constants.AddressZero, toBN(1, 18))
        ).to.revertedWith('Vault: Not Stayking contract.');
    });

    it('[실패] Vault 에 빌릴 자금이 부족한 경우', async () => {
        await expect(
            vault
                .connect(staker)
                .loan(
                    staker.address,
                    toBN(beforeVaultEvmosQty - vaultBufferEvmosQty + 1, 18)
                )
        ).to.revertedWith("Loan: Cant' loan debt anymore.");
    });

    it('[성공] Vault 에서 자금을 빌리는 것이 성공한 경우', async () => {
        const borrowingAmount = 1000;
        await vault
            .connect(staker)
            .loan(staker.address, toBN(borrowingAmount, 18));

        const debtInBaseOf = Number(
            ethers.utils.formatUnits(
                await vault.debtAmountInBase(staker.address),
                18
            )
        );

        expect(debtInBaseOf).to.be.eq(borrowingAmount);
    });
});

async function deployContracts(vaultTokenSymbol: string) {
    // 1. Token 배포
    const tokenDeployedResult = await deployToken(
        deployer,
        `${vaultTokenSymbol} token`,
        vaultTokenSymbol
    );

    // 2. MockSwap 배포
    const mockSwapDeployedResult = await deployMockSwapHelper(deployer, [
        ethers.constants.AddressZero,
        tokenDeployedResult.address,
    ]);

    // Stayking 배포
    const deployedStayKingResult = await deployStayKing(
        deployer,
        delegator.address,
        ethers.constants.AddressZero
    );

    // 3. 관련 계정과 배포된 컨트랙트 에 EVMOS 전송
    await setBalance(deployer.address, toBN(1, 30));
    await setBalance(staker.address, toBN(1, 30));
    await setBalance(lender.address, toBN(1, 30));
    await setBalance(mockSwapDeployedResult.address, toBN(1, 30));
    await setBalance(deployedStayKingResult.address, toBN(1, 30));

    // Token 민팅
    await mintToken(tokenDeployedResult.address, deployer, [
        deployer.address,
        lender.address,
        staker.address,
        mockSwapDeployedResult.address,
        deployedStayKingResult.address,
    ]);

    // InterestModel (implementation: TripleSlopeModel) 배포
    const interestDeployedResult = await deployInterestModel(deployer);

    // Vault 배포
    const vaultDeployedResult = await deployVault(deployer, {
        shareTokenName: `share ib${vaultTokenSymbol} Token`,
        shareTokenSymbol: `ib${vaultTokenSymbol}`,
        swapHelperAddress: mockSwapDeployedResult.address,
        stayKingAddress: staker.address,
        vaultTokenAddress: tokenDeployedResult.address,
        interestModelAddress: interestDeployedResult.address,
        minReservedBps: 1000,
    });

    return {
        tokenAddress: tokenDeployedResult.address,
        vaultAddress: vaultDeployedResult.address,
        stayKingAddress: deployedStayKingResult.address,
        mockSwapAddress: mockSwapDeployedResult.address,
        interestModelAddress: interestDeployedResult.address,
    };
}
