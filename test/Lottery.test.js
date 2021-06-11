const { web3, upgrades } = require('hardhat');
const assert = require('assert');
const { artifacts } = require('hardhat');
const RandomNumber = artifacts.require('RandomNumberConsumer');
const VRFCoordinator = artifacts.require('VRFCoordinatorMock');
const Lottery = artifacts.require('Lottery');
const IERC20 = artifacts.require('IERC20');

let accounts;
let randomNumber;
let VRFcoordinator;
let LINKtoken;
let lottery;

const LINK = '0x514910771AF9Ca656af840dff83E8264EcF986CA';

describe('Testing: Lottery Contract', async () => {
  before(async () => {
    // - Getting the accounts on web3:
    accounts = await web3.eth.getAccounts();

    // - VRFCoordinatorMock:
    const vrfNumber = await VRFCoordinator.new(
      '0x514910771af9ca656af840dff83e8264ecf986ca'
    );

    // - RandomNumberConsumer:
    randomNumber = await RandomNumber.new(
      vrfNumber.address,
      LINK,
      '0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4'
    );

    // - IERC20 of LINK:
    LINKtoken = await IERC20.at(LINK);

    await LINKtoken.transfer(
      randomNumber.address,
      web3.utils.toWei('5', 'ether')
    );

    // - Lottery:
    lottery = await upgrades.deployProxy(Lottery, [
      2,
      accounts[0],
      500,
      randomNumber.address,
    ]);
  });

  it('should get the randomResult number from the contract consumer', async () => {
    const tx = await lottery._getRandomNumber();

    console.log(tx);

    console.log(
      'Random Number: >> ',
      (await randomNumber.randomResult()).toString()
    );
  });
});
