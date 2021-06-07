const CurveSwap = artifacts.require('CurveSwap');
const { assert, web3 } = require('hardhat');

//Accounts with funds for transactions.
// For example: 17th place of the accounts with more ether according to etherscan
const ADMIN = '0x1b3cb81e51011b549d78bf720b0d924ac763a7c2';

//Utility Addresses

const ETH_ADDRESS = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE'
const DAI_ADDRESS = '0x6b175474e89094c44da98b954eedeac495271d0f'
//Utility functions
const toWei = (value, type) => web3.utils.toWei(String(value), type);
const fromWei = (value, type) =>
  Number(web3.utils.fromWei(String(value), type));
const toBN = (value) => web3.utils.toBN(String(value));

// Curve Swap
contract('Curve Swap', () => {
  let curveSwap;

  //impersonating accounts and deploying
  //this will give us permissions for using it in our test environment
  before(async () => {
    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [ADMIN],
    });

    //Get contract instance
    curveSwap = await CurveSwap.new();
  });
  it('Calculate amount returned', async function () {

    console.log(curveSwap)
    
  });
});