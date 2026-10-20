class AuditLog {
  final String id;
  final String action; // CREATE_RECEIPT, REPRINT_RECEIPT, CANCEL_RECEIPT, DAY_END_FINALIZED, SYNC
  final String referenceNo; // e.g. MR-026458
  final String collectorId;
  final String collectorName;
  final String details;
  final DateTime timestamp;

  const AuditLog({
    required this.id,
    required this.action,
    required this.referenceNo,
    required this.collectorId,
    required this.collectorName,
    required this.details,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'action': action,
    'referenceNo': referenceNo,
    'collectorId': collectorId,
    'collectorName': collectorName,
    'details': details,
    'timestamp': timestamp.toIso8601String(),
  };

  factory AuditLog.fromJson(Map<String, dynamic> json) => AuditLog(
    id: json['id'] as String,
    action: json['action'] as String,
    referenceNo: json['referenceNo'] as String,
    collectorId: json['collectorId'] as String,
    collectorName: json['collectorName'] as String,
    details: json['details'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}
