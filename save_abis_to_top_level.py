import json


def save_abis_to_top_level():
    for contract in ['AeraVaultV2', 'AeraVaultAssetRegistry', 'AeraVaultHooks']:
        with open(f'./out/{contract}.sol/{contract}.json', 'r') as f:
            abi = json.load(f)['abi']
        with open(f'./{contract}.json', 'w') as f:
            json.dump(abi, f)

    
if __name__ == '__main__':
    save_abis_to_top_level()