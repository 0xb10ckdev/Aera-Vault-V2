# Aera Protocol V2

[![Forge Test](https://github.com/GauntletNetworks/aera-contracts-v2/actions/workflows/forge.yml/badge.svg)](https://github.com/GauntletNetworks/aera-contracts-v2/actions/workflows/forge.yml)

Tools used:

- [Foundry](https://github.com/foundry-rs/foundry): Compile and run the smart contracts on a local development network
- [Solhint](https://github.com/protofire/solhint): linter
- [Prettier Plugin Solidity](https://github.com/prettier-solidity/prettier-plugin-solidity): code formatter

## Usage

### Pre Requisites

Before running any command, make sure to install dependencies:

```sh
$ yarn install
$ forge install
```

After that, copy the example environment file into an `.env` file like so:

```sh
$ cp .env.example .env
```

Team secrets are managed in [GCP secret manager](https://console.cloud.google.com/security/secret-manager?project=gauntlet-sim). If you don't have access, you need to be added to engineering@gauntlet.network

### Compile

Compile the smart contracts with Forge:

```sh
$ forge build
```

### Lint Solidity

Lint the Solidity code:

```sh
$ yarn lint:sol
```

### Test

Run the forge tests:

```sh
$ forge test
```

Tests run against forks of target environments (ie Mainnet, Polygon) and require a node provider to be authenticated in your [.env](./.env).

### Coverage

Generate the coverage report with env variables:

```sh
$ forge coverage
```

Generate the coverage report as lcov with env variables:

```sh
$ forge coverage --report lcov
```

### Report Gas

See the gas usage per unit test and average gas per method call:

```sh
$ forge test --gas-report
```

### Clean

Delete the smart contract artifacts and cache directories:

```sh
$ forge clean
```

### Deploy

Prior to deployment, make sure you have provided private key or mnemonic in your environment. If private key exists, it uses the private key, otherwise, it uses mnemonic.
And you should specify the parameters in configs.
To do this, copy the example config files without the `.example` name in `/config` path.

Deploy the AeraVaultV2Factory to a specific network:

```sh
$ forge script script/v2/deploy/DeployAeraVaultV2Factory.s.sol --fork-url <URL> --broadcast
```

Deploy the AeraVaultV2 to a specific network:

```sh
$ forge script script/v2/deploy/DeployAeraVaultV2.s.sol --fork-url <URL> --broadcast
```

Deploy the AeraVaultAssetRegistry to a specific network:

```sh
$ forge script script/v2/deploy/DeployAeraVaultAssetRegistry.s.sol --fork-url <URL> --broadcast

```

Deploy the AeraVaultHooks to a specific network:

```sh
$ forge script script/v2/deploy/DeployAeraVaultHooks.s.sol --fork-url <URL> --broadcast
```

To just get transaction calldata instead of deployment, you can omit `--broadcast`.
Once the deployments are done, the deployed addresses will be stored in the `/config/Deployments.json` file.
If you want to run the tests with the deployed contracts, you need to specify the deployment addresses in the file, and set `TEST_WITH_DEPLOYED_CONTRACTS` as `true`.
Then just run the tests.

#### Deployment Flow

```mermaid
graph LR
    D{Deployer}
    subgraph Contracts
        F(AeraVaultV2Factory)
        A(AeraVaultAssetRegistry)
        V(AeraVaultV2)
        H(AeraVaultHooks)
    end
    subgraph Process
        S1[1. Deploy AeraVaultV2Factory]:::Process
        S2[2. Deploy AeraVaultAssetRegistry]:::Process
        S3[3. Deploy AeraVaultV2]:::Process
        S4[4. Deploy AeraVaultHooks]:::Process
        S5[5. Link Vault and Hooks]:::Process
    end
    D --- S1 --> F
    D --- S2 --> A
    D --- S3 --> F -. Create .-> V -. link .-> A
    D --- S4 --> H -. link .-> V
    D --- S5 --> V -. link .-> H

    %% ===== This is just for order of process =====
    S1 --- A
    S2 --- H
    %% =============================================

    linkStyle 0,1 stroke:black
    linkStyle 2,3 stroke:cyan
    linkStyle 4,5,6,7 stroke:red
    linkStyle 8,9,10 stroke:blue
    linkStyle 11,12,13 stroke:green
    linkStyle 14,15 stroke:none

    classDef Process fill:none,stroke:none

    style Process fill:none,stroke:grey
    style Contracts fill:none,stroke:grey
```

## Syntax Highlighting

If you use VSCode, you can enjoy syntax highlighting for your Solidity code via the
[vscode-solidity](https://github.com/juanfranblanco/vscode-solidity) extension. The recommended approach to set the
compiler version is to add the following fields to your VSCode user settings:

```json
{
  "solidity.compileUsingRemoteVersion": "v0.8.19",
  "solidity.defaultCompiler": "remote"
}
```

Where of course `v0.8.19` can be replaced with any other version.
