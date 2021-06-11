const { upgrades, ethers } = require('hardhat');

let accounts;
let randomNumber;
let VRFcoordinator;
let LINKtoken;
let lottery;

const LINK = '0x514910771AF9Ca656af840dff83E8264EcF986CA';

describe('Testing: Lottery Contract', async () => {
  before(async () => {
    // - Getting the factories for the contracts:
    const VRFCoordinator = await ethers.getContractFactory(
      'VRFCoordinatorMock'
    );
    const RandomNumber = await ethers.getContractFactory(
      'RandomNumberConsumer'
    );
    const Lottery = await ethers.getContractFactory('Lottery');

    // - Getting the accounts on web3:
    accounts = await ethers.getSigners();

    // - VRFCoordinatorMock:
    VRFcoordinator = await VRFCoordinator.deploy(
      '0x514910771af9ca656af840dff83e8264ecf986ca'
    );
    await VRFcoordinator.deployed();

    // - RandomNumberConsumer:
    randomNumber = await RandomNumber.deploy(
      VRFcoordinator.address,
      LINK,
      '0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4'
    );
    await randomNumber.deployed();

    // - IERC20 of LINK:
    LINKtoken = await ethers.getContractAt('IERC20', LINK);

    await LINKtoken.transfer(
      randomNumber.address,
      ethers.utils.parseEther('5')
    );

    // - Lottery:
    lottery = await upgrades.deployProxy(Lottery, [
      2,
      accounts[0].address,
      500,
      randomNumber.address,
    ]);
    await lottery.deployed();
  });

  it('should get the randomResult number from the contract consumer', async () => {
    const tx = await lottery._getRandomNumber(5665);
    const receipt = await tx.wait();

    const requestId = receipt.events[3].args.requestId;
    const random = Math.floor(Math.random() * 100000);

    /*
      This is the VRFCoordinator that simulates the
      node calling the callback function.
    */
    await VRFcoordinator.callBackWithRandomness(
      requestId,
      ethers.utils.parseUnits(String(random), 18),
      randomNumber.address
    );

    await lottery._setRandomNumber();

    console.log(
      'Random Number: >> ',
      (await lottery.getRandomNumber()).toString()
    );
  });
});
