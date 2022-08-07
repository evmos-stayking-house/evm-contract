import { ethers } from 'hardhat'
import { expect } from 'chai'
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'

describe('CoinPricingOracle 컨트랙트 테스트', () => {
    async function deployContract() {
        // Contracts are deployed using the first signer/account by default
        const [owner, otherAccount] = await ethers.getSigners()

        const CoinPricingOracle = await ethers.getContractFactory(
            'CoinPricingOracle'
        )
        const coinPricingOracle = await CoinPricingOracle.deploy(
            otherAccount.address
        )

        return { coinPricingOracle, owner, otherAccount }
    }

    describe('컨트랙트', function () {
        it('배포 테스트', async function () {
            const { coinPricingOracle, otherAccount } = await loadFixture(
                deployContract
            )
            console.log(coinPricingOracle)
        })
    })
})
