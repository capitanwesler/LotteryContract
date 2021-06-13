// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IExchange {
  /** 
    @dev Interface for the Exchange to get the best rate of
    a pool to make the swap.
  **/

  function get_best_rate(address _from, address _to, uint256 _amount) external view returns(address, uint256);
}