import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { expect } from 'chai'
import { ethers } from 'hardhat'

describe('StayKingLendingPool 컨트랙트 테스트', () => {
    async function deployContract() {
        // Contracts are deployed using the first signer/account by default
        const [owner, otherAccount] = await ethers.getSigners()

        const StayKingLendingPool = await ethers.getContractFactory(
            'StayKingLendingPool'
        )

        const InterestBearingToken = await ethers.getContractFactory(
            'InterestBearingToken'
        )

        const ibToken = await InterestBearingToken.deploy(
            'Interest Bearing Evmos',
            'ibEvmos',
            1000000
        )

        const stayKingLendingPool = await StayKingLendingPool.deploy(
            ibToken.address,
            owner.address
        )

        return { stayKingLendingPool, owner, otherAccount }
    }

    describe('컨트랙트', function () {
        it('배포 확인', async function () {
            const { stayKingLendingPool, otherAccount } = await loadFixture(
                deployContract
            )

            console.log(stayKingLendingPool)
        })
    })
})
