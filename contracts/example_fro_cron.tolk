// simple counter contract in Tolk language

const OP_INCREASE = 0x1e8764ef;

// storage variables

global ctxLastUpdate: int;
global ctxCounter: int;
global ctxOwner: slice;

// loadData populates storage variables from persistent storage
fun loadData() {
    var ds = getContractData().beginParse();

    ctxLastUpdate = ds.loadUint(32);
    ctxCounter = ds.loadUint(32);
    ctxOwner = ds.loadAddress();
}

// saveData stores storage variables as a cell into persistent storage
fun saveData() {
    setContractData(
        beginCell()
        .storeUint(ctxLastUpdate, 32)
        .storeUint(ctxCounter, 32)
        .storeSlice(ctxOwner)
        .endCell()
    );
}

// onInternalMessage is the main entrypoint; it's called when a contract receives an internal message from other contracts
fun onInternalMessage(myBalance: int, msgValue: int, msgFull: cell, msgBody: slice) {
    if (msgBody.isEndOfSlice()) { // ignore all empty messages
        return;
    }

    var cs: slice = msgFull.beginParse();
    val flags = cs.loadMessageFlags();
    if (isMessageBounced(flags)) { // ignore all bounced messages
        return;
    }

    loadData(); // here we populate the storage variables

    var sender: slice = cs.loadAddress();

    if (addressIsNone(ctxOwner)) {
        ctxOwner = sender;
    } else {
        assert(isSliceBitsEqual(ctxOwner, sender), 403);
    }

    val op = msgBody.loadMessageOp();

    if (op == OP_INCREASE) {
        ctxCounter += 1;
        ctxLastUpdate = now();
        saveData();
        return;
    }

    throw 0xffff;
}

get currentCounter(): int {
    loadData();
    return ctxCounter;
}

get updatedAt(): int {
    loadData();
    return ctxLastUpdate;
}
