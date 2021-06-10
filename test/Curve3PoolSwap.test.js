const I3Pool = artifacts.require('I3Pool');
const { assert, web3 } = require('hardhat');

const ADMIN = '0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266'; // Using first account of the giving node forked

//Utility Addresses
const ETH_ADDRESS = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';
const DAI_ADDRESS = '0x6b175474e89094c44da98b954eedeac495271d0f';

//Utility functions
const toWei = (value, type) => web3.utils.toWei(String(value), type);
const fromWei = (value, type) =>
  Number(web3.utils.fromWei(String(value), type));
const toBN = (value) => web3.utils.toBN(String(value));


describe('Testing Swaap with 3Pool', () => {
    let i3Pool

  before(async () => {
    // Getting the instance of the contract
    i3Pool = await I3Pool.at(
      '0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7'
    );
  });
  
  it('should get the pool balances and coins array', async () => {

    //Getting balance and coin of the pool
    const balance = await i3Pool.balances.call(0);
    const coins = await i3Pool.coins.call(0);
    
    //Balance and address of DAI
    console.log("Balance:", balance.toString(),"Coin:", coins);
  });

  it('Should make an exchange', async () => {

    //Get the the amount that would receive
    const amount = await i3Pool.get_dy(1, 2, 100)
    console.log(amount.toString(), "im amount");

    //Exchange
    const txEchange = await i3Pool.exchange(1, 2, 100, amount)
    console.log(txEchange, "im exchange");
  })
})