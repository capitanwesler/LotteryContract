const IStableSwap = artifacts.require('IStableSwap');
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

describe('Testing: the interface of StableSwap of Curve', () => {
  let iStableSwap;

  before(async () => {
    // Getting the instance of the contract
    iStableSwap = await IStableSwap.at(
      '0x58A3c68e2D3aAf316239c003779F71aCb870Ee47'
    );
  });

  it('should get the synthethic address of DAI, sDAI', async () => {
    const sDAI = await iStableSwap.swappable_synth.call(DAI_ADDRESS);
    console.log(sDAI);
  });

  it('Should make a cross-asset swap', async () => {
    //First we need the sAddress
    const sDaiAddress = await iStableSwap.swappable_synth.call(DAI_ADDRESS);

    //Expected amount
    const expectedInto = await iStableSwap.get_swap_into_synth_amount.call(
      ETH_ADDRESS,
      sDaiAddress,
      toBN(BigInt(5 * 1e18))
    );
    console.log(expectedInto.toString(), 'im expected');

    //Initiate the swap
    const result = await iStableSwap.swap_into_synth.call(
      ETH_ADDRESS,
      sDaiAddress,
      toBN(BigInt(5 * 1e18)),
      expectedInto,
      ADMIN,
      0,
      {
        value: toBN(BigInt(5 * 1e18)),
      }
    );

    console.log(result.toString(), 'imtoken id');

    //Initiate the swap
    await iStableSwap.swap_into_synth(
      ETH_ADDRESS,
      sDaiAddress,
      toBN(BigInt(5 * 1e18)),
      expectedInto,
      ADMIN,
      0,
      {
        value: toBN(BigInt(5 * 1e18)),
      }
    );

    const expectedFrom = await iStableSwap.get_swap_from_synth_amount.call(
      sDaiAddress,
      DAI_ADDRESS,
      expectedInto
    );

    const amount = (await iStableSwap.token_info.call(result))[3];

    const resultTx = await iStableSwap.swap_from_synth(
      result,
      DAI_ADDRESS,
      amount,
      expectedFrom,
      ADMIN
    );

    console.log(resultTx);
  }).timeout(0);
});
