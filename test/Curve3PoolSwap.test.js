const { assert, ethers } = require('hardhat');

//Accounts with eth
const ADMIN = '0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266'; // Using first account of the giving node forked
const ADMIN2 = '0x1b3cb81e51011b549d78bf720b0d924ac763a7c2'; //17th place of the accounts with more ether according to etherscan

//Utility Addresses
const ETH_ADDRESS = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';
const DAI_ADDRESS = '0x6b175474e89094c44da98b954eedeac495271d0f';
const WETH_ADDRESS = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';

//Addresses of interfaces:
const I3POOL_ADDRESS = '0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7';

//Interfaces to use
let i3Pool;
let iERC20weth;

describe('Testing Swaap with 3Pool', () => {
  before(async () => {
    //Impersonating account
    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [ADMIN],
    });
    // Getting the instance of the contracts
    i3Pool = ethers.getContractAt('I3Pool', I3POOL_ADDRESS);

    iERC20weth = ethers.getContractAt('IERC20Weth', WETH_ADDRESS);
  });

  it('should get the pool balances and coins array', async () => {
    console.log(
      await i3Pool,
      '\n Calling balances from the instance function:',
      await i3Pool.balances
    );
    //Getting balance and coin of the pool
    const balance = await i3Pool.balances(0);
    const coins = await i3Pool.coins(0);

    //Balance and address of DAI
    console.log('Balance:', balance.toString(), 'Coin:', coins);
  });

  it('Should make an exchange', async () => {
    //Get the the amount that would receive
    const amount = await i3Pool.get_dy(1, 2, 100);
    console.log(amount.toString(), 'im amount');

    //Depositing to the WETH contract to get weth from eth
    const deposit = await iERC20weth.deposit({
      value: ethers.utils.parseUnits('1', 18),
    });
    const balance = await iERC20weth.balanceOf(ADMIN);
    console.log('Current Weth Balance: ', balance.toString());

    //Allow to spend weth
    const Allow = await iERC20weth.approve(
      I3POOL_ADDRESS,
      ethers.utils.parseUnits('1', 18),
      {
        from: ADMIN,
      }
    );

    //Check weth available to spend
    const allowance = await iERC20weth.allowance(ADMIN, I3POOL_ADDRESS);
    console.log('Weth Allowed to be spend: ', allowance.toString());

    //Exchange
    const txEchange = await i3Pool.exchange(1, 2, 100, amount);
    console.log(txEchange, 'im exchange');
  });
});
