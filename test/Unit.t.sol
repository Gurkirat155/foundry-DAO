// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;


import {Test}  from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Box} from "../src/Box.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {DAO} from "../src/DAO.sol";
import {GovToken} from "../src/VotingToken.sol";

contract DAOtest is Test {

    Box box;
    TimeLock timeLock;
    DAO dao;
    GovToken votingToken;

    address owner = makeAddr("owner");
    uint256 public constant Intial_Supply = 100 ether;
    uint256 public constant MIN_DELAY = 3600; // 1 hour
    uint256 public constant VOTING_DELAY = 7200; // 1 Day
    uint256 public constant VOTING_PERIOD = 50400; // This is how long voting lasts for
    address[] public proposers;
    address[] public executors;


    bytes[] functionCalls;
    address[] smartContractAddressesToCall;
    uint256[] values;

    function setUp() public {

        vm.startPrank(owner);
        votingToken = new GovToken(owner);
        votingToken.mint(owner, Intial_Supply);
        votingToken.delegate(owner);

        timeLock = new TimeLock(MIN_DELAY, proposers, executors);
        
        dao = new DAO(votingToken, timeLock);

        bytes32 proposerRole = timeLock.PROPOSER_ROLE();
        bytes32 executorRole = timeLock.EXECUTOR_ROLE();
        bytes32 adminRole = timeLock.DEFAULT_ADMIN_ROLE();

        timeLock.grantRole(proposerRole, address(dao));
        timeLock.grantRole(executorRole, address(0)); //Means any body can padd the proposal 
        timeLock.grantRole(adminRole, owner);

        box = new Box(owner);
        box.transferOwnership(address(timeLock));
        vm.stopPrank();
    }

    function testCantUpdateBoxWithoutGoverance()  public {
        vm.expectRevert();
        box.changeNumber(10);
    }

    function testUpdateBox() public {
        uint256 val = 10;
        vm.startPrank(address(timeLock));
        box.changeNumber(val);
        uint256 number = box.getNumber();
        assertEq(number, val);
        vm.stopPrank();
    }

    function testGoverance()  public {
        uint256 val = 20;
        string memory description = "Change the number to 20";
        bytes memory encodedFunctionCall = abi.encodeWithSignature("changeNumber(uint256)", val);
        smartContractAddressesToCall.push(address(box)); //Means which contract address to call to make changes
        values.push(0); //Don't know what this means
        functionCalls.push(encodedFunctionCall); //Means which function to call in the contract
        uint256 proposalId = dao.propose(smartContractAddressesToCall, values, functionCalls, description);

        //1. PROPOSE-- to the DAO
        // console.log("Proposal ID: ", proposalId);
        console.log("Proposal State before time has passed:", uint256(dao.state(proposalId)));
        // console.log(dao.proposalSnapshot(proposalId));
        // console.log(dao.proposalDeadline(proposalId));

        // console.log(block.timestamp);
        // console.log(block.number);

        // console.log("This is the voting delay: " ,dao.votingDelay());
        assertEq(uint256(dao.state(proposalId)), 0,"Voting has not started yet,because voting delay still has not passed");
        // To speed the time and delay to the voting period
        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        // console.log(block.timestamp);
        // console.log(block.number);

        console.log("Proposal State after time has passed:", uint256(dao.state(proposalId)));
        assertEq(uint256(dao.state(proposalId)), 1,"Voting has started");

        // 2. VOTE -- Voting Begins after the 1 week has passed and 1 block has been mined
        uint8 support  =   1;
        string memory reason = "I support this proposal to change value to 20";
        vm.prank(owner); //This is the voter I have just written owner so don't get confused
        dao.castVoteWithReason(proposalId, support, reason);

        vm.warp(block.timestamp + VOTING_PERIOD + 2);
        vm.roll(block.number + VOTING_PERIOD + 2);

        // console.log(block.timestamp);
        // console.log(block.number);

        console.log("Proposal State After Voting and 1 week time pass:", uint256(dao.state(proposalId)));
        assertEq(uint256(dao.state(proposalId)), 4,"Voting succeded");

        // 3. QUEUE -- Proposal has been voted on and now it is time to execute the proposal
        bytes32 descriptionHash = keccak256(abi.encodePacked(description)); //Description is taken in hash by the queue function i don't know why
        dao.queue(smartContractAddressesToCall, values, functionCalls, descriptionHash);
        console.log("Proposal State After it is queued:", uint256(dao.state(proposalId)));
        assertEq(uint256(dao.state(proposalId)), 5,"Proposal has been queued");

        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);
        
        // 4. EXECUTE -- Proposal has been queued and now it is time to execute the proposal
        dao.execute(smartContractAddressesToCall, values, functionCalls, descriptionHash);

        console.log("Proposal State After it is executed:", uint256(dao.state(proposalId)));
        assertEq(uint256(dao.state(proposalId)), 7,"Proposal has been executed");
    }    
}