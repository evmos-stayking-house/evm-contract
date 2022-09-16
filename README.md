## [Submodule] DeFi contract of StayKing House

## Deploy Local Node
1. First, run the local node using the script below in the terminal.

    ```bash
    npm install
    npm run node
    ```

    Local node access is now available at http://127.0.0.1:8545/ or http://localhost:8545/.

2. Open a new terminal and run the script below.
    ```
    npm run deploy:localhost
    ```
    When you run the deployment script, the contracts below are deployed. The address of each contract can be found in 'configs/localhost/${contract name}'
    The highest 'version' is the most recently distributed contract.


   - Three types of `ERC20Ownable` tokens (tATOM, tUSDC, tUSDT)
     These tokens are set to allow the deployer to mint freely.
   - `MockSwap` and `MockSwap Helper` MockSwap is a contract to implement the simplest features of DEX.
     Only EVMOS, tATOM, tUSDC, and tUSDT are supported. The replacement fee is 1 EVMOS = 2tATOM = 2tUSDC = 2tUSDT.
   - `TripleSlopeModel`
       Contract for calculating the interest cost of the Vault. It is not intended to be used directly by the web client.
   - `Stayking` Contract for Leverage Staking
   - `Vault` Contract for lending or borrowing Mock USDC for Leverage Staking
   - `UnbondedEvmos` uEVMOS token contract that allows future claims to be paid to users during unbonding


## Deployed the contracts on the testnet (evmos_9000-4)

```
    [mockUSDC] 0x9218b75D53612212137890354B1a16163Abb9DE3
    
    [MockSwap] 0x08Be1FDf4A512fc6caA7aE1Be029b922d05EA5B3
    
    [TripleSlopeModel] 0x739DDcC9e458bD0A88c0882aca7BB72EaFff8781
    
    [UnbondedEvmos] 0xedB25Fee105C80Ab43235e016962ffd29Fe616bC
    
    [Stayking] 0x18A1Af12338d5a0fFF6aADb4364dBd8efF58f3f6
    
    [Vault] 0x33061E03aa8082d03f0aA66cDCf8159c976fc806
```

## Terms
#### Lender
  The principal that supplies tokens to Vault.
- Deposit / Withdraw
   - Lender putting tokens into Vault is called 'deposit' and reclaiming them is called 'withdraw'.
- loan / repay
  - Stayking contract borrowing tokens from Vault is called 'loan' and paying debts is called 'repay'.
- Bps
  - Basis Points, Percentage of 10000
    ( e.g. 100bps = 0.01 / 12345bps = 1.2345 )
- Utilization Rate
  - Percentage of tokens lent to Vault that have been loaned to Stayking
  If 70ATOM of the e.g. lending 100ATOM is loaned, the utilization rate is 0.7.
  Because renders can 'withdraw' at any time, Vault must hold and leave a certain percentage of the total tokens free.
  The ratio of this minimum margin is called 'minReservedBps'.
#### Amount vs Share
The amount is usually added when counting the basic amount of Token, and the share is added when counting the amount of ibToken.
The ratio of totalAmount and totalShare determines the ratio of ibToken and Token.
Let's take an example of Mount and Share.

1. Bob 'Deposit' 100 Atom to the Atom Vault.
2. Bob receives 100 ib atom because it is initially 1 ib atom = 1 atom.
3. Let's assume that Stayking has earned an interest income of 10 Atom from an asset called 'loan' from the Atom Vault.
   If so, the total amount of ATOM in the ATOM Vault (`totalAmount`) is 110.
   (`totalShare` is still 100ibATOM.)
   Therefore, the current exchange rate is 1 ib Atom = 1.1 Atom.
4. At this point, Bob will receive 110 atom according to the exchange fee of '1 ib atom = 1.1 atom' if she brings the 100 ib atom she received at '2'.
5. Because interest income is constantly generated in Vault, the exchange rate between ibATOM and ATOM increases over time.
   Exceptionally, this exchange fee can be reduced if the user borrows an Atom and then the price of the Atom rises sharply and the user cannot pay back the borrowed Atom.




## Evmos Testnet JSON-RPC URL & Chain ID

```
ChainId : 9000
Currency : tEVMOS
Block Explorer : https://evm.evmos.dev
JSON-RPC URL : https://eth.bd.evmos.dev:8545	
```

