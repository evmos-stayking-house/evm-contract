import { DeployArgs, ProxyProps, address } from 'hardhat-craftform/dist/core';
import { BigNumberish } from 'ethers';
// argsType for constructor or initializer
// IInterestModel
export type IInterestModelArgs = [] | undefined;
export type IInterestModelDeployArgs = DeployArgs<IInterestModelArgs>;
// IStakedEvmos
export type IStakedEvmosArgs = [] | undefined;
export type IStakedEvmosDeployArgs = DeployArgs<IStakedEvmosArgs>;
// IStayking
export type IStaykingArgs = [] | undefined;
export type IStaykingDeployArgs = DeployArgs<IStaykingArgs>;
// ISwapHelper
export type ISwapHelperArgs = [] | undefined;
export type ISwapHelperDeployArgs = DeployArgs<ISwapHelperArgs>;
// IVault
export type IVaultArgs = [] | undefined;
export type IVaultDeployArgs = DeployArgs<IVaultArgs>;
// ContextUpgradeable
export type ContextUpgradeableArgs = [] | undefined;
export type ContextUpgradeableDeployArgs = DeployArgs<ContextUpgradeableArgs>;
// ERC20
export type ERC20Args = [string, string];
export type ERC20DeployArgs = DeployArgs<ERC20Args>;
// ERC20Ownable
export type ERC20OwnableArgs = [string, string];
export type ERC20OwnableDeployArgs = DeployArgs<ERC20OwnableArgs>;
// ERC20Upgradeable
export type ERC20UpgradeableArgs = [] | undefined;
export type ERC20UpgradeableDeployArgs = DeployArgs<ERC20UpgradeableArgs>;
// Initializable
export type InitializableArgs = [] | undefined;
export type InitializableDeployArgs = DeployArgs<InitializableArgs>;
// Ownable
export type OwnableArgs = [] | undefined;
export type OwnableDeployArgs = DeployArgs<OwnableArgs>;
// OwnableUpgradeable
export type OwnableUpgradeableArgs = [] | undefined;
export type OwnableUpgradeableDeployArgs = DeployArgs<OwnableUpgradeableArgs>;
// ReentrancyGuardUpgradeable
export type ReentrancyGuardUpgradeableArgs = [] | undefined;
export type ReentrancyGuardUpgradeableDeployArgs = DeployArgs<ReentrancyGuardUpgradeableArgs>;
// IERC20
export type IERC20Args = [] | undefined;
export type IERC20DeployArgs = DeployArgs<IERC20Args>;
// MockSwap
export type MockSwapArgs = [address[]];
export type MockSwapDeployArgs = DeployArgs<MockSwapArgs>;
// MockSwapHelper
export type MockSwapHelperArgs = [address];
export type MockSwapHelperDeployArgs = DeployArgs<MockSwapHelperArgs>;
// EvmoSwapHelper
export type EvmoSwapHelperArgs = [address];
export type EvmoSwapHelperDeployArgs = DeployArgs<EvmoSwapHelperArgs>;
// Stayking
export type StaykingArgs = [] | undefined;
export type StaykingProxyProps = ProxyProps<"__Stayking_init", [address]>;
export type StaykingDeployArgs = DeployArgs<StaykingArgs, StaykingProxyProps>;
// TripleSlopeModel
export type TripleSlopeModelArgs = [] | undefined;
export type TripleSlopeModelDeployArgs = DeployArgs<TripleSlopeModelArgs>;
// Vault
export type VaultArgs = [] | undefined;
export type VaultProxyProps = ProxyProps<"__Vault_init", [string, string, address, address, address, BigNumberish]>;
export type VaultDeployArgs = DeployArgs<VaultArgs, VaultProxyProps>;
