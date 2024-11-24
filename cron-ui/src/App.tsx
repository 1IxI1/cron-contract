import React, { useState, useEffect, useCallback } from 'react';
import { Buffer } from 'buffer';
import logo from './logo.svg';
import './App.css';
import { SendTransactionRequest, TonConnectButton, useTonAddress, useTonConnectUI } from '@tonconnect/ui-react';
import { address, beginCell, contractAddress, storeStateInit, toNano } from '@ton/core';
import { Cell } from '@ton/core';

function generateCounterCronExample() {
    const hexStringCode =
        'b5ee9c7241010a0100a6000114ff00f4a413f4bcf2c80b0102016202070202ce03060201200405008d1b088831c02456f8007434c0c05c6c2456f83c007e900c3e10f5c2c0700024be18e63e10c071c17cb864f8b4c7cc208407a1d93beea6fe10a93e18be08fe187c00b82103fcbc2000253b513434c7c07e1874c7c07e18be900c3e18e000254c8f84101cb1ff84201cb1ff843cf16c9ed5480201200809000dbd916f800fc20c000dbe5687800fc21470be289f';
    const buffer = Buffer.from(hexStringCode, 'hex');
    const code = Cell.fromBoc(buffer);

    const salt = Math.floor(Math.random() * 1000000000);
    const data = beginCell().storeUint(0, 32).storeUint(0, 32).storeAddress(null).storeUint(salt, 32).endCell();

    const body = beginCell().storeUint(0x1e8764ef, 32).endCell();

    const si = { code: code[0], data };

    const stateBoc = beginCell().store(storeStateInit(si)).endCell().toBoc().toString('hex');
    const bodyBoc = body.toBoc().toString('hex');
    const contractAddr = contractAddress(0, si).toString();

    console.log('STATE:', stateBoc);
    console.log('BODY:', bodyBoc);
    console.log('ADDR:', contractAddr);

    return { stateBoc, bodyBoc, contractAddr };
}

window.Buffer = Buffer;

const inputStyle: React.CSSProperties = {
    margin: '10px 0',
    padding: '10px',
    borderRadius: '5px',
    border: '1px solid #ddd',
    width: 'calc(100% - 120px)', // Adjusted to fit alongside label
    boxSizing: 'border-box',
};

const labelStyle: React.CSSProperties = {
    width: '100px', // Adjusted width for labels
    display: 'inline-block',
    marginRight: '10px',
    fontSize: '14px',
    fontStyle: 'bold',
};

const rowStyle: React.CSSProperties = {
    display: 'flex',
    alignItems: 'center',
};

const buttonStyle = (isDisabled: boolean): React.CSSProperties => ({
    margin: '20px 0',
    padding: '12px 24px',
    backgroundColor: isDisabled ? '#d3d3d3' : '#6200ea',
    color: '#fff',
    borderRadius: '5px',
    border: 'none',
    cursor: isDisabled ? 'not-allowed' : 'pointer',
    width: '100%',
    boxSizing: 'border-box',
});

const headerStyle: React.CSSProperties = {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    textAlign: 'center',
    backgroundColor: '#282c34',
    padding: '20px',
    color: 'white',
};

const containerStyle: React.CSSProperties = {
    width: '100%',
    maxWidth: '500px',
    margin: '0 auto',
    padding: '20px',
    boxSizing: 'border-box',
};

const addressStyle: React.CSSProperties = {
    fontSize: '12px',
    margin: '10px 0',
    wordBreak: 'break-all', // To wrap the address properly
};

