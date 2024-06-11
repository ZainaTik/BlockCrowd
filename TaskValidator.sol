// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.4.22 <0.9.0;

import "./UserManager.sol";
import "./TaskManager.sol";

contract TaskValidator {
    struct Reservation {
        address worker;
        bool reserved;
        bool dataSubmitted;
        string ipfsHash;
        uint256 availability;
        uint256[] data;
    }

    struct TaskDetails {
        address taskId;
        address requester;
        uint256 deposit;
        uint256 numWorkers;
        uint256 similarityThreshold;
        uint256 startTime;
        uint256 duration;
        address[] selectedWorkers;
        mapping(address => Reservation) reservations;
    }

    UserManager private userManager;
    TaskManager private taskManager;
    mapping(address => TaskDetails) public tasks;

    // Events
    event ReservationAdded(address indexed taskAddress, address indexed worker);
    event DataUploaded(address indexed taskAddress, address indexed worker, string ipfsHash);
    event TaskValidated(address indexed taskAddress);
    event UpdateRep(address indexed taskAddress);

    // Constructor to set the UserManager and TaskManager contract addresses
    constructor(address userManagerAddress, address taskManagerAddress) {
        userManager = UserManager(userManagerAddress);
        taskManager = TaskManager(taskManagerAddress);
    }

    // Function to add reservation for a worker
    function addReservation(address _taskAddress, uint256 _availability) external {
        TaskDetails storage task = tasks[_taskAddress];
        require(task.taskId != address(0), "Task does not exist");

        // Ensure the task status is Active
        require(taskManager.getTaskStatus(task.taskId) == TaskManager.Status.Active, "Task is not active");

        // Ensure the worker's availability is within the task duration
        uint256 currentTime = block.timestamp;
        require(currentTime >= task.startTime && currentTime <= task.startTime + task.duration, "Task is outside duration");

        // Ensure a single slot per worker
        require(!task.reservations[msg.sender].reserved, "Worker already reserved");
        uint256[] memory _data;
        // Add the reservation
        task.reservations[msg.sender] = Reservation({
            worker: msg.sender,
            reserved: true,
            dataSubmitted: false,
            ipfsHash: "",
            availability: _availability,
            data: _data
        });

        emit ReservationAdded(_taskAddress, msg.sender);
    }

     // Function to select workers based on reliability metrics
    function workerSelection(address _taskAddress) external {
        TaskDetails storage task = tasks[_taskAddress];
        require(task.taskId != address(0), "Task does not exist");
        require(task.requester == msg.sender, "Only requester can select workers");

        // Calculate reliability for each worker and select the top ones
        address[] memory potentialWorkers = new address[](task.numWorkers);
        uint256[] memory reliabilityScores = new uint256[](task.numWorkers);
        uint256 workerCount = 0;

        for (uint256 i = 0; i < task.selectedWorkers.length; i++) {
            address worker = task.selectedWorkers[i];
            if (task.reservations[worker].reserved) {
                uint256 availability = task.reservations[worker].availability;
                //int256 workerX = task.reservations[worker].x;
                //int256 workerY = task.reservations[worker].y;

                // Calculate the Euclidean distance
                //uint256 distance = uint256(sqrt(int256((workerX - task.taskX) ** 2 + (workerY - task.taskY) ** 2)));

                // Calculate the reliability score
                uint256 reliability = (4 * userManager.getUserReputation(worker) + 3 * availability)/10;

                // Insert the worker into the sorted list of potential workers
                if (workerCount < task.numWorkers) {
                    potentialWorkers[workerCount] = worker;
                    reliabilityScores[workerCount] = reliability;
                    workerCount++;
                } else {
                    // Find the worker with the lowest reliability score
                    uint256 minIndex = 0;
                    for (uint256 j = 1; j < task.numWorkers; j++) {
                        if (reliabilityScores[j] < reliabilityScores[minIndex]) {
                            minIndex = j;
                        }
                    }

                    // If the new worker has a higher reliability score, replace the lowest one
                    if (reliability > reliabilityScores[minIndex]) {
                        potentialWorkers[minIndex] = worker;
                        reliabilityScores[minIndex] = reliability;
                    }
                }
            }
        }

        task.selectedWorkers = potentialWorkers;
    }

    // Function to upload data to IPFS
    function uploadData(address _taskAddress, uint256[] memory _data) external {
        TaskDetails storage task = tasks[_taskAddress];
        require(task.taskId != address(0), "Task does not exist");
        require(task.reservations[msg.sender].reserved, "Worker did not reserve task");
        require(!task.reservations[msg.sender].dataSubmitted, "Data already submitted");

        // Normalize data
        uint256[] memory normalizedData = normalizeData(_data);

        // Store normalized data
        task.reservations[msg.sender].data = normalizedData;
        task.reservations[msg.sender].dataSubmitted = true;

        emit DataUploaded(_taskAddress, msg.sender, ""); // IPFS hash not used in this example
    }

    // Function to normalize data
    function normalizeData(uint256[] memory _data) internal view returns (uint256[] memory) {
        uint256[] memory normalizedData = new uint256[](_data.length);
        uint256 minValue = _data[0];
        uint256 maxValue = _data[0];

        // Find min and max values
        for (uint256 i = 1; i < _data.length; i++) {
            if (_data[i] < minValue) {
                minValue = _data[i];
            }
            if (_data[i] > maxValue) {
                maxValue = _data[i];
            }
        }

        // Normalize data
        for (uint256 i = 0; i < _data.length; i++) {
            normalizedData[i] = ((_data[i] - minValue) * 100) / (maxValue - minValue);
        }

        return normalizedData;
    }

    // Function to validate data and determine payments
    function dataValidation(address _taskAddress) external {
        TaskDetails storage task = tasks[_taskAddress];
        require(task.taskId != address(0), "Task does not exist");
        require(task.requester == msg.sender, "Only requester can validate data");

        // Validate data quality based on similarity
        for (uint256 i = 0; i < task.selectedWorkers.length; i++) {
            address worker1 = task.selectedWorkers[i];
            if (task.reservations[worker1].dataSubmitted) {
                for (uint256 j = i + 1; j < task.selectedWorkers.length; j++) {
                    address worker2 = task.selectedWorkers[j];
                    if (task.reservations[worker2].dataSubmitted) {
                        uint256 similarity = cosineSimilarity(task.reservations[worker1].data, task.reservations[worker2].data);
                        require(similarity >= task.similarityThreshold, "Data quality not met");
                    }
                }
            }
        }

        // Update worker reputation and make payments
        for (uint256 i = 0; i < task.selectedWorkers.length; i++) {
            address worker = task.selectedWorkers[i];
            if (task.reservations[worker].dataSubmitted) {
               // userManager.adjustReputation(worker, 50); // Increase reputation
               // payable(worker).transfer(task.deposit / task.numWorkers); // Payment
            }
        }

        emit TaskValidated(_taskAddress);
    }

    // Function to calculate cosine similarity
    function cosineSimilarity(uint256[] memory _data1, uint256[] memory _data2) internal pure returns (uint256) {
        require(_data1.length == _data2.length, "Data length mismatch");

        uint256 dotProduct = 0;
        uint256 normA = 0;
        uint256 normB = 0;

        for (uint256 i = 0; i < _data1.length; i++) {
            dotProduct += _data1[i] * _data2[i];
            normA += _data1[i] * _data1[i];
            normB += _data2[i] * _data2[i];
        }

        if (normA == 0 || normB == 0) {
            return 0; // Avoid division by zero
        }

        // Convert one of the operands to uint256 to avoid integer division
        return uint256((dotProduct * 100) / (uint256(sqrt(normA)) * uint256(sqrt(normB))));
    }

    // Helper function to calculate the square root
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    // Function to update reputation of workers and requester
    function updateReputation(address _taskAddress) external {
        TaskDetails storage task = tasks[_taskAddress];
        // Calculate worker's reputation
        for (uint256 i = 0; i < task.selectedWorkers.length; i++) {
            address worker = task.selectedWorkers[i];
            uint256 reputation = calculateWorkerReputation(worker);
            userManager.updateReputation(worker, reputation);
        }

        // Calculate requester's reputation
        address requester = taskManager.getRequester(_taskAddress);
        uint256 requesterReputation = calculateRequesterReputation(requester);
        userManager.updateReputation(requester, requesterReputation);

        emit UpdateRep(_taskAddress);
    }

    // Function to calculate worker's reputation
    function calculateWorkerReputation(address _worker) internal view returns (uint256) {
        uint256 completedTasks = userManager.getCompletedTasks(_worker);
        uint256 totalTasks = userManager.getTotalTasks(_worker);
        uint256 integrity = (completedTasks * 100) / totalTasks; // Integrity
        uint256 frequency = (totalTasks * 100) / (block.timestamp - 1000); // Frequency

        // Calculate worker's reputation using Eq. (8)
        return (6 * userManager.getUserReputation(_worker) + 2 * integrity + 2 * frequency);
    }

    // Function to calculate requester's reputation
    function calculateRequesterReputation(address _requester) internal view returns (uint256) {
        uint256 totalTasks = userManager.getTotalTasks(_requester);
        uint256 canceledTasks = totalTasks - userManager.getCompletedTasks(_requester);

        if (totalTasks == 0) {
            return 0; // Avoid division by zero
        }

        // Calculate requester's reputation using Eq. (9)
        return (100 - (canceledTasks * 100) / totalTasks);
    }

}
