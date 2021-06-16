const { assert, ethers } = require('hardhat');

//Accounts with ETH
const ADMIN = '0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266'; // Using first account of the giving node forked
const ADMIN2 = '0x1b3cb81e51011b549d78bf720b0d924ac763a7c2'; //17th place of the accounts with more ether according to etherscan

//Token Addresses
const ETH_ADDRESS = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';
const cETH_ADDRESS = '0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5';
const DAI_ADDRESS = '0x6b175474e89094c44da98b954eedeac495271d0f';
const cDAI_ADDRESS = '0x5d3a536e4d6dbd6114cc1ead35777bab948e3643';

let iAaveLendingPool;
let iAaveLengingPoolAddressesProvider;
let weth;
let cEth;

describe('Testing Compound cTokens', () => {
  /**
   * Goals:
   *    To mint  cToken.
   *    Redeem from cToken.
   */
  before(async () => {
    cEth = await ethers.getContractAt('ICERC20', cETH_ADDRESS);
    dai = await ethers.getContractAt('IERC20Weth', DAI_ADDRESS);
    cDai = await ethers.getContractAt('ICERC20', cDAI_ADDRESS);

    //Impersonating account
    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [ADMIN],
    });
  });

  it('Should make a deposit in eth to a cToken of Compound', async () => {
    try {
      //Getting cEth
      await cEth.mint({
        from: ADMIN,
        value: ethers.utils.parseUnits('1', 18),
      });
      const balanceCETH = await cEth.balanceOf(ADMIN);
      console.log('/n Current Balance of cEth: ', balanceCETH.toString());
    } catch (error) {
      console.log('There was an error getting the lending pool address', error);
    }
  });
});
