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
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./interfaces/IExchange.sol";
import "./interfaces/IAaveLendingPool.sol";
import "./interfaces/IERC20WETH.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract Lottery is Initializable, ContextUpgradeable, ChainlinkClientUpgradeable {
  using Chainlink for Chainlink.Request;
  using SafeERC20 for IERC20Metadata;
  address constant EXCHANGE = 0xD1602F68CC7C4c7B59D686243EA35a9C73B0c6a2;
  address constant UniswapRouter = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
  using SafeMath for uint256; 

  /**
    @notice This is the `ticketCost` for each lottery
    the user can change this any time with a function,
    this will be in USD the price of the ticket.
  **/
  uint256 public ticketCost;

  /**
    @dev Lending pool of this week, and what should the user
    swap the coins to.
  **/
  address public lendingPool;

  /**
    @dev Address of the holder of the balance
  **/
  address public balanceHolderAddress;

  /**
    @dev Address of the A token holding the balance
  **/
  address public aTokenHolderAddress;

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
      uint256 _seed,
      address _lendingPool,
      address _balanceHolder
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
    lendingPool = _lendingPool;
    balanceHolderAddress = _balanceHolder;
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
    public
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
    @dev Setting the address of the lending pool to use.
    @notice This is for using LP and generating interest.
    @param _lendingPool This is the LP address.
  **/

  function setLendingPool(address _lendingPool) external onlyAdmin returns (address) {
    lendingPool = _lendingPool;
    return _lendingPool;
  }

  /**
    @dev Setting the address of token that holds the balance
    @notice This is for calling the functions of a ERC20 token
    @param _balanceHolderAddress This is the token holding the balance
  **/

  function setBalanceholderAddress(address _balanceHolderAddress) external onlyAdmin returns (address) {
    balanceHolderAddress = _balanceHolderAddress;
    return _balanceHolderAddress;
  }
  
  /**
    @dev Setting the address of atoken that holds the balance
    @notice This is for calling the functions of a ERC20 token
    @param _aTokenHolderAddress This is the token holding the balance
  **/

  function setATokenholderAddress(address _aTokenHolderAddress) external onlyAdmin returns (address) {
    aTokenHolderAddress = _aTokenHolderAddress;
    return _aTokenHolderAddress;
  }

  
  /**
    @dev Depositing to the selected pool to earn interest
    @param _balance Balance to deposit inside the poo
    @param _LPAddress This is the pool that'll generate the interest
    @param _tokenAddress Token that will be deposited
  **/

  ///////////////////////////// WARNING ////////////////
  //Tested only for aave pool 
  function LPDeposit(uint256 _balance, address _LPAddress, _tokenAddress) internal {
    if(_tokenAddress == '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE'){
      //when exanching ETH use WETH
      //Using the WETH address for the ERC20
      IERC20Weth(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).deposit(_balance);

      //Approving the pool for spending our tokens
      //Using de AAVE LP Address 
      IERC20Metadata(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).aprove(_LPAddress, _balance);

      //Depositing to the pool
      /**
       address of the token to deposit, amount, address that will be registered the aToken to
      **/
      IAaveLendingPool(_LPAddress).deposit(_tokenAddress, _balance, address(this));
   
    } else {

      //Approving the pool for spending our tokens
      //Using de AAVE LP Address 
      IERC20Metadata(_tokenAddress).aprove(_LPAddress, _balance);

      //Depositing to the pool
      /**
       address of the token to deposit, amount, address that will be registered the aToken to
      **/
      IAaveLendingPool(_LPAddress).deposit(_tokenAddress, _balance, address(this));
    }
  }

   
  /**
    @dev Getting the earned interest in atoken
    @param _LPAddress Lending Pool address to search for equivalent token
    @param _tokenAddress address of the token being used
  **/
  function getATokenAddress(address _LPAddress,address _tokenAddress) internal returns(address) {
    //Using AAVE
    if(_LPAddress == 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9){
      //Getting Atoken Of DAI
      if(_tokenAddress == 0x6B175474E89094C44Da98b954EedeAC495271d0F){
        //returns aDAI
        return 0x028171bCA77440897B824Ca71D1c56caC55b68A3
      }
      //Getting Atoken Of Link
      if(_tokenAddress == 0x514910771AF9Ca656af840dff83E8264EcF986CA){
        //returns aLink
        return 0xa06bC25B5805d5F8d82847D191Cb4Af5A3e873E0
      }
      //Getting Atoken Of USDT
      if(_tokenAddress == 0xdAC17F958D2ee523a2206206994597C13D831ec7){
        //returns aUSDT
        return 0x3Ed3B47Dd13EC9a98b44e6204A523E766B225811
      }
      //Getting Atoken Of USDC
      if(_tokenAddress == 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48){
        //returns aUSDC
        return 0xBcca60bB61934080951369a648Fb03DF4F96263C
      }
      //Getting Atoken Of TUSD
      if(_tokenAddress == 0x0000000000085d4780B73119b644AE5ecd22b376){
        //returns aTUSD
        return 0x101cc05f4A51C0319f570d5E146a8C625198e636
      }
      //Getting Atoken Of BUSD
      if(_tokenAddress == 0x4Fabb145d64652a948d72533023f6E7A623C7C53){
        //returns aBUSD
        return 0xA361718326c15715591c299427c62086F69923D9
      }
    }
  }


  
  /**
    @dev Getting the earned interest in atoken
    @param _ATokenAddress atoken address that's generating the interest
    @param _balance total initial balance that was deposited to the contract
  **/

  function getEarnedInterest(address _ATokenAddresss,uint256 _balance) internal returns(uint256){
    return (IERC20(_ATokenAddress).balanceOf(this) - _balance);
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

  function _swapWithUniswap(address _token) payable public {
    /*
      The value in wei, needs to be greater than 1.
    */
    require(msg.value >= 1, "swapWithUniswap: NEED_TO_BE_GREATER_THAT_ONE");

    address[] memory _path = new address[](2);

    _path[0] = IUniswapV2Router02(UniswapRouter).WETH();
    _path[1] = address(_token);

    IUniswapV2Router02(UniswapRouter).swapExactETHForTokens{value: msg.value}
    (1, _path, _msgSender(), block.timestamp + 60);
    IERC20Metadata(_token).safeTransferFrom(
      _msgSender(), 
      address(this), 
      (_getPriceByToken(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) * msg.value.div(1e18)).mul(1e18)
    );
  }

  /**
    @dev Function to make the swap in curve.fi.
    @param _from Index of the underlying_coin to swap.
    @param _to Index of the underlying_coin to swap into.
    @param _amount Amount of coins to be swapped.
    @param _tokenFrom Address of the token to make the transaction of the transferFrom.
    @param _tokenTo Address of the token to get the rate.
  **/

  function _swapWithCurve(int128 _from, int128 _to, uint256 _amount, address _tokenFrom, address _tokenTo) public {
    (address _pool,) = IExchange(EXCHANGE).get_best_rate(
      _tokenFrom, 
      _tokenTo,
      _amount
    );
    IERC20Metadata(_tokenFrom).safeTransferFrom(_msgSender(), address(this), _amount);
    IERC20Metadata(_tokenFrom).approve(_pool, _amount);
    IStableSwap(_pool).exchange_underlying(_from, _to, _amount, 1);
  }

  /** 
    @dev buyTickets function, this will buy the tickets that the
    user desire.
    @param _payment The token that the users want to pay, this can be
    an stable coin or either an ERC20 Token (DAI, LINK).
  **/
  function buyTickets(address _payment, uint256 _quantityOfTickets, uint256 _amount, address _toSwap) external {
    require(_payment != address(0), "buyTickets: ZERO_ADDRESS");
    if (_payment == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
      require(
        _getPriceByToken(_payment) * IERC20Metadata(_payment).balanceOf(_msgSender()).div(1e18)
        >= 
        _quantityOfTickets * ticketCost,
        "buyTickets: NOT_ENOUGH_MONEY_TO_BUY"
      );
    } else {
      require(
        1 * IERC20Metadata(_payment).balanceOf(_msgSender()).div(10 ** IERC20Metadata(_payment).decimals())
        >= 
        _quantityOfTickets * ticketCost,
        "buyTickets: NOT_ENOUGH_MONEY_TO_BUY"
      );
    }
    require(_quantityOfTickets <= maxTicketsPerPlayer, "buyTickets: EXCEED_MAX_TICKETS");

    if (_payment == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
      _swapWithUniswap(_payment);
    } else {
      _swapWithCurve(0, 2, _amount, _payment, _toSwap);
    }
    
    if (statusLottery == LotteryStatus.OPEN) {
      players[playersCount].owner = _msgSender();
      players[playersCount].initialBuy = supplyTickets;
      players[playersCount].endBuy = supplyTickets - _quantityOfTickets;
      players[playersCount].quantityTickets = _quantityOfTickets;
      playersCount++;

      emit LotteryEnter(_msgSender(), _quantityOfTickets, address(0));
    }

    if (statusLottery == LotteryStatus.CLOSE) {
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
      @TODO
      -->
      Get the interests for that user from the
      pool that we had the lottery.
    */

    for (uint256 i = 0; i < playersCount; i++) {
      if (randomNumber >= players[i].initialBuy && randomNumber <= players[i].endBuy) {
        /*
          @TODO
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
      @TODO
      -->
      Add the logic to send all the tokens
      of one asset to a specific pool of that
      asset either in COMPOUND pools or AAVE pools.
    */
    _lendingPool

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