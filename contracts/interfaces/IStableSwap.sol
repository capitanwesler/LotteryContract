// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IStableSwap {
  /**
      @dev Getter of the pool coins  array
  */
  function coins(uint256 index) external view returns(address);

  /**
      @dev Getter of the pool balances array
  */
  function balances(uint256 index) external view returns(uint256);

  /**
      @dev Get the amount of coin j one would receive for swapping _dx of coin i.
    */
  function get_dy(int128 _i, int128 _j, uint256 _dx) external view returns(uint256);

  /**
      @dev Perform an exchange between two coins.
    */
  function exchange(int128 _i, int128 _j, uint256 _dx, uint256 _mintdy) external view returns(uint256);
}