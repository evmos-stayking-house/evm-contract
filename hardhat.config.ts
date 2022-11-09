import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import 'hardhat-deploy';
import '@openzeppelin/hardhat-upgrades';
import * as dotenv from 'dotenv';

dotenv.config();

const config: HardhatUserConfig = {
    solidity: {
        version: '0.8.17',
        settings: {
            optimizer: {
                enabled: true,
                runs: 200,
            },
        },
    },
    mocha: {
        timeout: 99999999,
    },
    networks: {
        hardhat: {},
        localhost: {
            url: 'http://127.0.0.1:8545',
        },
        testnet: {
            chainId: 9000,
            // url: 'http://65.108.225.158:8545', // 자체적으로 운영중인 State-Sync 노드
            url: 'https://eth.bd.evmos.dev:8545',
            accounts: [
                process.env.DEPLOYER_PRIVATE_KEY!,
                process.env.STAKER_PRIVATE_KEY!,
            ],
        },
    },
};

export default config;
