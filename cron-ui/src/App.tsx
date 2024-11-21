import React from 'react';
import {Buffer} from 'buffer';
import logo from './logo.svg';
import './App.css';
import { TonConnectButton, TonConnectUIProvider, useTonAddress } from '@tonconnect/ui-react';
import { Address, address, beginCell, toNano } from '@ton/core';
import { Cell } from '@ton/core';

window.Buffer = Buffer;

function App() {

  const userFriendlyAddress = useTonAddress();

  return (//
        <div className="App">
          <header className="App-header">
            <img src={logo} className="App-logo" alt="logo" />
            <p>
              CRON UI
            </p>
              {userFriendlyAddress ? <p>Address: {userFriendlyAddress}</p> : <TonConnectButton />}
          </header>
        </div>
  );
}

function prepareContract(owner: Address, to: Address, reward: bigint) {
    const hexStringCode =
        'b5ee9c7241020f0100025f000114ff00f4a413f4bcf2c80b01020120020e020148030d0202cd040c0201200509020120060801ef007434c0fe900c005c6c2497c0f80875d27080250074c7cc248c5c38bc004820840b9074eb2ea3934820840e5921832ea38b0c0c7e11b1c17cb864fc013220040072c17e11b3c59c3e809c0072daa0842ef89e084072c7f26040283ec20c23850c70c0250c3cb06426a082bebc202fa4bc0137b8b8b8c3600700a63031f841f2d193f8276f10821005f5e100bef2e0c8f842c000f2e0c9f843c200f2e0caf84601c705f2e0cbf848c000f2e0ccf849c000f2e0cdf847f003ed4420d765f869f900f868f823f843a0f862f002f004005f3b513434c0007e1874c7c07e18b4c7c07e18f4c7c07e197e80007e193e90007e19b5007e19f4ffc07e1a34c24c3e1a600201200a0b005b321c4072c03e108072c7fe10c072c7fe114072c7fe113e80be11b3c5be11c0733e120072fffe124072c2727b5520005f3434c148700600b00404ac7cb8193e900075d2604042eebcb8197e800c74da887040bcb81980700064f50c74644c38a000a5d64400800e582ba00e5813800e583c1786d1438143828a9ed34d89d34f192d3154d5b18aa9693142046ee3cbde365261a00e5ffb87d013800e5b541086813f7f280e58ffc2400e5fffc2480e584e4b8fd841840041a02c15e003f08fa1020223ae43f40061f04ede21f088254143f085f089f086826100acf2f001d31f0182102114702dbaf823f842beb08e3efa4030f800f823f843a0f862f002f80ff84771fb0830f844c2008e1fc8801001cb0501cf16f844fa027001cb6a82102e04891a01cb1fc971fb08309130e29130e218e4428a';
    const buffer = Buffer.from(hexStringCode, 'hex');
      const code = Cell.fromBoc(buffer);

      let msg = beginCell()
          .storeUint(0x10, 6) // non bouncable
          .storeAddress(to)
          .storeCoins(0)
          .storeUint(0, 1 + 4 + 4 + 64 + 32 + 1 + 1)
          .storeUint(0, 32).storeStringTail("From cron")
          .endCell()

      let data = beginCell()
          .storeUint(0, 1)
          .storeUint(0, 32)
          .storeUint(60, 32) // every
          .storeUint(1213, 32) // salt
          .storeCoins(reward) // reward
          .storeAddress(owner)
          .storeRef(msg)
          .storeUint(0, 256)
          .storeUint(0, 10)
          .endCell();

      let state = beginCell().storeUint(0b00110, 5).storeRef(code[0]).storeRef(data).endCell();
      let body = beginCell().storeUint(0x2e41d3ac, 32).endCell();

      let bocHex = state.toBoc().toString('base64url');
      console.log(bocHex);

      return bocHex;
}

export default App;
