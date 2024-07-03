// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
 
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract TimeLock is TimelockController {

    // Minimum after the voting is over so that other people not satisfied with the decision can withdraw their funds
    // With That period of minimum deley
    
    // The proposers are the one who can propose 
    // Executors are the one who can execute the proposal
    constructor(uint256 minDelay, address[] memory proposers, address[] memory executors)
        TimelockController(minDelay, proposers, executors, msg.sender)
    {}
}