const App: React.FC = () => {
    const [tonConnectUI] = useTonConnectUI();
    const userFriendlyAddress = useTonAddress();
    const [advancedMode, setAdvancedMode] = useState(false);

    const [amount, setAmount] = useState('0.3');
    const [msgAmount, setMessageAmount] = useState('0.03');
    const [msgTo, setMsgTo] = useState('EQBx6tZZWa2Tbv6BvgcvegoOQxkRrVaBVwBOoW85nbP37_Go');
    const [msgEvery, setMsgEvery] = useState(180);
    const [reward, setReward] = useState('0.005');
    const [msgText, setMsgText] = useState('Hey, cron!');
    const [message, setMessage] = useState<any>(null);
    const [contractAddr, setContractAddr] = useState('');
    const [bodyBoc, setBodyBoc] = useState('');
    const [stateBoc, setStateBoc] = useState('');

    const fillExampleData = () => {
        const example = generateCounterCronExample();
        setMsgTo(example.contractAddr);
        setStateBoc(example.stateBoc);
        setBodyBoc(example.bodyBoc);
    };

    const prepareContract = useCallback(
        (
            message: string,
            amount: string,
            msgEvery: number,
            userFriendlyAddress: string,
            msgTo: string,
            msgAmount: string,
            reward: string,
            advancedMode: boolean,
            bodyBOC: string,
            stateBOC?: string,
        ) => {
            try {
                let msg = beginCell()
                    .storeUint(0x10, 6) // non bouncable
                    .storeAddress(address(msgTo))
                    .storeCoins(0)
                    .storeUint(0, 1 + 4 + 4 + 64 + 32 + 1 + 1)
                    .storeUint(0, 32)
                    .storeStringTail(message)
                    .endCell();

                if (advancedMode) {
                    const bufBody = Buffer.from(bodyBOC, 'hex');
                    const body = Cell.fromBoc(bufBody);

                    let bd = beginCell()
                        .storeUint(0x10, 6) // non bouncable
                        .storeAddress(address(msgTo))
                        .storeCoins(toNano(msgAmount))
                        .storeUint(0, 1 + 4 + 4 + 64 + 32);

                    if (stateBOC) {
                        const bufState = Buffer.from(stateBOC, 'hex');
                        const st = Cell.fromBoc(bufState);
                        bd.storeUint(3, 2).storeRef(st[0]); // state in ref
                    } else {
                        bd.storeUint(0, 1);
                    }
                    bd.storeUint(1, 1).storeRef(body[0]); // body in ref

                    msg = bd.endCell();
                } else {
                    reward = "0.005"
                }

                let data = beginCell()
                    .storeUint(0, 1)
                    .storeUint(0, 32)
                    .storeUint(msgEvery, 32) // every
                    .storeUint(777, 32) // salt
                    .storeCoins(toNano(reward)) // reward
                    .storeAddress(address(userFriendlyAddress))
                    .storeRef(msg)
                    .storeUint(0, 256)
                    .storeUint(0, 10)
                    .endCell();

                let state = beginCell().storeUint(0b00110, 5).storeRef(code[0]).storeRef(data).endCell();
                let body = beginCell().storeUint(0x2e41d3ac, 32).endCell();

                let stateBoc = state.toBoc().toString('base64');
                let bodyBoc = body.toBoc().toString('base64');

                let cAddr = contractAddress(0, {
                    code: code[0],
                    data: data,
                });

                setMessage({
                    address: cAddr.toString(), // message destination in user-friendly format
                    amount: toNano(amount).toString(), // Toncoin in nanotons
                    payload: bodyBoc,
                    stateInit: stateBoc,
                });

                setContractAddr(cAddr.toString());
                console.log('OK!');
            } catch (error) {
                console.log(error);
                setMessage(null);
                setContractAddr('');
            }
        },
        [],
    );

    useEffect(() => {
        prepareContract(
            msgText,
            amount,
            msgEvery,
            userFriendlyAddress,
            msgTo,
            msgAmount,
            reward,
            advancedMode,
            bodyBoc,
            stateBoc != '' ? stateBoc : undefined,
        );
    }, [
        amount,
        msgText,
        msgEvery,
        userFriendlyAddress,
        msgTo,
        reward,
        prepareContract,
        msgAmount,
        advancedMode,
        bodyBoc,
        stateBoc,
    ]);

    const deploy = (ui: any, message: any) => {
        if (message == null) return;

        const transaction: SendTransactionRequest = {
            validUntil: Date.now() + 5 * 60 * 1000, // 5 minutes
            messages: [message],
        };

        try {
            ui.sendTransaction(transaction);
        } catch (e) {
            console.log(e);
        }
    };

    return (
        <div className="App">
            <header style={headerStyle}>
                <img src={logo} className="App-logo" alt="logo" />
                <h1 style={{ fontSize: '24px', margin: '20px 0' }}>CRON UI</h1>
                {userFriendlyAddress ? '' : <TonConnectButton />}
                <p>Deploy your CRON contract on TON blockchain and schedule tasks with ease!</p>
                {userFriendlyAddress ? <div>
                    <label>
                        Advanced Mode:
                        <input type="checkbox" checked={advancedMode} onChange={() => setAdvancedMode(!advancedMode)} />
                    </label>
                </div> : ""}
            </header>
            <div style={containerStyle}>
                {userFriendlyAddress ? (
                    <>
                        <div style={addressStyle}>
                            <strong>Wallet Address:</strong> {userFriendlyAddress}
                        </div>
                        <div style={addressStyle}>
                            <strong>CRON Address:</strong> {contractAddr}
                        </div>
                        <div style={rowStyle}>
                            <label htmlFor="amount" style={labelStyle}>
                                Amount Balance:
                            </label>
                            <input
                                id="amount"
                                type="number"
                                value={amount}
                                style={inputStyle}
                                onChange={(e) => setAmount(e.target.value)}
                            />
                        </div>
                        <div style={rowStyle}>
                            <label htmlFor="msgTo" style={labelStyle}>
                                Message To:
                            </label>
                            <input
                                id="msgTo"
                                type="text"
                                value={msgTo}
                                placeholder="Message To"
                                style={inputStyle}
                                onChange={(e) => setMsgTo(e.target.value)}
                            />
                        </div>
                        <div style={rowStyle}>
                            <label htmlFor="msgEvery" style={labelStyle}>
                                Message Every (seconds):
                            </label>
                            <input
                                id="msgEvery"
                                type="number"
                                value={msgEvery}
                                placeholder="Message Every (seconds)"
                                style={inputStyle}
                                onChange={(e) => setMsgEvery(parseInt(e.target.value, 10))}
                            />
                        </div>
                        <div style={rowStyle}>
                            <label htmlFor="messageAmount" style={labelStyle}>
                                Message Amount:
                            </label>
                            <input
                                id="messageAmount"
                                type="number"
                                value={msgAmount}
                                onChange={(e) => setMessageAmount(e.target.value)}
                                style={inputStyle}
                            />
                        </div>
                        {advancedMode ? (
                            <>
                                <div style={rowStyle}>
                                    <label htmlFor="reward" style={labelStyle}>
                                        Reward:
                                    </label>
                                    <input
                                        id="reward"
                                        type="number"
                                        value={reward}
                                        placeholder="Reward"
                                        style={inputStyle}
                                        onChange={(e) => setReward(e.target.value)}
                                    />
                                </div>
                                <button
                                    style={{
                                        backgroundColor: '#0098EA',
                                        color: '#F7F9FB',
                                        border: '1px solid #ddd',
                                        margin: '20px 0',
                                        padding: '8px 16px',
                                        borderRadius: '5px',
                                        cursor: 'pointer',
                                        width: '50%',
                                    }}
                                    onClick={fillExampleData}
                                >
                                    Set Example Contract Data
                                </button>
                                <div style={rowStyle}>
                                    <label htmlFor="bodyBoc" style={labelStyle}>
                                        Body BOC (HEX):
                                    </label>
                                    <input
                                        id="bodyBoc"
                                        type="text"
                                        value={bodyBoc}
                                        style={inputStyle}
                                        onChange={(e) => setBodyBoc(e.target.value)}
                                    />
                                </div>
                                <div style={rowStyle}>
                                    <label htmlFor="stateBoc" style={labelStyle}>
                                        StateInit BOC (HEX):
                                    </label>
                                    <input
                                        id="stateBoc"
                                        type="text"
                                        value={stateBoc}
                                        style={inputStyle}
                                        onChange={(e) => setStateBoc(e.target.value)}
                                    />
                                </div>
                            </>
                        ) : (
                            <div style={rowStyle}>
                                <label htmlFor="msgText" style={labelStyle}>
                                    CRON Message Text:
                                </label>
                                <input
                                    id="msgText"
                                    type="text"
                                    value={msgText}
                                    placeholder="CRON Message Text"
                                    style={inputStyle}
                                    onChange={(e) => setMsgText(e.target.value)}
                                />
                            </div>
                        )}
                        <button
                            style={buttonStyle(message == null)}
                            disabled={message == null}
                            onClick={() => deploy(tonConnectUI, message)}
                        >
                            Deploy CRON Contract
                        </button>
                    </>
                ) : (
                    <TonConnectButton />
                )}
            </div>
        </div>
    );
};

