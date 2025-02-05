// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

contract BlindAuction_4 {
    // 拍卖的参数。
    // 时间是 unix 的绝对时间戳（自1970-01-01以来的秒数）
    // 或以秒为单位的时间段。
    address payable public beneficiary;
    uint public auctionEndTime;

    // 拍卖的当前状态。
    address public highestBidder;
    uint public highestBid;

    /// 已经有一个更高的或相等的出价。
    error BidNotHighEnough(uint highestBid);
    /// 函数 auctionEnd 已经被调用。
    error AuctionEndAlreadyCalled();
    /// 仅允许在这时间后调用
    error OnlyCanBeCallAfterThisTime();
    /// 仅允许在这时间前调用
    error OnlyCanBeCallBeforeThisTime();

    // 允许取回以前的竞标。
    mapping(address => uint) public pendingReturns;
    // 拍卖结束后设为 'true'，将禁止所有的变更
    // 默认初始化为 'false'。
    bool ended;
    // 使用 修饰符（modifier） 可以更便捷的校验函数的入参。
    // 'onlyBefore' 会被用于后面的 'bid' 函数：
    // 新的函数体是由 modifier 本身的函数体，其中'_'被旧的函数体所取代。
    modifier onlyBefore(uint time) {
        if (block.timestamp >= time) revert OnlyCanBeCallBeforeThisTime();
        _;
    }
    modifier onlyAfter(uint time) {
        if (block.timestamp <= time) revert OnlyCanBeCallAfterThisTime();
        _;
    }
    /// 以受益者地址 'beneficiaryAddress' 创建一个简单的拍卖，
    /// 拍卖时长为 '_biddingTime'。
    constructor(
        uint biddingTime,
        address payable beneficiaryAddress
    ) {
        beneficiary = beneficiaryAddress;
        auctionEndTime = block.timestamp + biddingTime;
    }

    /// 对拍卖进行出价，具体的出价随交易一起发送。
    function bid() external payable onlyBefore(auctionEndTime) {
        // 如果出价不高，就把钱送回去
        //（revert语句将恢复这个函数执行中的所有变化，
        // 包括它已经收到钱）。
        if (msg.value <= highestBid)
            revert BidNotHighEnough(highestBid);
        if (highestBid != 0) {
            pendingReturns[highestBidder] += highestBid;
        }
        highestBidder = msg.sender;
        highestBid = msg.value;
    }

    /// 撤回出价过高的竞标。
    function withdraw() external {
        uint amount = pendingReturns[msg.sender];
        if (amount > 0) {
            // 将其设置为0是很重要的，
            // 因为接收者可以在 'send' 返回之前再次调用这个函数
            // 作为接收调用的一部分。
            pendingReturns[msg.sender] = 0;
            // msg.sender 不属于 'address payable' 类型，
            // 必须使用 'payable(msg.sender)' 明确转换，
            // 以便使用成员函数 'transfer()'。
            payable(msg.sender).transfer(amount);
        }
    }

    /// 结束拍卖，并把最高的出价发送给受益人。
    function auctionEnd() external onlyAfter(auctionEndTime) {
        // 对于可与其他合约交互的函数（意味着它会调用其他函数或发送以太币），
        // 一个好的指导方针是将其结构分为三个阶段：
        // 1. 检查条件
        // 2. 执行动作 (可能会改变条件)
        // 3. 与其他合约交互
        // 如果这些阶段相混合，其他的合约可能会回调当前合约并修改状态，
        // 或者导致某些效果（比如支付以太币）多次生效。
        // 如果合约内调用的函数包含了与外部合约的交互，
        // 则它也会被认为是与外部合约有交互的。
        // 1. 条件
        if (ended)
            revert AuctionEndAlreadyCalled();
        // 2. 影响
        ended = true;
        // 3. 交互
        beneficiary.transfer(highestBid);
    }
}