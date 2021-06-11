const { ethers } = require('hardhat');

let swapper;
let DAItoken;
let LINKtoken;

/*
  This is just to get DAI tokens
  and LINK tokens in the forked mainnet.
*/

before(async () => {
  const DAI = '0x6B175474E89094C44Da98b954EedeAC495271d0F';
  const LINK = '0x514910771AF9Ca656af840dff83E8264EcF986CA';

  // - Getting the factories for the contracts:
  const Swapper = await ethers.getContractFactory('Swapper');

  const accounts = await ethers.getSigners();

  swapper = await Swapper.deploy(accounts[0].address);
  await swapper.deployed();

  // DAI TOKEN
  DAItoken = await ethers.getContractAt('IERC20', DAI);

  // LINK TOKEN
  LINKtoken = await ethers.getContractAt('IERC20', LINK);
});

describe('Swapping ETH for Tokens', () => {
  it('change ETH for multiple tokens', async () => {
    const porcents = [50 * 10, 50 * 10];
    const tokens = [
      '0x6B175474E89094C44Da98b954EedeAC495271d0F', // DAI Token
      '0x514910771AF9Ca656af840dff83E8264EcF986CA', // LINK Token
    ];

    await swapper.swapEthForTokens(tokens, porcents, {
      value: ethers.utils.parseEther('5'),
    });
  });
});
