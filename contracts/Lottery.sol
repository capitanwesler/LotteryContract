// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/dev/ChainlinkClient.sol";
import "./interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./RandomNumberConsumer.sol";

contract Lottery is Initializable, ContextUpgradeable, ChainlinkClient {
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
    @notice This is the counter for the tickets that we can sell.
  **/
  uint256 public supplyTickets = 2**256 - 1;

  /**
    @notice This is `maxTicketsPerPlayer` this can
    be set by the admin, if he wants to change it
    and the player can only get this amount of tickets.
  **/
  uint256 public maxTicketsPerPlayer;

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
    @dev This will be the mapping of the lottery players.
    @notice We have a struct for the Player, so we canm
    store where the player bought the tickets and when
    the end of the bought.
  **/

  struct Player {
    address owner;
    uint256 initialBuy;
    uint256 endBuy;
    uint256 quantityTickets;
  }

  mapping(uint256 => Player) public players;

  /** 
    @dev Counter of players.
  **/
  uint256 public playersCount;


  /** 
    @notice Event for each person who enters in the lottery.
    @dev The address for lendingPool is to filter each pool
    and we can see who buyed for a specific pool.
  **/
  event LotteryEnter (
    address indexed person,
    uint256 ticketsBuyed,
    address indexed lendingPool
  );

  /** 
    @notice Event that shot when a winner is chosen.
  **/
  event Winner(
    address indexed person,
    uint256 ticketWinner
  );
  
  /** 
    @dev Initializer of the function, here we will set
    the price of the `ticketCost` and who's the owner
    of the contract.
    @notice The iteration is for creating the admins
    of the contract, so we can easily choose who's the
    admin and deploy it with those address.
  **/
  function initialize(
      uint256 _ticketCost, 
      address[] memory _listAdmins, 
      uint256 _ticketsPerPlayer
    )
      public 
      initializer
    {
    maxTicketsPerPlayer = _ticketsPerPlayer;
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
    
    if (_tokenPayment != aggregators[_tokenPayment]) {
      (,int256 price,,,) = AggregatorV3Interface(aggregators[_tokenPayment]).latestRoundData();
      return uint256(price);
    }

    return 1;
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
    @dev Function to remove the aggregators.
    @param _token This is the token what we want to delete from the aggregators.
  **/

  function _removeAggregator(address _token) external onlyAdmin {
    require(_token != address(0), "Aggregator: ZERO_ADDRESS");
    delete aggregators[_token];
  }

  /** 
    @dev buyTickets function, this will buy the tickets that the
    user desire.
    @param _payment The token that the users want to pay, this can be
    an stable coin or either an ERC20 Token (DAI, LINK).
  **/
  function buyTickets(address _payment, uint256 _quantityOfTickets) external returns (uint256) {
    require(_payment != address(0), "buyTickets: ZERO_ADDRESS");
    require(
      _getPriceByToken(_payment) * IERC20(_payment).balanceOf(_msgSender()) 
      >= 
      _quantityOfTickets * ticketCost,
      "buyTickets: NOT_ENOUGH_MONEY_TO_BUY"
    );

    /*
      -->
      We need to implement the swap
      to the pool token, that we are
      handling this week.
    */


    /*
      This means that the _payment address is
      not a stable coin, and we need to get the price.
    */
    
    IERC20(_payment).transferFrom(
      _msgSender(), 
      address(this), 
      (_quantityOfTickets * ticketCost).div(_getPriceByToken(_payment))
    );

    players[playersCount].owner = _msgSender();
    players[playersCount].initialBuy = supplyTickets;
    players[playersCount].endBuy = supplyTickets - _quantityOfTickets;
    players[playersCount].quantityTickets = _quantityOfTickets;
    playersCount++;

    emit LotteryEnter(_msgSender(), _quantityOfTickets, address(0));
  }

  /**
    @param _randomNumber This is the randomNumber as a parameter to choose the winner.
    @dev This function is going to be shot, after five days to choose the winner
    of the interest in the pools.
  **/

  function chooseWinner(uint256 _randomNumber) external returns (address) {
    /*
      Get the interests for that user from the
      pool that we had the lottery.
    */

    for (uint256 i = 0; i < playersCount; i++) {
      if (_randomNumber >= players[i].initialBuy && _randomNumber <= players[i].endBuy) {
        /*
          -->
          Logic for earning the interest to this
          address and giving the admin 5% of fee.
        */

        emit Winner(players[i].owner, _randomNumber);
        return players[i].owner;
      }
    }

    for (uint256 i = 0; i < playersCount; i++) {
      delete players[i];
      playersCount = 0;
    }
  }
}