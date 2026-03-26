// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title RentalAgreement
 * @notice On-chain rental agreements between registered landlords and tenants.
 * @dev ETH is held in this contract for deposits until released. Rent is forwarded to the landlord on payment.
 *      Includes a minimal `ReentrancyGuard` for external ETH calls (no external package required).
 */

/* --- Minimal ReentrancyGuard (no external deps) --- */
abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract RentalAgreement is ReentrancyGuard {
    /* ============ Types ============ */

    /**
     * @notice Core agreement record stored on-chain.
     * @param agreementId Unique identifier (also the mapping key).
     * @param landlord Party offering the property.
     * @param tenant Party renting; set at creation time.
     * @param rentAmount Per-payment rent in wei.
     * @param depositAmount Security deposit in wei.
     * @param startDate Unix timestamp when the term begins.
     * @param endDate Unix timestamp when the term ends.
     * @param isSigned Tenant has accepted the terms.
     * @param isActive Agreement not terminated and still valid for actions.
     * @param depositPaid Tenant paid the full deposit into this contract.
     * @param depositReleased Deposit has been withdrawn (landlord or tenant refund path).
     * @param terminatedEarly True if landlord called terminate before endDate (enables tenant deposit refund).
     */
    struct Agreement {
        uint256 agreementId;
        address landlord;
        address tenant;
        uint256 rentAmount;
        uint256 depositAmount;
        uint256 startDate;
        uint256 endDate;
        bool isSigned;
        bool isActive;
        bool depositPaid;
        bool depositReleased;
        bool terminatedEarly;
    }

    /* ============ State ============ */

    uint256 private _nextAgreementId;

    mapping(uint256 => Agreement) public agreements;
    mapping(address => bool) public isLandlord;
    mapping(address => bool) public isTenant;

    mapping(address => uint256[]) private _landlordAgreementIds;
    mapping(address => uint256[]) private _tenantAgreementIds;

    /* ============ Events ============ */

    event AgreementCreated(
        uint256 indexed agreementId,
        address indexed landlord,
        address indexed tenant,
        uint256 rentAmount,
        uint256 depositAmount,
        uint256 startDate,
        uint256 endDate
    );

    event AgreementSigned(uint256 indexed agreementId, address indexed tenant);
    event DepositPaid(uint256 indexed agreementId, address indexed tenant, uint256 amount);
    event RentPaid(uint256 indexed agreementId, address indexed tenant, address indexed landlord, uint256 amount);
    event AgreementTerminated(uint256 indexed agreementId, address indexed landlord);
    event DepositWithdrawn(uint256 indexed agreementId, address indexed recipient, uint256 amount);

    /* ============ Modifiers ============ */

    modifier agreementExists(uint256 agreementId) {
        require(agreementId < _nextAgreementId, "Rental: agreement does not exist");
        _;
    }

    /**
     * @notice Caller must be the landlord recorded on this agreement.
     */
    modifier onlyLandlord(uint256 agreementId) {
        require(agreements[agreementId].landlord == msg.sender, "Rental: not agreement landlord");
        _;
    }

    /**
     * @notice Caller must be the tenant recorded on this agreement.
     */
    modifier onlyTenant(uint256 agreementId) {
        require(agreements[agreementId].tenant == msg.sender, "Rental: not agreement tenant");
        _;
    }

    /* ============ Registration ============ */

    /**
     * @notice Register `msg.sender` as a landlord. One role per address.
     */
    function registerLandlord() external {
        require(!isLandlord[msg.sender], "Rental: already landlord");
        require(!isTenant[msg.sender], "Rental: already tenant");
        isLandlord[msg.sender] = true;
    }

    /**
     * @notice Register `msg.sender` as a tenant. One role per address.
     */
    function registerTenant() external {
        require(!isTenant[msg.sender], "Rental: already tenant");
        require(!isLandlord[msg.sender], "Rental: already landlord");
        isTenant[msg.sender] = true;
    }

    /* ============ Agreement lifecycle ============ */

    /**
     * @notice Create a new agreement. Caller must be a registered landlord.
     * @param tenant Address of the tenant (should match a registered tenant in your DApp flow).
     * @param rentAmount Wei sent per rent payment (exact value expected in `payRent`).
     * @param depositAmount Wei expected in `payDeposit`.
     * @param duration Seconds added to `block.timestamp` for `endDate`; `startDate` is `block.timestamp`.
     */
    function createAgreement(
        address tenant,
        uint256 rentAmount,
        uint256 depositAmount,
        uint256 duration
    ) external returns (uint256 agreementId) {
        require(isLandlord[msg.sender], "Rental: not registered landlord");
        require(tenant != address(0), "Rental: invalid tenant");
        require(tenant != msg.sender, "Rental: landlord cannot be tenant");
        require(isTenant[tenant], "Rental: tenant not registered");
        require(rentAmount > 0, "Rental: invalid rent");
        require(depositAmount > 0, "Rental: invalid deposit");
        require(duration > 0, "Rental: invalid duration");

        agreementId = _nextAgreementId++;
        uint256 start = block.timestamp;
        uint256 end = start + duration;

        agreements[agreementId] = Agreement({
            agreementId: agreementId,
            landlord: msg.sender,
            tenant: tenant,
            rentAmount: rentAmount,
            depositAmount: depositAmount,
            startDate: start,
            endDate: end,
            isSigned: false,
            isActive: true,
            depositPaid: false,
            depositReleased: false,
            terminatedEarly: false
        });

        _landlordAgreementIds[msg.sender].push(agreementId);
        _tenantAgreementIds[tenant].push(agreementId);

        emit AgreementCreated(agreementId, msg.sender, tenant, rentAmount, depositAmount, start, end);
    }

    /**
     * @notice Tenant accepts the agreement. Required before paying deposit.
     */
    function signAgreement(uint256 agreementId) external agreementExists(agreementId) onlyTenant(agreementId) {
        Agreement storage a = agreements[agreementId];
        require(a.isActive, "Rental: not active");
        require(!a.isSigned, "Rental: already signed");

        a.isSigned = true;
        emit AgreementSigned(agreementId, msg.sender);
    }

    /**
     * @notice Tenant pays the security deposit; ETH must match `depositAmount` exactly.
     */
    function payDeposit(uint256 agreementId)
        external
        payable
        agreementExists(agreementId)
        onlyTenant(agreementId)
        nonReentrant
    {
        Agreement storage a = agreements[agreementId];
        require(a.isActive, "Rental: not active");
        require(a.isSigned, "Rental: not signed");
        require(!a.depositPaid, "Rental: deposit already paid");
        require(msg.value == a.depositAmount, "Rental: wrong deposit amount");

        a.depositPaid = true;
        emit DepositPaid(agreementId, msg.sender, msg.value);
    }

    /**
     * @notice Tenant pays one period of rent; forwarded to landlord immediately.
     */
    function payRent(uint256 agreementId)
        external
        payable
        agreementExists(agreementId)
        onlyTenant(agreementId)
        nonReentrant
    {
        Agreement storage a = agreements[agreementId];
        require(a.isActive, "Rental: not active");
        require(a.isSigned, "Rental: not signed");
        require(block.timestamp >= a.startDate, "Rental: term not started");
        require(block.timestamp < a.endDate, "Rental: term ended");
        require(msg.value == a.rentAmount, "Rental: wrong rent amount");

        (bool ok, ) = payable(a.landlord).call{value: msg.value}("");
        require(ok, "Rental: rent transfer failed");

        emit RentPaid(agreementId, msg.sender, a.landlord, msg.value);
    }

    /**
     * @notice Release held deposit after term ends (landlord) or after early termination (tenant refund).
     * @dev If `block.timestamp >= endDate` and agreement was not early-terminated by landlord, landlord receives deposit.
     *      If landlord called `terminateAgreement` before `endDate`, tenant can reclaim the deposit.
     */
    function withdrawDeposit(uint256 agreementId)
        external
        agreementExists(agreementId)
        nonReentrant
    {
        Agreement storage a = agreements[agreementId];
        require(a.depositPaid, "Rental: no deposit");
        require(!a.depositReleased, "Rental: deposit already released");

        address recipient;
        if (a.terminatedEarly) {
            require(msg.sender == a.tenant, "Rental: only tenant after early termination");
            recipient = a.tenant;
        } else {
            require(block.timestamp >= a.endDate, "Rental: term not ended");
            require(msg.sender == a.landlord, "Rental: only landlord after natural end");
            recipient = a.landlord;
        }

        a.depositReleased = true;
        uint256 amount = a.depositAmount;

        (bool ok, ) = payable(recipient).call{value: amount}("");
        require(ok, "Rental: deposit transfer failed");

        emit DepositWithdrawn(agreementId, recipient, amount);
    }

    /**
     * @notice Landlord ends the agreement. If before `endDate`, deposit is refundable to the tenant; otherwise release rules follow `withdrawDeposit` (landlord after term).
     */
    function terminateAgreement(uint256 agreementId)
        external
        agreementExists(agreementId)
        onlyLandlord(agreementId)
    {
        Agreement storage a = agreements[agreementId];
        require(a.isActive, "Rental: not active");

        a.isActive = false;
        if (block.timestamp < a.endDate) {
            a.terminatedEarly = true;
        }

        emit AgreementTerminated(agreementId, msg.sender);
    }

    /* ============ Views ============ */

    /**
     * @notice Full agreement struct for a given id.
     */
    function getAgreement(uint256 agreementId) external view agreementExists(agreementId) returns (Agreement memory) {
        return agreements[agreementId];
    }

    /**
     * @notice All agreement IDs created where `landlord` is the landlord.
     */
    function getAgreementsByLandlord(address landlord) external view returns (uint256[] memory) {
        return _landlordAgreementIds[landlord];
    }

    /**
     * @notice All agreement IDs where `tenant` is the tenant.
     */
    function getAgreementsByTenant(address tenant) external view returns (uint256[] memory) {
        return _tenantAgreementIds[tenant];
    }

    /**
     * @notice Next id to be assigned (total agreements = nextId).
     */
    function nextAgreementId() external view returns (uint256) {
        return _nextAgreementId;
    }

    /**
     * @notice ETH balance held for an agreement's deposit (0 if already released or never paid).
     */
    function getHeldDeposit(uint256 agreementId) external view agreementExists(agreementId) returns (uint256) {
        Agreement storage a = agreements[agreementId];
        if (!a.depositPaid || a.depositReleased) return 0;
        return a.depositAmount;
    }
}
