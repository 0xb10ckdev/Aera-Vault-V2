Scripts ran:

```
forge script script/periphery/deploy/DeployTETHCurveOracle.s.sol --rpc-url $ETH_RPC_URL -vvvv --ledger --sender 0xA02e24B89Fb296A3c347f88C5Ff3dE3aeFAa6b8b --broadcast
```
Deployed TETHCurveOracle: `0x0B453140f6174788b5657876D6D25aA02f79962F`

```
forge script script/v2/deploy/DeployAeraContractsForThreshold.s.sol --rpc-url $ETH_RPC_URL -vvvv --ledger --sender 0xA02e24B89Fb296A3c347f88C5Ff3dE3aeFAa6b8b --broadcast
```
Deployed AeraVaultV2: ``
Deployed AeraVaultHooks: ``
Deployed AeraVaultAssetRegistry: ``
Factories hardcoded into `script/v2/deploy/DeployAeraContractsForThreshold.s.sol``