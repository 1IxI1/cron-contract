import { Address, beginCell, Cell, Contract, contractAddress, ContractProvider, Sender, SendMode } from '@ton/core';

export type CronConfig = {};

export function cronConfigToCell(config: CronConfig): Cell {
    return beginCell().endCell();
}

export class Cron implements Contract {
    constructor(readonly address: Address, readonly init?: { code: Cell; data: Cell }) {}

    static createFromAddress(address: Address) {
        return new Cron(address);
    }

    static createFromConfig(config: CronConfig, code: Cell, workchain = 0) {
        const data = cronConfigToCell(config);
        const init = { code, data };
        return new Cron(contractAddress(workchain, init), init);
    }

    async sendDeploy(provider: ContractProvider, via: Sender, value: bigint) {
        await provider.internal(via, {
            value,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell().endCell(),
        });
    }
}
