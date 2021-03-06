/***************************************************************************************************
 *                                                                                                 *
 * (c) 2018, 2019 Quantstamp, Inc. This content and its use are governed by the license terms at   *
 * <https://s3.amazonaws.com/qsp-protocol-license/V2_LICENSE.txt>.                                 *
 *                                                                                                 *
 **************************************************************************************************/

pragma solidity 0.4.25;

// File: contracts/QuantstampAudit.sol
// For updating the protocol node to use the real QuantstampAudit contract,
// see notes in https://quantstamp.atlassian.net/browse/QSP-369.

contract QuantstampAudit {

  // mapping from an auditor address to the number of requests that it currently processes
  mapping(address => uint256) public assignedRequestCount;

  // if submit report is called, the mock sets this to true
  bool hasRewards = false;

  // state of audit requests submitted to the contract
  enum AuditState {
    None,
    Queued,
    Assigned,
    Refunded,
    Completed,  // automated audit finished successfully and the report is available
    Error       // automated audit failed to finish; the report contains detailed information about the error
  }

  // structure representing an audit
  struct Audit {
    address requestor;
    string contractUri;
    uint256 price;
    uint256 transactionFee;
    uint requestBlockNumber; // approximate time of when audit was requested
    AuditState state;
    address auditor;       // the address of the node assigned to the audit
    uint assignBlockNumber;  // approximate time of when audit was assigned
    string reportHash;     // stores the hash of audit report
    uint reportBlockNumber;  // approximate time of when the payment and the audit report were submitted
  }

  struct AuditData {
      uint256 auditTimeoutInBlocks;
      uint256 maxAssignedRequests;
  }

  event LogAuditFinished(
    uint256 requestId,
    address auditor,
    AuditState auditResult,
    string reportHash
  );

  event LogAuditRequested(uint256 requestId,
    address requestor,
    string uri,
    uint256 price
  );

  // TODO update the smart contract appropriately
  event LogAuditAssigned(uint256 requestId,
      address auditor,
      address requestor,
      string uri,
      uint256 price,
      uint256 requestBlockNumber);
  event LogReportSubmissionError_InvalidAuditor(uint256 requestId, address auditor);
  event LogReportSubmissionError_InvalidState(uint256 requestId, address auditor, AuditState state);
  event LogAuditQueueIsEmpty();

  event LogAuditAssignmentError_ExceededMaxAssignedRequests(address auditor);
  event LogAuditAssignmentError_Understaked(address auditor, uint256 stake);

  event LogPayAuditor(uint256 requestId, address auditor, uint256 amount);
  event LogTransactionFeeChanged(uint256 oldFee, uint256 newFee);
  event LogAuditNodePriceChanged(address auditor, uint256 amount);

  event LogRefund(uint256 requestId, address requestor, uint256 amount);
  event LogRefundInvalidRequestor(uint256 requestId, address requestor);
  event LogRefundInvalidState(uint256 requestId, AuditState state);
  event LogRefundInvalidFundsLocked(uint256 requestId, uint256 currentBlock, uint256 fundLockEndBlock);

  // the audit queue has elements, but none satisfy the minPrice of the audit node
  // amount corresponds to the current minPrice of the auditor
  event LogAuditNodePriceHigherThanRequests(address auditor, uint256 amount);

  constructor () public { }

  function emitLogAuditFinished(uint256 requestId, address auditor, AuditState auditResult, string reportHash) {
    emit LogAuditFinished(requestId, auditor, auditResult, reportHash);
  }

  function emitLogAuditRequested(uint256 requestId, address requestor, string uri, uint256 price) {
    emit LogAuditRequested(requestId, requestor, uri, price);
  }

  function emitLogAuditAssigned(uint256 requestId, address auditor, address requestor, string uri, uint256 price, uint256 requestBlockNumber) {
    emit LogAuditAssigned(requestId, auditor, requestor, uri, price, requestBlockNumber);
  }

  // The struct exists for the purposes of mocking function myMostRecentAssignedAudit
  struct AssignedAuditMock {
    uint256 requestId;
    address requestor;
    string contractUri;
    uint256 price;
    uint256 blockNumber;
  }

  // Mapping of the most recently assigned audits for function myMostRecentAssignedAudit
  mapping(address => AssignedAuditMock) public mostRecentAssignedRequestPerAuditor;

  // Emits that an audit was assigned and records the assignment. Deprecates emitLogAuditAssigned.
  function assignAuditAndEmit(uint256 requestId, address auditor, address requestor, string uri, uint256 price, uint256 requestBlockNumber) {
    emitLogAuditAssigned(requestId, auditor, requestor, uri, price, requestBlockNumber);
    mostRecentAssignedRequestPerAuditor[auditor] = AssignedAuditMock(
      requestId,
      requestor,
      uri,
      price,
      requestBlockNumber
    );
  }

  // Mocks the myMostRecentAssignedAudit function from the smart contract
  function myMostRecentAssignedAudit() public view returns(
    uint256, // requestId
    address, // requestor
    string,  // contract uri
    uint256, // price
    uint256  // request block number
  ) {
    return (
      mostRecentAssignedRequestPerAuditor[msg.sender].requestId,
      mostRecentAssignedRequestPerAuditor[msg.sender].requestor,
      mostRecentAssignedRequestPerAuditor[msg.sender].contractUri,
      mostRecentAssignedRequestPerAuditor[msg.sender].price,
      mostRecentAssignedRequestPerAuditor[msg.sender].blockNumber
    );
  }


  mapping(uint256 => bool) public finishedAudits;
  mapping(address => uint256) public staked;
  mapping(address => uint256) public maxAssigned;
  mapping(address => uint256) public minPrices;

  function isAuditFinished(uint256 requestId) public view returns(bool) {
    return finishedAudits[requestId];
  }

  function emitLogReportSubmissionError_InvalidAuditor(uint256 requestId, address auditor) {
    emit LogReportSubmissionError_InvalidAuditor(requestId, auditor);
  }

  function emitLogReportSubmissionError_InvalidState(uint256 requestId, address auditor, AuditState state) {
    emit LogReportSubmissionError_InvalidState(requestId, auditor, state);
  }

  function emitLogAuditQueueIsEmpty() {
    emit LogAuditQueueIsEmpty();
  }

  function emitLogAuditAssignmentError_ExceededMaxAssignedRequests(address auditor) {
    emit LogAuditAssignmentError_ExceededMaxAssignedRequests(auditor);
  }

  function emitLogPayAuditor(uint256 requestId, address auditor, uint256 amount) {
    emit LogPayAuditor(requestId, auditor, amount);
  }

  function emitLogTransactionFeeChanged(uint256 oldFee, uint256 newFee) {
    emit LogTransactionFeeChanged(oldFee, newFee);
  }

  function emitLogAuditNodePriceChanged(address auditor, uint256 amount) {
    emit LogAuditNodePriceChanged(auditor, amount);
  }

  function emitLogRefund(uint256 requestId, address requestor, uint256 amount) {
    emit LogRefund(requestId, requestor, amount);
  }

  function emitLogRefundInvalidRequestor(uint256 requestId, address requestor) {
    emit LogRefundInvalidRequestor(requestId, requestor);
  }

  function emitLogRefundInvalidState(uint256 requestId, AuditState state) {
    emit LogRefundInvalidState(requestId, state);
  }

  function emitLogRefundInvalidFundsLocked(uint256 requestId, uint256 currentBlock, uint256 fundLockEndBlock) {
    emit LogRefundInvalidFundsLocked(requestId, currentBlock, fundLockEndBlock);
  }

  function emitLogAuditNodePriceHigherThanRequests(address auditor, uint256 amount) {
    emit LogAuditNodePriceHigherThanRequests(auditor, amount);
  }

  event requestAudit_called();
  function requestAudit() {
    emit requestAudit_called();
  }

  event getNextPoliceAssignment_called();
  function getNextPoliceAssignment() public view returns (bool, uint256, uint256, string, uint256) {
    emit getNextPoliceAssignment_called();
    return (false, 0, 0, "", 0);
  }

  event getNextAuditRequest_called();
  function getNextAuditRequest() {
    emit getNextAuditRequest_called();
  }

  event submitReport_called(uint256 requestId, AuditState auditResult, bytes compressedReportBytes);
  function submitReport(uint256 requestId, AuditState auditResult, bytes compressedReportBytes){
    finishedAudits[requestId] = true;
    hasRewards = true;
    emit submitReport_called(requestId, auditResult, compressedReportBytes);
  }

  event submitPoliceReport_called(uint256 requestId, bytes report, bool isVerified);
  function submitPoliceReport(
    uint256 requestId,
    bytes report,
    bool isVerified) public returns (bool) {
      emit submitPoliceReport_called(requestId, report, isVerified);
  }

  function getAuditTimeoutInBlocks() public view returns(uint256) {
    return 25;
  }

  event setMinAuditPriceResult_called(address auditor, uint256 mocked_result);
  function setMinAuditPriceResult(address auditor, uint256 mocked_result) {
      minPrices[auditor] = mocked_result;
      emit setMinAuditPriceResult_called(auditor, mocked_result);
  }
  function getMinAuditPrice (address auditor) public view returns(uint256) {
    return minPrices[auditor];
  }

  uint256 minAuditStake_mocked_result = 0;

  event setMinAuditStake_called(uint256 mocked_result);
  function setMinAuditPriceResult(uint256 mocked_result) {
      minAuditStake_mocked_result = mocked_result;
      emit setMinAuditStake_called(mocked_result);
  }
  function getMinAuditStake() public view returns(uint256) {
    return minAuditStake_mocked_result;
  }

  function getMaxAssignedRequests() public view returns(uint256) {
    return 10;
  }

  uint256 anyRequestAvailable_mocked_result = 0;

  function anyRequestAvailable() public view returns(uint256) {
    return anyRequestAvailable_mocked_result;
  }

  event setAnyRequestAvailableResult_called(uint256 result);
  function setAnyRequestAvailableResult(uint256 _anyRequestAvailable_mocked_result) {
    anyRequestAvailable_mocked_result = _anyRequestAvailable_mocked_result;
    emit setAnyRequestAvailableResult_called(_anyRequestAvailable_mocked_result);
  }

  event setAssignedRequestCount_called(address auditor, uint256 num);
  function setAssignedRequestCount(address auditor, uint256 num) {
    assignedRequestCount[auditor] = num;
    emit setAssignedRequestCount_called(auditor, num);
  }

  event setAuditNodePrice_called(uint256 price);
  function setAuditNodePrice(uint256 price){
    emit setAuditNodePrice_called(price);
  }

  event setClaimRewards_called();
  function claimRewards() public {
    emit setClaimRewards_called();
    hasRewards = false;
  }

  event hasAvailableRewards_called();
  function hasAvailableRewards() public view returns(bool){
    emit hasAvailableRewards_called();
    return hasRewards;
  }

  event setTotalStakedForResult_called(address addr, uint256 mocked_result);
  function setTotalStakedForResult(address addr, uint256 mocked_result) {
    staked[addr] = mocked_result;
    emit setTotalStakedForResult_called(addr, mocked_result);
  }
  function totalStakedFor(address addr) public view returns(uint256) {
    return staked[addr];
  }

  function hasEnoughStake(address addr) public view returns(bool) {
    return true;
  }

  // By default, set nodes not to be police
  function isPoliceNode(address addr) public view returns(bool){
    return false;
  }

  event getReport_called(uint256 requestId);
  function getReport(uint256 requestId) public view returns (bytes) {
    emit getReport_called(requestId);
    return "";
  }

}
