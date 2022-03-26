// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

// Imports
import "./Libraries.sol";
//we put the team funds in here so the people see we cant take and trade or
//sell all at once just like them we cant act as a whale
contract TeamVesting is ReentrancyGuard {
    IERC20 public token;
    address public teamWallet; // team wallet
    uint public cooldownTime = 30 days; // cooldown time
    uint public claimReady; //save claim  time
    bool private tokenAvailable = false;
    uint public initialContractBalance; // Initial contract balance.
    bool private initialized; // Checks if the variable initializedContractBalance has been defined.

    constructor(address _teamWallet) {
        teamWallet = _teamWallet;
    }

    modifier onlyOwner() {
        require(msg.sender == teamWallet, 'You must be the owner.');
        _;
    }

    //add the token can only happen once
    function setToken(IERC20 _token) public onlyOwner {
        require(!tokenAvailable, "Token is already inserted.");
        token = _token;
        tokenAvailable = true;
    }

    //% calculator
    function mulScale (uint x, uint y, uint128 scale) internal pure returns (uint) {
        uint a = x / scale;
        uint b = x % scale;
        uint c = y / scale;
        uint d = y % scale;

        return a * c * scale + a * d + b * c + b * d / scale;
    }

    //team claim
    function claimTokens() public onlyOwner nonReentrant {
        require(claimReady <= block.timestamp, "You can't claim now.");
        require(token.balanceOf(address(this)) > 0, "Insufficient Balance.");

        if(!initialized) {
            initialContractBalance = token.balanceOf(address(this));
            initialized = true;
        }

        uint _withdrawableBalance = mulScale(initialContractBalance, 1000, 10000); // 1000 basis points = 10%.

        if(token.balanceOf(address(this)) <= _withdrawableBalance) {
            token.transfer(teamWallet, token.balanceOf(address(this)));
        } else {
            claimReady = block.timestamp + cooldownTime;

            token.transfer(teamWallet, _withdrawableBalance); 
        }
    }
}