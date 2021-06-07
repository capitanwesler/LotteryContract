// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";


contract Lottery is Initializable {
    function initialize() public initializer {}

    mapping(address => address) participants;
}