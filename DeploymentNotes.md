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
Deployed AeraVaultV2: `0x5B45aB5F70B3272410088D241bfDc6E3DBC0F5D4`
Deployed AeraVaultAssetRegistry: `0xdabA15E7eF77116d3eeC99C349AcfbA30BB4974c`
Deployed AeraVaultHooks: `0x029DDFccb7004e2e5D8e68AF4C5a6b3b4feBA658`
Factories hardcoded into `script/v2/deploy/DeployAeraContractsForThreshold.s.sol``

Then transferred ownership to multisig via:
```
VAULT_ADDRESS=0x5B45aB5F70B3272410088D2
41bfDc6E3DBC0F5D4  NEW_OWNER=0xc4b8454126969b1dca7854982E639EeeE19291AA forge script script/v2/Transfe
rOwnership.s.sol --rpc-url $ETH_RPC_URL -vvvv --ledger --sender 0xA02e24B89Fb296A3c347f88C5Ff3dE3aeFAa
6b8b --broadcast
```