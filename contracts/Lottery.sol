// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.6;

import "hardhat/console.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "./RandomNumberConsumer.sol";
import "./ChainlinkClientUpgradeable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./RandomNumberConsumer.sol";
import "./interfaces/IStableSwap.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IExchange.sol";
import "./interfaces/IAaveLendingPool.sol";
import "./interfaces/IERC20Weth.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract Lottery is Initializable, ContextUpgradeable, ChainlinkClientUpgradeable {
  using Chainlink for Chainlink.Request;
  using SafeERC20 for IERC20;
  address constant EXCHANGE = 0xD1602F68CC7C4c7B59D686243EA35a9C73B0c6a2;
  address constant UniswapRouter = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
  address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  using SafeMath for uint256;

  /**
    @notice This is the `ticketCost` for each lottery
    the user can change this any time with a function,
    this will be in USD the price of the ticket.
  **/
  uint256 public ticketCost;

  /**
    @dev Balance of the holder after sending the tokens to earn
    interest.
  **/
  uint256 public balanceToken;

  /**
    @dev Lending pool of this week, and what should the user
    swap the coins to.
  **/
  address public lendingPool;

  /**
    @dev Address of the token that will hold our balance.
  **/
  address public balanceHolderAddress;

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
    @dev This is going to be the token balance that we are holding.
  **/
  uint256 private tokenBalance;


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
    __ChainlinkClient_init();
    setPublicChainlinkToken();
    maxTicketsPerPlayer = _ticketsPerPlayer;
    ticketCost = _ticketCost;
    admin = _admin;
    randomNumberConsumer = _randomNumberConsumer;
    supplyTickets = ~uint256(0);
    supplyTicketsRunning = ~uint256(0);
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

  function setBalanceHolderAddress(address _balanceHolderAddress) external onlyAdmin returns (address) {
    balanceHolderAddress = _balanceHolderAddress;
    return _balanceHolderAddress;
  }

  /**
    @dev Adding a function, to claim the funds that the person invested in
    our lottery.
    @notice This only work if the lottery is still open.
  **/

  function claimFunds() external {
    require(statusLottery == LotteryStatus.OPEN, "claimFunds: LOTTERY_NEED_TO_BE_OPEN");
    for (uint256 i = 0; i < playersCount; i++) {
      if (players[i].owner == _msgSender()) {
        IERC20(balanceHolderAddress).transfer(
          _msgSender(), 
          (players[i].quantityTickets * ticketCost).mul(1e18)
        );
      }

      delete players[i];
    }
  }

  /**
    @dev Withdrawing the funds to the respective token.
    @param _LPAddress Pool to withdraw funds from.
    @param _tokenAddress Token that will be withdrawed address of the underlying asset, not the aToken.
  **/

  function withdrawFunds(address _LPAddress, address _tokenAddress) public {
    // For Aave Pool
    if(_LPAddress == 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9) {
      IAaveLendingPool(_LPAddress).withdraw(_tokenAddress, ~uint256(0), address(this));
    }
  }

  /**
    @dev Getting the earned interest in the AAVE pool, by getting the aToken.
    @param _LPAddress Lending Pool address to search for equivalent token.
    @param _tokenAddress address of the token being used.
  **/

  function getATokenAddress(address _LPAddress, address _tokenAddress) public pure returns(address) {
    if(_LPAddress == 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9) {
      //Getting Atoken Of DAI
      if(_tokenAddress == 0x6B175474E89094C44Da98b954EedeAC495271d0F) {
        //returns aDAI
        return 0x028171bCA77440897B824Ca71D1c56caC55b68A3;
      }
      //Getting Atoken Of USDT
      if(_tokenAddress == 0xdAC17F958D2ee523a2206206994597C13D831ec7) {
        //returns aUSDT
        return 0x3Ed3B47Dd13EC9a98b44e6204A523E766B225811;
      }
      //Getting Atoken Of USDC
      if(_tokenAddress == 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48){
        //returns aUSDC
        return 0xBcca60bB61934080951369a648Fb03DF4F96263C;
      }
      //Getting Atoken Of TUSD
      if(_tokenAddress == 0x0000000000085d4780B73119b644AE5ecd22b376) {
        //returns aTUSD
        return 0x101cc05f4A51C0319f570d5E146a8C625198e636;
      }
      //Getting Atoken Of BUSD
      if(_tokenAddress == 0x4Fabb145d64652a948d72533023f6E7A623C7C53) {
        //returns aBUSD
        return 0xA361718326c15715591c299427c62086F69923D9;
      }
    }

    return address(0);
  }
  
  /**
    @dev Getting the earned interest in atoken
    @param _ATokenAddress atoken address that's generating the interest
    @param _balance total initial balance that was deposited to the contract
  **/

  function getEarnedInterest(address _ATokenAddress, uint256 _balance) internal view returns(uint256){
    return (IERC20(_ATokenAddress).balanceOf(address(this)) - _balance);
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
    @dev Function to make the swap, for ETH to an StableCoin.
    @param _token This is the address of the token to receive.
  **/

  // @TODO Fix this function
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
    IERC20(_token).safeTransferFrom(
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
    IERC20(_tokenFrom).safeTransferFrom(_msgSender(), address(this), _amount);
    IERC20(_tokenFrom).safeApprove(_pool, _amount);
    IStableSwap(_pool).exchange_underlying(_from, _to, _amount, 1);
  }

  /** 
    @dev buyTickets function, this will buy the tickets that the
    user desire.
    @param _payment The token that the users want to pay, this can be
    an stable coin or either an ERC20 Token (DAI, LINK).
  **/
  function buyTickets(
    address _payment, 
    uint256 _quantityOfTickets, 
    uint256 _amount, 
    address _toSwap,
    int128 _indexFrom,
    int128 _indexTo
    ) external {
    require(_payment != address(0), "buyTickets: ZERO_ADDRESS");
    if (_payment == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
      require(
        _getPriceByToken(_payment) * IERC20(_payment).balanceOf(_msgSender()).div(1e18)
        >= 
        _quantityOfTickets * ticketCost,
        "buyTickets: NOT_ENOUGH_MONEY_TO_BUY"
      );
    } else {
      require(
        1 * IERC20(_payment).balanceOf(_msgSender()).div(1e18)
        >= 
        _quantityOfTickets * ticketCost,
        "buyTickets: NOT_ENOUGH_MONEY_TO_BUY"
      );
    }
    require(_quantityOfTickets <= maxTicketsPerPlayer, "buyTickets: EXCEED_MAX_TICKETS");

    if (_payment == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
      // @TODO Handle this function, when the user is paying with ETHER
      _swapWithUniswap(_payment);
    } else {
      _swapWithCurve(_indexFrom, _indexTo, _amount, _payment, _toSwap);
    }
    
    if (statusLottery == LotteryStatus.OPEN) {
      players[playersCount].owner = _msgSender();
      players[playersCount].initialBuy = supplyTickets;
      players[playersCount].endBuy = supplyTickets - _quantityOfTickets;
      players[playersCount].quantityTickets = _quantityOfTickets;
      supplyTickets = supplyTickets - _quantityOfTickets;
      playersCount++;

      emit LotteryEnter(_msgSender(), _quantityOfTickets, address(0));
    }

    if (statusLottery == LotteryStatus.CLOSE) {
      playersRunning[playersRunningCount].owner = _msgSender();
      playersRunning[playersRunningCount].initialBuy = supplyTicketsRunning;
      playersRunning[playersRunningCount].endBuy = supplyTicketsRunning - _quantityOfTickets;
      playersRunning[playersRunningCount].quantityTickets = _quantityOfTickets;
      supplyTicketsRunning = supplyTicketsRunning - _quantityOfTickets;
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
    @dev This is the function to send the tokens
    and when is pass the 2 days, it will fullfill
    to transfers the tokens to the a specific pool.
    @dev We are using a mock for testing so, be sure
    to always have the mock.
  **/

  function sendTokensToPool() external onlyAdmin {
    require(statusLottery == LotteryStatus.OPEN, "sendTokensToPool: LOTTERY_NEED_TO_BE_OPEN");
    require(IERC20(balanceHolderAddress).balanceOf(address(this)) > 0, "sendTokensToPool: NEED_TO_HAVE_BALANCE");

    /*
      We build the chainlink request,
      and the function `fulfill_tokens`
      should be shot after 2 days,
      with the oracle of CHAINLINK.
    */

    Chainlink.Request memory req = buildChainlinkRequest(
      "0be1216ae9344e7b8e81539939b5ac64", /* This is the _jobId of CHAINLIN for MAINNET. */
      address(this), 
      this.fulfill_tokens.selector
    );
    req.addUint("until", block.timestamp + 172800); /* 2 days in seconds */
    sendChainlinkRequestTo(oracleAddress, req, 1 * 1e18);
  }

  /** 
    @dev This functions will fullfill when  passed two days,
    this function should be called by the oracle of CHAINLINK.

    @notice If you are testing in a TESTNET, always remember to
    pass LINK to the oracle to complete the request, in this
    case we are using a mock, but we still pass in tests LINK
    to simulate the transaction.
  **/

  function fulfill_tokens(bytes32 _requestId) external recordChainlinkFulfillment(_requestId) {
    /*
      Add the logic to send all the tokens
      of one asset to a specific pool of that
      asset either in COMPOUND pools or AAVE pools.
    */

    tokenBalance = IERC20(balanceHolderAddress).balanceOf(address(this));
    IERC20(balanceHolderAddress).safeApprove(lendingPool, IERC20(balanceHolderAddress).balanceOf(address(this)));
    IAaveLendingPool(lendingPool).deposit(balanceHolderAddress, IERC20(balanceHolderAddress).balanceOf(address(this)), address(this), 0);
    _getRandomNumber(seed); /* This is to get the request for getting the randomNumber */

    statusLottery = LotteryStatus.CLOSE;
    emit StatusOfLottery(statusLottery);
    
    Chainlink.Request memory req = buildChainlinkRequest(
      "0be1216ae9344e7b8e81539939b5ac64", 
      address(this), 
      this.fulfill_winner.selector
    );
    req.addUint("until", block.timestamp + 472800);
    sendChainlinkRequestTo(oracleAddress, req, 1 * 1e18);
  }

  /**
    @dev This is the function to fullfill to choose the winner.
  **/
  function fulfill_winner(bytes32 _requestId) external recordChainlinkFulfillment(_requestId) {
    withdrawFunds(lendingPool, balanceHolderAddress);

    for (uint256 i = 0; i < playersCount; i++) {
      if (
          randomNumber.mod(supplyTickets - players[playersCount].endBuy) >= players[i].initialBuy 
          && 
          randomNumber.mod(supplyTickets - players[playersCount].endBuy) <= players[i].endBuy
        ) {
        /*
          Logic for earning the interest to this
          address and giving the admin 5% of fee.
        */

        IERC20(balanceHolderAddress)
          .transfer(
            players[i].owner, 
            (players[i].quantityTickets * ticketCost).mul(1e18)
            + 
            getEarnedInterest(
              getATokenAddress(lendingPool, balanceHolderAddress), 
              tokenBalance
            )
          );

        emit Winner(players[i].owner, RandomNumberConsumer(randomNumberConsumer).randomResult());
      } else {
        IERC20(balanceHolderAddress)
          .transfer(
            players[i].owner, 
            (players[i].quantityTickets * ticketCost).mul(1e18)
          );
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
      supplyTicketsRunning = ~uint256(0);
    } else {
      supplyTickets = ~uint256(0);
    }

    statusLottery = LotteryStatus.OPEN;
    emit StatusOfLottery(statusLottery); 
  }
}