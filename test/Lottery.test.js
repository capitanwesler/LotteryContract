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
    const Lottery = await ethers.getContractFactory('Lottery');
    // - Lottery:
    const lotteryTest = await upgrades.deployProxy(Lottery, [
      2,
      accounts[0].address,
      500,
      randomNumber.address,
      alarmClock.address,
      45665,
    ]);
    await lotteryTest.deployed();

    await LINKtoken.transfer(lotteryTest.address, ethers.utils.parseEther('5'));
    const tx = await lotteryTest.sendTokensToPool();

    const requestId = (await tx.wait()).events[0].args.id;
    const random = Math.floor(Math.random() * 100000);

    console.log(
      'Random Number: >> ',
      (await lotteryTest.getRandomNumber()).toString()
    );
    assert.strictEqual((await lotteryTest.getRandomNumber()).toString(), '0');

    await alarmClock.fulfillOracleRequest(
      requestId,
      '0x0000000000000000000000000000000000000000000000000000000000000000'
    );

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
      (await lotteryTest.getRandomNumber()).toString()
    );
    assert.notStrictEqual(
      (await lotteryTest.getRandomNumber()).toString(),
      '0'
    );
  });

  it('should add a aggregator to the mapping of aggregators', async () => {
    console.log('Adding the aggregator for ETH...');
    await lottery._addAggregator(
      '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE', // Stands for ETH in our Lottery
      '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419'
    );
    console.log(
      'Added the aggregator: >> ',
      await lottery.aggregators('0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE')
    );
    assert.strictEqual(
      await lottery.aggregators('0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE'),
      '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419'
    );
  });

  it('should remove a aggregator of the mapping of aggregators', async () => {
    console.log(
      'Removing the aggregator: >> ',
      await lottery.aggregators('0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE')
    );
    await lottery._removeAggregator(
      '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE' // Stands for ETH in our Lottery
    );
    assert.strictEqual(
      await lottery.aggregators('0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE'),
      '0x0000000000000000000000000000000000000000'
    );
  });

  it('should set the ticket cost, only the admin can do this', async () => {
    console.log('Setting the ticket cost to: >> 3');
    await lottery.setTicketCost(3);
    console.log('TicketCost: >> ', (await lottery.ticketCost()).toString());
    assert.strictEqual('3', (await lottery.ticketCost()).toString());
  });

  it('should add a player to the lottery players mapping', async () => {
    console.log('Buying a tickets for the lottery...');
    await lottery.buyTickets('0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE', 200);
    const player = await lottery.players(0);
    console.log('Who buyed the tickets: >> ', player.owner);
    assert.strictEqual(accounts[0].address, player.owner);
    assert.strictEqual('200', player.quantityTickets.toString());
  });

  it('should change the lottery status when send tokens to pool', async () => {
    console.log(
      'Changing the status of the lottery, sending the tokens to the pool...'
    );
    console.log('StatusOfLottery: >> ', await lottery.statusLottery());
    console.log(await (await lottery.sendTokensToPool()).wait());
    const requestId = (await (await lottery.sendTokensToPool()).wait())
      .events[0].args.id;
    await alarmClock.fulfillOracleRequest(
      requestId,
      '0x0000000000000000000000000000000000000000000000000000000000000000'
    );
    console.log('StatusOfLottery: >> ', await lottery.statusLottery());
  });
});
