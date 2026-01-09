// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ScontoIdentity {

    // =========================
    // ROLES
    // =========================
    address public superAdmin;

    constructor() {
        superAdmin = msg.sender;
    }

    modifier onlySuperAdmin() {
        require(msg.sender == superAdmin, "Not Super Admin");
        _;
    }

    modifier onlyInstitutionAdmin() {
        uint256 instId = adminToInstitution[msg.sender];
        require(instId != 0, "Not Institution Admin");
        require(institutions[instId].authorized, "Institution suspended");
        _;
    }

    // =========================
    // STRUCTS
    // =========================
    struct Institution {
        uint256 id;
        string name;
        address admin;
        bool authorized;
    }

    struct Department {
        uint256 id;
        string name;
        uint256 institutionId;
    }

    struct Batch {
        uint256 id;
        uint16 year;
        uint256 departmentId;
    }

    struct Student {
        bool exists;
        uint256 institutionId;
        uint256 departmentId;
        uint256 batchId;
        string name;
        string studentId;
        bytes32 photoHash;
    }

    // =========================
    // STORAGE
    // =========================
    uint256 public nextInstitutionId = 1;
    uint256 public nextDepartmentId = 1;
    uint256 public nextBatchId = 1;

    mapping(uint256 => Institution) public institutions;
    mapping(uint256 => Department) public departments;
    mapping(uint256 => Batch) public batches;

    mapping(uint256 => mapping(uint16 => uint256)) public batchByYear;
    mapping(address => Student) public students;

    // institutionAdmin → institutionId
    mapping(address => uint256) public adminToInstitution;

    // =========================
    // EVENTS
    // =========================
    event InstitutionCreated(uint256 id, string name, address admin);
    event InstitutionStatusChanged(uint256 id, bool authorized);
    event DepartmentCreated(uint256 id, uint256 institutionId);
    event BatchCreated(uint256 id, uint256 departmentId, uint16 year);
    event StudentRegistered(address wallet, uint256 batchId);

    // =========================
    // SUPER ADMIN FUNCTIONS
    // =========================
    function addInstitution(
        address institutionAdmin,
        string memory name
    ) external onlySuperAdmin {

        uint256 id = nextInstitutionId++;

        institutions[id] = Institution({
            id: id,
            name: name,
            admin: institutionAdmin,
            authorized: true
        });

        adminToInstitution[institutionAdmin] = id;

        emit InstitutionCreated(id, name, institutionAdmin);
    }

    function setInstitutionStatus(
        uint256 institutionId,
        bool authorized
    ) external onlySuperAdmin {
        institutions[institutionId].authorized = authorized;
        emit InstitutionStatusChanged(institutionId, authorized);
    }

    // =========================
    // INSTITUTION ADMIN FUNCTIONS
    // =========================
    function addDepartment(string memory name)
        external
        onlyInstitutionAdmin
    {
        uint256 instId = adminToInstitution[msg.sender];
        uint256 id = nextDepartmentId++;

        departments[id] = Department({
            id: id,
            name: name,
            institutionId: instId
        });

        emit DepartmentCreated(id, instId);
    }

    function addBatchByYear(
        uint256 departmentId,
        uint16 year
    ) external onlyInstitutionAdmin {

        uint256 instId = adminToInstitution[msg.sender];
        require(
            departments[departmentId].institutionId == instId,
            "Department not in institution"
        );

        require(
            batchByYear[departmentId][year] == 0,
            "Batch already exists"
        );

        uint256 id = nextBatchId++;
        batches[id] = Batch(id, year, departmentId);
        batchByYear[departmentId][year] = id;

        emit BatchCreated(id, departmentId, year);
    }

    function addStudent(
        address wallet,
        uint256 departmentId,
        uint16 year,
        string memory name,
        string memory studentId,
        bytes32 photoHash
    ) external onlyInstitutionAdmin {

        uint256 instId = adminToInstitution[msg.sender];
        require(
            departments[departmentId].institutionId == instId,
            "Invalid department"
        );

        uint256 batchId = batchByYear[departmentId][year];
        require(batchId != 0, "Batch not created");

        students[wallet] = Student({
            exists: true,
            institutionId: instId,
            departmentId: departmentId,
            batchId: batchId,
            name: name,
            studentId: studentId,
            photoHash: photoHash
        });

        emit StudentRegistered(wallet, batchId);
    }

    // =========================
    // READ FUNCTIONS
    // =========================
    function studentExists(address wallet)
        external
        view
        returns (bool)
    {
        return students[wallet].exists;
    }
}
