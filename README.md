## [Submodule] defi contract of the Stayking finance

## 로컬 노드 배포
1. 먼저 터미널에 아래 스크립트를 사용해서 로컬 노드를 실행합니다.
```bash
npm install
npm run node
```
이제 http://127.0.0.1:8545/ 혹은 http://localhost:8545/ 로 로컬 노드 접근이 가능합니다.

2. 새로운 터미널을 하나 띄우고, 아래 스크립트를 실행합니다.
```
npm run deploy:localhost
```
배포 스크립트를 실행하면 아래 컨트랙트들이 배포됩니다. 각 컨트랙트의 주소는 `configs/localhost/${컨트랙트명}` 에서 확인 가능하며,
`version` 이 가장 높은 것이 가장 최근에 배포된 컨트랙트입니다.

- `ERC20Ownable` 토큰 3종 (tATOM, tUSDC, tUSDT)
    이 토큰들은 deployer가 자유롭게 mint 가능하도록 설정해 두었습니다.
- `MockSwap` 및 `MockSwapHelper`
    MockSwap은 DEX의 가장 단순한 기능을 구현하기 위한 컨트랙트입니다.
    EVMOS, tATOM, tUSDC, tUSDT만을 지원합니다.
    교환비는 1EVMOS = 2tATOM = 2tUSDC = 2tUSDT 입니다.
- `TripleSlopeModel`
    Vault의 이자비용 계산을 위한 컨트랙트입니다. 웹 클라이언트에서 직접 사용할 일은 없습니다.
- `Stayking`
- `Vault`

현재는 `Stayking` 의 delegator side 관련된 함수는 구현되어 있지 않아서,
Vault 컨트랙트의 deposit, withdraw, balanceOf과 Stayking의 addPosition 등의 함수만 우선적으로 연결하시면 될 것 같습니다.


## 용어 정리
#### Lender
Vault에 토큰을 공급하는 주체입니다.
#### Deposit / Withdraw
Lender가 Vault에 토큰을 투입하는 것을 `deposit` , 다시 회수해가는 것을 `withdraw` 라 합니다.
#### loan / repay
Stayking 컨트랙트가 Vault에서 토큰을 빌려오는 것을 `loan` , 빚을 갚는 것을 `repay` 라 합니다.
#### Bps
Basis Points, 만분율
e.g. 100bps = 0.01 / 12345bps = 1.2345
#### 가동률 (Utilization Rate)
Vault에 lend된 토큰 중 Stayking으로 대출되어 나간 토큰의 비율
e.g. lending 100ATOM 중 70ATOM이 대출되어 나갔으면 가동률은 0.7이다.
lender들이 언제든지 `withdraw` 할 수 있기 때문에, Vault는 보유하고 전체 토큰 중 일정 비율을 여유분으로 남겨두어야 합니다.
이 최소 여유분의 비율을 `minReservedBps` 라 합니다.
#### Amount vs Share
주로 amount는 기본 Token의 양을 셀 때, share는 ibToken의 양을 셀 때 붙습니다.
totalAmount와 totalShare의 비로 ibToken과 Token의 비가 결정됩니다.
예시로 Amount와 Share에 대해 알아보겠습니다.
1. Alice는 ATOM Vault에 100 ATOM을 `Deposit` 하였습니다.
2. 최초에는 1 ibATOM = 1 ATOM 이므로 Alice는 100 ibATOM을 받습니다.
3. 이후에 Stayking에서 ATOM Vault로부터 `loan` 한 자산으로부터 10ATOM의 이자수익이 발생하였다고 가정합시다.  
    그렇다면 ATOM Vault에 들어있는 ATOM의 총량(`totalAmount`)은 110 ATOM이 됩니다.  
    (`totalShare`은 여전히 100ibATOM입니다.)
    따라서, 현재 교환비는 1 ibATOM = 1.1 ATOM입니다.
4. 이 시점에서, Alice가 `2번` 에서 받았던 100 ibATOM을 가져오면 `1 ibATOM = 1.1 ATOM` 의 교환비에 따라 110 ATOM을 수령하게 됩니다.
5. Vault에서 이자수익이 지속적으로 발생하므로 ibATOM과 ATOM간의 교환비는 시간이 지남에 따라 상승합니다.
    예외적으로, 유저가 ATOM을 빌려간 후에 ATOM의 가격이 급상승하여 빌려간 ATOM을 갚지 못하는 상황이 발생하면 이 교환비는 감소할 수 있습니다.


## Evmos Testnet JSON-RPC URL 및 체인 정보
```
ChainId : 9000
Currency : tEVMOS
Block Explorer : https://evm.evmos.dev
JSON-RPC URL : https://eth.bd.evmos.dev:8545	
```

## Evmos Mainnet JSON-RPC URL 및 체인 정보
```
ChainId : 9001
Currency : EVMOS
Block Explorer : https://evm.evmos.org
JSON-RPC URL : https://eth.bd.evmos.org:8545
```
