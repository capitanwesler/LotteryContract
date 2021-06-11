const { upgrades, ethers } = require('hardhat');
const assert = require('assert');

let accounts;
let randomNumber;
let VRFcoordinator;
let LINKtoken;
let lottery;
let alarmClock;

const LINK = '0x514910771AF9Ca656af840dff83E8264EcF986CA';

describe('Testing: Lottery Contract', async () => {
  before(async () => {
    // - Getting the factories for the contracts:
    const VRFCoordinator = await ethers.getContractFactory(
      'VRFCoordinatorMock'
    );

    // - IERC20 of LINK:
    LINKtoken = await ethers.getContractAt('IERC20', LINK);

    const RandomNumber = await ethers.getContractFactory(
      'RandomNumberConsumer'
    );
    const Lottery = await ethers.getContractFactory('Lottery');
    const MockOracle = await ethers.getContractFactory('MockOracle');

    // - Getting the accounts on ethers:
    accounts = await ethers.getSigners();

    // - VRFCoordinatorMock:
    VRFcoordinator = await VRFCoordinator.deploy(
      '0x514910771AF9Ca656af840dff83E8264EcF986CA'
    );
    await VRFcoordinator.deployed();

    // - RandomNumberConsumer:
    randomNumber = await RandomNumber.deploy(
      VRFcoordinator.address,
      LINK,
      '0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4'
    );
    await randomNumber.deployed();

    await LINKtoken.transfer(
      randomNumber.address,
      ethers.utils.parseEther('5')
    );

    // - MockOracle for the AlarmClock:
    alarmClock = await MockOracle.deploy(LINK);
    await alarmClock.deployed();

    await LINKtoken.transfer(alarmClock.address, ethers.utils.parseEther('5'));

    // - Lottery:
    lottery = await upgrades.deployProxy(Lottery, [
      2,
      accounts[0].address,
      500,
      randomNumber.address,
      alarmClock.address,
      45665,
    ]);
    await lottery.deployed();

    await LINKtoken.transfer(lottery.address, ethers.utils.parseEther('5'));
  });

  it('should get the randomResult number from the contract consumer', async () => {
    const tx = await lottery.sendTokensToPool();

    const requestId = (await tx.wait()).events[0].args.id;
    const random = Math.floor(Math.random() * 100000);

    console.log(
      'Random Number: >> ',
      (await lottery.getRandomNumber()).toString()
    );
    assert.strictEqual((await lottery.getRandomNumber()).toString(), '0');

    /*
      This is the VRFCoordinator that simulates the
      node calling the callback function.
    */
    await VRFcoordinator.callBackWithRandomness(
      requestId,
      ethers.utils.parseUnits(String(random), 18),
      randomNumber.address
    );

    console.log(
      'Random Number: >> ',
      (await lottery.getRandomNumber()).toString()
    );
    assert.notStrictEqual((await lottery.getRandomNumber()).toString(), '0');
  });

  // it ('should shot a determinate function when the clock is done', async () => {

  // });
});
