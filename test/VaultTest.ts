import { expect } from 'chai'
import { craftform, ethers } from 'hardhat'
import { before } from 'mocha'
import deployLocal from '../scripts/deploy/localhost'
import { toBN } from '../scripts/utils'


describe('Vault 컨트랙트 테스트', async () => {
    before(async () => {
        await deployLocal()
    })

    describe('컨트랙트', function () {

        it('배포 확인', async function () {
            const ibtATOM = await craftform.contract("Vault").attach("ibtATOM");
            console.log(ibtATOM.address);
        })

        it("First time Lending", async function () {
            const [deployer, lender1] = await ethers.getSigners();
            const tATOM = await craftform.contract("ERC20Ownable").attach("tATOM");
            const ibtATOM = await craftform.contract("Vault").attach("ibtATOM");

            // 이전 ibtATOM 잔고
            const beforeibtATOMBalance = await ibtATOM.balanceOf(lender1.address);

            // approve first
            const depositAmount = toBN(5, 18);
            await tATOM.connect(lender1).approve(ibtATOM.address, depositAmount);

            await ibtATOM.connect(lender1).deposit(depositAmount);

            const afteribtATOMBalance = await ibtATOM.balanceOf(lender1.address);

            // afteribtATOMBalance - beforeibtATOMBalance == depositAmount
            expect(afteribtATOMBalance.sub(beforeibtATOMBalance).eq(depositAmount)).eq(true);
        })
    })
})
