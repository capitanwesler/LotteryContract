// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Lottery is Initializable, ContextUpgradeable {
  /**
    @dev Using safe math for all the operations with
    uint256.
  **/
  using SafeMath for uint256; 

  /**
    @notice This is the `ticketCost` for each lottery
    the user can change this any time with a function,
    this will be in USD the price of the ticket.
  **/
  uint256 public ticketCost;

  /** 
    @dev This is a mapping for admins.
    @notice A array of admins will be introduced as a
    parameter on the initializer to stablish the admins
    of the contract.
  **/
  mapping(address => bool) admins;


  /** 
    @notice Event for each person who enters in the lottery.
    @dev The address for lendingPool is to filter each pool
    and we can see who buyed for a specific pool.
  **/
  event LotteryEnter (
    address person,
    uint256 ticketsBuyed,
    address indexed lendingPool
  );

  /** 
    @notice This are the enums for the price feeds that what we are working.
    @dev It's going to be passed as a parameter.
  **/
  enum PriceFeed {
    DAI,
    LINK,
    ETH
  }

  /** 
    @notice Internal function to check the prices in the oracle.
    @dev You need to pass the enum as the parameter.
    @param _priceFeed Is the price feed that we are going to check in the oracle.
    @param _priceFeedAddress PriceFeedAddress that we are going to check the price.
    @dev I am dividing by 1e8, because I want to have the price in USD with decimals.
  **/
  function _getPriceFeed(PriceFeed _priceFeed, address _priceFeedAddress) internal view returns (uint256 resultPrice){
    /*
      We are going to check for the differents price feeds
      in out contract and get the price of that feed.
    */
    if (_priceFeed == PriceFeed.DAI) {
      (,int price,,,) = AggregatorV3Interface(_priceFeedAddress).latestRoundData();
      resultPrice = uint256(price).div(1e8);
    }

    if (_priceFeed == PriceFeed.LINK) {
      (,int price,,,) = AggregatorV3Interface(_priceFeedAddress).latestRoundData();
      resultPrice = uint256(price).div(1e8);
    }

    if (_priceFeed == PriceFeed.ETH) {
      (,int price,,,) = AggregatorV3Interface(_priceFeedAddress).latestRoundData();
      resultPrice = uint256(price).div(1e8);
    }
  }
  
  /** 
    @dev Initializer of the function, here we will set
    the price of the `ticketCost` and who's the owner
    of the contract.
    @notice The iteration is for creating the admins
    of the contract, so we can easily choose who's the
    admin and deploy it with those address.
  **/
  function initialize(uint256 _ticketCost, address[] memory _listAdmins) public initializer {
    ticketCost = _ticketCost;
    for (uint256 i; i < _listAdmins.length; i++) {
      admins[_listAdmins[i]] = true;
    }
  }

  /** 
    @dev Modifier, to check if either the actual user is an admin or not.
  **/
  modifier onlyAdmin() {
    require(admins[_msgSender()], "ADMIN ERROR: You aren't an admin to do this.");
    _;
  }

  /**
    @dev Setting the ticketCost can only be done by an admin.
    @notice This is for changing the price of the ticket,
    if we want to change the price of the tickets after a
    lottery has pass.
  **/
  function setTicketCost(uint256 _ticketCost) external onlyAdmin returns(bool success) {
    ticketCost = _ticketCost;
    success = true;
  }
}