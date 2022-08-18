import * as CraftFactories from './crafts.factory';
import { BaseCraft, BaseConfig, CraftFactory, DeployArgsBase } from 'hardhat-craftform/dist/core';

declare module "hardhat/types/runtime" {
    interface ICraftformHelper {
        contract(contract: "IInterestModel"): CraftFactories.IInterestModelCraftFactory;
        contract(contract: "IStayking"): CraftFactories.IStaykingCraftFactory;
        contract(contract: "ISwapHelper"): CraftFactories.ISwapHelperCraftFactory;
        contract(contract: "IUnbondedEvmos"): CraftFactories.IUnbondedEvmosCraftFactory;
        contract(contract: "IVault"): CraftFactories.IVaultCraftFactory;
        contract(contract: "ContextUpgradeable"): CraftFactories.ContextUpgradeableCraftFactory;
        contract(contract: "ERC20"): CraftFactories.ERC20CraftFactory;
        contract(contract: "ERC20Ownable"): CraftFactories.ERC20OwnableCraftFactory;
        contract(contract: "ERC20Upgradeable"): CraftFactories.ERC20UpgradeableCraftFactory;
        contract(contract: "Initializable"): CraftFactories.InitializableCraftFactory;
        contract(contract: "Ownable"): CraftFactories.OwnableCraftFactory;
        contract(contract: "OwnableUpgradeable"): CraftFactories.OwnableUpgradeableCraftFactory;
        contract(contract: "ReentrancyGuardUpgradeable"): CraftFactories.ReentrancyGuardUpgradeableCraftFactory;
        contract(contract: "IERC20"): CraftFactories.IERC20CraftFactory;
        contract(contract: "MockSwap"): CraftFactories.MockSwapCraftFactory;
        contract(contract: "MockSwapHelper"): CraftFactories.MockSwapHelperCraftFactory;
        contract(contract: "EvmoSwapHelper"): CraftFactories.EvmoSwapHelperCraftFactory;
        contract(contract: "Stayking"): CraftFactories.StaykingCraftFactory;
        contract(contract: "TripleSlopeModel"): CraftFactories.TripleSlopeModelCraftFactory;
        contract(contract: "Vault"): CraftFactories.VaultCraftFactory;
        contract(contract: string): CraftFactory<BaseConfig, BaseCraft<BaseConfig>, DeployArgsBase>;
    }
}
