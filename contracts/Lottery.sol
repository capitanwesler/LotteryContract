// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./RandomNumberConsumer.sol";
import "./ChainlinkClientUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./RandomNumberConsumer.sol";
import "./interfaces/IStableSwap.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol"; 

contract Lottery is Initializable, ContextUpgradeable, ChainlinkClientUpgradeable {
  using Chainlink for Chainlink.Request;
  using SafeERC20 for IERC20;

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
  uint256 public supplyTickets;
  uint256 public supplyTicketsRunning;

  /**
    @notice This is `maxTicketsPerPlayer` this can
    be set by the admin, if he wants to change it
    and the player can only get this amount of tickets.
  **/
  uint256 public maxTicketsPerPlayer;

  /** 
    @dev This is address of the admin of the contract.
  **/
  address public admin;

  /**
    @dev This is the mapping of aggregators. 
    @notice It will check if an address has 
    the address of the aggregator to check
    the price in USD from this address, if the address
    to check the price in `USD` is equal to the address 
    in the `aggregators` that mean it's a stablecoin.
  **/
  mapping(address => address) public aggregators;

  /** 
    @dev This will be the mapping of the lottery players.
    @notice We have a struct for the Player, so we can
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

  mapping(uint256 => Player) public playersRunning;

  /** 
    @dev RandomNumber.
  **/

  uint256 private randomNumber;

  /** 
    @dev Counter of players.
  **/
  uint256 public playersCount;

  uint256 public playersRunningCount;

  /**
    @dev This is the address of the randomNumberConsumer.
  **/

  address public randomNumberConsumer;

  /**
    @dev This is the address of the ChainlinkRequester.
  **/

  address public oracleAddress;

  /**
    @dev This is the seed for the randomNumber.
  **/
  uint256 public seed;

  /**
    @dev This is to check when a lottery is already running.
  **/
  enum LotteryStatus {CLOSE, OPEN}

  LotteryStatus public statusLottery;

  event StatusOfLottery (
    LotteryStatus lottery
  );


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
    @dev Event to register the requestId of the randomNumber.
  **/

  event RandomNumber (
    bytes32 requestId,
    uint256 userProvidedSeed
  );

  /** 
    @notice Event that shot when a winner is chosen.
  **/
  event Winner(
    address indexed person,
    uint256 ticketWinner
  );

  /**
    @notice Event that shot when a request is completed.
  **/
  event SendingTokens (
    bytes32 requestId
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
      address _admin, 
      uint256 _ticketsPerPlayer,
      address _randomNumberConsumer,
      address _oracleAddress, 
      uint256 _seed
    )
      public 
      initializer
    {
    setPublicChainlinkToken();
    maxTicketsPerPlayer = _ticketsPerPlayer;
    ticketCost = _ticketCost;
    admin = _admin;
    randomNumberConsumer = _randomNumberConsumer;
    supplyTickets = 2**256 - 1;
    supplyTicketsRunning = 2**256 - 1;
    statusLottery = LotteryStatus.OPEN;
    seed = _seed;
    oracleAddress = _oracleAddress;
  }

  /** 
    @dev Modifier, to check if either the actual user is an admin or not.
  **/
  modifier onlyAdmin() {
    require(admin == _msgSender(), "Admin: NOT_ADMIN");
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
    @dev Function to make the swap in curve.fi.
    @param _pool Address of the pool to make the swap.
    @param _from Index of the underlying_coin to swap.
    @param _to Index of the underlying_coin to swap into.
    @param _token Address of the token to make the transaction of the transferFrom.
  **/

  function _swap(address _pool, int128 _from, int128 _to, uint256 _amount, address _token) external {
    IERC20(_token).safeTransferFrom(_msgSender(), address(this), _amount);
    IERC20(_token).approve(_pool, _amount);
    IStableSwap(_pool).exchange_underlying(_from, _to, _amount, 1);
  }

  /** 
    @dev buyTickets function, this will buy the tickets that the
    user desire.
    @param _payment The token that the users want to pay, this can be
    an stable coin or either an ERC20 Token (DAI, LINK).
  **/
  function buyTickets(address _payment, uint256 _quantityOfTickets) external {
    require(_payment != address(0), "buyTickets: ZERO_ADDRESS");
    if (_payment != 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
      require(
      _getPriceByToken(_payment) * IERC20(_payment).balanceOf(_msgSender()) 
      >= 
      _quantityOfTickets * ticketCost,
      "buyTickets: NOT_ENOUGH_MONEY_TO_BUY"
    );
    }
    require(_quantityOfTickets <= maxTicketsPerPlayer, "buyTickets: EXCEED_MAX_TICKETS");

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
    
    if (statusLottery == LotteryStatus.OPEN) {
      // IERC20(_payment).transferFrom(
      //   _msgSender(), 
      //   address(this), 
      //   (_quantityOfTickets * ticketCost).div(_getPriceByToken(_payment))
      // );

      players[playersCount].owner = _msgSender();
      players[playersCount].initialBuy = supplyTickets;
      players[playersCount].endBuy = supplyTickets - _quantityOfTickets;
      players[playersCount].quantityTickets = _quantityOfTickets;
      playersCount++;

      emit LotteryEnter(_msgSender(), _quantityOfTickets, address(0));
    }

    if (statusLottery == LotteryStatus.CLOSE) {
      // IERC20(_payment).transferFrom(
      //   _msgSender(), 
      //   address(this), 
      //   (_quantityOfTickets * ticketCost).div(_getPriceByToken(_payment))
      // );

      playersRunning[playersRunningCount].owner = _msgSender();
      playersRunning[playersRunningCount].initialBuy = supplyTicketsRunning;
      playersRunning[playersRunningCount].endBuy = supplyTicketsRunning - _quantityOfTickets;
      playersRunning[playersRunningCount].quantityTickets = _quantityOfTickets;
      playersRunningCount++;

      emit LotteryEnter(_msgSender(), _quantityOfTickets, address(0));
    }
  }

  /** 
    @dev This can be called to get the randomNumber.
  **/
  function _getRandomNumber(uint256 _seed) internal {
    bytes32 requestId = RandomNumberConsumer(randomNumberConsumer).getRandomNumber(_seed);
    emit RandomNumber(requestId, _seed);
  }
  
  /** 
    @dev Get the randomNumber.
  **/
  function getRandomNumber() external view onlyAdmin returns(uint256) {
    return RandomNumberConsumer(randomNumberConsumer).randomResult();
  }


  /**
    @dev This function is going to be shot, after five days to choose the winner
    of the interest in the pools.
  **/

  function chooseWinner() internal {
    /*
      -->
      Get the interests for that user from the
      pool that we had the lottery.
    */

    for (uint256 i = 0; i < playersCount; i++) {
      if (randomNumber >= players[i].initialBuy && randomNumber <= players[i].endBuy) {
        /*
          -->
          Logic for earning the interest to this
          address and giving the admin 5% of fee.
        */

        emit Winner(players[i].owner, RandomNumberConsumer(randomNumberConsumer).randomResult());
      }
    }

    for (uint256 i = 0; i < playersCount; i++) {
      delete players[i];
    }

    playersCount = 0;

    if (playersRunningCount > 0) {
      for (uint256 i = 0; i < playersRunningCount; i++) {
        players[i] = playersRunning[i];
        delete playersRunning[i];
        playersCount++;
      }

      playersRunningCount = 0;

      supplyTickets = supplyTicketsRunning;
      supplyTicketsRunning = 2**256 - 1;
    } else {
      supplyTickets = 2**256 - 1;
    }

    statusLottery = LotteryStatus.OPEN;
    emit StatusOfLottery(statusLottery);  
  }

  /**
    @dev This is the function to send the tokens
    and when is pass the 2 days, it will fullfill
    to transfers the tokens to the a specific pool.
  **/

  function sendTokensToPool() external /* Add modifier who should call */ {
    require(statusLottery == LotteryStatus.OPEN, "sendTokensToPool: LOTTERY_NEED_TO_BE_OPEN");
    Chainlink.Request memory req = buildChainlinkRequest(
      "0be1216ae9344e7b8e81539939b5ac64", 
      address(this), 
      this.fulfill_tokens.selector
    );
    req.addUint("until", block.timestamp + 172800);
    sendChainlinkRequestTo(oracleAddress, req, 1 * 1e18);
  }

  /** 
    @dev This functions will fullfill when the timer is done.
  **/

  function fulfill_tokens(bytes32 _requestId) external recordChainlinkFulfillment(_requestId) {
    /*
      -->
      Add the logic to send all the tokens
      of one asset to a specific pool of that
      asset either in COMPUND pools or AAVE pools.
    */
    _getRandomNumber(seed); /* This is to get the request for getting the randomNumber */

    statusLottery = LotteryStatus.CLOSE;
    emit StatusOfLottery(statusLottery);
    /*
      -->
      After this we can add another delay to choose the winner.
    */
     Chainlink.Request memory req = buildChainlinkRequest(
      "0be1216ae9344e7b8e81539939b5ac64", 
      address(this), 
      this.fulfill_winner.selector
    );
    req.addUint("until", block.timestamp + 272800);
    sendChainlinkRequestTo(oracleAddress, req, 1 * 1e18);
  }

  /**
    @dev This is the function to fullfill to choose the winner.
  **/
  function fulfill_winner(bytes32 _requestId) external recordChainlinkFulfillment(_requestId) {
    chooseWinner();
  }
}