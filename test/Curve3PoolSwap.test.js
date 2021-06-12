const { assert, ethers } = require('hardhat');

const ADMIN = '0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266'; // Using first account of the giving node forked

//Utility Addresses
const ETH_ADDRESS = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';
const DAI_ADDRESS = '0x6b175474e89094c44da98b954eedeac495271d0f';

let i3Pool;

describe('Testing Swaap with 3Pool', () => {
  before(async () => {
    //Impersonating account
    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [ADMIN2],
    });
    // Getting the instance of the contract
    i3Pool = ethers.getContractAt(
      'I3Pool',
      '0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7'
    );
  });

  it('should get the pool balances and coins array', async () => {
    //Getting balance and coin of the pool
    const balance = await i3Pool.balances(0);
    const coins = await i3Pool.coins(0);

    //Balance and address of DAI
    console.log('Balance:', balance.toString(), 'Coin:', coins);
  });

  // it('Should make an exchange', async () => {
  //   //Get the the amount that would receive
  //   const amount = await i3Pool.get_dy(1, 2, 100);
  //   console.log(amount.toString(), 'im amount');

  //   //Exchange
  //   const txEchange = await i3Pool.exchange(1, 2, 100, amount);
  //   console.log(txEchange, 'im exchange');
  // });
});

    //Exchange
    const txEchange = await i3Pool.exchange(1, 2, 100, amount)
    console.log(txEchange, "im exchange");
  })
})