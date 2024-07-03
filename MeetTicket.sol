// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts@4.7.3/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts@4.7.3/access/Ownable.sol";

contract Ticket is ERC1155, Ownable {

    uint256 public constant TICKET_TYPE = 1;
    uint256 private _totalSupply;

    mapping(address => mapping(address => mapping(uint256 => uint256))) private _allowances;

    event ApprovalForId(address indexed owner, address indexed spender, uint256 indexed id, uint256 oldValue, uint256 value);

    error ERC1155ApprovalForAllOrApprovalForId(address operator, address owner);

    constructor(address initialOwner, uint256 amount) ERC1155("") {
        _totalSupply = amount;
        _mint(initialOwner, TICKET_TYPE, _totalSupply, "");
        transferOwnership(initialOwner);
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function mintToOwner(uint256 amount) public onlyOwner {
        _mint(msg.sender, TICKET_TYPE, amount, "");
        _totalSupply += amount;
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }


    function setApprovalForId(address spender, uint256 id, uint256 currentValue, uint256 value) external {
        address sender = _msgSender();
        require(_allowances[sender][spender][id] == currentValue);
        _allowances[sender][spender][id] = value;

        emit ApprovalForId(sender, spender, id, currentValue, value);
    }


    function approvedForId(address owner, address spender, uint256 id) public view returns (uint256){
        return _allowances[owner][spender][id];
    }


    function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes memory data) public override  virtual {
        address sender = _msgSender();
        require(from != to, "from cannot equal to");
        if (from != sender && !(isApprovedForAll(from, sender) || _allowances[from][sender][id] >= value)) {
            revert ERC1155ApprovalForAllOrApprovalForId(sender, from);
        }

        if (from != sender && _allowances[from][sender][id] > 0) {
            _allowances[from][sender][id] = (_allowances[from][sender][id] > value) ? _allowances[from][sender][id] - value : 0;
        }

        super._safeTransferFrom(from, to, id, value, data);
    }


    function safeBatchTransferFrom(address from, address to, uint256[] memory ids, uint256[] memory values, bytes memory data ) public override virtual {
        address sender = _msgSender();
        require(from != to, "from cannot equal to");
        if (from != sender && !isApprovedForAll(from, sender)) {
            for (uint256 i = 0; i < ids.length; i++) {
                if(_allowances[from][sender][ids[i]] < values[i]){
                    revert ERC1155ApprovalForAllOrApprovalForId(sender, from);
                }
            }
        }

        if (from != sender) {
            for (uint256 i = 0; i < ids.length; i++) {
                if(_allowances[from][sender][ids[i]] > 0){
                    _allowances[from][sender][ids[i]] = (_allowances[from][sender][ids[i]] > values[i]) ? _allowances[from][sender][ids[i]] - values[i] : 0;
                }
            }
        }
        
        _safeBatchTransferFrom(from, to, ids, values, data);
    }



}