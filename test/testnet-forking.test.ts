import { expect } from 'chai'
import { craftform, ethers } from 'hardhat'
import { before } from 'mocha'
import deployLocal from '../scripts/deploy/localhost'
import { toBN } from '../scripts/utils'
import "../crafts"

const ROUTER_ADDRESS = "0xb6b801Aa59970A9247F662F322a5B231503BF126"
const TOKEN_ADDRESS = {
    // tATOM: "",
    mockUSDC: "0xae95d4890bf4471501E0066b6c6244E1CAaEe791",
    mockUSDT: "0x397F8aBd481B7c00883fb70da2ea5Ae70999c37c",
    mockDAI: "0x7c4a1D38A755a7Ce5521260e874C009ad9e4Bf9c",
    mockWEVMOS: "0x3d486E0fBa11f6F929E99a47037A5cd615636E17",
    EVMOS: ethers.constants.AddressZero,
}


describe('Testnet fork test', async () => {
    describe('컨트랙트', function () {
        before("EvmoSwap 컨트랙트 config 업데이트", async function (){
            await craftform.contract("EvmoSwapRouter").upsertConfig({
                address: ROUTER_ADDRESS
            });
        })

        it('EvmoSwapHelper 배포', async function () {
            const [deployer] = await ethers.getSigners();
            const EvmoSwapHelper = await craftform.contract("EvmoSwapHelper").deploy(
                null,
                {
                    from: deployer.address,
                    args: [ROUTER_ADDRESS]
                }
            )

            expect(await EvmoSwapHelper.router()).to.equal(ROUTER_ADDRESS);
        })

        it("getDx", async function () {
            const EvmoSwap = await craftform.contract("EvmoSwapRouter").attach()
            const EvmoSwapHelper = await craftform.contract("EvmoSwapHelper").attach()

            const dy = toBN(1, 6);
            const swapDx = await EvmoSwap.getAmountsIn(
                dy, 
                [
                    TOKEN_ADDRESS.mockWEVMOS,
                    TOKEN_ADDRESS.mockUSDT,
                ]
            )
        
            const helperDx = await EvmoSwapHelper.getDx(
                TOKEN_ADDRESS.EVMOS,
                TOKEN_ADDRESS.mockUSDT,
                dy, 
            )

            expect(swapDx[1]).to.equal(dy);
            expect(helperDx).to.equal(swapDx[0]);
        })

        it("getDy", async function () {
            const EvmoSwap = await craftform.contract("EvmoSwapRouter").attach()
            const EvmoSwapHelper = await craftform.contract("EvmoSwapHelper").attach()

            const dx = toBN(1, 18);
            const swapDy = await EvmoSwap.getAmountsOut(
                dx, 
                [
                    TOKEN_ADDRESS.mockWEVMOS,
                    TOKEN_ADDRESS.mockUSDT,
                ]
            )
        
            const helperDy = await EvmoSwapHelper.getDy(
                TOKEN_ADDRESS.EVMOS,
                TOKEN_ADDRESS.mockUSDT,
                dx,
            )

            expect(swapDy[0]).to.equal(dx);
            expect(helperDy).to.equal(swapDy[1]);
        })

        it("exchange", async function () {
            const [account] = await ethers.getSigners()
            const EvmoSwapHelper = await craftform.contract("EvmoSwapHelper").attach()
            const USDT = await craftform.contract("ERC20").upsertConfig({
                alias: "USDT",
                address: TOKEN_ADDRESS.mockUSDT
            })

            const dx = toBN(1, 18);
        
            const helperDy = await EvmoSwapHelper.getDy(
                TOKEN_ADDRESS.EVMOS,
                TOKEN_ADDRESS.mockUSDT,
                dx,
            )
            
            const beforeEVMOS = await account.getBalance();
            const beforeUSDT = await USDT.balanceOf(account.address);
            
            const tx = await EvmoSwapHelper.exchange(
                TOKEN_ADDRESS.EVMOS,
                TOKEN_ADDRESS.mockUSDT,
                dx,
                helperDy,
                { value: dx.toString() }
            )
            const gasUsed = (await tx.wait()).gasUsed;

            const afterEVMOS = await account.getBalance();
            const afterUSDT = await USDT.balanceOf(account.address);

            expect(afterUSDT).to.equal(beforeUSDT.add(helperDy));
            expect(beforeEVMOS.sub(afterEVMOS)).to.equal(dx.add(gasUsed.mul(tx.gasPrice!)));
        })
    })
})
