const { web3 } = require('hardhat');
const { deployProxy, upgradeProxy } = require('@openzeppelin/truffle-upgrades');
const assert = require('assert');
const { artifacts } = require('hardhat');
const RandomNumber = artifacts.require('RandomNumberConsumer');
const VRFCoordinator = artifacts.require('VRFCoordinatorMock');
const IERC20 = artifacts.require('IERC20');

let accounts;
let randomNumber;
let VRFcoordinator;
let LINKtoken;

const LINK = '0x514910771AF9Ca656af840dff83E8264EcF986CA';

describe('Testing: Lottery Contract', async () => {
  before(async () => {
    // Getting the accounts on web3:
    accounts = await web3.eth.getAccounts();

    randomNumber = await RandomNumber.new();

    VRFcoordinator = await VRFCoordinator.at(
      '0x851356ae760d987E095750cCeb3bC6014560891C'
    );

    LINKtoken = await IERC20.at(LINK);

    await LINKtoken.transfer(
      randomNumber.address,
      web3.utils.toWei('10', 'ether')
    );
  });

  it('should get the randomResult number from the contract consumer', async () => {
    const tx = await randomNumber.getRandomNumber(111123123);

    const requestId = tx.logs[0].args.requestId;
    const random = Math.floor(Math.random() * 99999999999999999999) + 1;

    const tx2 = await VRFcoordinator.callBackWithRandomness(
      requestId,
      web3.utils.toBN(random),
      randomNumber.address
    );

    console.log(
      'Random Number: >> ',
      (await randomNumber.randomResult()).toString()
    );
  });
});
