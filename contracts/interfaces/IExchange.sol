// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IExchange {
  /** 
    @dev Interface for the Exchange to get the best rate of
    a pool to make the swap.
  **/

  function get_best_rate(address _from, address _to, uint256 _amount) external view returns(address, uint256);


  
  /** 
    @dev Get the current number of coins received in an exchange.
    @param   _pool: Pool address.
    @param  _from: Address of coin to be sent.
    @param  _to: Address of coin to be received.
    @param  _amount: Quantity of _from to be sent.
    @return Returns the quantity of _to to be received in the exchange.
  **/
function get_exchange_amount(address _pool,address  _from, address _to, uint256 _amount) external view returns(uint256);
  

  /**
    @dev  Perform an token exchange using a specific pool.
    @param  _pool: Address of the pool to use for the swap.
    @param  _from: Address of coin being sent.
    @param  _to: Address of coin being received.
    @param  _amount: Quantity of _from being sent.
    @param  _expected: Minimum quantity of _to received in order for the transaction to succeed.
    @param  _receiver: Optional address to transfer the received tokens to. If not specified, defaults to the caller.
    @return Returns the amount of _to received in the exchange.

  **/
function exchange(address _pool,address _from,address _to, uint256 _amount, uint256 _expected, address _receiver) external view returns(uint256);

}