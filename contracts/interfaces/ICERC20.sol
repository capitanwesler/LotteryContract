// SPDX-License-Identifier: MIT
pragma solidity 0.6.6;

interface ICERC20 {
   
    /**
     * @notice Gets the balance of the specified address.
     * @param owner The address from which the balance will be retrieved
     * @return balance The balance
     */
    function balanceOfUnderlying(address owner) external view returns (uint256);

    /**
      * @notice Approve `spender` to transfer up to `amount` from `src`
      * @dev This will overwrite the approval amount for `spender`
      *  and is subject to issues noted [here](https://eips.ethereum.org/EIPS/eip-20#approve)
      * @param spender The address of the account which may transfer tokens
      * @param amount The number of tokens that are approved
      * @return  success Whether or not the approval succeeded
      */
    function approve(address spender, uint256 amount) external returns (bool success);

    /**
     * @notice Sender supplies assets into the market and receives cTokens in exchange
     * @dev Reverts upon any failure
     */
    function mint(uint mintAmount) external returns (uint);


    /**
     * @notice Sender redeems cTokens in exchange for the underlying asset
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param redeemTokens The number of cTokens to redeem into underlying
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function redeem(uint redeemTokens) external view returns (uint);
}