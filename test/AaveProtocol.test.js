const { assert, ethers } = require('hardhat');

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

let iAaveLendingPool;
let iAaveLengingPoolAddressesProvider;
let weth;
let aWeth;

describe('Testing Lending Pools of Aave', () => {
  /**
   * Goals:
   *    Get the latest LendingPool from LendingPoolAddressesProvider.
   *    Deposit to LendingPool.
   *    Redeem from aToken.
   */
  before(async () => {
    iAaveLendingPool = await ethers.getContractAt(
      'IAaveLendingPool',
      AAVELP_ADDRESS
    );
    iAaveLengingPoolAddressesProvider = await ethers.getContractAt(
      'IAaveLendingPoolAddressesProvider',
      AAVELP_ADDRESS_PROVIDER
    );
    weth = await ethers.getContractAt('IERC20Weth', WETH_ADDRESS);
    aWeth = await ethers.getContractAt('IERC20Weth', AWETH_ADDRESS);

    //Impersonating account
    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [ADMIN2],
    });
  });

  it('Should make a deposit in eth to the LP of Aave', async () => {
    try {
      // const LPAddress = await iAaveLengingPoolAddressesProvider.getLendingPool();
      // console.log('Im lending pool address', LPAddress);

      //Depositing to the WETH contract to get weth from eth
      const deposit = await weth.deposit({
        value: ethers.utils.parseUnits('1', 18),
      });
      const balance = await weth.balanceOf(ADMIN);
      console.log('Current Weth Balance: ', balance.toString());

      //Allow to spend weth
      const Allow = await weth.approve(
        AAVELP_ADDRESS,
        ethers.utils.parseUnits('1', 18),
        {
          from: ADMIN,
        }
      );

      //Check weth available to spend
      const allowance = await weth.allowance(ADMIN, AAVELP_ADDRESS);
      console.log('Weth Allowed to be spend: ', allowance.toString());

      //Deposit to the Aave LP
      const tx = await iAaveLendingPool.deposit(
        WETH_ADDRESS,
        ethers.utils.parseUnits('1', 18),
        ADMIN,
        0,
        {
          from: ADMIN,
        }
      );

      //Once the weth it's deposited it starts to earn interests
      const aWethBalance = await aWeth.balanceOf(ADMIN);
      const wethBalance = await weth.balanceOf(ADMIN);
      console.log(
        'Balance of aWeth Token: ',
        aWethBalance.toString(),
        'Remaining Balance of Weth token: ',
        wethBalance.toString()
      );

      //Withdrawing
      await iAaveLendingPool.withdraw(
        WETH_ADDRESS,
        ethers.utils.parseUnits('1', 18),
        ADMIN
      );
      const finalWeth = await weth.balanceOf(ADMIN);
      const finalAWeth = await aWeth.balanceOf(ADMIN);

      console.log(
        'After withdraw: \n',
        'Balance of aWeth Token: ',
        finalAWeth.toString(),
        '\n Remaining Balance of Weth token: ',
        finalWeth.toString()
      );
    } catch (error) {
      console.log('There was an error getting the lending pool address', error);
    }
  });
});
