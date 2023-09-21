Scripts ran:

```
forge script script/periphery/deploy/DeployTETHCurveOracle.s.sol --rpc-url $ETH_RPC_URL -vvvv --ledger --sender 0xA02e24B89Fb296A3c347f88C5Ff3dE3aeFAa6b8b --broadcast
```
Deployed TETHCurveOracle: `0x0B453140f6174788b5657876D6D25aA02f79962F`

Verified with:
```
ETHERSCAN_API_KEY=$ETHERSCAN_API_KEY forge verify-contract 0x0B453140f6174788b5657876D6D25aA02f79962F CurveOracle --compiler-version 0.8.21+commit.d9974bed --watch --constructor-args $(cast abi-encode "constructor(address)" "0x752eBeb79963cf0732E9c0fec72a49FD1DEfAEAC")
```

```
forge script script/v2/deploy/DeployAeraContractsForThreshold.s.sol --rpc-url $ETH_RPC_URL -vvvv --ledger --sender 0xA02e24B89Fb296A3c347f88C5Ff3dE3aeFAa6b8b --broadcast
```
Deployed AeraVaultV2: ``
Deployed AeraVaultHooks: ``
Deployed AeraVaultAssetRegistry: ``
Factories hardcoded into `script/v2/deploy/DeployAeraContractsForThreshold.s.sol``