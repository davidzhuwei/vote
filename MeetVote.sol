// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts@4.7.3/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts@4.7.3/access/Ownable.sol";
import "@openzeppelin/contracts@4.7.3/token/ERC1155/IERC1155.sol";

contract ImplV1Store {
    // Idol结构体，包含id,队伍名称，投票数，活跃状态和地址的投票映射
    struct Idol {
        uint256 id;
        bytes32 team;
        uint256 voteCount;
        bool isActive;
        mapping(address => uint256) votesByAddress;
    }

    // NFT票据合约的接口
    IERC1155 public nftTicket;
    // ID到Idol的映射
    mapping(uint256 => Idol) internal idols;
    // ID到偶像真实名字的私有映射
    mapping(uint256 => bytes32) internal idolRealNames;
    // 所有偶像ID的数组
    uint256[] internal idolIds;
    // 投票是否启用的状态变量
    bool public votingEnabled;
    // 投票转换idolId的参数
    uint256 internal value;
    // 新偶像添加事件
    event IdolAdded(uint256 indexed id);
    // 投票事件
    event VoteCasted(
        address indexed voter,
        uint256 indexed id,
        uint256 ticketAmount
    );
}

contract IdolVotingV2 is ERC1155Holder, ImplV1Store, Ownable  {
    constructor(address initialOwner, address _nftTicket, uint256 _value) {
        nftTicket = IERC1155(_nftTicket);
        votingEnabled = false;
        value = _value;
        transferOwnership(initialOwner);
    }

    // 开启投票的函数，只有合约所有者可以调用
    function enableVoting() public onlyOwner {
        votingEnabled = true;
    }

    // 禁用投票的函数，只有合约所有者可以调用
    function disableVoting() public onlyOwner {
        votingEnabled = false;
    }

    // 添加偶像
    function addIdol(uint256 id, bytes32 name, bytes32 team) public onlyOwner {
        require(id != 0, "Idol does not exist");
        require(idols[id].id == 0, "Idol already exists");

        idols[id].id = id;
        idolRealNames[id] = name;
        idols[id].team = team;
        idols[id].voteCount = 0;
        idols[id].isActive = true;

        idolIds.push(id);
        emit IdolAdded(id);
    }

    // 投票
    function vote(uint256 id, uint256 ticketAmount) public {
        require(votingEnabled, "Voting is currently disabled");
        uint256 xorId = id ^ value;
        require(xorId != 0, "Idol does not exist");
        require(idols[xorId].id != 0, "Idol does not exist");
        require(idols[xorId].isActive, "Idol voting is disabled");
        require(ticketAmount > 0, "Ticket amount must be greater than 0");
        require(
            nftTicket.balanceOf(msg.sender, 1) >= ticketAmount,
            "Insufficient NFT ticket balance"
        );

        // 从投票者转移NFT票据到这个合约
        nftTicket.safeTransferFrom(
            msg.sender,
            address(this),
            1,
            ticketAmount,
            ""
        );

        // 更新投票数和投票者的投票数
        idols[xorId].voteCount += ticketAmount;
        idols[xorId].votesByAddress[msg.sender] += ticketAmount;

        // 触发投票事件
        emit VoteCasted(msg.sender, xorId, ticketAmount);
    }

    // 更改value
    function setValue(uint256 newValue) public onlyOwner {
        value = newValue;
    }

    // 更新偶像活跃状态的函数，只有合约所有者可以调用
    function setIdolStatus(uint256 id, bool status) public onlyOwner {
        require(id != 0, "Idol does not exist");
        require(idols[id].id != 0, "Idol does not exist");
        idols[id].isActive = status;
    }

    // 更新偶像真实名字的函数，接收偶像ID和新名字作为参数，只有合约所有者可以调用
    function setIdolRealName(uint256 id, bytes32 newName) public onlyOwner {
        require(id != 0, "Idol does not exist");
        require(idols[id].id != 0, "Idol does not exist");
        idolRealNames[id] = newName;
    }

    // 提取NFT投票券的函数，只有合约所有者可以调用
    function withdrawNFT(uint256 ticketAmount) public onlyOwner {
        require(ticketAmount != 0, "ticketAmount cannot be zero");
        nftTicket.safeTransferFrom(
            address(this),
            msg.sender,
            1,
            ticketAmount,
            ""
        );
    }

    // 获取偶像信息的函数，接收偶像ID作为参数
    function getIdolInfo(
        uint256 id
    ) public view onlyOwner returns (bytes32, bytes32, uint256, bool) {
        require(id != 0, "Idol does not exist");
        require(idols[id].id != 0, "Idol does not exist");
        return (
            idolRealNames[id],
            idols[id].team,
            idols[id].voteCount,
            idols[id].isActive
        );
    }

    // 获取用户给某偶像的投票数的函数，接收偶像ID和用户地址作为参数
    function getUserVotes(
        uint256 id,
        address userAddr
    ) public view onlyOwner returns (uint256) {
        require(id != 0, "Idol does not exist");
        require(idols[id].id != 0, "Idol does not exist");
        return idols[id].votesByAddress[userAddr];
    }

    // 获取偶像id总数的函数
    function getTotalIdols() public view onlyOwner returns (uint256) {
        return idolIds.length;
    }

    //返回idol排名
    function getIdolRank(
        uint256 rank
    ) public view onlyOwner returns (uint256[] memory, uint256[] memory) {
        require(rank != 0, "rank cannot be zero");
        require(
            rank <= idolIds.length,
            "rank cannot be greater than the number of idols"
        );

        uint256[] memory ids = new uint256[](rank);
        uint256[] memory votes = new uint256[](rank);

        for (uint256 i = 0; i < idolIds.length; i++) {
            uint256 currentId = idolIds[i];
            uint256 currentVotes = idols[currentId].voteCount;

            for (uint256 j = 0; j < rank; j++) {
                if (currentVotes >= votes[j]) {
                    for (uint256 k = rank - 1; k > j; k--) {
                        ids[k] = ids[k - 1];
                        votes[k] = votes[k - 1];
                    }
                    ids[j] = currentId;
                    votes[j] = currentVotes;
                    break;
                }
            }
        }
        return (ids, votes);
    }
    
    // 提现函数
    function withdrawBNB(uint256 amount) public onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        require(address(this).balance >= amount, "Insufficient balance");

        // 使用 transfer 方法安全地发送 BNB 到所有者地址
        payable(msg.sender).transfer(amount);
    }

    // 接收以太的回退函数
    receive() external payable {}
}
