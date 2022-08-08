import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { expect } from 'chai'
import { ethers } from 'hardhat'

describe('StayKingLeveragedPool 컨트랙트 테스트', () => {
    async function deployContract() {
        const [owner, otherAccount] = await ethers.getSigners()
        const StayKingLeveragedPool = await ethers.getContractFactory(
            'StayKingLeveragedPool'
        )

        const stayKingLeveragedPool = await StayKingLeveragedPool.deploy(
            owner.address
        )

        return { stayKingLeveragedPool, owner, otherAccount }
    }

    describe('컨트랙트', function () {
        it('배포 확인', async function () {
            const { stayKingLeveragedPool, otherAccount } = await loadFixture(
                deployContract
            )

            console.log(stayKingLeveragedPool)
        })
    })
})
