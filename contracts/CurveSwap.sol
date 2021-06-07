// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import "./interfaces/IStableSwap.sol";


contract CurveSwap {
    
    function getAmountReceived(address _from, address _synth, uint256 _amount) public view returns(uint) {
        
        return IStableSwap(0x58A3c68e2D3aAf316239c003779F71aCb870Ee47).get_swap_into_synth_amount(_from, _synth, _amount);
    }
}