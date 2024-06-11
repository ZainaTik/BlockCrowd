// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.4.22 <0.9.0;

import "./UserManager.sol";

contract TaskManager {
    enum Status { Active, Completed, Canceled }

    struct Task {
        address taskId;
        address requester;
        string dataType;
        string location;
        uint256 duration; // duration in seconds
        uint256 numberOfWorkers;
        Status status;
        uint256 deposit;
        uint256 similarityThreshold;
        uint256 startTime;
    }

    UserManager private userManager;
    Task[] public tasks;

    // Event to log task publishing
    event TaskPublished(address indexed taskId, address indexed requester, string dataType, string location, uint256 deposit);

    // Modifier to check if the caller is a registered requester
    modifier onlyRegisteredRequester() {
        (address blockchainAddress, UserManager.UserType userType, ) = userManager.getUser(msg.sender);
        require(blockchainAddress != address(0), "User not registered");
        require(userType == UserManager.UserType.Requester, "Caller is not a requester");
        _;
    }

    // Constructor to set the UserManager contract address
    constructor(address userManagerAddress) {
        userManager = UserManager(userManagerAddress);
    }

    // Function to publish a new task
    function publishTask(
        string memory _dataType,
        string memory _location,
        uint256 _duration,
        uint256 _numberOfWorkers,
        uint256 _deposit,
        uint256 _similarityThreshold
    ) external onlyRegisteredRequester {
        Task memory newTask = Task({
            requester: msg.sender,
            dataType: _dataType,
            location: _location,
            duration: _duration,
            numberOfWorkers: _numberOfWorkers,
            status: Status.Active,
            deposit: _deposit,
            similarityThreshold: _similarityThreshold,
            startTime: block.timestamp
        });

        tasks.push(newTask);

        emit TaskPublished(new address, msg.sender, _dataType, _location, _deposit);
    }

    // Function to get task details
    function getTask(address _taskId) external view returns (
        address, string memory, string memory, uint256, uint256, Status, uint256, uint256, uint256
    ) {
        Task memory task = tasks[_taskId];
        return (
            task.requester,
            task.dataType,
            task.location,
            task.duration,
            task.numberOfWorkers,
            task.status,
            task.deposit,
            task.similarityThreshold,
            task.startTime
        );
    }
    // Function to get task Requester
    function getRequester(address _taskId) external view returns (address) {
        Task memory task = tasks[_taskId];
        return task.requester;
    }

     // Function to get task Status
    function getTaskStatus(address _taskId) external view returns (Status) {
        Task memory task = tasks[_taskId];
        return task.status;
    }

    // Function to update task status
    function updateTaskStatus(address _taskId) external {
        Task storage task = tasks[_taskId];
        require(task.requester == msg.sender, "Only requester can update task status");

        if (block.timestamp >= task.startTime + task.duration) {
            task.status = Status.Completed;
        } else {
            task.status = Status.Canceled;
        }
    }

    // Function to get the number of tasks
    function getNumberOfTasks() external view returns (uint256) {
        return tasks.length;
    }

    // Function to check and update task status automatically
    function checkAndUpdateTaskStatus(address _taskId) external {
        Task storage task = tasks[_taskId];
        
        if (task.status == Status.Active && block.timestamp >= task.startTime + task.duration) {
            task.status = Status.Completed;
        }
    }
}