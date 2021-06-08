// SPDX-License-Identifier: MIT
pragma solidity ^0.8;


interface IStableSwap {

    /**
    @notice Estimate the final amount received when swapping between `_from` and `_to`
    @dev Actual received amount may be different if synth rates change during settlement
    @param _from Address of the initial asset being exchanged
    @param _to Address of the asset to swap into
    @param _amount Amount of `_from` being exchanged
    @return uint256 Estimated amount of `_to` received
    **/

    function get_estimated_swap_amount(address _from, address _to, uint256 _amount) external view returns(uint256);
    
    /**
    @notice Return the amount received when swapping out of a settled synth
    @dev Used to calculate `_expected` when calling `swap_from_synth`. Be sure to
         reduce the value slightly to account for market movement prior to the
         transaction confirmation.
    @param _synth Address of the synth being swapped out of
    @param _to Address of the asset to swap into
    @param _amount Amount of `_synth` being exchanged
    @return uint256 Expected amount of `_to` received
    **/

    function get_swap_from_synth_amount( address _synth,  address _to,  uint256 _amount) external view returns(uint256);


    /** 
    @notice Return the amount received when performing a cross-asset swap
    @dev Used to calculate `_expected` when calling `swap_into_synth`. Be sure to
         reduce the value slightly to account for market movement prior to the
         transaction confirmation.
    @param _from Address of the initial asset being exchanged
    @param _synth Address of the synth being swapped into
    @param _amount Amount of `_from` to swap
    @return uint256 Expected amount of `_synth` received
    **/

    function get_swap_into_synth_amount(address _from, address _synth, uint256 _amount) external view returns(uint256);

    /**
    @notice Perform a cross-asset swap between `_from` and `_synth`
    @dev Synth swaps require a settlement time to complete and so the newly
         generated synth cannot immediately be transferred onward. Calling
         this function mints an NFT which represents ownership of the generated
         synth. Once the settlement time has passed, the owner may claim the
         synth by calling to `swap_from_synth` or `withdraw`.
    @param _from Address of the initial asset being exchanged
    @param _synth Address of the synth being swapped into
    @param _amount Amount of `_from` to swap
    @param _expected Minimum amount of `_synth` to receive
    @param _receiver Address of the recipient of `_synth`, if not given
                       defaults to `msg.sender`
    @param _existing_token_id Token ID to deposit `_synth` into. If left as 0, a new NFT
                       is minted for the generated synth. If non-zero, the token ID
                       must be owned by `msg.sender` and must represent the same
                       synth as is being swapped into.
    @return uint256 NFT token ID
    **/

    function swap_into_synth(
    address _from,
    address _synth,
    uint256 _amount,
    uint256 _expected,
    address _receiver,
    uint256 _existing_token_id
    ) external payable returns(uint256);

    /**
    @notice Withdraw the synth represented by an NFT.
    @dev Callable by the owner or operator of `_token_id` after the synth settlement
         period has passed. If `_amount` is equal to the entire balance within
         the NFT, the NFT is burned.
    @param _token_id The identifier for an NFT
    @param _amount Amount of the synth to withdraw
    @param _receiver Address of the recipient of the synth,
                     if not given defaults to `msg.sender`
    @return uint256 Synth balance remaining in `_token_id`
    **/

    function withdraw(uint256 _token_id,uint256 _amount, address _receiver) external view returns(uint256);

    /**
      @notice This is to get the address of the sToken if the address is passed.
    **/
    function swappable_synth(address _token) external;
}