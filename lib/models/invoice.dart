class Invoice {
  final String invoiceNo;
  final String customerCode;
  final DateTime invoiceDate;
  final DateTime deliveryDate;
  final double totalAmount;
  final double setAmt;
  double outstandingBalance;
  double allocatedAmount;
  bool isSelected;
  final String status;

  Invoice({
    required this.invoiceNo,
    required this.customerCode,
    required this.invoiceDate,
    required this.deliveryDate,
    required this.totalAmount,
    this.setAmt = 0.0,
    required this.outstandingBalance,
    this.allocatedAmount = 0.0,
    this.isSelected = false,
    this.status = 'Pending',
  });

  // Delivery Age in days calculated from delivery date to current date
  int get deliveryAgeDays {
    final now = DateTime.now();
    final diff = now.difference(deliveryDate).inDays;
    return diff >= 0 ? diff : 0;
  }

  // Remaining balance after current allocation
  double get remainingBalanceAfterAllocation {
    final rem = outstandingBalance - allocatedAmount;
    return rem >= 0 ? rem : 0.0;
  }

  Invoice copyWith({
    String? invoiceNo,
    String? customerCode,
    DateTime? invoiceDate,
    DateTime? deliveryDate,
    double? totalAmount,
    double? setAmt,
    double? outstandingBalance,
    double? allocatedAmount,
    bool? isSelected,
    String? status,
  }) {
    return Invoice(
      invoiceNo: invoiceNo ?? this.invoiceNo,
      customerCode: customerCode ?? this.customerCode,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      totalAmount: totalAmount ?? this.totalAmount,
      setAmt: setAmt ?? this.setAmt,
      outstandingBalance: outstandingBalance ?? this.outstandingBalance,
      allocatedAmount: allocatedAmount ?? this.allocatedAmount,
      isSelected: isSelected ?? this.isSelected,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
    'invoiceNo': invoiceNo,
    'customerCode': customerCode,
    'invoiceDate': invoiceDate.toIso8601String(),
    'deliveryDate': deliveryDate.toIso8601String(),
    'totalAmount': totalAmount,
    'setAmt': setAmt,
    'outstandingBalance': outstandingBalance,
    'allocatedAmount': allocatedAmount,
    'isSelected': isSelected,
    'status': status,
  };

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
    invoiceNo: json['invoiceNo'] as String,
    customerCode: json['customerCode'] as String,
    invoiceDate: DateTime.parse(json['invoiceDate'] as String),
    deliveryDate: DateTime.parse(json['deliveryDate'] as String),
    totalAmount: (json['totalAmount'] as num).toDouble(),
    setAmt: (json['setAmt'] as num?)?.toDouble() ?? 0.0,
    outstandingBalance: (json['outstandingBalance'] as num).toDouble(),
    allocatedAmount: (json['allocatedAmount'] as num?)?.toDouble() ?? 0.0,
    isSelected: json['isSelected'] as bool? ?? false,
    status: json['status'] as String? ?? 'Pending',
  );
}
