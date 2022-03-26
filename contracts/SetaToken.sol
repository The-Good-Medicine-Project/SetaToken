// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;
//pancake swap clone on bsc works good - launch net TBA
//testnet router: https://pancake.kiemtienonline360.com/- 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3 
//shit wallet-3 -0x22204A6bd11965F19F3ccf64541f34EcdF560d45
import "./Libraries.sol";

contract SetasToken {
    string public name = "Seta Token";
    string public symbol = "Seta";
    uint256 public totalSupply = 10000000; // 10 millon
    uint8 public decimals = 0;
    address public teamWallet; // owner wallet address
    address public marketingWallet; // marketing wallet address
    address private firstPresaleContract; // first presale address
    address private secondPresaleContract; // second presale address
    address private teamVestingContract; // team vesting contract
    IUniswapV2Router02 router; // Router.
    address private pancakePairAddress; // the pancakeswap pair address.
    uint public liquidityLockTime = 900 days; // how long do we lock up liquidity
    uint public liquidityLockCooldown;// cooldown period for changes to liquidity settings and removal

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) private _allowances;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    constructor(
        address _teamWallet, 
        address _marketingWallet, 
        address _firstPresaleContract, 
        address _secondPresaleContract, 
        address _teamVestingContract) {
        teamWallet = _teamWallet;
        marketingWallet = _marketingWallet;
        firstPresaleContract = _firstPresaleContract;
        secondPresaleContract = _secondPresaleContract;
        teamVestingContract = _teamVestingContract;
        router = IUniswapV2Router02(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3);//router address for pair creation
        pancakePairAddress = IPancakeFactory(router.factory()).createPair(address(this), router.WETH());

        uint _firstPresaleTokens =  1500000;//15%
        uint _secondPresaleTokens = 1500000;//15%
        uint _teamVestingTokens =   1500000;//15%
        uint _marketingTokens =     1500000;//15%
        uint _contractTokens = totalSupply - (_teamVestingTokens + _marketingTokens + _firstPresaleTokens + _secondPresaleTokens);
        //40% left to contract
        balanceOf[firstPresaleContract] = _firstPresaleTokens;
        balanceOf[secondPresaleContract] = _secondPresaleTokens;
        balanceOf[teamVestingContract] = _teamVestingTokens;
        balanceOf[marketingWallet] = _marketingTokens;
        balanceOf[address(this)] = _contractTokens;
    }

    modifier onlyOwner() {
        require(msg.sender == teamWallet, 'You must be the owner.');
        _;
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(balanceOf[msg.sender] >= _value);

        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;

        emit Transfer(msg.sender, _to, _value);

        return true;
    }

    function allowance(address _owner, address _spender) public view virtual returns (uint256) {
        return _allowances[_owner][_spender];
    }

    function increaseAllowance(address _spender, uint256 _addedValue) public virtual returns (bool) {
        _approve(msg.sender, _spender, _allowances[msg.sender][_spender] + _addedValue);

        return true;
    }

    function decreaseAllowance(address _spender, uint256 _subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][_spender];
        require(currentAllowance >= _subtractedValue, "ERC20: decreased allowance below zero");

        unchecked {
            _approve(msg.sender, _spender, currentAllowance - _subtractedValue);
        }
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        _approve(msg.sender, _spender, _value);

        return true;
    }

    function _approve(address _owner, address _spender, uint256 _amount) internal virtual {
        require(_owner != address(0), "ERC20: approve from the zero address");
        require(_spender != address(0), "ERC20: approve to the zero address");

        _allowances[_owner][_spender] = _amount;

        emit Approval(_owner, _spender, _amount);
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_value <= balanceOf[_from]);
        require(_value <= _allowances[_from][msg.sender]);

        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        _allowances[_from][msg.sender] -= _value;

        emit Transfer(_from, _to, _value);

        return true;
    }

    function burn(uint256 _amount) public virtual {
        _burn(msg.sender, _amount);
    }

    function _burn(address _account, uint256 _amount) internal virtual {
        require(_account != address(0), '');
        require(balanceOf[_account] >= _amount, 'tokens insuficient.');

        balanceOf[_account] -= _amount;
        totalSupply -= _amount;

        emit Transfer(_account, address(0), _amount);
    }
    
    function addLiquidity(uint _tokenAmount) public payable onlyOwner {
        require(_tokenAmount > 0 || msg.value > 0, "Insufficient tokens or BNBs.");
        
        _approve(address(this), address(router), _tokenAmount);

        liquidityLockCooldown = block.timestamp + liquidityLockTime;

        router.addLiquidityETH{value: msg.value}(
            address(this),
            _tokenAmount,
            0,
            0,
            address(this),
            block.timestamp
        );
    }

    function removeLiquidity() public onlyOwner {
        require(block.timestamp >= liquidityLockCooldown, "Locked");

        IERC20 liquidityTokens = IERC20(pancakePairAddress);
        uint _amount = liquidityTokens.balanceOf(address(this));
        liquidityTokens.approve(address(router), _amount);

        router.removeLiquidityETH(
            address(this),
            _amount,
            0,
            0,
            teamWallet,
            block.timestamp
        );
    }
}
