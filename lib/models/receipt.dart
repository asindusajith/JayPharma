enum PaymentMethod { cash, cheque }
enum SyncStatus { synced, pendingSync }
enum ReceiptCopyMode { all, customerOnly, accountsOnly }

class ReceiptInvoiceItem {
  final int itemIndex;
  final String invoiceNo;
  final DateTime invoiceDate;
  final double invoiceAmount;
  final double amountSettled;
  final double remainingBalance;

  const ReceiptInvoiceItem({
    required this.itemIndex,
    required this.invoiceNo,
    required this.invoiceDate,
    required this.invoiceAmount,
    required this.amountSettled,
    required this.remainingBalance,
  });

  Map<String, dynamic> toJson() => {
    'itemIndex': itemIndex,
    'invoiceNo': invoiceNo,
    'invoiceDate': invoiceDate.toIso8601String(),
    'invoiceAmount': invoiceAmount,
    'amountSettled': amountSettled,
    'remainingBalance': remainingBalance,
  };

  factory ReceiptInvoiceItem.fromJson(Map<String, dynamic> json) => ReceiptInvoiceItem(
    itemIndex: json['itemIndex'] as int,
    invoiceNo: json['invoiceNo'] as String,
    invoiceDate: DateTime.parse(json['invoiceDate'] as String),
    invoiceAmount: (json['invoiceAmount'] as num).toDouble(),
    amountSettled: (json['amountSettled'] as num).toDouble(),
    remainingBalance: (json['remainingBalance'] as num).toDouble(),
  );
}

class ReprintRecord {
  final DateTime timestamp;
  final String collectorId;
  final String otpUsed;
  final String reason;

  const ReprintRecord({
    required this.timestamp,
    required this.collectorId,
    required this.otpUsed,
    required this.reason,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'collectorId': collectorId,
    'otpUsed': otpUsed,
    'reason': reason,
  };

  factory ReprintRecord.fromJson(Map<String, dynamic> json) => ReprintRecord(
    timestamp: DateTime.parse(json['timestamp'] as String),
    collectorId: json['collectorId'] as String,
    otpUsed: json['otpUsed'] as String,
    reason: json['reason'] as String,
  );
}

class Receipt {
  final String manualReceiptNo; // E.g. MR-026458
  final String customerCode;    // E.g. C1001
  final String customerName;    // E.g. City Pharmacy
  final String customerAddress; // E.g. 123 Galle Road, Colombo 07
  final String customerPhone;
  final PaymentMethod paymentMethod;
  final String? bank;
  final String? branch;
  final String? chequeNumber;
  final DateTime? chequeDate;
  final double totalAmount;
  final List<ReceiptInvoiceItem> allocatedInvoices;
  final String comments;
  final bool isAdvancePayment;
  final String collectorId;
  final String collectorName;
  final double latitude;
  final double longitude;
  final String locationAddress;
  final DateTime createdAt;
  bool isCancelled;
  int reprintCount;
  List<ReprintRecord> reprintHistory;
  SyncStatus syncStatus;

  Receipt({
    required this.manualReceiptNo,
    required this.customerCode,
    required this.customerName,
    required this.customerAddress,
    required this.customerPhone,
    required this.paymentMethod,
    this.bank,
    this.branch,
    this.chequeNumber,
    this.chequeDate,
    required this.totalAmount,
    required this.allocatedInvoices,
    this.comments = '',
    this.isAdvancePayment = false,
    required this.collectorId,
    required this.collectorName,
    required this.latitude,
    required this.longitude,
    required this.locationAddress,
    required this.createdAt,
    this.isCancelled = false,
    this.reprintCount = 0,
    List<ReprintRecord>? reprintHistory,
    this.syncStatus = SyncStatus.synced,
  }) : reprintHistory = reprintHistory ?? [];

  String get paymentMethodDisplay => paymentMethod == PaymentMethod.cash ? 'Cash' : 'Cheque';

  String get invoiceNumbersDisplay {
    if (allocatedInvoices.isEmpty) return 'Advance Payment';
    return allocatedInvoices.map((e) => e.invoiceNo).join(', ');
  }

  Map<String, dynamic> toJson() => {
    'manualReceiptNo': manualReceiptNo,
    'customerCode': customerCode,
    'customerName': customerName,
    'customerAddress': customerAddress,
    'customerPhone': customerPhone,
    'paymentMethod': paymentMethod.name,
    'bank': bank,
    'branch': branch,
    'chequeNumber': chequeNumber,
    'chequeDate': chequeDate?.toIso8601String(),
    'totalAmount': totalAmount,
    'allocatedInvoices': allocatedInvoices.map((e) => e.toJson()).toList(),
    'comments': comments,
    'isAdvancePayment': isAdvancePayment,
    'collectorId': collectorId,
    'collectorName': collectorName,
    'latitude': latitude,
    'longitude': longitude,
    'locationAddress': locationAddress,
    'createdAt': createdAt.toIso8601String(),
    'isCancelled': isCancelled,
    'reprintCount': reprintCount,
    'reprintHistory': reprintHistory.map((e) => e.toJson()).toList(),
    'syncStatus': syncStatus.name,
  };

  factory Receipt.fromJson(Map<String, dynamic> json) {
    final methodStr = (json['paymentMethod'] ?? 'cash').toString().toLowerCase();
    final method = methodStr.contains('cheque') ? PaymentMethod.cheque : PaymentMethod.cash;

    final syncStr = (json['syncStatus'] ?? 'synced').toString().toLowerCase();
    final sync = syncStr.contains('pending') ? SyncStatus.pendingSync : SyncStatus.synced;

    return Receipt(
      manualReceiptNo: json['manualReceiptNo'] as String? ?? '',
      customerCode: json['customerCode'] as String? ?? '',
      customerName: json['customerName'] as String? ?? '',
      customerAddress: json['customerAddress'] as String? ?? '',
      customerPhone: json['customerPhone'] as String? ?? '',
      paymentMethod: method,
      bank: json['bank'] as String?,
      branch: json['branch'] as String?,
      chequeNumber: json['chequeNumber'] as String?,
      chequeDate: json['chequeDate'] != null ? DateTime.tryParse(json['chequeDate'].toString()) : null,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      allocatedInvoices: (json['allocatedInvoices'] as List?)
              ?.map((e) => ReceiptInvoiceItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      comments: json['comments'] as String? ?? '',
      isAdvancePayment: json['isAdvancePayment'] as bool? ?? false,
      collectorId: json['collectorId'] as String? ?? '',
      collectorName: json['collectorName'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      locationAddress: json['locationAddress'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      isCancelled: json['isCancelled'] as bool? ?? false,
      reprintCount: json['reprintCount'] as int? ?? 0,
      reprintHistory: (json['reprintHistory'] as List?)
              ?.map((e) => ReprintRecord.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      syncStatus: sync,
    );
  }
}
