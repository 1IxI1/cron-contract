# cron-contract

⚡️ **Contract deployment UI is available at: https://xssnick.github.io/cron-manifest/ui/**

UI source code is located in `cron-ui` folder of this repo

#### Deployment by another contract

You can deploy cron contract from another contract, for example to create a task for trigger itself from time to time.

For this you need to use cron contract initial data as follows:
```c
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

Full Tolk code example that can be used for CRON deployment from another contract:
```c
fun calculateStateInit(cronContractCode: cell): cell {
    var data: cell = beginCell()
        .storeUint(0, 1)
        .storeUint(0, 32)
        .storeUint(3600, 32) // every hour
        .storeUint(0, 32) // salt to randomize address
        .storeCoins(5000000) // 0.005 TON reward per trigger
        .storeSlice(getMyAddress())
        .storeRef(beginCell()
            .storeUint(0x10, 6) // non bouncable
            .storeSlice(getMyAddress())
            .storeCoins(ctxReward)
            .storeUint(0, 1 + 4 + 4 + 64 + 32 + 1 + 1)
            .storeUint(OP_CALL_ME_BACK, 32)
            .endCell())
        .storeUint(0, 256)
        .storeUint(0, 10)
    .endCell();

    return beginCell().storeUint(0, 2).storeDict(cronContractCode).storeDict(data).storeUint(0, 1).endCell();
}

fun calculateContractAddress(wc: int, stateInit: cell): slice {
    return beginCell().storeUint(4, 3)
        .storeInt(wc, 8)
        .storeUint(cellHash(stateInit), 256)
        .endCell()
    .beginParse();
}

fun deployCron(cronCode: cell, amount: int) {
    var stateInit: cell = calculateStateInit(cronCode);
    var addr: slice = calculateContractAddress(0, stateInit);
    var body: cell = beginCell().storeUint(0x2e41d3ac, 32).endCell(); // cron init opcode

    sendMessage(beginCell()
        .storeUint(0x18, 6)
        .storeSlice(addr)
        .storeCoins(amount)
        .storeUint(4 + 2 + 1, 1 + 4 + 4 + 64 + 32 + 1 + 1 + 1)
        .storeRef(stateInit)
        .storeRef(body)
    .endCell(), 1);
}
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
