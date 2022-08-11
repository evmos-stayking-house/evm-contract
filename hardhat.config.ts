import { HardhatUserConfig } from 'hardhat/config'
import '@nomicfoundation/hardhat-toolbox'

const config: HardhatUserConfig = {
    solidity: {
        compilers: [
            {
                version: '0.8.4',
            },
        ],
    },
}
export default config
