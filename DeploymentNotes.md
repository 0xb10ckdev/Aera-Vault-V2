Scripts ran:

```
forge script script/periphery/deploy/DeployTETHCurveOracle.s.sol --rpc-url $ETH_RPC_URL -vvvv --ledger --sender 0xA02e24B89Fb296A3c347f88C5Ff3dE3aeFAa6b8b --broadcast
```
Deployed TETHCurveOracle: `0x0B453140f6174788b5657876D6D25aA02f79962F`

Verified with:
```
ETHERSCAN_API_KEY=$ETHERSCAN_API_KEY forge verify-contract 0x0B453140f6174788b5657876D6D25aA02f79962F CurveOracle --compiler-version 0.8.21+commit.d9974bed --watch --constructor-args $(cast abi-encode "constructor(address)" "0x752eBeb79963cf0732E9c0fec72a49FD1DEfAEAC")
```

Factory deployment scripts ran:
```
forge script script/v2/deploy/DeployAeraV2Factory.s.sol --optimize --optimier-runs 200 --rpc-url $ETH_RPC_URL --chain-id 1 -vvvv --ledger --sender 0xA02e24B89Fb296A3c347f88C5Ff3dE3aeFAa6b8b --etherscan-api-key=CJP7T4ZNQPPWGWGWM4HTHNSKZG5Y44EI1T --verify --broadcast AeraV2Factory

forge script script/v2/deploy/DeployAeraVaultModulesFactory.s.sol --optimize --optimizer-runs 200 --rpc-url $ETH_RPC_URL --chain-id 1 -vvvv --ledger --sender 0xA02e24B89Fb296A3c347f88C5Ff3dE3aeFAa6b8b --etherscan-api-key=CJP7T4ZNQPPWGWGWM4HTHNSKZG5Y44EI1T --verify --broadcast AeraVaultModulesFactory
```
Factory deployment addresses:
```
AeraV2Factory: 0x9500948c2BEeeB2Da4CC3aA21CB05Bd2e7C27191
AeraVaultModulesFactory: 0x0fB6052Cc079A4EEc277f73e51E0dE3411792FF4
```

Deployment script ran:
```
forge script script/v2/deploy/DeployAeraContractsForThreshold.s.sol --optimize --optimizer-runs 200 --rpc-url $ETH_RPC_URL --chain-id 1 -vvvv --ledger --sender 0xA02e24B89Fb296A3c347f88C5Ff3dE3aeFAa6b8b --etherscan-api-key=CJP7T4ZNQPPWGWGWM4HTHNSKZG5Y44EI1T --verify --broadcast AeraVaultV2 AeraVaultHooks AeraVaultAssetRegistry
```
Deployed AeraVaultV2: `0x9ecf0d8dcc0076dd153749bece0762acae1c9049`
Deployed AeraVaultAssetRegistry: `0x148DfB85a90ff55AD3dFdAA345FEBf494A2E23D9`
Deployed AeraVaultHooks: `0x6aF3f5Ae6AdF03fe737AD42DBD152B2a08dB7d1C`
Factories hardcoded into `script/v2/deploy/DeployAeraContractsForThreshold.s.sol``

Then transferred ownership to multisig via:
```
VAULT_ADDRESS=0x9ecf0d8dcc0076dd153749bece0762acae1c9049  NEW_OWNER=0x71e47a4429d35827e0312aa13162197c23287546 forge script script/v2/TransferOwnership.s.sol --rpc-url $ETH_RPC_URL -vvvv --ledger --sender 0xA02e24B89Fb296A3c347f88C5Ff3dE3aeFAa6b8b --broadcast
```