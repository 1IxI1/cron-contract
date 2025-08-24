// Storage structure for cron contract

struct Storage {
    initialized: bool
    nextCallTime: uint32
    repeatEvery: uint32
    salt: uint32
    reward: coins
    ownerAddress: address
    message: cell
    initStateHash: uint256
    initStateDepth: uint10
}

// Storage management functions
fun Storage.load(): Storage {
    return Storage.fromCell(contract.getData());
}

fun Storage.save(self): void {
    contract.setData(self.toCell());
}