pragma solidity ^0.5.4;

library SafeMath {
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
    // benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
    if (a == 0) {
      return 0;
    }

    uint256 c = a * b;
    require(c / a == b);

    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b > 0); // Solidity only automatically asserts when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold

    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b <= a);
    uint256 c = a - b;

    return c;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a);

    return c;
  }

  function mod(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0);
    return a % b;
  }
}

contract BasicToken {
    using SafeMath for uint256;

    uint256 internal _totalSupply;

    string public name;

    uint8 public decimals;

    string public symbol;

    mapping (address => uint256) internal _balances;

    mapping (address => mapping (address => uint256)) internal _allowed;


    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    constructor (
        uint256 totalSupply,
        string memory tokenName,
        string memory tokenSymbol,
        uint8 decimalUnits
    ) public {
        _totalSupply = totalSupply;
        _balances[msg.sender] = totalSupply;
        name = tokenName;
        decimals = decimalUnits;
        symbol = tokenSymbol;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address owner) external view returns (uint256) {
        return _balances[owner];
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowed[owner][spender];
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(value <= _balances[msg.sender]);
        require(to != address(0));

        _balances[from] = _balances[from].sub(value);
        _balances[to] = _balances[to].add(value);
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        require(spender != address(0));

        _allowed[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        require(value <= _allowed[from][msg.sender]);
        _allowed[from][msg.sender] = _allowed[from][msg.sender].sub(value);

        _transfer(from, to, value);
        emit Transfer(from, to, value);
        return true;
    }
}

contract GameToken is BasicToken {

    // erc721
    struct Avatar {
      uint256 gene;
      uint256 avatarLevel;
      bool weaponed;
      bool armored;
    }
    
    address public _owner;

    uint constant internal MAXLEVEL= 2;

    mapping (uint256 => address) internal _avatarOwner;

    mapping (uint256 => Avatar) public avatar;

    mapping (address => uint256) internal _ownedAvatars;



    event Reward(address machine, address  player, uint256 value);
    event Consume(address machine, address  player, uint256 value);

    constructor (
        uint256 totalSupply,
        string memory tokenName,
        string memory tokenSymbol,
        uint8 decimalUnits
    ) BasicToken(totalSupply,tokenName,tokenSymbol,decimalUnits) public {
        _owner = msg.sender;
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        address owner = _avatarOwner[tokenId];
        require(owner != address(0));
        return owner;
    }

    function ownedAvatars(address owner) external view returns (uint256){
        return _ownedAvatars[owner];
    }
    
    function avatarState(uint256 tokenId) external view returns (uint256,uint256,bool,bool) {
        address owner = _avatarOwner[tokenId];
        require(owner != address(0));
        Avatar memory a = avatar[tokenId];
        return (a.gene,a.avatarLevel,a.weaponed,a.armored);
    }

    function mint(address to, uint256 tokenId) external {
        require(to !=address(0));
        _avatarOwner[tokenId] = to ;
        _ownedAvatars[to]= tokenId;
        avatar[tokenId].gene= now %2;
    }

    function upgrade(uint256 tokenId) external {
        require(avatar[tokenId].avatarLevel < MAXLEVEL);
        avatar[tokenId].avatarLevel +=1;
    }

    function equipWeapon(uint256 tokenId, address user) external {
        require(_avatarOwner[tokenId]==user);
        require(!avatar[tokenId].weaponed);
        avatar[tokenId].weaponed = true;
    }

    function equipArmor(uint256 tokenId, address user) external {
        require(_avatarOwner[tokenId]==user);
        require(!avatar[tokenId].armored);
        avatar[tokenId].armored  = true;
    }

    function reward(address to, uint256 value) public returns (bool) {
        _transfer(msg.sender, to, value);
        emit Reward(msg.sender, to, value);
        return true;
    }

    function consume(address by, uint256 value) public  returns (bool){
        _transfer(by, msg.sender, value);
        emit Consume(msg.sender, by, value);
        return true;
    }

}

contract BridgeToken is GameToken{

    mapping (bytes32 => bool) public payed;
    uint256 public requiredSignatures;

    event Exchange(address user, uint amount);
    event Pay(address user, uint amount);
    event ExchangeNFT(uint256 tokenID, address owner, uint256 gene, uint256 avatarLevel, bool weaponed, bool armored);
    event PayNFT(uint256 tokenID, address avatarOwner, uint256 gene, uint256 avatarLevel, bool weaponed, bool armored);

    constructor (uint256 totalSupply,
                string memory tokenName,
                string memory tokenSymbol,
                uint8 decimalUnits,
                uint _requiredSignatures)
    public GameToken(totalSupply,tokenName,tokenSymbol,decimalUnits) {
        requiredSignatures = _requiredSignatures;
        _owner = msg.sender;

    }

    function exchange(address user,uint amount) external {
        _transfer(user, _owner, amount);
        emit Exchange(user, amount);
    }
    
    function pay(address user, uint amount) external {
        _transfer(_owner, user, amount);
        emit Pay(user,amount);
    } 

    function exchangeNFT (uint256 tokenID) external {
        address avatarOwner = _avatarOwner[tokenID];
        require(msg.sender == avatarOwner);
        _ownedAvatars[avatarOwner]=0;
        _avatarOwner[tokenID]= address(0);
        uint256 gene = avatar[tokenID].gene ;
        uint256 avatarLevel = avatar[tokenID].avatarLevel;
        bool weaponed = avatar[tokenID].weaponed;
        bool armored = avatar[tokenID].armored;
        avatar[tokenID].gene=0;
        avatar[tokenID].avatarLevel = 0;
        avatar[tokenID].weaponed = false;
        avatar[tokenID].armored = false;
        emit ExchangeNFT(tokenID,avatarOwner, gene, avatarLevel, weaponed, armored);
    }

    function payNFT (uint256 tokenID, address avatarOwner, uint256 gene, uint256 avatarLevel, bool weaponed, bool armored) external {
        _ownedAvatars[avatarOwner]=tokenID;
        _avatarOwner[tokenID]=avatarOwner;
        avatar[tokenID].gene = gene;
        avatar[tokenID].avatarLevel = avatarLevel;
        avatar[tokenID].weaponed = weaponed;
        avatar[tokenID].armored = armored;
        emit PayNFT(tokenID, avatarOwner, gene, avatarLevel, weaponed, armored);
    }
}