import { toNano } from '@ton/core';
import { ExampleFroCron } from '../wrappers/ExampleFroCron';
import { compile, NetworkProvider } from '@ton/blueprint';

export async function run(provider: NetworkProvider) {
    const exampleFroCron = provider.open(
        ExampleFroCron.createFromConfig(
            {
                id: Math.floor(Math.random() * 10000),
                counter: 0,
            },
            await compile('ExampleFroCron')
        )
    );

    await exampleFroCron.sendDeploy(provider.sender(), toNano('0.05'));

    await provider.waitForDeploy(exampleFroCron.address);

    console.log('ID', await exampleFroCron.getID());
}
