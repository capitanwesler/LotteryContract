const { assert, ethers } = require('hardhat');

//Accounts with eth
const ADMIN = '0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266'; // Using first account of the giving node forked
const ADMIN2 = '0x1b3cb81e51011b549d78bf720b0d924ac763a7c2'; //17th place of the accounts with more ether according to etherscan

//Utility Addresses
const ETH_ADDRESS = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';
const DAI_ADDRESS = '0x6b175474e89094c44da98b954eedeac495271d0f';
const WETH_ADDRESS = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
const EXCHANGE_ADDRESS = '0xD1602F68CC7C4c7B59D686243EA35a9C73B0c6a2';
const USDT_ADDRESS = '0xdAC17F958D2ee523a2206206994597C13D831ec7';

//Addresses of interfaces:
const AAVE_ADDRESS = '0xDeBF20617708857ebe4F679508E7b7863a8A8EeE';

//Interfaces to use
let iStableSwap;
let iERC20weth;
let iExchange;
let iERC20Dai;
let iERC20USDT;
let swapper;
describe('Testing Swaap with 3Pool', () => {
  before(async () => {
    // Getting the instance of the contracts
    iStableSwap = await ethers.getContractAt('IStableSwap', AAVE_ADDRESS);

    iERC20weth = await ethers.getContractAt('IERC20Weth', WETH_ADDRESS);

    iERC20Dai = await ethers.getContractAt('IERC20', DAI_ADDRESS);

    iERC20USDT = await ethers.getContractAt('IERC20', USDT_ADDRESS);

    iExchange = await ethers.getContractAt('IExchange', EXCHANGE_ADDRESS);

    Swapper = await ethers.getContractFactory('Swapper');

    swapper = await Swapper.deploy(ADMIN);
    await swapper.deployed();
  });

  it('should get the pool balances and coins array', async () => {
    //Getting balance and coin of the pool

    //Swap Eth for Dai

    await swapper.swapEthForTokens([DAI_ADDRESS, USDT_ADDRESS], [500, 500], {
      from: ADMIN,
      value: ethers.utils.parseEther('5'),
    });

    const daiBalance = await iERC20Dai.balanceOf(ADMIN);

    console.log('Current Balance of Dai: ', daiBalance.toString());

    const bestRate = await iExchange.get_best_rate(
      DAI_ADDRESS,
      USDT_ADDRESS,
      ethers.utils.parseUnits('10', 18)
    );
    console.log(
      'Best Rate Pool and Amount is:',
      bestRate[0],
      bestRate[1].toString()
    );

    //Get expected amount
    const bestAmount = await iExchange.get_exchange_amount(
      bestRate[0],
      DAI_ADDRESS,
      USDT_ADDRESS,
      daiBalance
    );

    console.log('Best amount available:', bestAmount.toString());

    //Allow Exchange contract to spend Dai
    const Allow = await iERC20Dai.approve(EXCHANGE_ADDRESS, daiBalance, {
      from: ADMIN,
    });

    //Check weth available dai to spend
    const allowance = await iERC20Dai.allowance(ADMIN, EXCHANGE_ADDRESS);
    console.log('Dai Allowed to be spend: ', allowance.toString());

    const exchangeTx = await iExchange.exchange(
      bestRate[0],
      DAI_ADDRESS,
      USDT_ADDRESS,
      bestAmount - 960323532174,
      0,
      ADMIN
    );
    // const coins = await iStableSwap.coins(0);

    // //Balance and address of DAI
    // console.log('Balance:', balance.toString(), 'Coin:', coins);
  });

  // it('Should make an exchange', async () => {
  //   //Get the the amount that would receive
  //   const amount = await i3Pool.get_dy(1, 2, 100);
  //   console.log(amount.toString(), 'im amount');

  //   //Depositing to the WETH contract to get weth from eth
  //   const deposit = await iERC20weth.deposit({
  //     value: ethers.utils.parseUnits('1', 18),
  //   });
  //   const balance = await iERC20weth.balanceOf(ADMIN);
  //   console.log('Current Weth Balance: ', balance.toString());

  //   //Allow to spend weth
  //   const Allow = await iERC20weth.approve(
  //     I3POOL_ADDRESS,
  //     ethers.utils.parseUnits('1', 18),
  //     {
  //       from: ADMIN,
  //     }
  //   );

  //   //Check weth available to spend
  //   const allowance = await iERC20weth.allowance(ADMIN, I3POOL_ADDRESS);
  //   console.log('Weth Allowed to be spend: ', allowance.toString());

  //   //Exchange
  //   const txEchange = await i3Pool.exchange(1, 2, 100, amount);
  //   console.log(txEchange, 'im exchange');
  // });
});
