// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;
///shit-wallet-MAIN-0x241a0CAeeC24fac2CBB6D44324A83F214E216C17
// Imports
import "./Libraries.sol";

contract FirstPresale is ReentrancyGuard {
    address public owner; // owner
    IERC20 public token; //  Token.
    bool private tokenAvailable = false;
    uint public tokensPerETH = 8000; // spore per eth
    uint public ending; // sale end time
    bool public presaleStarted = false; //started or not
    address public deadWallet = 0x0000000000000000000000000000000000000000; // burn wallet for after sale
    uint public cooldownTime = 0 days; // time between withdrawals of token
    uint public tokensSold;

    mapping(address => bool) public whitelist; // Whitelist for presale.
    mapping(address => uint) public invested; // how much a person invested.
    mapping(address => uint) public investorBalance;//their current balance
    mapping(address => uint) public withdrawableBalance;//how much they can take out of tha platform
    mapping(address => uint) public claimReady;//is it time for that to happen

    constructor(address _teamWallet) {
        owner = _teamWallet;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, 'You must be the owner.');
        _;
    }

   //token insertion can only happen 1 time
    function setToken(IERC20 _token) public onlyOwner {
        require(!tokenAvailable, "Token is already inserted.");
        token = _token;
        tokenAvailable = true;
    }

    //add to whitelist
    function addToWhitelist(address _investor) public onlyOwner {
            require(_investor != address(0), 'Invalid address.');
            address _investorAddress = _investor;
            whitelist[_investorAddress] = true;        
    }

    function startPresale(uint _presaleTime) public onlyOwner {
        require(!presaleStarted, "Presale already started.");

        ending = block.timestamp + _presaleTime;
        presaleStarted = true;
    }

    function invest() public payable nonReentrant {
        require(whitelist[msg.sender], "You must be on the whitelist.");
        require(presaleStarted, "Presale must have started.");
        require(block.timestamp <= ending, "Presale finished.");
        invested[msg.sender] += msg.value; // update investors balance
        require(invested[msg.sender] >= 0.10 ether, "Your investment should be more than 0.10 BNB.");
        require(invested[msg.sender] <= 10 ether, "Your investment cannot exceed 10 BNB.");

        uint _investorTokens = msg.value * tokensPerETH; // how many tokens they will receive
        investorBalance[msg.sender] += _investorTokens;//do the swap
        withdrawableBalance[msg.sender] += _investorTokens;//update the necesary balances
        tokensSold += _investorTokens;//account for sale
    }

    //% calculation
    function mulScale (uint x, uint y, uint128 scale) internal pure returns (uint) {
        uint a = x / scale;
        uint b = x % scale;
        uint c = y / scale;
        uint d = y % scale;

        return a * c * scale + a * d + b * c + b * d / scale;
    }
    //investors claim function - they claim tokens at the end of the presale 
    //10% every 7 days to prevent whaling we should tweak this
    //it means a buyer who buys 1000 tokens can take 100 a week every week for x weeks
    function claimTokens() public nonReentrant {
        require(whitelist[msg.sender], "You must be on the whitelist.");
        require(block.timestamp > ending, "Presale must have finished.");
        require(claimReady[msg.sender] <= block.timestamp, "You can't claim now.");
        uint _contractBalance = token.balanceOf(address(this));
        require(_contractBalance > 0, "Insufficient contract balance.");
        require(investorBalance[msg.sender] > 0, "Insufficient investor balance.");
        uint _withdrawableTokensBalance = mulScale(investorBalance[msg.sender], 1000, 10000); // 1000 basis points = 10%.
        if(withdrawableBalance[msg.sender] <= _withdrawableTokensBalance) {
            token.transfer(msg.sender, withdrawableBalance[msg.sender]);
            investorBalance[msg.sender] = 0;
            withdrawableBalance[msg.sender] = 0;
        } else {
            claimReady[msg.sender] = block.timestamp + cooldownTime; // update next claim time
            withdrawableBalance[msg.sender] -= _withdrawableTokensBalance; // update withdrawable balance
            token.transfer(msg.sender, _withdrawableTokensBalance); // transfer the tokens
        }
    }

    function BalancingOut() public onlyOwner {
        uint _bBalance = address(this).balance;
        payable(owner).transfer(_bBalance);
    }

    //burn left over tokens
    function burnTokens() public onlyOwner {
        require(block.timestamp > ending, "Presale must have finished.");
        uint _contractBalance = token.balanceOf(address(this));
        uint _tokenBalance = _contractBalance - tokensSold;
        token.transfer(deadWallet, _tokenBalance);
    }
}