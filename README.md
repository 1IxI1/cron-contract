# cron-contract

⚡️ **Contract deployment UI is available at: https://xssnick.github.io/cron-manifest/ui/**

UI source code is located in `cron-ui` folder of this repo

#### Deployment by another contract

You can deploy cron contract from another contract, for example to create a task for trigger itself from time to time.

For this you need to use cron contract initial data as follows:
```
beginCell()
        .storeUint(0, 1)
        .storeUint(0, 32)
        .storeUint({period in seconds}, 32)
        .storeUint({any number (salt)}, 32)
        .storeCoins({reward for providers per call})
        .storeSlice(getMyAddress())
        .storeRef({message cell (like for sendMessage)})
        .storeUint(0, 256)
        .storeUint(0, 10)
    .endCell()
```

## Project structure

-   `contracts` - source code of all the smart contracts of the project and their dependencies.
-   `wrappers` - wrapper classes (implementing `Contract` from ton-core) for the contracts, including any [de]serialization primitives and compilation functions.
-   `tests` - tests for the contracts.
-   `scripts` - scripts used by the project, mainly the deployment scripts.

## How to use

### Build

`npx blueprint build` or `yarn blueprint build`

### Test

`npx blueprint test` or `yarn blueprint test`

### Deploy or run another script

`npx blueprint run` or `yarn blueprint run`

### Add a new contract

`npx blueprint create ContractName` or `yarn blueprint create ContractName`
