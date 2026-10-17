/// Why the agent cancels a request (Figma REQ-10). The wire value is a
/// placeholder contract (docs/BACKEND_MIGRATION_GAPS.md, section 21).
enum CancelReason {
  customerCancelled('CUSTOMER_CANCELLED'),
  dataError('DATA_ERROR'),
  delayed('DELAYED'),
  other('OTHER');

  const CancelReason(this.wire);

  final String wire;
}
