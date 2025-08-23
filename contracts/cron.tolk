import "@stdlib/gas-payments"
import "cron-storage"

// Message validation errors (100-199)
const ERROR_INVALID_MSG_FLAGS = 100;

// Initialization errors (200-299)
const ERROR_NOT_ENOUGH_BALANCE_FOR_INIT = 200;
const ERROR_INIT_NEXT_CALL_TIME_NOT_ZERO = 201;
const ERROR_INIT_REPEAT_EVERY_IS_ZERO = 202;
const ERROR_INIT_SENDER_IS_NOT_OWNER = 203;
const ERROR_INIT_STATE_HASH_IS_NOT_ZERO = 204;
const ERROR_INIT_STATE_DEPTH_IS_NOT_ZERO = 205;

// Authorization errors (400-499)
const ERROR_INVALID_PROVIDER_ADDRESS = 400;
const ERROR_ACCESS_DENIED = 401;
const ERROR_EARLY_TRIGGER = 402;
const ERROR_ALREADY_INITIALIZED = 403;

// General errors
const ERROR_UNSUPPORTED_OPCODE = 0xffff;

// Special addresses
const SPECIAL_DISCOVER_ADDR = address("0QAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAcGJH5Lec");

// Financial constants
const MIN_BALANCE_FOR_INIT = ton("0.1");
const MIN_AMOUNT_FOR_NOTIFY = ton("0.05");
const DISCOVERY_AMOUNT_FOR_NOTIFY = ton("0.001");

// Message schemes
struct (0xd027efe5) CronNotify {
    initStateHash: uint256
    initStateDepth: uint10
}
struct (0xbbe27821) CronDestroyed

struct (0x2e41d3ac) CronInit
struct (0x00000000) OpText { rest: RemainingBitsAndRefs }

type AllowedMessageToCron = CronInit | OpText

struct (0x2114702d) CronTrigger  {
    rewardAddress: address
    salt: uint32
}
struct (0x2e04891a) CronReward

type AllowedExternalMessageToCron = CronTrigger

// Get method reply scheme
struct CronInfoReply {
    nextCallTime: int
    reward: int
    availableBalance: int
    repeatEvery: int
}

@inline
fun validateTriggerMessage(msg: cell) {
    // just to avoid failure when running get method (get_cron_info)
    var data = msg.beginParse();
    var flags = data.loadUint(6);
    assert((flags == 0x18) | (flags == 0x10)) throw ERROR_INVALID_MSG_FLAGS;
    var addr = data.loadAddress();
    data.loadCoins();
}

fun notifyDiscoveryContract(storage: Storage) {
    // send message to special address for provider discovery
    val notifyMsg = createMessage({
        bounce: false,
        value: DISCOVERY_AMOUNT_FOR_NOTIFY,
        dest: SPECIAL_DISCOVER_ADDR,
        body: CronNotify {
            initStateHash: storage.initStateHash,
            initStateDepth: storage.initStateDepth
        }
    });
    notifyMsg.send(1);
}

fun onInternalMessage(in: InMessage) {
    val msg = lazy AllowedMessageToCron.fromSlice(in.body);
    
    match (msg) {
        CronInit => {
            var storage = lazy Storage.load();
            assert(!storage.initialized) throw ERROR_ALREADY_INITIALIZED;
            assert(contract.getOriginalBalance() >= MIN_BALANCE_FOR_INIT) throw ERROR_NOT_ENOUGH_BALANCE_FOR_INIT;
            assert(storage.repeatEvery > 0) throw ERROR_INIT_REPEAT_EVERY_IS_ZERO;
            assert(in.senderAddress == storage.ownerAddress) throw ERROR_INIT_SENDER_IS_NOT_OWNER;
            assert(storage.initStateHash == 0) throw ERROR_INIT_STATE_HASH_IS_NOT_ZERO;
            assert(storage.initStateDepth == 0) throw ERROR_INIT_STATE_DEPTH_IS_NOT_ZERO;
            
            validateTriggerMessage(storage.message);
            
            var data = contract.getData();
            storage.initStateDepth = data.depth();
            storage.initStateHash = data.hash();
            if (storage.nextCallTime == 0) {
                storage.nextCallTime = blockchain.now() + storage.repeatEvery;
            }
            storage.initialized = true;
            
            storage.save();
            notifyDiscoveryContract(storage);
        }
        OpText => {
            if (msg.rest.bitsEqual("destroy")) {
                var storage: Storage = lazy Storage.load();
                assert(in.senderAddress == storage.ownerAddress) throw ERROR_ACCESS_DENIED;
                notifyDiscoveryContract(storage);
                val destroyMsg = createMessage({
                    bounce: false,
                    value: 0,
                    dest: storage.ownerAddress,
                    body: CronDestroyed {}
                });
                destroyMsg.send(128 + 32);
            } else {
                if (in.valueCoins >= MIN_AMOUNT_FOR_NOTIFY) {
                    var storage: Storage = lazy Storage.load();
                    notifyDiscoveryContract(storage);
                }
            }
        }
        else => {
            throw ERROR_UNSUPPORTED_OPCODE;
        }
    }
}

fun onExternalMessage(msgBody: slice) {
    val msg = lazy AllowedExternalMessageToCron.fromSlice(msgBody, {
        throwIfOpcodeDoesNotMatch: ERROR_UNSUPPORTED_OPCODE,
    });
    var storage = lazy Storage.load();
    assert(blockchain.now() >= storage.nextCallTime) throw ERROR_EARLY_TRIGGER;
    assert(msg.rewardAddress.isInternal() & (msg.rewardAddress.getWorkchain() == 0)) throw ERROR_INVALID_PROVIDER_ADDRESS;

    acceptExternalMessage();

    storage.nextCallTime = blockchain.now() + storage.repeatEvery;
    storage.save();
    
    if (storage.reward > 0) {
        val rewardMsg = createMessage({
            bounce: false,
            value: storage.reward,
            dest: msg.rewardAddress,
            body: CronReward {}
        });
        rewardMsg.send(3);
    }
    
    sendRawMessage(storage.message, 3);
}

get fun get_cron_info(): CronInfoReply {
    var storage = lazy Storage.load();
    var msg = storage.message.beginParse().skipBits(6 + 267);
    var amount = msg.loadCoins();
    
    var balanceMinusAmounts = contract.getOriginalBalance() - (amount + storage.reward);
    
    return {
        nextCallTime: storage.nextCallTime,
        reward: storage.reward,
        availableBalance: balanceMinusAmounts,
        repeatEvery: storage.repeatEvery
    };
}