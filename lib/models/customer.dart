class Customer {
  final String code;
  final String name;
  final String address;
  final String phone;
  final String email;
  final String town;
  final double creditLimit;
  final int pendingInvoiceCount;
  final int pendingCount;
  final int partSettledCount;
  final double totalOutstanding;

  const Customer({
    required this.code,
    required this.name,
    this.address = '',
    this.phone = '',
    this.email = '',
    this.town = '',
    this.creditLimit = 1000000.0,
    this.pendingInvoiceCount = 0,
    this.pendingCount = 0,
    this.partSettledCount = 0,
    this.totalOutstanding = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'address': address,
    'phone': phone,
    'email': email,
    'town': town,
    'creditLimit': creditLimit,
    'pendingInvoiceCount': pendingInvoiceCount,
    'pendingCount': pendingCount,
    'partSettledCount': partSettledCount,
    'totalOutstanding': totalOutstanding,
  };

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    code: json['code']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    address: json['address']?.toString() ?? '',
    phone: json['phone']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    town: json['town']?.toString() ?? '',
    creditLimit: (json['creditLimit'] as num?)?.toDouble() ?? 1000000.0,
    pendingInvoiceCount: (json['pendingInvoiceCount'] as num?)?.toInt() ?? 0,
    pendingCount: (json['pendingCount'] as num?)?.toInt() ?? 0,
    partSettledCount: (json['partSettledCount'] as num?)?.toInt() ?? 0,
    totalOutstanding: (json['totalOutstanding'] as num?)?.toDouble() ?? 0.0,
  );
}
