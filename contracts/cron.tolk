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

const OP_TRIGGER = 0x2114702d; // "op::cron_trigger addr:addr"c;
const OP_REWARD = 0x2e04891a; // "op::cron_trigger_reward"c;
const OP_INIT = 0x2e41d3ac; // "op::cron_init"c;
const OP_NOTIFY = 0xd027efe5; // "op::cron_notify"c;
const OP_DESTROYED = 0xbbe27821; // "op::cron_destroyed"c;

const SPECIAL_DISCOVER_ADDR_DATA = "cron discovery contract"c;

const ERROR_INVALID_MSG_FLAGS = 100;
const ERROR_INVALID_MSG_ADDRESS = 101;

const ERROR_NOT_ENOUGH_BALANCE_FOR_INIT = 200;
const ERROR_INIT_NEXT_CALL_TIME_NOT_ZERO = 201;
const ERROR_INIT_REPEAT_EVERY_IS_ZERO = 202;
const ERROR_INIT_SENDER_IS_NOT_OWNER = 203;
const ERROR_INIT_STATE_HASH_IS_NOT_ZERO = 204;
const ERROR_INIT_STATE_DEPTH_IS_NOT_ZERO = 205;

const ERROR_INVALID_PROVIDER_ADDRESS = 400;
const ERROR_ALREADY_INITIALIZED = 403;
const ERROR_ACCESS_DENIED = 401;

const ERROR_UNSUPPORTED_OPCODE = 0xffff;


const MIN_BALANCE_FOR_INIT = 100000000; // 0.1 TON
const MIN_AMOUNT_FOR_NOTIFY = 50000000; // 0.05 TON
const DISCOVERY_AMOUNT_FOR_NOTIFY = 1000000; // 0.001 TON

fun loadContractDataToGlobals() {
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

fun storeGlobalsToContractData() {
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

    loadContractDataToGlobals();

    var op: int = msgBody.getRemainingBitsCount() > 0 ? msgBody.loadMessageOp() : 0;

    if (op == OP_INIT) {
        assert(!ctxInitialized, ERROR_ALREADY_INITIALIZED);

        assert(getMyOriginalBalance() >= MIN_BALANCE_FOR_INIT, ERROR_NOT_ENOUGH_BALANCE_FOR_INIT);

        assert(ctxNextCallTime == 0, ERROR_INIT_NEXT_CALL_TIME_NOT_ZERO);
        assert(ctxRepeatEvery > 0, ERROR_INIT_REPEAT_EVERY_IS_ZERO);
        // we check owner address with sender to avoid
        // external message replacement with owner change attack
        assert(isSliceBitsEqual(ctxOwnerAddress, sender), ERROR_INIT_SENDER_IS_NOT_OWNER);
        assert(ctxInitStateHash == 0, ERROR_INIT_STATE_HASH_IS_NOT_ZERO);
        assert(ctxInitStateDepth == 0, ERROR_INIT_STATE_DEPTH_IS_NOT_ZERO);

        validateTriggerMessage(ctxMessage);

        var data: cell = getContractData();
        ctxInitStateDepth = data.getCellDepth();
        ctxInitStateHash = data.cellHash();
        ctxNextCallTime = now() + ctxRepeatEvery;

        storeGlobalsToContractData();

        // we need it to allow providers to add us back to list when balance is enough for trigger
        notifyDiscoveryContract();

        return;
    } else if (op == 0) {
        if (msgBody.getRemainingBitsCount() == 8*7) {
            if (isSliceBitsEqual(msgBody.preloadBits(8 * 7), "destroy")) {
                assert(isSliceBitsEqual(sender, ctxOwnerAddress), ERROR_ACCESS_DENIED);

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

    throw ERROR_UNSUPPORTED_OPCODE;
}

@inline
fun validateTriggerMessage(msg: cell) {
    // we do it to validate basic message structure to not corrupt a contract,
    // because we loading coins amount in get method
    var data: slice = msg.beginParse();
    var flags: int = data.loadUint(6);

    assert((flags == 0x18) | (flags == 0x10), ERROR_INVALID_MSG_FLAGS);
    assert(data.loadAddress().getRemainingBitsCount() == 267, ERROR_INVALID_MSG_ADDRESS);
    data.loadCoins();
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
    loadContractDataToGlobals();

    if ((msgBody.loadMessageOp() == OP_TRIGGER) & (now() >= ctxNextCallTime)) {
        var rewardAddr: slice = msgBody.loadAddress();
        // should be std addr of 0 workchain with no anycast
        assert(rewardAddr.preloadUint(11) == 0x400, ERROR_INVALID_PROVIDER_ADDRESS);
        msgBody.loadUint(32); // salt for ls to not ignore external
        msgBody.assertEndOfSlice();

        acceptExternalMessage();

        ctxNextCallTime = now() + ctxRepeatEvery;
        storeGlobalsToContractData();

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

get get_cron_info(): (int, int, int, int) {
    loadContractDataToGlobals();
    var msg: slice = ctxMessage.beginParse().skipBits(6 + 267);
    var amount: int = msg.loadCoins();

    var balanceMinusAmounts = getMyOriginalBalance() - (amount + ctxReward);
    return (ctxNextCallTime, ctxReward, balanceMinusAmounts, ctxRepeatEvery);
}