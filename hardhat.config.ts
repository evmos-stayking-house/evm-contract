import { HardhatUserConfig } from 'hardhat/config'
import '@nomicfoundation/hardhat-toolbox'

const config: HardhatUserConfig = {
    solidity: {
        compilers: [
            {
                version: '0.6.0',
            },
            {
                version: '0.8.0',
            },
        ],
    },
}
export default config
