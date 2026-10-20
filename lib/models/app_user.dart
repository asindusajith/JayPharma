class AppUser {
  final String collectorId;
  final String username;
  final String fullName;
  final String phone;
  final String branch;
  final String accessLevel; // 'Admin', 'Manager', 'Collector', 'Cashier'
  final String assignedLocations; // 'ALL' or comma-separated list e.g. 'Kandy, Matale'
  final bool isActive;
  final DateTime? createdAt;

  const AppUser({
    required this.collectorId,
    required this.username,
    required this.fullName,
    this.phone = '',
    this.branch = 'Jay Pharma',
    this.accessLevel = 'Collector',
    this.assignedLocations = 'ALL',
    this.isActive = true,
    this.createdAt,
  });

  bool get isAdmin => accessLevel.toLowerCase() == 'admin';
  bool get isManager => accessLevel.toLowerCase() == 'manager' || isAdmin;
  bool get isCollector => accessLevel.toLowerCase() == 'collector';
  bool get isCashier => accessLevel.toLowerCase() == 'cashier';

  bool get hasAllLocations {
    final clean = assignedLocations.trim().toUpperCase();
    return clean == 'ALL' || clean.isEmpty || clean == '*';
  }

  List<String> get locationList {
    if (hasAllLocations) return const [];
    return assignedLocations
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  bool canAccessCustomer({
    required String code,
    required String name,
    String town = '',
    String address = '',
  }) {
    if (hasAllLocations) return true;
    final list = locationList;
    if (list.isEmpty) return true;

    final cleanCode = code.trim().toLowerCase();
    final cleanName = name.trim().toLowerCase();
    final cleanTown = town.trim().toLowerCase();
    final cleanAddr = address.trim().toLowerCase();

    for (final loc in list) {
      final l = loc.toLowerCase();
      if (cleanCode == l ||
          cleanName.contains(l) ||
          (cleanTown.isNotEmpty && cleanTown.contains(l)) ||
          (cleanAddr.isNotEmpty && cleanAddr.contains(l))) {
        return true;
      }
    }
    return false;
  }

  bool canAccessLocation(String customerInfo) {
    if (hasAllLocations) return true;
    final lowerInfo = customerInfo.toLowerCase();
    final list = locationList;
    if (list.isEmpty) return true;

    for (final loc in list) {
      if (lowerInfo.contains(loc.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  Map<String, dynamic> toJson() => {
    'collectorId': collectorId,
    'username': username,
    'fullName': fullName,
    'phone': phone,
    'branch': branch,
    'accessLevel': accessLevel,
    'assignedLocations': assignedLocations,
    'isActive': isActive,
    'createdAt': createdAt?.toIso8601String(),
  };

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      collectorId: json['collectorId']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      branch: json['branch']?.toString() ?? 'Jay Pharma',
      accessLevel: json['accessLevel']?.toString() ?? 'Collector',
      assignedLocations: json['assignedLocations']?.toString() ?? 'ALL',
      isActive: json['isActive'] == true || json['isActive'] == 1,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }
}
