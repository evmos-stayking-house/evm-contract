import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { expect } from 'chai'
import { ethers } from 'hardhat'

describe('SimpleDelegating 컨트랙트 테스트', () => {
    async function deployContract() {
        // Contracts are deployed using the first signer/account by default
        const [owner, otherAccount] = await ethers.getSigners()

        const SimpleDelegating = await ethers.getContractFactory(
            'SimpleDelegating'
        )
        const simpleDelegating = await SimpleDelegating.deploy(
            otherAccount.address
        )

        return { simpleDelegating, owner, otherAccount }
    }

    describe('컨트랙트', function () {
        it('배포된 컨트랙트의 스윕할 대상의 마스터 월렛 확인', async function () {
            const { simpleDelegating, otherAccount } = await loadFixture(
                deployContract
            )

            expect(await simpleDelegating.masterWallet()).to.equal(
                otherAccount.address
            )
        })
    })
})
