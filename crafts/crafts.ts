import { CraftType } from 'hardhat-craftform/dist/core';
import * as Typechain from '../typechain-types';
import * as Configs from './configs';

export type IEvmoSwapRouterCraft = CraftType<
    Typechain.IEvmoSwapRouter,
    Configs.IEvmoSwapRouterConfig
>;
export type IInterestModelCraft = CraftType<
    Typechain.IInterestModel,
    Configs.IInterestModelConfig
>;
export type IStaykingCraft = CraftType<
    Typechain.IStayking,
    Configs.IStaykingConfig
>;
export type ISwapHelperCraft = CraftType<
    Typechain.ISwapHelper,
    Configs.ISwapHelperConfig
>;
export type IUnbondedEvmosCraft = CraftType<
    Typechain.IUnbondedEvmos,
    Configs.IUnbondedEvmosConfig
>;
export type IVaultCraft = CraftType<Typechain.IVault, Configs.IVaultConfig>;
export type ContextUpgradeableCraft = CraftType<
    Typechain.ContextUpgradeable,
    Configs.ContextUpgradeableConfig
>;
export type ERC20Craft = CraftType<Typechain.ERC20, Configs.ERC20Config>;
export type ERC20OwnableCraft = CraftType<
    Typechain.ERC20Ownable,
    Configs.ERC20OwnableConfig
>;
export type ERC20UpgradeableCraft = CraftType<
    Typechain.ERC20Upgradeable,
    Configs.ERC20UpgradeableConfig
>;
export type InitializableCraft = CraftType<
    Typechain.Initializable,
    Configs.InitializableConfig
>;
export type OwnableCraft = CraftType<Typechain.Ownable, Configs.OwnableConfig>;
export type OwnableUpgradeableCraft = CraftType<
    Typechain.OwnableUpgradeable,
    Configs.OwnableUpgradeableConfig
>;
export type ReentrancyGuardUpgradeableCraft = CraftType<
    Typechain.ReentrancyGuardUpgradeable,
    Configs.ReentrancyGuardUpgradeableConfig
>;
export type IERC20Craft = CraftType<Typechain.IERC20, Configs.IERC20Config>;
export type MockSwapCraft = CraftType<
    Typechain.MockSwap,
    Configs.MockSwapConfig
>;
export type MockSwapHelperCraft = CraftType<
    Typechain.MockSwapHelper,
    Configs.MockSwapHelperConfig
>;
export type EvmoSwapHelperCraft = CraftType<
    Typechain.EvmoSwapHelper,
    Configs.EvmoSwapHelperConfig
>;
export type StaykingCraft = CraftType<
    Typechain.Stayking,
    Configs.StaykingConfig
>;
export type TripleSlopeModelCraft = CraftType<
    Typechain.TripleSlopeModel,
    Configs.TripleSlopeModelConfig
>;
export type UnbondedEvmosCraft = CraftType<
    Typechain.UnbondedEvmos,
    Configs.UnbondedEvmosConfig
>;
export type VaultCraft = CraftType<Typechain.Vault, Configs.VaultConfig>;
