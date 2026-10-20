import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/customer.dart';
import '../models/invoice.dart';
import '../models/receipt.dart';
import '../models/day_end_summary.dart';
import '../models/audit_log.dart';
import '../services/location_service.dart';
import '../services/sms_service.dart';

import '../models/app_user.dart';

class AppState extends ChangeNotifier {
  // Realtime Backend API
  String apiBaseUrl = _resolveInitialApiUrl();
  bool isLiveConnected = false;

  static String _resolveInitialApiUrl() {
    if (!kIsWeb) {
      // Mobile Android / iOS App: connect to remote public server IP
      return 'http://220.247.236.89:83/jaypharma-api/api';
    }
    try {
      final host = Uri.base.host;
      final port = Uri.base.port;
      if (host.contains('vercel.app')) {
        // Hosted on Vercel: proxy through /api rewrite to avoid mixed-content (HTTPS -> HTTP) and CORS
        return Uri.base.resolve('/api').toString();
      }
      if (host.isNotEmpty && (port == 83 || host == '220.247.236.89')) {
        return 'http://$host:83/jaypharma-api/api';
      }
      if (host.isNotEmpty && host != 'localhost' && host != '127.0.0.1') {
        return 'http://$host:5100/api';
      }
    } catch (_) {}
    return 'http://localhost:5100/api';
  }

  Future<void> _autoDetectApiUrl() async {
    try {
      final candidates = <String>[];
      if (!kIsWeb) {
        candidates.add('http://220.247.236.89:83/jaypharma-api/api');
        candidates.add('http://220.247.236.89:5100/api');
        candidates.add('http://10.0.2.2:5100/api');
      } else {
        final host = Uri.base.host;
        final port = Uri.base.port;
        if (host.contains('vercel.app')) {
          candidates.add(Uri.base.resolve('/api').toString());
        }
        if (host.isNotEmpty && (port == 83 || host == '220.247.236.89')) {
          candidates.add('http://$host:83/jaypharma-api/api');
          candidates.add('http://$host:5100/api');
        }
        candidates.add('http://localhost:5100/api');
        candidates.add('http://127.0.0.1:5100/api');
      }

      for (final candidate in candidates) {
        try {
          final res = await http.get(Uri.parse('$candidate/health')).timeout(const Duration(milliseconds: 1500));
          if (res.statusCode == 200) {
            if (apiBaseUrl != candidate) {
              apiBaseUrl = candidate;
              isLiveConnected = true;
              notifyListeners();
              fetchRealtimeCustomers();
              fetchRealtimeReceipts();
            }
            break;
          }
        } catch (_) {}
      }
    } catch (_) {}
  }


  // Session & Current User
  AppUser currentUser = const AppUser(
    collectorId: '',
    username: '',
    fullName: '',
    phone: '',
    branch: '',
    accessLevel: '',
    assignedLocations: '',
  );

  String get collectorId => currentUser.collectorId;
  String get collectorName => currentUser.fullName;
  String get userAccessLevel => currentUser.accessLevel;
  String get userAssignedLocations => currentUser.assignedLocations;
  bool get isAdmin => currentUser.isAdmin;
  bool get isManager => currentUser.isManager;

  final String deviceId = 'TAB-COL-042 (Samsung Tab Active 3)';
  bool isDeviceAuthorized = true;
  bool isLoggedIn = false;
  DateTime lastActivityTime = DateTime.now();
  int sessionTimeoutMinutes = 60;
  Timer? _inactivityTimer;

  // Users Directory (Admin/Manager accessible)
  List<AppUser> _allUsers = [];
  List<AppUser> get allUsers => List.unmodifiable(_allUsers);
  bool isLoadingUsers = false;
  bool _isFetchingUsers = false;
  DateTime? _lastUsersFetchTime;

  // Language & UI Preferences
  String currentLanguage = 'en'; // 'en' or 'si'

  // Sync Status
  DateTime lastSyncTime = DateTime.now().subtract(const Duration(hours: 2, minutes: 15));
  bool isSyncing = false;
  int pendingSyncCount = 0;

  // Day-End Finalization State (Section 3 Requirement)
  bool isDayEndFinalized = false;
  DateTime? dayEndFinalizedAt;

  // Master Data
  final List<Customer> _customers = [];
  final Map<String, List<Invoice>> _customerInvoicesMap = {};
  final List<Receipt> _receipts = [];
  final List<AuditLog> _auditLogs = [];

  bool _isFetchingCustomers = false;
  DateTime? _lastCustomersFetchTime;

  bool _isFetchingReceipts = false;
  DateTime? _lastReceiptsFetchTime;

