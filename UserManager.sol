// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract UserManager {
    enum UserType { Requester, Worker }

    struct User {
        address blockchainAddress;
        UserType userType;
        uint256 reputation; // Using a scaled integer for reputation, e.g., 0 to 1000
        uint256 totalTasks;
        uint256 completedTasks;
    }

    mapping(address => User) public users;

    //definition of Pools
    address[] public requesterPool;
    address[] public workerPool;

    // Event to log user registration
    event UserRegistered(address indexed blockchainAddress, UserType userType);

    // Function to register a new user
    function addUser(UserType _userType) public {
         //Verification
        require(_userType != UserType.Worker || !isAddressInArray(msg.sender, workerPool), "Worker already registered");
        require(_userType != UserType.Requester || !isAddressInArray(msg.sender, requesterPool), "Requester already registered");

        // Initialize reputation to 500 (scaled as 0.5)
        users[msg.sender] = User({
            blockchainAddress: msg.sender,
            userType: _userType,
            reputation: 5,
            totalTasks: 0,
            completedTasks:0
        });
        //Add the user's address to the appropriate pool
        if (_userType == UserType.Requester) { // if Requester
            requesterPool.push(msg.sender);
        } else if (_userType == UserType.Worker) { // if Worker
            workerPool.push(msg.sender);
        }
        emit UserRegistered(msg.sender, _userType);
    }

    // Function to get user information
    function getUser(address _userAddress) public view returns (address, UserType, uint256) {
        User memory user = users[_userAddress];
        require(user.blockchainAddress != address(0), "User not registered");
        return (user.blockchainAddress, user.userType, user.reputation);
    }

        // Function to check if an address exists in a pool
    function isAddressInArray(address _address, address[] storage _array) internal view returns (bool) {
        for (uint256 i = 0; i < _array.length; i++) {
            if (_array[i] == _address) {
                return true;
            }
        }
        return false;
    }

    // Function to update reputation of a user
    function updateReputation(address _userAddress, uint256 _newReputation) external {
        User memory user = users[_userAddress];
        user.reputation = _newReputation;
    }

    // Function to get user reputation
    function getUserReputation(address _userAddress) public view returns (uint256) {
        User memory user = users[_userAddress];
        require(user.blockchainAddress != address(0), "User not registered");
        return user.reputation;
    }
    // Function to get user Completed tasks
    function getCompletedTasks(address _userAddress) public view returns (uint256) {
        User memory user = users[_userAddress];
        require(user.blockchainAddress != address(0), "User not registered");
        return user.completedTasks;
    }
    
    // Function to get user Completed tasks
    function getTotalTasks(address _userAddress) public view returns (uint256) {
        User memory user = users[_userAddress];
        require(user.blockchainAddress != address(0), "User not registered");
        return user.totalTasks;
    }
}
