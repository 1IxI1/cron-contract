import { toNano } from '@ton/core';
import { Cron } from '../wrappers/Cron';
import { compile, NetworkProvider } from '@ton/blueprint';

export async function run(provider: NetworkProvider) {
    const cron = provider.open(Cron.createFromConfig({}, await compile('Cron')));

    await cron.sendDeploy(provider.sender(), toNano('0.05'));

    await provider.waitForDeploy(cron.address);

    // run methods on `cron`
}
