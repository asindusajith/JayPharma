class ChequeSummaryItem {
  final String chequeNumber;
  final String bank;
  final String customerCode;
  final String customerName;
  final double amount;
  final DateTime chequeDate;

  const ChequeSummaryItem({
    required this.chequeNumber,
    required this.bank,
    required this.customerCode,
    required this.customerName,
    required this.amount,
    required this.chequeDate,
  });

  Map<String, dynamic> toJson() => {
    'chequeNumber': chequeNumber,
    'bank': bank,
    'customerCode': customerCode,
    'customerName': customerName,
    'amount': amount,
    'chequeDate': chequeDate.toIso8601String(),
  };

  factory ChequeSummaryItem.fromJson(Map<String, dynamic> json) => ChequeSummaryItem(
    chequeNumber: json['chequeNumber'] as String,
    bank: json['bank'] as String,
    customerCode: json['customerCode'] as String,
    customerName: json['customerName'] as String,
    amount: (json['amount'] as num).toDouble(),
    chequeDate: DateTime.parse(json['chequeDate'] as String),
  );
}

class DayEndSummary {
  final DateTime date;
  final String collectorId;
  final String collectorName;
  final double totalCash;
  final double totalCheque;
  final List<ChequeSummaryItem> chequesList;
  final double totalIncome;
  final int totalReceiptsCount;
  final bool isFinalized;
  final DateTime? finalizedAt;
  final String? cashierNotes;

  const DayEndSummary({
    required this.date,
    required this.collectorId,
    required this.collectorName,
    required this.totalCash,
    required this.totalCheque,
    required this.chequesList,
    required this.totalIncome,
    required this.totalReceiptsCount,
    this.isFinalized = false,
    this.finalizedAt,
    this.cashierNotes,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'collectorId': collectorId,
    'collectorName': collectorName,
    'totalCash': totalCash,
    'totalCheque': totalCheque,
    'chequesList': chequesList.map((e) => e.toJson()).toList(),
    'totalIncome': totalIncome,
    'totalReceiptsCount': totalReceiptsCount,
    'isFinalized': isFinalized,
    'finalizedAt': finalizedAt?.toIso8601String(),
    'cashierNotes': cashierNotes,
  };

  factory DayEndSummary.fromJson(Map<String, dynamic> json) => DayEndSummary(
    date: DateTime.parse(json['date'] as String),
    collectorId: json['collectorId'] as String,
    collectorName: json['collectorName'] as String,
    totalCash: (json['totalCash'] as num).toDouble(),
    totalCheque: (json['totalCheque'] as num).toDouble(),
    chequesList: (json['chequesList'] as List)
        .map((e) => ChequeSummaryItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    totalIncome: (json['totalIncome'] as num).toDouble(),
    totalReceiptsCount: json['totalReceiptsCount'] as int,
    isFinalized: json['isFinalized'] as bool? ?? false,
    finalizedAt: json['finalizedAt'] != null ? DateTime.parse(json['finalizedAt'] as String) : null,
    cashierNotes: json['cashierNotes'] as String?,
  );
}
