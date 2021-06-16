const LINK = '0x514910771AF9Ca656af840dff83E8264EcF986CA';
const DAI = '0x6B175474E89094C44Da98b954EedeAC495271d0F';
const USDT = '0xdAC17F958D2ee523a2206206994597C13D831ec7';
let accounts;
let randomNumber;
let VRFcoordinator;
let LINKtoken;
let lottery;
let alarmClock;
let iERC20Dai;
let iERC20USDT;

async function main() {
  // - Getting the factories for the contracts:
  const Swapper = await ethers.getContractFactory('Swapper');
  // - Getting the accounts on ethers:
  accounts = await ethers.getSigners();
  swapper = await Swapper.deploy(accounts[0].address);
  await swapper.deployed();

  // DAI TOKEN
  DAItoken = await ethers.getContractAt('IERC20', DAI);

  // LINK TOKEN
  LINKtoken = await ethers.getContractAt('IERC20', LINK);

  const porcents = [50 * 10, 50 * 10];
  const tokens = [
    '0x6B175474E89094C44Da98b954EedeAC495271d0F', // DAI Token
    '0x514910771AF9Ca656af840dff83E8264EcF986CA', // LINK Token
  ];

  await swapper.swapEthForTokens(tokens, porcents, {
    value: ethers.utils.parseEther('2'),
  });
  //deploying contracts
  // - Getting the factories for the contracts:
  const VRFCoordinator = await ethers.getContractFactory('VRFCoordinatorMock');

  const RandomNumber = await ethers.getContractFactory('RandomNumberConsumer');
  const Lottery = await ethers.getContractFactory('Lottery');
  const MockOracle = await ethers.getContractFactory('MockOracle');

  // - Getting the accounts on ethers:
  accounts = await ethers.getSigners();
  const firstBalance = await ethers.provider.getBalance(accounts[0].address);
  console.log(
    'first account available address:',
    accounts[0].address,
    '\n Balance:',
    firstBalance.toString()
  );
  // - VRFCoordinatorMock:
  VRFcoordinator = await VRFCoordinator.deploy(
    '0x514910771AF9Ca656af840dff83E8264EcF986CA'
  );
  await VRFcoordinator.deployed();

  console.log('\n VRF ADDRESS:', VRFcoordinator.address);

  // - RandomNumberConsumer:
  randomNumber = await RandomNumber.deploy(
    VRFcoordinator.address,
    LINK,
    '0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4'
  );
  await randomNumber.deployed();

  console.log('\n randomNumber ADDRESS:', randomNumber.address);

  await LINKtoken.transfer(randomNumber.address, ethers.utils.parseEther('5'));

  // - MockOracle for the AlarmClock:
  alarmClock = await MockOracle.deploy(LINK);
  await alarmClock.deployed();
  console.log('\n alarmClock ADDRESS:', alarmClock.address);

  await LINKtoken.transfer(alarmClock.address, ethers.utils.parseEther('5'));

  // - Lottery:
  lottery = await upgrades.deployProxy(Lottery, [
    2,
    accounts[0].address,
    500,
    randomNumber.address,
    alarmClock.address,
    45665,
    '0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9',
    USDT,
  ]);
  await lottery.deployed();

  await LINKtoken.transfer(lottery.address, ethers.utils.parseEther('5'));
  console.log('\n Lottery Address: ', lottery.address);
  iERC20Dai = await ethers.getContractAt('IERC20', DAI);

  iERC20USDT = await ethers.getContractAt('IERC20', USDT);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
