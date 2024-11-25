import "@stdlib/gas-payments.tolk"

global ctxInitialized: int;
global ctxNextCallTime: int;
global ctxRepeatEvery: int;
global ctxReward: int;
global ctxSalt: int;
global ctxOwnerAddress: slice;
global ctxMessage: cell;
global ctxInitStateHash: int;
global ctxInitStateDepth: int;


const OP_TRIGGER = "op::cron_trigger addr:addr"c;
const OP_REWARD = "op::cron_trigger_reward"c;
const OP_INIT = "op::cron_init"c;
const OP_NOTIFY = "op::cron_notify"c;
const OP_DESTROYED = "op::cron_destroyed"c;
const OP_TOPUP = "op::cron_topup"c;

const SPECIAL_DISCOVER_ADDR_DATA = "cron discovery contract"c;

const MIN_BALANCE_FOR_INIT = 100000000; // 0.1 TON
const MIN_AMOUNT_FOR_NOTIFY = 50000000; // 0.05 TON
const DISCOVERY_AMOUNT_FOR_NOTIFY = 1000000; // 0.001 TON

fun loadData() {
    var data: slice = getContractData().beginParse();

    ctxInitialized = data.loadUint(1);
    ctxNextCallTime = data.loadUint(32);
    ctxRepeatEvery = data.loadUint(32);
    ctxSalt = data.loadUint(32);
    ctxReward = data.loadCoins();
    ctxOwnerAddress = data.loadAddress();
    ctxMessage = data.loadRef();
    ctxInitStateHash = data.loadUint(256);
    ctxInitStateDepth = data.loadUint(10);
}

fun storeData() {
    setContractData(beginCell()
        .storeUint(1, 1)
        .storeUint(ctxNextCallTime, 32)
        .storeUint(ctxRepeatEvery, 32)
        .storeUint(ctxSalt, 32)
        .storeCoins(ctxReward)
        .storeSlice(ctxOwnerAddress)
        .storeRef(ctxMessage)
        .storeUint(ctxInitStateHash, 256)
        .storeUint(ctxInitStateDepth, 10)
    .endCell());
}

fun onInternalMessage(msgValue: int, msgFull: cell, msgBody: slice) {
    var cs = msgFull.beginParse();
    var flags = cs.loadMessageFlags();
    var sender: slice = cs.loadAddress();
    if (isMessageBounced(flags)) {
        return;
    }

    loadData();

    var op: int = msgBody.getRemainingBitsCount() > 0 ? msgBody.loadMessageOp() : 0;

    if (op == OP_INIT) {
        assert(!ctxInitialized, 403);

        assert(getMyOriginalBalance() >= MIN_BALANCE_FOR_INIT, 200);

        assert(ctxNextCallTime == 0, 201);
        assert(ctxRepeatEvery > 0, 202);
        // we check owner address with sender to avoid
        // external message replacement with owner change attack
        assert(isSliceBitsEqual(ctxOwnerAddress, sender), 203);
        assert(ctxInitStateHash == 0, 204);
        assert(ctxInitStateDepth == 0, 205);

        verifyTriggerMessage(ctxMessage);

        var data: cell = getContractData();
        ctxInitStateDepth = data.getCellDepth();
        ctxInitStateHash = data.cellHash();
        ctxNextCallTime = now() + ctxRepeatEvery;

        storeData();

        // we need it to allow providers to add us back to list when balance is enough for trigger
        notifyDiscoveryContract();

        return;
    } else if (op == 0) {
        if (msgBody.getRemainingBitsCount() == 8*7) {
            if (isSliceBitsEqual(msgBody.preloadBits(8 * 7), "destroy")) {
                assert(isSliceBitsEqual(sender, ctxOwnerAddress), 403);

                notifyDiscoveryContract();

                sendMessage(beginCell()
                .storeUint(0x10, 6) // non bouncable
                .storeSlice(ctxOwnerAddress)
                .storeCoins(0)
                .storeUint(0, 1 + 4 + 4 + 64 + 32 + 1 + 1)
                .storeUint(OP_DESTROYED, 32)
                .endCell(), 128 + 32);

                return;
            }
        }

        if (msgValue >= MIN_AMOUNT_FOR_NOTIFY) {
            notifyDiscoveryContract();
        }

        return;
    }

    throw 0xffff;
}

@inline
fun verifyTriggerMessage(msg: cell) {
    var data: slice = msg.beginParse();
    var flags: int = data.loadUint(6);

    assert((flags == 0x18) | (flags == 0x10), 100);
    assert(data.loadAddress().getRemainingBitsCount() == 267, 101);
    data.loadCoins();

    var bData: int = data.loadUint(1 + 4 + 4 + 64 + 32);
    assert(bData == 0, 102);

    var hasState: int = data.loadBool();
    if (hasState) {
        var stateInitRef: cell = data.loadMaybeRef(); // load either state
        assert(stateInitRef != null, 103); // state init must be in ref (simplify validation)

        var si: slice = stateInitRef.beginParse();
        var (bits, refs) = si.getRemainingBitsAndRefsCount();
        assert((bits == 5) & (refs == 2), 104);
        assert(si.preloadUint(5) == 6, 105); // only code and data
    }
    data.loadMaybeRef(); // load either body
}

fun notifyDiscoveryContract() {
    // send message to special address, so providers can discover
    // our contract without scanning whole chain
    sendMessage(beginCell()
        .storeUint(0x10, 6) // non bouncable
        .storeUint(0x400, 11).storeUint(SPECIAL_DISCOVER_ADDR_DATA, 256)
        .storeCoins(DISCOVERY_AMOUNT_FOR_NOTIFY)
        .storeUint(0, 1 + 4 + 4 + 64 + 32 + 1 + 1)
        .storeUint(OP_NOTIFY, 32)
        // we send init data hash to allow contract addr verification without addtional calls
        .storeUint(ctxInitStateHash, 256)
        .storeUint(ctxInitStateDepth, 10)
    .endCell(), 1);
}

fun onExternalMessage(msgBody: slice) {
    loadData();

    if ((msgBody.loadMessageOp() == OP_TRIGGER) & (now() >= ctxNextCallTime)) {
        var rewardAddr: slice = msgBody.loadAddress();
        // should be std addr of 0 workchain with no anycast
        assert(rewardAddr.preloadUint(11) == 0x400, 400);

        acceptExternalMessage();

        ctxNextCallTime = now() + ctxRepeatEvery;
        storeData();

        if (ctxReward > 0) {
            // reward message
            sendMessage(beginCell()
                .storeUint(0x10, 6) // non bouncable
                .storeSlice(rewardAddr)
                .storeCoins(ctxReward)
                .storeUint(0, 1 + 4 + 4 + 64 + 32 + 1 + 1)
                .storeUint(OP_REWARD, 32)
                .endCell(), 3);
        }

        // cron message
        sendMessage(ctxMessage, 3);
    }
}

get getCronInfo(): (int, int, int, int) {
    loadData();
    var msg: slice = ctxMessage.beginParse().skipBits(6 + 267);
    var amount: int = msg.loadCoins();

    var balanceMinusAmounts = getMyOriginalBalance() - (amount + ctxReward);
    return (ctxNextCallTime, ctxReward, balanceMinusAmounts, ctxRepeatEvery);
}