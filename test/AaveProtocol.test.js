const { assert, web3 } = require('hardhat');
const IAaveLendingPool = artifacts.require('IAaveLendingPool');
const IAaveLendingPoolAddressesProvider = artifacts.require(
  'IAaveLendingPoolAddressesProvider'
);
const IERC20Weth = artifacts.require('IERC20Weth');
const IERC20 = artifacts.require('IERC20');

//Accounts with ETH
const ADMIN = '0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266'; // Using first account of the giving node forked
const ADMIN2 = '0x1b3cb81e51011b549d78bf720b0d924ac763a7c2'; //17th place of the accounts with more ether according to etherscan

//Token Addresses
const ETH_ADDRESS = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';
const WETH_ADDRESS = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
const AWETH_ADDRESS = '0x030bA81f1c18d280636F32af80b9AAd02Cf0854e';
const DAI_ADDRESS = '0x6b175474e89094c44da98b954eedeac495271d0f';
const ADAI_ADDRESS = '0x028171bCA77440897B824Ca71D1c56caC55b68A3';

//Pools addresses for use
//Aave Lendign pool address
const AAVELP_ADDRESS = '0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9';
const AAVELP_ADDRESS_PROVIDER = '0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5';

//Utility functions
const toWei = (value, type) => web3.utils.toWei(String(value), type);
const fromWei = (value, type) =>
  Number(web3.utils.fromWei(String(value), type));
const toBN = (value) => web3.utils.toBN(String(value));

describe('Testing Lending Pools of Aave', () => {
  let iAaveLendingPool;
  let iAaveLengingPoolAddressesProvider;
  let weth;
  let aWeth;
  /**
   * Goals:
   *    Get the latest LendingPool from LendingPoolAddressesProvider.
   *    Deposit to LendingPool.
   *    Redeem from aToken.
   */
  before(async () => {
    //Impersonating account
    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [ADMIN2],
    });
    // Getting the instance of the contracts
    iAaveLendingPool = await IAaveLendingPool.at(AAVELP_ADDRESS);
    iAaveLengingPoolAddressesProvider = await IAaveLendingPoolAddressesProvider.at(
      '0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5'
    );
    weth = await IERC20Weth.at(WETH_ADDRESS);
    aWeth = await IERC20Weth.at(AWETH_ADDRESS);
  });

  it('Should make a deposit in eth to the LP of Aave', async () => {
    try {
      // const LPAddress = await iAaveLengingPoolAddressesProvider.getLendingPool();
      // console.log('Im lending pool address', LPAddress);

      //Depositing to the WETH contract to get weth from eth
      const deposit = await weth.deposit({ value: toWei(1) });
      const balance = await weth.balanceOf(ADMIN);
      console.log('Current Weth Balance: ', balance.toString());

      //Allow to spend weth
      const Allow = await weth.approve(AAVELP_ADDRESS, toWei(1), {
        from: ADMIN,
      });

      //Check weth available to spend
      const allowance = await weth.allowance(ADMIN, AAVELP_ADDRESS);
      console.log('Weth Allowed to be spend: ', allowance.toString());

      //Deposit to the Aave LP
      const tx = await iAaveLendingPool.deposit(
        WETH_ADDRESS,
        toWei(1),
        ADMIN,
        0,
        {
          from: ADMIN,
        }
      );

      const aWethBalance = await aWeth.balanceOf(ADMIN);
      console.log('Balance of aWeth Token: ', aWethBalance.toString());
    } catch (error) {
      console.log('There was an error getting the lending pool address', error);
    }
  });
});
