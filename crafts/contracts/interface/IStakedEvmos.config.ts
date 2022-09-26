import { Contract, Config, BaseConfig } from 'hardhat-craftform/dist/core';

// Contract Config class
/**
 * Write down your custom configs...
 *  You can use @Contract property decorator to connect other contract's config.
 */
@Config()
export class IStakedEvmosConfig extends BaseConfig {}
