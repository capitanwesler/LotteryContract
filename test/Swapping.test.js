const { web3 } = require('hardhat');
const assert = require('assert');
const Swapper = artifacts.require('Swapper');
const IERC20 = artifacts.require('IERC20');

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

  const accounts = await web3.eth.getAccounts();

  swapper = await Swapper.new(accounts[0]);
  Swapper.setAsDeployed(swapper);

  // DAI TOKEN
  DAItoken = await IERC20.at(DAI);

  // LINK TOKEN
  LINKtoken = await IERC20.at(LINK);
});

describe('Swapping ETH for Tokens', () => {
  it('change ETH for multiple tokens', async () => {
    const porcents = [50 * 10, 50 * 10];
    const tokens = [
      '0x6B175474E89094C44Da98b954EedeAC495271d0F', // DAI Token
      '0x514910771AF9Ca656af840dff83E8264EcF986CA', // LINK Token
    ];

    await swapper.swapEthForTokens(tokens, porcents, {
      value: web3.utils.toWei('5', 'ether'),
    });
  });
});