  // Active Draft Payment State (Step 1 -> Step 2 -> Step 3)
  Customer? draftCustomer;
  double draftPaymentAmount = 0.0;
  PaymentMethod draftPaymentMethod = PaymentMethod.cash;
  String? draftBank;
  String? draftBranch;
  String? draftChequeNumber;
  DateTime? draftChequeDate;
  String draftManualReceiptNo = '';
  String draftComments = '';
  List<Invoice> draftInvoices = [];
  bool draftIsAdvancePayment = false;

  AppState() {
    _initSampleData();
    _startInactivityTimer();
    _autoDetectApiUrl();
    fetchRealtimeCustomers();
    fetchRealtimeReceipts();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  List<Customer> get customers => List.unmodifiable(_customers);

  // Filtered customers accessible by current user's assigned locations
  List<Customer> get accessibleCustomers {
    if (currentUser.hasAllLocations) {
      return _customers;
    }
    return _customers.where((c) {
      return currentUser.canAccessCustomer(
        code: c.code,
        name: c.name,
        town: c.town,
        address: c.address,
      );
    }).toList();
  }

  // Receipts filtered by user's assigned locations (or all if ALL locations assigned)
  List<Receipt> get receipts {
    if (currentUser.hasAllLocations) {
      return List.unmodifiable(_receipts);
    }
    final scoped = _receipts.where((r) {
      return currentUser.canAccessCustomer(
        code: r.customerCode,
        name: r.customerName,
        address: r.customerAddress,
      );
    }).toList();
    return List.unmodifiable(scoped);
  }
  List<AuditLog> get auditLogs => List.unmodifiable(_auditLogs);

  // Inactivity session timer (Section 4)
  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (DateTime.now().difference(lastActivityTime).inMinutes >= sessionTimeoutMinutes) {
        logoutDueToInactivity();
      }
    });
  }

  void userInteracted() {
    lastActivityTime = DateTime.now();
  }

  void logoutDueToInactivity() {
    isLoggedIn = false;
    currentUser = const AppUser(
      collectorId: '',
      username: '',
      fullName: '',
      phone: '',
      branch: '',
      accessLevel: '',
      assignedLocations: '',
    );
    notifyListeners();
  }

  void logout() {
    isLoggedIn = false;
    currentUser = const AppUser(
      collectorId: '',
      username: '',
      fullName: '',
      phone: '',
      branch: '',
      accessLevel: '',
      assignedLocations: '',
    );
    _inactivityTimer?.cancel();
    notifyListeners();
  }

  // Real Backend Authentication
  Future<bool> loginWithCredentials(String username, String password) async {
    userInteracted();
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username.trim(),
          'password': password.trim(),
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        currentUser = AppUser(
          collectorId: data['collectorId'] ?? username.trim(),
          username: data['username'] ?? username.trim(),
          fullName: data['fullName'] ?? 'Collector',
          phone: data['phone'] ?? '',
          branch: data['branch'] ?? 'Jay Pharma',
          accessLevel: data['accessLevel'] ?? 'Collector',
          assignedLocations: data['assignedLocations'] ?? 'ALL',
        );
        isLoggedIn = true;
        lastActivityTime = DateTime.now();
        _startInactivityTimer();
        
        // Refresh users, customers & receipts for the logged-in user
        fetchAllUsers(force: true);
        fetchRealtimeCustomers(force: true);
        fetchRealtimeReceipts(force: true);

        // Audit Log entry
        _auditLogs.insert(0, AuditLog(
          id: 'AUD-${DateTime.now().millisecondsSinceEpoch}',
          action: 'LOGIN',
          referenceNo: currentUser.collectorId,
          collectorId: currentUser.collectorId,
          collectorName: currentUser.fullName,
          details: 'User logged in successfully (${currentUser.accessLevel} - Areas: ${currentUser.assignedLocations})',
          timestamp: DateTime.now(),
        ));

        notifyListeners();
        return true;
      } else if (response.statusCode == 401) {
        throw Exception('Invalid Username or Password.');
      } else {
        throw Exception('Server returned status: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // --- User Management Methods (Settings Screen) ---
  Future<void> fetchAllUsers({bool force = false}) async {
    if (!force && _lastUsersFetchTime != null && _allUsers.isNotEmpty) {
      if (DateTime.now().difference(_lastUsersFetchTime!).inSeconds < 60) {
        return;
      }
    }
    if (_isFetchingUsers) return;
    _isFetchingUsers = true;

    try {
      isLoadingUsers = true;
      final response = await http.get(Uri.parse('$apiBaseUrl/users')).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        _allUsers = list.map((json) => AppUser.fromJson(json)).toList();
        _lastUsersFetchTime = DateTime.now();
      }
    } catch (e) {
      debugPrint('[Fetch Users Error]: $e');
    } finally {
      isLoadingUsers = false;
      _isFetchingUsers = false;
      notifyListeners();
    }
  }

  Future<void> createNewUser({
    required String username,
    required String password,
    required String fullName,
    String? phone,
    String? branch,
    required String accessLevel,
    required String assignedLocations,
    String? collectorId,
  }) async {
    try {
      final payload = {
        'username': username.trim(),
        'password': password.trim(),
        'fullName': fullName.trim(),
        'phone': phone?.trim() ?? '',
        'branch': branch?.trim() ?? 'Jay Pharma',
        'accessLevel': accessLevel,
        'assignedLocations': assignedLocations.trim(),
        'collectorId': collectorId?.trim(),
      };

      final response = await http.post(
        Uri.parse('$apiBaseUrl/users'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        // Audit Log
        _auditLogs.insert(0, AuditLog(
          id: 'AUD-${DateTime.now().millisecondsSinceEpoch}',
          action: 'CREATE_USER',
          referenceNo: username.trim(),
          collectorId: collectorId ?? this.collectorId,
          collectorName: collectorName,
          details: 'Created user $fullName ($accessLevel) with locations: $assignedLocations',
          timestamp: DateTime.now(),
        ));

        await fetchAllUsers();
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? 'Failed to create user (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('[Create User Error]: $e');
      rethrow;
    }
  }

  Future<void> toggleUserStatus(String colId) async {
    try {
      final response = await http.delete(Uri.parse('$apiBaseUrl/users/$colId')).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        await fetchAllUsers();
      }
    } catch (e) {
      debugPrint('[Toggle User Error]: $e');
      rethrow;
    }
  }

  Future<void> updateUserLocations(String colId, String assignedLocations) async {
    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/users/$colId/locations'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'assignedLocations': assignedLocations.trim()}),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        _auditLogs.insert(0, AuditLog(
          id: 'AUD-${DateTime.now().millisecondsSinceEpoch}',
          action: 'UPDATE_LOCATIONS',
          referenceNo: colId,
          collectorId: collectorId,
          collectorName: collectorName,
          details: 'Updated assigned locations for user $colId: $assignedLocations',
          timestamp: DateTime.now(),
        ));
        await fetchAllUsers();
        if (currentUser.collectorId == colId) {
          currentUser = AppUser(
            collectorId: currentUser.collectorId,
            username: currentUser.username,
            fullName: currentUser.fullName,
            phone: currentUser.phone,
            branch: currentUser.branch,
            accessLevel: currentUser.accessLevel,
            assignedLocations: assignedLocations.trim(),
            isActive: currentUser.isActive,
            createdAt: currentUser.createdAt,
          );
        }
        notifyListeners();
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? 'Failed to update locations');
      }
    } catch (e) {
      debugPrint('[Update Locations Error]: $e');
      rethrow;
    }
  }

  void login(String id, String password) {
    loginWithCredentials(id, password);
  }

  void toggleLanguage(String lang) {
    currentLanguage = lang;
    notifyListeners();
  }

  // --- Initial Master Data Matching PDF ---
  void _initSampleData() {
    _customers.addAll([
      const Customer(
        code: 'C1001',
        name: 'City Pharmacy',
        address: '123 Galle Road, Colombo 07',
        phone: '011 234 5678',
        email: 'citypharmacy@gmail.com',
        town: 'Colombo 07',
        creditLimit: 1500000.0,
      ),
      const Customer(
        code: 'C1002',
        name: 'HealthPlus Pharmacy',
        address: '45 Negombo Road, Negombo',
        phone: '031 223 8890',
        email: 'healthplus.negombo@gmail.com',
        town: 'Negombo',
        creditLimit: 800000.0,
      ),
      const Customer(
        code: 'C1003',
        name: 'MediCare Pharmacy',
        address: '88 Peradeniya Road, Kandy',
        phone: '081 223 4455',
        email: 'medicare.kandy@gmail.com',
        town: 'Kandy',
        creditLimit: 1200000.0,
      ),
      const Customer(
        code: 'C1004',
        name: 'Sunshine Pharmacy',
        address: '12 Colombo Road, Kurunegala',
        phone: '037 222 1144',
        email: 'sunshine.pharma@gmail.com',
        town: 'Kurunegala',
        creditLimit: 750000.0,
      ),
      const Customer(
        code: 'C1005',
        name: 'WellCare Pharmacy',
        address: '99 Main Street, Gampaha',
        phone: '033 222 7788',
        email: 'wellcare.gampaha@gmail.com',
        town: 'Gampaha',
        creditLimit: 900000.0,
      ),
      const Customer(
        code: 'C1006',
        name: 'New Life Pharmacy',
        address: '24 Station Road, Ja-Ela',
        phone: '011 224 9911',
        email: 'newlife.jaela@gmail.com',
        town: 'Ja-Ela',
        creditLimit: 600000.0,
      ),
      const Customer(
        code: 'C1007',
        name: 'Lanka Medicals',
        address: '67 Duplication Road, Colombo 03',
        phone: '011 257 6633',
        email: 'lankamedicals@gmail.com',
        town: 'Colombo 03',
        creditLimit: 2000000.0,
      ),
    ]);

    // Sample invoices for C1001 (Matching page 2, 3, 4 of PDF)
    _customerInvoicesMap['C1001'] = [
      Invoice(
        invoiceNo: 'INV-1045',
        customerCode: 'C1001',
        invoiceDate: DateTime(2026, 9, 12),
        deliveryDate: DateTime(2026, 9, 12),
        totalAmount: 125000.0,
        outstandingBalance: 125000.0,
      ),
      Invoice(
        invoiceNo: 'INV-1048',
        customerCode: 'C1001',
        invoiceDate: DateTime(2026, 9, 18),
        deliveryDate: DateTime(2026, 9, 18),
        totalAmount: 87650.0,
        outstandingBalance: 87650.0,
      ),
      Invoice(
        invoiceNo: 'INV-1051',
        customerCode: 'C1001',
        invoiceDate: DateTime(2026, 9, 25),
        deliveryDate: DateTime(2026, 9, 25),
        totalAmount: 210000.0,
        outstandingBalance: 210000.0,
      ),
      Invoice(
        invoiceNo: 'INV-1055',
        customerCode: 'C1001',
        invoiceDate: DateTime(2026, 10, 2),
        deliveryDate: DateTime(2026, 10, 2),
        totalAmount: 65000.0,
        outstandingBalance: 65000.0,
      ),
    ];

    // Invoices for C1002
    _customerInvoicesMap['C1002'] = [
      Invoice(
        invoiceNo: 'INV-1060',
        customerCode: 'C1002',
        invoiceDate: DateTime(2026, 9, 20),
        deliveryDate: DateTime(2026, 9, 20),
        totalAmount: 95000.0,
        outstandingBalance: 95000.0,
      ),
      Invoice(
        invoiceNo: 'INV-1064',
        customerCode: 'C1002',
        invoiceDate: DateTime(2026, 10, 5),
        deliveryDate: DateTime(2026, 10, 5),
        totalAmount: 140000.0,
        outstandingBalance: 140000.0,
      ),
    ];

    // Invoices for C1003
    _customerInvoicesMap['C1003'] = [
      Invoice(
        invoiceNo: 'INV-1070',
        customerCode: 'C1003',
        invoiceDate: DateTime(2026, 9, 15),
        deliveryDate: DateTime(2026, 9, 15),
        totalAmount: 180000.0,
        outstandingBalance: 180000.0,
      ),
    ];
  }

  bool isLoadingInvoices = false;

  // --- Realtime API Synchronization ---
  Future<void> fetchRealtimeCustomers({String? search, bool force = false}) async {
    final isGeneralFetch = search == null || search.isEmpty;
    if (isGeneralFetch && !force && _lastCustomersFetchTime != null && _customers.isNotEmpty) {
      if (DateTime.now().difference(_lastCustomersFetchTime!).inSeconds < 30) {
        return;
      }
    }
    if (_isFetchingCustomers) return;
    _isFetchingCustomers = true;

    try {
      final uri = Uri.parse('$apiBaseUrl/customers${search != null && search.isNotEmpty ? '?search=${Uri.encodeComponent(search)}' : ''}');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        if (list.isNotEmpty) {
          final liveCustomers = list.map((item) => Customer(
            code: item['code'].toString(),
            name: item['name'].toString(),
            address: item['address']?.toString() ?? '',
            phone: item['phone']?.toString() ?? '',
            email: item['email']?.toString() ?? '',
            town: item['town']?.toString() ?? '',
            creditLimit: (item['creditLimit'] as num?)?.toDouble() ?? 1000000.0,
            pendingInvoiceCount: (item['pendingInvoiceCount'] as num?)?.toInt() ?? 0,
            pendingCount: (item['pendingCount'] as num?)?.toInt() ?? 0,
            partSettledCount: (item['partSettledCount'] as num?)?.toInt() ?? 0,
            totalOutstanding: (item['totalOutstanding'] as num?)?.toDouble() ?? 0.0,
          )).toList();

          _customers.clear();
          _customers.addAll(liveCustomers);
          isLiveConnected = true;
          if (isGeneralFetch) _lastCustomersFetchTime = DateTime.now();
          notifyListeners();
        }
      }
    } catch (_) {
      // Offline fallback: retain initial sample data
    } finally {
      _isFetchingCustomers = false;
    }
  }

  Future<void> fetchInvoicesForCustomerRealtime(String customerCode) async {
    // If we already have invoices cached locally, initialize draft immediately so there's 0 lag
    if (_customerInvoicesMap.containsKey(customerCode) && _customerInvoicesMap[customerCode]!.isNotEmpty) {
      final cached = _customerInvoicesMap[customerCode]!;
      if (draftCustomer?.code == customerCode) {
        draftInvoices = cached.map((inv) => inv.copyWith(allocatedAmount: 0.0, isSelected: false)).toList();
        isLoadingInvoices = false;
        notifyListeners();
      }
    } else {
      isLoadingInvoices = true;
      notifyListeners();
    }

    try {
      final res = await http.get(Uri.parse('$apiBaseUrl/customers/$customerCode/invoices')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        final invoices = list.map((item) => Invoice(
          invoiceNo: item['invoiceNo'].toString(),
          customerCode: item['customerCode'].toString(),
          invoiceDate: DateTime.tryParse(item['invoiceDate'].toString()) ?? DateTime.now(),
          deliveryDate: DateTime.tryParse(item['deliveryDate'].toString()) ?? DateTime.now(),
          totalAmount: (item['totalAmount'] as num).toDouble(),
          setAmt: (item['setAmt'] as num?)?.toDouble() ?? 0.0,
          outstandingBalance: (item['outstandingBalance'] as num).toDouble(),
          status: item['status']?.toString() ?? 'Pending',
        )).toList();

        _customerInvoicesMap[customerCode] = invoices;
        if (draftCustomer?.code == customerCode) {
          draftInvoices = invoices.map((inv) => inv.copyWith(allocatedAmount: 0.0, isSelected: false)).toList();
        }
      }
    } catch (_) {
      // Retain fallback data
    } finally {
      isLoadingInvoices = false;
      notifyListeners();
    }
  }

  // Retrieve invoices for a customer
  List<Invoice> getCustomerInvoices(String customerCode) {
    return _customerInvoicesMap[customerCode] ?? [];
  }

  // Fetch real recorded receipts from JayPharmaApp backend
  Future<void> fetchRealtimeReceipts({bool force = false}) async {
    if (!force && _lastReceiptsFetchTime != null && _receipts.isNotEmpty) {
      if (DateTime.now().difference(_lastReceiptsFetchTime!).inSeconds < 20) {
        return;
      }
    }
    if (_isFetchingReceipts) return;
    _isFetchingReceipts = true;

    try {
      final res = await http.get(Uri.parse('$apiBaseUrl/receipts')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        _receipts.clear();
        for (final item in list) {
          try {
            _receipts.add(Receipt.fromJson(item as Map<String, dynamic>));
          } catch (e) {
            debugPrint('[Receipt parse error]: $e');
          }
        }
        _lastReceiptsFetchTime = DateTime.now();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[Fetch receipts error]: $e');
    } finally {
      _isFetchingReceipts = false;
    }
  }

  // --- Payment Draft Flow Management ---
  void startNewPayment(Customer customer) {
    draftCustomer = customer;
    draftPaymentAmount = 0.0;
    draftPaymentMethod = PaymentMethod.cash;
    draftBank = null;
    draftBranch = null;
    draftChequeNumber = null;
    draftChequeDate = null;
    // Suggest next available sequential manual receipt number
    draftManualReceiptNo = _generateSuggestedManualReceiptNo();
    draftComments = '';
    draftIsAdvancePayment = false;

    // Fetch live next receipt number from server
    fetchNextSuggestedReceiptNo();

    // Clone any existing invoices or prepare empty while fetching
    final existing = getCustomerInvoices(customer.code);
    draftInvoices = existing.map((inv) => inv.copyWith(allocatedAmount: 0.0, isSelected: false)).toList();
    isLoadingInvoices = true;
    notifyListeners();

    // Immediately fetch live invoices from Realtime API
    fetchInvoicesForCustomerRealtime(customer.code);
  }

  Future<void> fetchNextSuggestedReceiptNo() async {
    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/receipts/next-number')).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['nextReceiptNo'] != null) {
          draftManualReceiptNo = data['nextReceiptNo'].toString();
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  String _generateSuggestedManualReceiptNo() {
    int maxNum = 26450;
    for (final r in _receipts) {
      final parts = r.manualReceiptNo.replaceAll('MR-', '');
      final parsed = int.tryParse(parts);
      if (parsed != null && parsed > maxNum) {
        maxNum = parsed;
      }
    }
    return 'MR-${(maxNum + 1).toString().padLeft(6, '0')}';
  }

  void setDraftPaymentAmount(double amount) {
    draftPaymentAmount = amount;
    // Reset any allocations when total amount is changed
    for (final inv in draftInvoices) {
      inv.isSelected = false;
      inv.allocatedAmount = 0.0;
    }
    notifyListeners();
  }

  void setDraftPaymentMethod(PaymentMethod method) {
    draftPaymentMethod = method;
    notifyListeners();
  }

  void setDraftChequeDetails({
    required String? bank,
    required String? branch,
    required String? chequeNumber,
    required DateTime? chequeDate,
  }) {
    draftBank = bank;
    draftBranch = branch;
    draftChequeNumber = chequeNumber;
    draftChequeDate = chequeDate;
    notifyListeners();
  }

  void setDraftManualReceiptNo(String no) {
    draftManualReceiptNo = no.trim();
    notifyListeners();
  }

  void setDraftComments(String comments) {
    draftComments = comments;
    notifyListeners();
  }

  // --- Dynamic Allocation Logic (Strictly Following Pages 3 & 4) ---
  double get totalAllocatedAmount {
    return draftInvoices.where((i) => i.isSelected).fold(0.0, (sum, i) => sum + i.allocatedAmount);
  }

  double get remainingPaymentAmount {
    final rem = draftPaymentAmount - totalAllocatedAmount;
    return rem >= 0 ? rem : 0.0;
  }

  String? toggleInvoice(Invoice inv) {
    if (inv.outstandingBalance <= 0 || inv.status == 'Settled') {
      return 'This invoice is already fully settled.';
    }

    if (inv.isSelected) {
      // Deselecting: clear allocation and return to available pool
      inv.isSelected = false;
      inv.allocatedAmount = 0.0;
      notifyListeners();
      return null;
    }

    // Selecting: check if remaining payment amount is 0
    final available = remainingPaymentAmount;
    if (available <= 0) {
      // Prevent selection as per Page 3 & 4: "Prevent users from selecting additional invoices because the entire payment amount has been allocated. Display an appropriate message."
      return 'Entire payment amount has already been allocated. You cannot select additional invoices.';
    }

    // Allocate automatically
    inv.isSelected = true;
    if (available >= inv.outstandingBalance) {
      // Full settlement of this invoice
      inv.allocatedAmount = inv.outstandingBalance;
    } else {
      // Partial payment
      inv.allocatedAmount = available;
    }

    notifyListeners();
    return null;
  }

  /// Returns null on success, or an error message if selection is prevented
  String? toggleInvoiceSelection(int index) {
    if (index < 0 || index >= draftInvoices.length) return 'Invalid invoice index';
    return toggleInvoice(draftInvoices[index]);
  }

  // Validation before proceeding to Review Screen (Step 3)
  String? validateDraftPayment() {
    if (isDayEndFinalized) {
      return 'Day-end process has been completed for today. No further payments can be recorded.';
    }
    if (draftCustomer == null) {
      return 'Please select a customer.';
    }
    if (draftPaymentAmount <= 0) {
      return 'Please enter a valid payment amount greater than zero.';
    }
    if (draftManualReceiptNo.trim().isEmpty) {
      return 'Manual receipt number is mandatory.';
    }
    if (!isReceiptNumberUnique(draftManualReceiptNo)) {
      return 'Manual receipt number "$draftManualReceiptNo" has already been used. Numbers must be unique and cannot be reused.';
    }
    if (draftPaymentMethod == PaymentMethod.cheque) {
      if (draftBank == null || draftBank!.trim().isEmpty) {
        return 'Bank name is mandatory for cheque payment.';
      }
      if (draftBranch == null || draftBranch!.trim().isEmpty) {
        return 'Branch name is mandatory for cheque payment.';
      }
      if (draftChequeNumber == null || draftChequeNumber!.trim().isEmpty) {
        return 'Cheque number is mandatory for cheque payment.';
      }
      if (draftChequeDate == null) {
        return 'Cheque date is mandatory for cheque payment.';
      }
    }
    return null; // Valid
  }

  bool isReceiptNumberUnique(String receiptNo) {
    final cleanNo = receiptNo.trim().toUpperCase();
    return !_receipts.any((r) => r.manualReceiptNo.trim().toUpperCase() == cleanNo);
  }

  // Confirm and Generate Final Receipt (Section 2.2 Page 5)
  Future<Receipt> confirmAndGenerateReceipt() async {
    final validation = validateDraftPayment();
    if (validation != null) {
      throw Exception(validation);
    }

    final loc = await LocationService.getCurrentLocation();
    final effectiveLocationAddress = (loc.address.isNotEmpty)
        ? loc.address
        : (draftCustomer?.address.isNotEmpty == true
            ? draftCustomer!.address
            : 'Galle Road, Colombo 03, Western Province, Sri Lanka');
    final effectiveBranch = (draftBranch != null && draftBranch!.trim().isNotEmpty)
        ? draftBranch!.trim()
        : (draftCustomer?.town.isNotEmpty == true
            ? draftCustomer!.town
            : 'Colombo');

    // Prepare allocated invoice items
    final selectedInvoices = draftInvoices.where((i) => i.isSelected && i.allocatedAmount > 0).toList();
    final items = <ReceiptInvoiceItem>[];
    for (int i = 0; i < selectedInvoices.length; i++) {
      final inv = selectedInvoices[i];
      items.add(ReceiptInvoiceItem(
        itemIndex: i + 1,
        invoiceNo: inv.invoiceNo,
        invoiceDate: inv.invoiceDate,
        invoiceAmount: inv.totalAmount,
        amountSettled: inv.allocatedAmount,
        remainingBalance: (inv.outstandingBalance - inv.allocatedAmount).clamp(0.0, double.infinity),
      ));

      // Update actual outstanding balance in master data
      final originalList = _customerInvoicesMap[draftCustomer!.code] ?? [];
      final masterInv = originalList.firstWhere((element) => element.invoiceNo == inv.invoiceNo);
      masterInv.outstandingBalance -= inv.allocatedAmount;
      if (masterInv.outstandingBalance < 0.01) masterInv.outstandingBalance = 0.0;
    }

    final newReceipt = Receipt(
      manualReceiptNo: draftManualReceiptNo.trim(),
      customerCode: draftCustomer!.code,
      customerName: draftCustomer!.name,
      customerAddress: draftCustomer!.address,
      customerPhone: draftCustomer!.phone,
      paymentMethod: draftPaymentMethod,
      bank: draftBank,
      branch: effectiveBranch,
      chequeNumber: draftChequeNumber,
      chequeDate: draftChequeDate,
      totalAmount: draftPaymentAmount,
      allocatedInvoices: items,
      comments: draftComments,
      isAdvancePayment: items.isEmpty,
      collectorId: collectorId,
      collectorName: collectorName,
      latitude: loc.latitude != 0.0 ? loc.latitude : 6.927079,
      longitude: loc.longitude != 0.0 ? loc.longitude : 79.861244,
      locationAddress: effectiveLocationAddress,
      createdAt: DateTime.now(),
      syncStatus: SyncStatus.synced,
    );

    _receipts.insert(0, newReceipt);

    // Audit Log entry (Section 6)
    _auditLogs.insert(0, AuditLog(
      id: 'AUD-${DateTime.now().millisecondsSinceEpoch}',
      action: 'CREATE_RECEIPT',
      referenceNo: newReceipt.manualReceiptNo,
      collectorId: collectorId,
      collectorName: collectorName,
      details: 'Created receipt for ${newReceipt.customerName} - Rs. ${newReceipt.totalAmount} (${newReceipt.paymentMethodDisplay})',
      timestamp: DateTime.now(),
    ));

    // Realtime API Post to JayPharmaApp & Main ERP (JayPharma on port 5000)
    try {
      final payload = {
        'manualReceiptNo': newReceipt.manualReceiptNo,
        'customerCode': newReceipt.customerCode,
        'customerName': newReceipt.customerName,
        'customerAddress': newReceipt.customerAddress,
        'customerPhone': newReceipt.customerPhone,
        'paymentMethod': newReceipt.paymentMethod.name.toUpperCase(),
        'bank': newReceipt.bank,
        'branch': newReceipt.branch,
        'chequeNumber': newReceipt.chequeNumber,
        'chequeDate': newReceipt.chequeDate?.toIso8601String(),
        'totalAmount': newReceipt.totalAmount,
        'comments': newReceipt.comments,
        'collectorId': newReceipt.collectorId,
        'collectorName': newReceipt.collectorName,
        'latitude': newReceipt.latitude,
        'longitude': newReceipt.longitude,
        'locationAddress': newReceipt.locationAddress,
        'allocatedInvoices': items.map((i) => {
          'invoiceNo': i.invoiceNo,
          'invoiceDate': i.invoiceDate.toIso8601String(),
          'invoiceAmount': i.invoiceAmount,
          'amountSettled': i.amountSettled,
          'remainingBalance': i.remainingBalance,
        }).toList(),
      };

      final response = await http.post(
        Uri.parse('$apiBaseUrl/receipts'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        final errMsg = body['error'] ?? 'Server error ${response.statusCode}';
        throw Exception(errMsg);
      }
    } catch (e) {
      debugPrint('[API Post Failed]: $e');
      rethrow;
    }

    // Send simulated SMS notification (Page 5)
    await SmsService.sendCustomerPaymentSms(newReceipt);

    // Refresh live receipts
    fetchRealtimeReceipts();

    notifyListeners();
    return newReceipt;
  }

  // --- Controlled Reprint with OTP (Page 5 & Section 2.5) ---
  bool reprintReceiptWithOtp({
    required String receiptNo,
    required String enteredOtp,
    required String reason,
  }) {
    final index = _receipts.indexWhere((r) => r.manualReceiptNo == receiptNo);
    if (index == -1) return false;

    // Audit and update reprint count
    final receipt = _receipts[index];
    receipt.reprintCount += 1;
    receipt.reprintHistory.add(ReprintRecord(
      timestamp: DateTime.now(),
      collectorId: collectorId,
      otpUsed: enteredOtp,
      reason: reason,
    ));

    _auditLogs.insert(0, AuditLog(
      id: 'AUD-${DateTime.now().millisecondsSinceEpoch}',
      action: 'REPRINT_RECEIPT',
      referenceNo: receiptNo,
      collectorId: collectorId,
      collectorName: collectorName,
      details: 'Reprinted receipt #$receiptNo under OTP authorization. Reason: $reason',
      timestamp: DateTime.now(),
    ));

    notifyListeners();
    return true;
  }

  // --- Day-End Calculation & Submission (Section 3) ---
  DayEndSummary calculateDayEndSummary(DateTime targetDate) {
    final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final endOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);

    final dayReceipts = _receipts.where((r) {
      if (r.isCancelled) return false;
      if (r.createdAt.isBefore(startOfDay) || r.createdAt.isAfter(endOfDay)) return false;

      // Filter by user's assigned locations (if ALL locations assigned, display all payments)
      if (currentUser.hasAllLocations) {
        return true;
      }
      return currentUser.canAccessCustomer(
        code: r.customerCode,
        name: r.customerName,
        address: r.customerAddress,
      );
    }).toList();

    double totalCash = 0.0;
    double totalCheque = 0.0;
    final List<ChequeSummaryItem> cheques = [];

    for (final r in dayReceipts) {
      if (r.paymentMethod == PaymentMethod.cash) {
        totalCash += r.totalAmount;
      } else {
        totalCheque += r.totalAmount;
        cheques.add(ChequeSummaryItem(
          chequeNumber: r.chequeNumber ?? 'N/A',
          bank: r.bank ?? 'N/A',
          customerCode: r.customerCode,
          customerName: r.customerName,
          amount: r.totalAmount,
          chequeDate: r.chequeDate ?? r.createdAt,
        ));
      }
    }

    return DayEndSummary(
      date: targetDate,
      collectorId: collectorId,
      collectorName: collectorName,
      totalCash: totalCash,
      totalCheque: totalCheque,
      chequesList: cheques,
      totalIncome: totalCash + totalCheque,
      totalReceiptsCount: dayReceipts.length,
      isFinalized: isDayEndFinalized,
      finalizedAt: dayEndFinalizedAt,
    );
  }

  // Finalize Day-End: locks payment recording for today (Section 3)
  void finalizeDayEndSummary(String notes) {
    isDayEndFinalized = true;
    dayEndFinalizedAt = DateTime.now();

    _auditLogs.insert(0, AuditLog(
      id: 'AUD-${DateTime.now().millisecondsSinceEpoch}',
      action: 'DAY_END_FINALIZED',
      referenceNo: 'DAY-END-${dayEndFinalizedAt!.millisecondsSinceEpoch}',
      collectorId: collectorId,
      collectorName: collectorName,
      details: 'Finalized Day-End reconciliation. Cashier notes: $notes. Payment collection locked.',
      timestamp: DateTime.now(),
    ));

    notifyListeners();
  }

  // Manual unlock for admin/testing
  void unlockDayEndForTesting() {
    isDayEndFinalized = false;
    dayEndFinalizedAt = null;
    notifyListeners();
  }

  // --- Offline Sync Action ---
  Future<void> syncData() async {
    isSyncing = true;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 2));

    lastSyncTime = DateTime.now();
    pendingSyncCount = 0;
    isSyncing = false;

    _auditLogs.insert(0, AuditLog(
      id: 'AUD-${DateTime.now().millisecondsSinceEpoch}',
      action: 'SYNC',
      referenceNo: 'SYNC-${lastSyncTime.millisecondsSinceEpoch}',
      collectorId: collectorId,
      collectorName: collectorName,
      details: 'Offline synchronization completed with SQL Server database.',
      timestamp: DateTime.now(),
    ));

    notifyListeners();
  }
}
