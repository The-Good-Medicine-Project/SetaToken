// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

// Imports
import "./Libraries.sol";

contract SecondPresale is ReentrancyGuard {
    address public owner; // owner wallet
    IERC20 public token; //  Token.
    bool private tokenAvailable = false;
    uint public tokensPerETH = 5000; // new quantity of tokens per bnb half as many as presale 1
    uint public ending; // end time
    bool public presaleStarted = false; // true or false
    address public deadWallet = 0x0000000000000000000000000000000000000000; // burn Wallet.
    uint public cooldownTime = 0 days; //time between withdrawals to prevent whales
    uint public tokensSold;//sold quantity

    mapping(address => bool) public whitelist; // Whitelist of investors for presale
    mapping(address => uint) public invested; //how much bnb have they invested
    mapping(address => uint) public investorBalance;//what is their balance
    mapping(address => uint) public withdrawableBalance;//how much of that can they withdraw
    mapping(address => uint) public claimReady;//is the claim ready

    constructor(address _teamWallet) {
        owner = _teamWallet;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, 'You must be the owner.');
        _;
    }

    //set the token can do only 1 time
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

    //buy token
    function invest() public payable nonReentrant {
        require(whitelist[msg.sender], "You must be on the whitelist.");
        require(presaleStarted, "Presale must have started.");
        require(block.timestamp <= ending, "Presale finished.");
        invested[msg.sender] += msg.value; // update the investors investment
        require(invested[msg.sender] >= 0.10 ether, "Your investment should be more than 0.10 BNB.");
        require(invested[msg.sender] <= 10 ether, "Your investment cannot exceed 10 BNB.");
        uint _investorTokens = msg.value * tokensPerETH; // how many PLRT Token will they receive
        investorBalance[msg.sender] += _investorTokens;
        withdrawableBalance[msg.sender] += _investorTokens;
        tokensSold += _investorTokens;
    }

    //% calculator
    function mulScale (uint x, uint y, uint128 scale) internal pure returns (uint) {
        uint a = x / scale;
        uint b = x % scale;
        uint c = y / scale;
        uint d = y % scale;
        return a * c * scale + a * d + b * c + b * d / scale;
    }
    //claim function for investors
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
            claimReady[msg.sender] = block.timestamp + cooldownTime; // udate next claim time
            withdrawableBalance[msg.sender] -= _withdrawableTokensBalance; // update balance
            token.transfer(msg.sender, _withdrawableTokensBalance); // transfer tokens
        }
    }

    function BalanceOut() public onlyOwner {
        uint _bBalance = address(this).balance;
        payable(owner).transfer(_bBalance);
    }
    //burn leftover tokens
    function burnTokens() public onlyOwner {
        require(block.timestamp > ending, "Presale must have finished.");
        uint _contractBalance = token.balanceOf(address(this));
        uint _tokenBalance = _contractBalance - tokensSold;
        token.transfer(deadWallet, _tokenBalance);
    }
}