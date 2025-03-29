import { AccountWallet, CompleteAddress, Contract, Fr, createLogger } from '@aztec/aztec.js';
import { NFTContract } from '../artifacts/NFT';
import { deployerEnv } from '../src/config.js';

const logger = createLogger('aztec:http-pxe-client');

describe('BoxReact Contract Tests', () => {
  let wallet: AccountWallet;
  let contract: Contract;
  const numberToSet = Fr.random();
  let accountCompleteAddress: CompleteAddress;z

  beforeAll(async () => {
    wallet = await deployerEnv.getWallet();
    accountCompleteAddress = wallet.getCompleteAddress();
    const salt = Fr.random();

    contract = await NFTContract.deploy(
      wallet,
      accountCompleteAddress.address,
      "NFT Collection",
      "NFT",
      accountCompleteAddress.address
    )
      .send({ contractAddressSalt: salt })
      .deployed();

    logger.info(`L2 contract deployed at ${contract.address}`);
  }, 60000);

  test('Can set a number', async () => {
    logger.info(`${await wallet.getRegisteredAccounts()}`);

    await contract.methods
      .setNumber(
        numberToSet,
        accountCompleteAddress.address
      )
      .send()
      .wait();
  }, 40000);

  test('Can read a number', async () => {
    const viewTxReceipt = await contract.methods.getNumber(accountCompleteAddress.address).simulate();
    expect(numberToSet.toBigInt()).toEqual(viewTxReceipt.value);
  }, 40000);
});
