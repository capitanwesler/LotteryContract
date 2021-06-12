const { assert, ethers } = require('hardhat');

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
    // iStableSwap = await ethers.getContractAt('IStableSwap', AAVE_ADDRESS);

    iERC20weth = await ethers.getContractAt('IERC20Weth', WETH_ADDRESS);

    iERC20Dai = await ethers.getContractAt('IERC20', DAI_ADDRESS);

    iERC20USDT = await ethers.getContractAt('IERC20', USDT_ADDRESS);

    iExchange = await ethers.getContractAt('IExchange', EXCHANGE_ADDRESS);

    Swapper = await ethers.getContractFactory('Swapper');

    swapper = await Swapper.deploy((await ethers.getSigners())[0].address);
    await swapper.deployed();
  });

  it('should get the pool balances and coins array', async () => {
    //Getting balance and coin of the pool

    //Swap Eth for Dai

    // await swapper.swapEthForTokens([DAI_ADDRESS], [1000], {
    //   from: (await ethers.getSigners())[0].address,
    //   value: ethers.utils.parseEther('1'),
    // });

    let daiBalance = await iERC20Dai.balanceOf(
      (
        await ethers.getSigners()
      )[0].address
    );

    console.log('Current Balance of Dai: >> ', daiBalance.toString());

    const bestRate = await iExchange.get_best_rate(
      DAI_ADDRESS,
      USDT_ADDRESS,
      ethers.utils.parseUnits('100', 18)
    );

    //Get instance of te pool
    iStableSwap = await ethers.getContractAt('IStableSwap', bestRate[0]);

    //Allow Exchange contract to spend Dai
    await iERC20Dai.approve(bestRate[0], daiBalance, {
      from: (await ethers.getSigners())[0].address,
    });

    //Check weth available dai to spend
    const allowance = await iERC20Dai.allowance(
      (
        await ethers.getSigners()
      )[0].address,
      bestRate[0]
    );

    console.log(
      'Dai Allowed to be spend by the Swapper: >> ',
      allowance.toString()
    );

    //Getting underlying tokens addresses
    const sendIndex = await iStableSwap.underlying_coins(0);
    const receiveIndex = await iStableSwap.underlying_coins(2);

    console.log('Obtained Indexes(send, receive): ', sendIndex, receiveIndex);

    const receivedInSwap = await iStableSwap.exchange_underlying(
      0,
      2,
      ethers.utils.parseUnits('100', 18),
      1,
      { from: (await ethers.getSigners())[0].address }
    );

    console.log('Received in swap: >> ', receivedInSwap.toString());
    console.log('---------------');
    console.log(
      'My Balance of USDT: >> ',
      (
        await iERC20USDT.balanceOf((await ethers.getSigners())[0].address)
      ).toString()
    );
    daiBalance = await iERC20Dai.balanceOf(
      (
        await ethers.getSigners()
      )[0].address
    );

    console.log('Current Balance of Dai: >> ', daiBalance.toString());
  });
});
