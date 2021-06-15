const { upgrades, ethers, network } = require('hardhat');
const assert = require('assert');

const LINK = '0x514910771AF9Ca656af840dff83E8264EcF986CA';
const DAI = '0x6B175474E89094C44Da98b954EedeAC495271d0F';
const USDT = '0xdAC17F958D2ee523a2206206994597C13D831ec7';
const AAVEPool = '0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9';
const addressIndexes = {
  '0x6B175474E89094C44Da98b954EedeAC495271d0F': 0, // DAI
  '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48': 1, // USDC
  '0xdAC17F958D2ee523a2206206994597C13D831ec7': 2, // USDT
  '0x4Fabb145d64652a948d72533023f6E7A623C7C53': 3, // TUSD
  '0x0000000000085d4780B73119b644AE5ecd22b376': 3, // BUSD
};
const addressCToken = [
  '0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643', // cDAI
  '0xf650C3d88D12dB855b8bf7D11Be6C55A4e07dCC9', // cUSDT
  '0x39AA39c021dfbaE8faC545936693aC917d5E7563', // cUSDC
  '0x12392F67bdf24faE0AF363c24aC620a2f67DAd86', // cTUSD
];

/*
  This is just to get DAI tokens
  and LINK tokens in the forked mainnet.
*/

describe('Swapping: ETH for Tokens', () => {
  let swapper;
  let DAItoken;
  let LINKtoken;
  let account1, account2;

  before(async () => {
    // - Getting the factories for the contracts:
    const Swapper = await ethers.getContractFactory('Swapper');

    [account1, account2] = await ethers.getSigners();

    swapper = await Swapper.deploy(account1.address);
    await swapper.deployed();

    // DAI TOKEN
    DAItoken = await ethers.getContractAt('IERC20', DAI);

    // LINK TOKEN
    LINKtoken = await ethers.getContractAt('IERC20', LINK);
  });

  it('change ETH for multiple tokens for the first account', async () => {
    const porcents = [35 * 10, 35 * 10, 30 * 10];
    const tokens = [
      '0x6B175474E89094C44Da98b954EedeAC495271d0F', // DAI Token
      '0x514910771AF9Ca656af840dff83E8264EcF986CA', // LINK Token
      '0xdAC17F958D2ee523a2206206994597C13D831ec7', // USDT Token
    ];

    await swapper.connect(account1).swapEthForTokens(tokens, porcents, {
      value: ethers.utils.parseEther('50'),
    });
  });
});