const hexStringCode =
    'b5ee9c7241021001000276000114ff00f4a413f4bcf2c80b01020120020f020148030e0202cd040d020120050a0201200609026d3b68bb7ec07434c0fe900c005c6c2497c0f83c004875d2708024c074c7e49c16388860840b9074eb2eb8c080700038c097c0e103fcbc20070800aa10235f03f841f2d193f8276f10821005f5e100bef2e0c8f842c000f2e0c9f843c200f2e0caf84601c705f2e0cbf848c000f2e0ccf849c000f2e0cdf847f003ed4420d765f869f900f868f823f843a0f862f002f00400aa20d749c0388e3fd71d378b764657374726f798c7058e2d31f846c705f2e193f004c8801001cb05f846cf1670fa027001cb6a8210bbe2782101cb1fc98100a0fb0830db31e030915be2820afaf080be92f004dedb31005f3b513434c0007e1874c7c07e18b4c7c07e18f4c7c07e197e80007e193e90007e19b5007e19f4ffc07e1a34c24c3e1a600201200b0c005b321c4072c03e108072c7fe10c072c7fe114072c7fe113e80be11b3c5be11c0733e120072fffe124072c2727b552000973434c148700600b00404ac7cb8193e900075d2604042eebcb8197e800c74da0070003cb819b480006387bd010c081bbcb419f40835d2c07001407000ac3cb81a35c2c13001bcb81a644c38a0006dd64400800e582ba00e5813800e583c108383123f200e5ffb87d013800e5b541086813f7f280e58ffc2400e5fffc2480e584e4b8fd841840041a02c15e003f08fa1020223ae43f40061f04ede21f088254143f085f089f086826100a8f2f001d31f0182102114702dbaf823f842beb08e3cfa4030f800f823f843a0f862f002f844c2008e1fc8801001cb0501cf16f844fa027001cb6a82102e04891a01cb1fc973fb08309130e2f84773fb08309130e23b048606';
const buffer = Buffer.from(hexStringCode, 'hex');
const code = Cell.fromBoc(buffer);

export default App;
