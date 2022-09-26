import { CraftFactory } from 'hardhat-craftform/dist/core';
import * as Configs from './configs';
import * as Crafts from './crafts';
import * as Deploy from './deploy.args';

export type IEvmoSwapRouterCraftFactory = CraftFactory<
    Configs.IEvmoSwapRouterConfig,
    Crafts.IEvmoSwapRouterCraft,
    Deploy.IEvmoSwapRouterDeployArgs
>;
export type IInterestModelCraftFactory = CraftFactory<
    Configs.IInterestModelConfig,
    Crafts.IInterestModelCraft,
    Deploy.IInterestModelDeployArgs
>;
export type IStaykingCraftFactory = CraftFactory<
    Configs.IStaykingConfig,
    Crafts.IStaykingCraft,
    Deploy.IStaykingDeployArgs
>;
export type ISwapHelperCraftFactory = CraftFactory<
    Configs.ISwapHelperConfig,
    Crafts.ISwapHelperCraft,
    Deploy.ISwapHelperDeployArgs
>;
export type IUnbondedEvmosCraftFactory = CraftFactory<
    Configs.IUnbondedEvmosConfig,
    Crafts.IUnbondedEvmosCraft,
    Deploy.IUnbondedEvmosDeployArgs
>;
export type IVaultCraftFactory = CraftFactory<
    Configs.IVaultConfig,
    Crafts.IVaultCraft,
    Deploy.IVaultDeployArgs
>;
export type ContextUpgradeableCraftFactory = CraftFactory<
    Configs.ContextUpgradeableConfig,
    Crafts.ContextUpgradeableCraft,
    Deploy.ContextUpgradeableDeployArgs
>;
export type ERC20CraftFactory = CraftFactory<
    Configs.ERC20Config,
    Crafts.ERC20Craft,
    Deploy.ERC20DeployArgs
>;
export type ERC20OwnableCraftFactory = CraftFactory<
    Configs.ERC20OwnableConfig,
    Crafts.ERC20OwnableCraft,
    Deploy.ERC20OwnableDeployArgs
>;
export type ERC20UpgradeableCraftFactory = CraftFactory<
    Configs.ERC20UpgradeableConfig,
    Crafts.ERC20UpgradeableCraft,
    Deploy.ERC20UpgradeableDeployArgs
>;
export type InitializableCraftFactory = CraftFactory<
    Configs.InitializableConfig,
    Crafts.InitializableCraft,
    Deploy.InitializableDeployArgs
>;
export type OwnableCraftFactory = CraftFactory<
    Configs.OwnableConfig,
    Crafts.OwnableCraft,
    Deploy.OwnableDeployArgs
>;
export type OwnableUpgradeableCraftFactory = CraftFactory<
    Configs.OwnableUpgradeableConfig,
    Crafts.OwnableUpgradeableCraft,
    Deploy.OwnableUpgradeableDeployArgs
>;
export type ReentrancyGuardUpgradeableCraftFactory = CraftFactory<
    Configs.ReentrancyGuardUpgradeableConfig,
    Crafts.ReentrancyGuardUpgradeableCraft,
    Deploy.ReentrancyGuardUpgradeableDeployArgs
>;
export type IERC20CraftFactory = CraftFactory<
    Configs.IERC20Config,
    Crafts.IERC20Craft,
    Deploy.IERC20DeployArgs
>;
export type MockSwapCraftFactory = CraftFactory<
    Configs.MockSwapConfig,
    Crafts.MockSwapCraft,
    Deploy.MockSwapDeployArgs
>;
export type MockSwapHelperCraftFactory = CraftFactory<
    Configs.MockSwapHelperConfig,
    Crafts.MockSwapHelperCraft,
    Deploy.MockSwapHelperDeployArgs
>;
export type EvmoSwapHelperCraftFactory = CraftFactory<
    Configs.EvmoSwapHelperConfig,
    Crafts.EvmoSwapHelperCraft,
    Deploy.EvmoSwapHelperDeployArgs
>;
export type StaykingCraftFactory = CraftFactory<
    Configs.StaykingConfig,
    Crafts.StaykingCraft,
    Deploy.StaykingDeployArgs
>;
export type TripleSlopeModelCraftFactory = CraftFactory<
    Configs.TripleSlopeModelConfig,
    Crafts.TripleSlopeModelCraft,
    Deploy.TripleSlopeModelDeployArgs
>;
export type UnbondedEvmosCraftFactory = CraftFactory<
    Configs.UnbondedEvmosConfig,
    Crafts.UnbondedEvmosCraft,
    Deploy.UnbondedEvmosDeployArgs
>;
export type VaultCraftFactory = CraftFactory<
    Configs.VaultConfig,
    Crafts.VaultCraft,
    Deploy.VaultDeployArgs
>;