describe('Testing: Lottery Contract', async () => {
  let accounts;
  let randomNumber;
  let VRFcoordinator;
  let LINKtoken;
  let lottery;
  let alarmClock;
  let iERC20Dai;
  let iERC20USDT;

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
      '0x0000000000000000000000000000000000000000' /* Passing the 0 address, so after we can set it, the lending pool. */,
      '0x0000000000000000000000000000000000000000' /* Passing the 0 address, so after we can set it, the balance holder. */,
    ]);
    await lottery.deployed();

    await LINKtoken.transfer(lottery.address, ethers.utils.parseEther('5'));

    iERC20Dai = await ethers.getContractAt('IERC20', DAI);

    iERC20USDT = await ethers.getContractAt('IERC20', USDT);

    // - Setting some defaults:
    await lottery.setBalanceHolderAddress(USDT);
    await lottery.setLendingPool(AAVEPool);
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
      '0x0000000000000000000000000000000000000000',
      '0x0000000000000000000000000000000000000000' /* Passing the 0 address, so after we can set it, the balance holder. */,
    ]);
    await lotteryTest.deployed();

    await lotteryTest.setBalanceHolderAddress(USDT);

    await iERC20Dai.approve(
      lotteryTest.address,
      ethers.utils.parseEther('200')
    );

    await LINKtoken.transfer(lotteryTest.address, ethers.utils.parseEther('5'));

    await lotteryTest.buyTickets(
      DAI,
      200,
      ethers.utils.parseEther('200'),
      USDT,
      addressIndexes[DAI],
      addressIndexes[USDT]
    );

    const tx = await (await lotteryTest.sendTokensToPool()).wait();

    const requestId = tx.events[0].args.id;
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
    assert(Number((await lotteryTest.getRandomNumber()).toString()) > 0);
  });

  it('should set a balance holder to receive the tokens', async () => {
    console.log('Setting the balance holder to: >> ', USDT);
    await lottery.setBalanceHolderAddress(USDT);

    console.log(
      'The actual balance holder for asset is: >> ',
      await lottery.balanceHolderAddress()
    );

    assert.strictEqual(await lottery.balanceHolderAddress(), USDT);
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

  it('should add a player to the lottery players mapping by buying tokens', async () => {
    console.log('Buying a tickets for the lottery...');
    await iERC20Dai.approve(lottery.address, ethers.utils.parseEther('200'));
    await lottery.buyTickets(
      DAI,
      200,
      ethers.utils.parseEther('200'),
      USDT,
      addressIndexes[DAI],
      addressIndexes[USDT]
    );
    const player = await lottery.players(0);
    console.log('Who buyed the tickets: >> ', player.owner);
    assert.strictEqual(accounts[0].address, player.owner);
    assert.strictEqual('200', player.quantityTickets.toString());
    console.log(
      'Current contract Balance of USDT: >> ',
      (await iERC20USDT.balanceOf(lottery.address)).toString()
    );
  });

  it('should revert if a player try to buy more of the max ticket', async () => {
    console.log('Trying to buy out of the max tickets...');
    try {
      await lottery.buyTickets(
        DAI,
        1000,
        ethers.utils.parseEther('200'),
        USDT,
        addressIndexes[DAI],
        addressIndexes[USDT]
      );
    } catch (error) {
      assert(error);
    }
  });

  it('should change the lottery status when send tokens to pool and withdraw the funds', async () => {
    console.log(
      'Changing the status of the lottery, sending the tokens to the pool...'
    );
    console.log('StatusOfLottery: >> ', await lottery.statusLottery());
    const tx = await (await lottery.sendTokensToPool()).wait();
    const tx2 = await (
      await alarmClock.fulfillOracleRequest(
        tx.events[0].args.id,
        '0x0000000000000000000000000000000000000000000000000000000000000000'
      )
    ).wait();

    let iERC20AToken;
    let iERC20CToken;

    if ((await lottery.lendingPool()) === AAVEPool) {
      iERC20AToken = await ethers.getContractAt(
        'IERC20',
        await lottery.getAorCTokenAddress(USDT)
      );

      /*
        Traveling to the future,
        to see how much interest,
        we won already in the aToken.
      */
      await network.provider.send('evm_increaseTime', [10000000]);
      await network.provider.send('evm_mine');
      console.log(
        'We deposit 200 USDT so we have: >> ',
        (await iERC20AToken.balanceOf(lottery.address)).toString()
      );
      console.log('StatusOfLottery: >> ', await lottery.statusLottery());
      await alarmClock.fulfillOracleRequest(
        tx2.events[22].args.requestId,
        '0x0000000000000000000000000000000000000000000000000000000000000000'
      );
      assert.strictEqual(await lottery.statusLottery(), 0);
    } else {
      iERC20CToken = await ethers.getContractAt('ICERC20', addressCToken[1]);

      /*
        Traveling to the future,
        to see how much interest,
        we won already in the aToken.
      */
      console.log(
        'CToken before: >> ',
        (await iERC20CToken.balanceOfUnderlying(lottery.address)).toString()
      );
      await network.provider.send('evm_increaseTime', [100000]);
      await network.provider.send('evm_mine');
      console.log(
        'CToken after: >> ',
        (await iERC20CToken.balanceOfUnderlying(lottery.address)).toString()
      );
      console.log('StatusOfLottery: >> ', await lottery.statusLottery());
      await alarmClock.fulfillOracleRequest(
        tx2.events[15].args.requestId,
        '0x0000000000000000000000000000000000000000000000000000000000000000'
      );
      assert.strictEqual(await lottery.statusLottery(), 0);
    }
  });

  it('should make a swap with curve.fi', async () => {
    let daiBalance = await iERC20Dai.balanceOf(
      (
        await ethers.getSigners()
      )[0].address
    );

    await iERC20Dai.approve(lottery.address, ethers.utils.parseEther('200'));

    await lottery._swapWithCurve(
      addressIndexes[DAI],
      addressIndexes[USDT],
      ethers.utils.parseEther('200'),
      DAI,
      USDT
    );

    console.log('Current Balance of DAI: >> ', daiBalance.toString());
    console.log('---------------');
    daiBalance = await iERC20Dai.balanceOf(
      (
        await ethers.getSigners()
      )[0].address
    );
    console.log('Current Contract Balance of Dai: >> ', daiBalance.toString());
    console.log(
      'Current contract Balance of USDT: >> ',
      (await iERC20USDT.balanceOf(lottery.address)).toString()
    );
    assert(
      Number((await iERC20USDT.balanceOf(lottery.address)).toString()) > 0
    );
  });

  it('should earn interest in the compound cToken of DAI', async () => {
    const Lottery = await ethers.getContractFactory('Lottery');

    // - Lottery:
    const lotteryTest = await upgrades.deployProxy(Lottery, [
      1,
      accounts[0].address,
      500,
      randomNumber.address,
      alarmClock.address,
      45665,
      '0x0000000000000000000000000000000000000000',
      '0x0000000000000000000000000000000000000000' /* Passing the 0 address, so after we can set it, the balance holder. */,
    ]);
    await lotteryTest.deployed();

    await lotteryTest.setBalanceHolderAddress(DAI);

    await lotteryTest.setLendingPool(addressCToken[0]);

    await iERC20USDT.approve(
      lotteryTest.address,
      ethers.utils.parseEther('200')
    );

    await LINKtoken.transfer(lotteryTest.address, ethers.utils.parseEther('5'));

    await lotteryTest.buyTickets(
      USDT,
      200,
      ethers.utils.parseEther('200'),
      DAI,
      addressIndexes[USDT],
      addressIndexes[DAI]
    );

    const tx = await (await lotteryTest.sendTokensToPool()).wait();
    console.log(tx);

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
    assert(Number((await lotteryTest.getRandomNumber()).toString()) > 0);
  });

  // it('should make a swap with uniswap', async () => {
  //   let daiBalance = await iERC20Dai.balanceOf(
  //     (
  //       await ethers.getSigners()
  //     )[0].address
  //   );

  //   console.log('Initial balance of DAI: >> ', daiBalance.toString());
  //   await lottery._addAggregator(
  //     '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE',
  //     '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419'
  //   );

  //   console.log(
  //     await lottery.aggregators('0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE')
  //   );

  //   await lottery._swapWithUniswap(DAI, {
  //     value: ethers.utils.parseEther('2'),
  //   });

  //   daiBalance = await iERC20Dai.balanceOf(
  //     (
  //       await ethers.getSigners()
  //     )[0].address
  //   );

  //   console.log('End balance of DAI: >> ', daiBalance.toString());
  // });
});
