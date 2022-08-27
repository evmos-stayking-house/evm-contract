import { HardhatUserConfig } from 'hardhat/config'
import '@nomicfoundation/hardhat-toolbox'
import 'hardhat-deploy'
import 'hardhat-craftform'
import * as dotenv from "dotenv";

dotenv.config();

const config: HardhatUserConfig = {
    solidity: {
        compilers: [
            {
                version: '0.8.4',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
        ],
    },
    craftform: {
        initializer: "__$_init"
    },
    networks: {
        hardhat: {
            // forking: {
            //     url: "https://eth.bd.evmos.dev:8545",
            // },
        },
        localhost: {
            accounts: [
                process.env.DEPLOYER_PRIVATE_KEY!,
                process.env.DELEGATOR_PRIVATE_KEY!
            ]
        },
        sooho: {
            chainId: 9000,
            url: "http://15.164.214.195:8545",
            accounts: [
                process.env.DEPLOYER_PRIVATE_KEY!,
                process.env.DELEGATOR_PRIVATE_KEY!
            ]
        },
        testnet: {
            chainId: 9000,
            url: "https://eth.bd.evmos.dev:8545",
            accounts: [
                process.env.DEPLOYER_PRIVATE_KEY!,
                process.env.DELEGATOR_PRIVATE_KEY!
            ]
        },
        mainnet: {
            chainId: 9001,
            url: "https://eth.bd.evmos.org:8545",
            accounts: [
                process.env.DEPLOYER_PRIVATE_KEY!,
                process.env.DELEGATOR_PRIVATE_KEY!
            ]
        }
    }
}
export default config
