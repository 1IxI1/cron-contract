import { Blockchain, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { Cell, toNano } from '@ton/core';
import { Cron } from '../wrappers/Cron';
import '@ton/test-utils';
import { compile } from '@ton/blueprint';

describe('Cron', () => {
    let code: Cell;

    beforeAll(async () => {
        code = await compile('Cron');
    });

    let blockchain: Blockchain;
    let deployer: SandboxContract<TreasuryContract>;
    let cron: SandboxContract<Cron>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();

        cron = blockchain.openContract(Cron.createFromConfig({}, code));

        deployer = await blockchain.treasury('deployer');

        const deployResult = await cron.sendDeploy(deployer.getSender(), toNano('0.05'));

        expect(deployResult.transactions).toHaveTransaction({
            from: deployer.address,
            to: cron.address,
            deploy: true,
            success: true,
        });
    });

    it('should deploy', async () => {
        // the check is done inside beforeEach
        // blockchain and cron are ready to use
    });
});
