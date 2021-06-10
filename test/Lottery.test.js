const { web3 } = require('hardhat');
const { deployProxy, upgradeProxy } = require('@openzeppelin/truffle-upgrades');
const assert = require('assert');
const RandomNumber = artifacts.require('RandomNumberConsumer');
const IERC20 = artifacts.require('IERC20');

let accounts;
let randomNumber;
let LINKtoken;

const LINK = '0x514910771AF9Ca656af840dff83E8264EcF986CA';

describe('Testing: Lottery Contract', async () => {
  before(async () => {
    // Getting the accounts on web3:
    accounts = await web3.eth.getAccounts();

    randomNumber = await RandomNumber.new();
    LINKtoken = await IERC20.at(LINK);
    await LINKtoken.transfer(
      randomNumber.address,
      web3.utils.toWei('10', 'ether')
    );
  });

  it('should get the randomResult number from the contract consumer', async () => {
    await randomNumber.getRandomNumber(1231231);
    console.log(
      'Random Number: >> ',
      (await randomNumber.randomResult()).toString()
    );
  });
});
