//SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.11;

contract PoolingContract{
    address public owner;
    address[] public participants;
    uint256 public constant PARTICIPANT_AMOUNT = 0.01 ether;
    uint256 public poolBalance;
    bool public poolClosed = false;

    address public selectedWinner;
    bool public winnerDrawn = false;

    // 이벤트 호출 함수
    event ParticipantJoined(address indexed participant, uint256 amount);
    event WinnerSelected(address indexed winner, uint256 winningAmount);
    event OwnerFeePaid(address indexed owner, uint256 feeAmount);
    event PoolClosed(uint256 totalAmount, uint256 participantCount);


    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }

    modifier poolOpen(){
        require(!poolClosed, "Pool is open");
        _;
    }

    modifier poolIsClosed(){
        require(poolClosed, "Pool must be closed first");
        _;
    }

    modifier exactAmount(){
        require(msg.value == PARTICIPANT_AMOUNT, "Must send exactly 0.01 ETH");
        _;
    }

    constructor() payable{
        owner = msg.sender;
        poolBalance = 0;
    }

    function bet() public payable poolOpen exactAmount{
        for(uint i = 0; i < participants.length; i++){
            require(participants[i] != msg.sender, "You already joined to the Pool");
        }
        participants.push(msg.sender);
        poolBalance += msg.value;

        emit ParticipantJoined(msg.sender, msg.value);
    }

    function draw() public payable onlyOwner poolOpen{
        require(participants.length > 0, "No participants in the Pool");

        poolClosed = true;

        emit PoolClosed(poolBalance, participants.length);

        selectRandomWinner();
       
    }

    function selectRandomWinner() private{
        require(participants.length > 0, "No Participants");

        uint256 randomIndex = uint256(
            keccak256(abi.encodePacked(block.timestamp, block.prevrandao, participants.length))
        ) % participants.length;
        selectedWinner = participants[randomIndex];
        winnerDrawn = true;

        distributePrizes();
    }

    function distributePrizes() public onlyOwner poolIsClosed{
        require(winnerDrawn, "Winner must be selected first");
        require(selectedWinner != address(0), "Invalid Winner");
        require(poolBalance > 0, "No balance to distribute");

        uint256 winnerAmount = (poolBalance * 90) / 100;
        uint256 ownerAmount = (poolBalance *10) / 100;
        uint256 remainder = poolBalance - winnerAmount - ownerAmount;
        // uint256 totalDistribute = poolBalance;
        poolBalance = 0;

        (bool winnerSuccess,) = selectedWinner.call{value: winnerAmount + remainder}("");
        require(winnerSuccess, "Transfer to winner failed");
        emit WinnerSelected(selectedWinner, winnerAmount + remainder);

        (bool ownerSuccess,) = owner.call{value: ownerAmount}("");
        require(ownerSuccess, "Transfer to owner failed");
        emit OwnerFeePaid(owner, ownerAmount);

        resetPool();

    }

    function getParticipantCount() public view returns (uint256){
        return participants.length;
    }

    function getPoolBalance() public view returns (uint256){
        return poolBalance;
    }

    function isParticipant(address _address) public view returns (bool){
        for (uint256 i = 0; i < participants.length;i++){
            if(participants[i] == _address){
                return true;
            }
        }
        return false;
    }

    function calculateWinnerPrize() public view returns (uint256){
        if(poolBalance == 0) return 0;
        return ((poolBalance * 90) / 100);
    }

    function resetPool() public onlyOwner {
        require(poolBalance == 0, "Pool balance must be zero to reset");

        participants = new address[](0);
        poolClosed = false;
        selectedWinner = address(0);
        winnerDrawn = false;
    }
   
    function emergencyWithdraw() public onlyOwner{
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");

        (bool success,) = owner.call{value: balance}("");
        require(success, "Emergency withdrawal failed");
    }
    receive() external payable {
        // 자도응로 풀에 참여하지 않음 (명시적 호출 필요);
    }
}