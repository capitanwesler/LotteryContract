// SPDX-License-Identifier: MIT
pragma solidity 0.6.6;

interface IStableSwap {
  /**
    @dev Interface of the StableSwap of the pools
    in curve.
  **/
  function underlying_coins(uint256 index) external view returns(address);
  
  function exchange_underlying(int128 _i, int128 _j, uint256 _dx, uint256 _mintdy) external;
}