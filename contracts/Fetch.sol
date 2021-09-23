pragma solidity ^0.6.2;

import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/ISale.sol";
import "./interfaces/IStake.sol";
import "./openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./openzeppelin-contracts/contracts/math/SafeMath.sol";
import "./openzeppelin-contracts/contracts/token/ERC20/SafeERC20.sol";
import "./openzeppelin-contracts/contracts/access/Ownable.sol";


contract Fetch is Ownable {

  using SafeERC20 for IERC20;
  using SafeMath for uint256;
  address public WETH;
  address public pancakeRouter;
  address public coSwapRouter;

  address public stakeClaimAble;
  address public stakeNonClaimAble;

  address public token;
  address public uniPair;
  address public tokenSale;

  uint256 public pancakeSplit = 50;
  uint256 public coSwapSplit = 25;
  uint256 public saleSplit = 25;

  /**
  * @dev constructor
  *
  * @param _stakeClaimAble        address of claim able stake
  * @param _stakeNonClaimAble     address of non claim able stake
  * @param _token                 address of token token
  * @param _uniPair               address of pool pair
  * @param _tokenSale             address of token sale
  */
  constructor(
    address _WETH,
    address _pancakeRouter,
    address _coSwapRouter,
    address _stakeClaimAble,
    address _stakeNonClaimAble,
    address _token,
    address _uniPair,
    address _tokenSale
    )
    public
  {
    WETH = _WETH;
    pancakeRouter = _pancakeRouter;
    coSwapRouter = _coSwapRouter;
    stakeClaimAble = _stakeClaimAble;
    stakeNonClaimAble = _stakeNonClaimAble;
    token = _token;
    uniPair = _uniPair;
    tokenSale = _tokenSale;
  }

  // deposit only ETH
  function deposit(bool _isClaimAbleStake) external payable {
    require(msg.value > 0, "zerro eth");
    // swap ETH
    swapETHInput(msg.value);
    // deposit and stake
    _depositFor(_isClaimAbleStake, msg.sender);
  }

  // deposit only ETH for a certain address
  function depositFor(bool _isClaimAbleStake, address receiver) external payable {
    require(msg.value > 0, "zerro eth");
    // swap ETH
    swapETHInput(msg.value);
    // deposit and stake
    _depositFor(_isClaimAbleStake, receiver);
  }

  // deposit ETH and token without convert
  function depositETHAndERC20(bool _isClaimAbleStake, uint256 tokenAmount) external payable {
    IERC20(token).safeTransferFrom(msg.sender, address(this), tokenAmount);
    // deposit and stake
    _depositFor(_isClaimAbleStake, msg.sender);
  }

  /**
  * @dev convert deposited ETH into pool and then stake
  */
  function _depositFor(bool _isClaimAbleStake, address receiver) internal {
    // define stake address
    address stakeAddress = _isClaimAbleStake
    ? stakeClaimAble
    : stakeNonClaimAble;

    // check if token received
    uint256 tokenReceived = IERC20(token).balanceOf(address(this));
    uint256 ethBalance = address(this).balance;

    require(tokenReceived > 0, "NOT SWAPED");
    require(ethBalance > 0, "ETH NOT REMAINS");

    // convert ETH to WETH
    IWETH(WETH).deposit.value(ethBalance)();

    // approve tokens to router
    IERC20(token).approve(pancakeRouter, tokenReceived);
    IERC20(WETH).approve(pancakeRouter, ethBalance);

    // add LD
    IUniswapV2Router02(pancakeRouter).addLiquidity(
        WETH,
        token,
        ethBalance,
        tokenReceived,
        1,
        1,
        address(this),
        now + 1800
    );

    // approve pool to stake
    uint256 poolReceived = IERC20(uniPair).balanceOf(address(this));
    IERC20(uniPair).approve(stakeAddress, poolReceived);

    // deposit received pool in token vault strategy
    IStake(stakeAddress).stakeFor(poolReceived, receiver);

    // send remains and shares back to users
    sendRemains(stakeAddress, receiver);
  }


 /**
 * @dev send remains back to user
 */
 function sendRemains(address stakeAddress, address receiver) internal {
    uint256 tokenRemains = IERC20(token).balanceOf(address(this));
    if(tokenRemains > 0)
       IERC20(token).transfer(receiver, tokenRemains);

    uint256 wethRemains = IERC20(WETH).balanceOf(address(this));
    if(wethRemains > 0)
      IERC20(WETH).transfer(receiver, wethRemains);

    uint256 ethRemains = address(this).balance;
    if(ethRemains > 0)
       payable(receiver).transfer(ethRemains);
 }

 /**
 * @dev swap ETH to token via DEX and Sale
 */
 function swapETHInput(uint256 input) internal {
   // determining the portion of the incoming ETH to be converted to the ERC20 Token
   uint256 conversionPortion = input.mul(505).div(1000);

   (uint256 ethToPancake,
    uint256 ethToCoSwap,
    uint256 ethToSale) = calculateToSplit(conversionPortion);

   // SPLIT SALE with Pancake, CoSwap and Sale
   if(ethToPancake > 0)
     swapETHViaDEX(pancakeRouter, ethToPancake);

   if(ethToCoSwap > 0)
     swapETHViaDEX(coSwapRouter, ethToCoSwap);

   if(ethToSale > 0)
     ISale(tokenSale).buy.value(ethToSale)();
 }

 // helper for swap via dex
 function swapETHViaDEX(address routerDEX, uint256 amount) internal {
   // SWAP split % of ETH input to token from pool
   address[] memory path = new address[](2);
   path[0] = WETH;
   path[1] = token;

   IUniswapV2Router02(routerDEX).swapExactETHForTokens.value(amount)(
     1,
     path,
     address(this),
     now + 1800
   );
 }

 /**
 * @dev return split % amount of input
 */
 function calculateToSplit(uint256 ethInput)
   public
   view
   returns(uint256 ethToPancake, uint256 ethToCoSwap, uint256 ethToSale)
 {
   ethToPancake = ethInput.div(100).mul(pancakeSplit);
   ethToCoSwap = ethInput.div(100).mul(coSwapSplit);
   ethToSale = ethInput.div(100).mul(saleSplit);
 }

 /**
 * @dev allow owner set new split
 */
 function updateSplit(
   uint256 _pancakeSplit,
   uint256 _coSwapSplit,
   uint256 _saleSplit
 )
   external
   onlyOwner
 {
   uint256 totalPercentage = _pancakeSplit + _coSwapSplit + _saleSplit;
   require(totalPercentage == 100, "wrong total split");

   pancakeSplit = _pancakeSplit;
   coSwapSplit = _coSwapSplit;
   saleSplit = _saleSplit;
 }

 // TODO BUY via split
 // function buy()
}
