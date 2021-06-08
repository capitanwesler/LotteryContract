// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./interfaces/IERC20.sol";
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
  mapping(address => bool) public admins;

  /**
    @dev This is the mapping of aggregators. 
    @notice It will check if an address has 
    the address of the aggregator to check
    the price in USD from this address, if the address
    to check the price in `USD` is equal to the address 
    in the `aggregators` that mean it's a stablecoin.
  **/
  mapping(address => address) internal aggregators;


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
    require(admins[_msgSender()], "Admin: NOT_ADMIN");
    _;
  }

  /**
    @dev Setting the ticketCost can only be done by an admin.
    @notice This is for changing the price of the ticket,
    if we want to change the price of the tickets after a
    lottery has pass.
    @param _ticketCost This is the ticketCost and it can be only set by an admin.
  **/
  function setTicketCost(uint256 _ticketCost) external onlyAdmin returns(bool success) {
    require(_ticketCost != 0, "TicketCost: ERROR_TICKET_COST");
    ticketCost = _ticketCost;
    success = true;
  }

  /**
    @dev Function to add the aggregator to check the chainlink aggregator.
    @param _token This is the token what we want to get the `USD` price.
    @param _aggregator This is the aggregator to check the `USD` price.
  **/

  function _addAggregator(address _token, address _aggregator) external onlyAdmin {
    require(_token != address(0) && _aggregator != address(0), "Aggregator: ZERO_ADDRESS");
    aggregators[_token] = _aggregator;
  }

  /**
    @dev Returns the price of a token in USD.
    @param _tokenPayment Address of the ERC-20 Token.
  */
  function _getPriceByToken(address _tokenPayment)
    internal
    view
    returns (uint256)
  {
    require(
        aggregators[_tokenPayment] != address(0),
        "Aggregator: ZERO_ADDRESS"
    );
    (,int256 price,,,) = AggregatorV3Interface(aggregators[_tokenPayment]).latestRoundData();

    return uint256(price);
  }
}