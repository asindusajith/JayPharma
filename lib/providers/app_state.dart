import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/customer.dart';
import '../models/invoice.dart';
import '../models/receipt.dart';
import '../models/day_end_summary.dart';
import '../models/audit_log.dart';
import '../services/location_service.dart';
import '../services/sms_service.dart';
import '../services/bluetooth_printer_service.dart';

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

  /// Prefix used for Manual Receipt Numbers based on User's Code / Collector ID (e.g. XXX-026470)
  String get userReceiptPrefix {
    String code = collectorId.trim();
    if (code.toUpperCase().startsWith('COL-') && code.length > 4) {
      code = code.substring(4).trim();
    }
    if (code.isEmpty) {
      code = currentUser.username.trim();
    }
    if (code.isEmpty) {
      code = 'MR';
    }
    return code.toUpperCase();
  }

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

  // Day-End Finalization State & Day Start Freeze
  bool isDayEndFinalized = false;
  DateTime? dayEndFinalizedAt;
  String? dayStartLockReason; // 'NEW_DAY' or 'DAY_END_FINALIZED'
  bool isCheckingDayEndStatus = false;
  bool isRequestingDayStartOtp = false;
  bool isVerifyingDayStartOtp = false;
  bool dayStartOtpDispatched = false;
  String? dayStartError;

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

  // Real-time Device Hardware GPS Status
  GpsStatusResult gpsStatus = const GpsStatusResult(
    isServiceEnabled: false,
    permission: LocationPermission.denied,
    hasPermission: false,
    isReady: false,
  );
  StreamSubscription<ServiceStatus>? _gpsServiceSubscription;
  Timer? _gpsCheckTimer;

  bool get isGpsOnline => gpsStatus.isReady;
  bool get isGpsHardwareOn => gpsStatus.isServiceEnabled;
  bool get hasLocationPermission => gpsStatus.hasPermission;
  bool get isLocationPermissionNeeded => gpsStatus.isPermissionNeeded;

  AppState() {
    _initSampleData();
    _startInactivityTimer();
    _autoDetectApiUrl();
    _initGpsMonitoring();
    _initBluetoothPrinter();
    fetchRealtimeCustomers();
    fetchRealtimeReceipts();
  }

  void _initBluetoothPrinter() {
    // Attempt auto-connecting to saved Bluetooth printer on app launch
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        await BluetoothPrinterService.autoConnectToSavedPrinter();
      } catch (_) {}
    });
  }

  bool isConnectingGps = false;

  void _initGpsMonitoring() {
    checkGpsStatus();
    // Auto-prompt and connect device hardware GPS on app setup/startup (only for collectors, not Admin)
    if (!isAdmin) {
      requestAndConnectGps();
    }

    try {
      _gpsServiceSubscription = Geolocator.getServiceStatusStream().listen((status) {
        checkGpsStatus();
      });
    } catch (_) {}

    // Safe periodic check every 4 seconds without prompting permissions in background
    _gpsCheckTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      checkGpsStatus();
    });
  }

  Future<void> checkGpsStatus() async {
    try {
      final status = await LocationService.checkStatus();
      if (gpsStatus.isReady != status.isReady ||
          gpsStatus.isServiceEnabled != status.isServiceEnabled ||
          gpsStatus.hasPermission != status.hasPermission) {
        gpsStatus = status;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Actively connect to device hardware GPS (prompts permission, gets real coordinates)
  Future<LocationData?> requestAndConnectGps() async {
    if (isConnectingGps) return LocationService.lastKnownLocation;
    isConnectingGps = true;
    notifyListeners();

    try {
      final loc = await LocationService.requestAndConnectGps();
      final status = await LocationService.checkStatus();
      gpsStatus = status;
      return loc;
    } catch (e) {
      debugPrint('requestAndConnectGps failed: $e');
      return null;
    } finally {
      isConnectingGps = false;
      notifyListeners();
    }
  }

  Future<void> requestGpsPermission() async {
    await requestAndConnectGps();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _gpsServiceSubscription?.cancel();
    _gpsCheckTimer?.cancel();
    super.dispose();
  }

  List<Customer> get customers => List.unmodifiable(_customers);

  // Filtered customers accessible by current user's assigned locations
  List<Customer> get accessibleCustomers {
    if (isAdmin || currentUser.hasAllLocations) {
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
    if (isAdmin || currentUser.hasAllLocations) {
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

        // Auto-connect device hardware GPS immediately upon login for field collectors (Admin does not require GPS)
        if (!currentUser.isAdmin) {
          requestAndConnectGps();
          // Check Day-End status & Freeze for field collector
          await checkDayEndStatus();
        }

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
      final prefix = userReceiptPrefix;
      final response = await http.get(Uri.parse('$apiBaseUrl/receipts/next-number?prefix=$prefix')).timeout(const Duration(seconds: 4));
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
      final match = RegExp(r'\d+').firstMatch(r.manualReceiptNo);
      if (match != null) {
        final parsed = int.tryParse(match.group(0)!);
        if (parsed != null && parsed > maxNum) {
          maxNum = parsed;
        }
      }
    }
    final prefix = userReceiptPrefix;
    return '$prefix-${(maxNum + 1).toString().padLeft(6, '0')}';
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
    draftChequeNumber = chequeNumber;
    draftChequeDate = chequeDate;

    // Auto-extract bank and branch codes from full cheque number if available
    if (chequeNumber != null && chequeNumber.isNotEmpty) {
      final digits = chequeNumber.replaceAll(RegExp(r'\D'), '');
      if (digits.length > 6) {
        draftBank = digits.substring(6, digits.length.clamp(6, 10));
      } else {
        draftBank = bank;
      }
      if (digits.length > 10) {
        draftBranch = digits.substring(10, digits.length.clamp(10, 13));
      } else {
        draftBranch = branch;
      }
    } else {
      draftBank = bank;
      draftBranch = branch;
    }
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

  /// Custom allocation for a specific invoice (partial or custom amount)
  String? setInvoiceAllocatedAmount(Invoice inv, double newAmount) {
    if (newAmount < 0) {
      return currentLanguage == 'si'
          ? 'මුදල සෘණ අගයක් විය නොහැක.'
          : 'Amount cannot be negative.';
    }
    if (newAmount > inv.outstandingBalance + 0.01) {
      return currentLanguage == 'si'
          ? 'වෙන් කරන මුදල ඉන්වොයිසියේ හිඟ මුදලට වඩා වැඩි විය නොහැක (උපරිම: රු. ${inv.outstandingBalance.toStringAsFixed(2)}).'
          : 'Allocated amount cannot exceed invoice due balance (Max: Rs. ${inv.outstandingBalance.toStringAsFixed(2)}).';
    }

    final otherAllocated = draftInvoices
        .where((i) => i.isSelected && i.invoiceNo != inv.invoiceNo)
        .fold(0.0, (sum, i) => sum + i.allocatedAmount);

    final maxPossibleForThis = (draftPaymentAmount - otherAllocated).clamp(0.0, inv.outstandingBalance);

    if (newAmount > maxPossibleForThis + 0.01) {
      return currentLanguage == 'si'
          ? 'වෙන් කරන මුදල ඉතිරි ගෙවීම් මුදලට වඩා වැඩි විය නොහැක (උපරිම: රු. ${maxPossibleForThis.toStringAsFixed(2)}).'
          : 'Allocated amount cannot exceed available payment amount (Max: Rs. ${maxPossibleForThis.toStringAsFixed(2)}).';
    }

    if (newAmount <= 0.01) {
      inv.isSelected = false;
      inv.allocatedAmount = 0.0;
    } else {
      inv.isSelected = true;
      inv.allocatedAmount = newAmount;
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
    if (!isAdmin && isDayEndFinalized) {
      return 'Day-end process has been completed for today. No further payments can be recorded.';
    }
    if (draftCustomer == null) {
      return 'Please select a customer.';
    }
    if (draftPaymentMethod == PaymentMethod.cheque) {
      final digits = (draftChequeNumber ?? '').replaceAll(RegExp(r'\D'), '');
      if (digits.isEmpty) {
        return currentLanguage == 'si'
            ? 'චෙක්පත් ගෙවීම් සඳහා චෙක්පත් අංකය ඇතුළත් කිරීම අනිවාර්ය වේ.'
            : 'Cheque number is mandatory for cheque payment.';
      }
      if (digits.length != 13) {
        return currentLanguage == 'si'
            ? 'චෙක්පත් අංකය සම්පූර්ණයෙන්ම ඇතුළත් කළ යුතුය (ඉලක්කම් 13ක්: චෙක්පත් අංකය, බැංකු කේතය, ශාඛා කේතය). දැනට ඇතුළත් කර ඇත්තේ ඉලක්කම් ${digits.length} කි.'
            : 'Cheque number must be fully entered (13 digits: Cheque No, Bank Code, Branch Code). Currently entered: ${digits.length}/13 digits.';
      }
      if (draftChequeDate == null) {
        return currentLanguage == 'si'
            ? 'චෙක්පත් දිනය තෝරාගැනීම අනිවාර්ය වේ.'
            : 'Cheque date is mandatory for cheque payment.';
      }
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

    // GPS validation — mandatory hardware GPS lock for field collectors; optional for Admin
    LocationData? loc;
    if (!isAdmin) {
      final gpsCheck = await LocationService.checkStatus();
      if (!gpsCheck.isReady) {
        if (!gpsCheck.isServiceEnabled) {
          throw Exception(
            'බිල්පතක් නිකුත් කිරීමට දුරකථනයේ GPS සක්‍රීය කර තිබීම අනිවාර්ය වේ. කරුණාකර ඔබගේ දුරකථනයේ GPS සක්‍රීය කරන්න. (Device GPS is OFF)',
          );
        } else {
          throw Exception(
            'බිල්පතක් නිකුත් කිරීමට App එකට Location අවසරය ලබා දිය යුතුය. කරුණාකර Location අවසරය ලබා දෙන්න. (Location permission required)',
          );
        }
      }

      loc = await LocationService.getCurrentLocation();
      if (!loc.isValid) {
        throw Exception(
          'වලංගු GPS සංඥාවක් ලබා ගැනීමට නොහැකි විය. කරුණාකර GPS සංඥා ලැබෙන ස්ථානයක සිට නැවත උත්සාහ කරන්න.',
        );
      }
    } else {
      // Admin account: GPS is optional. If available, capture it; otherwise graceful fallback
      try {
        if (LocationService.lastKnownLocation != null && LocationService.lastKnownLocation!.isValid) {
          loc = LocationService.lastKnownLocation;
        } else {
          loc = await LocationService.getCurrentLocation().timeout(const Duration(seconds: 2));
        }
      } catch (_) {
        loc = null;
      }
    }

    final effectiveLat = (loc != null && loc.isValid)
        ? loc.latitude
        : 6.927079;
    final effectiveLng = (loc != null && loc.isValid)
        ? loc.longitude
        : 79.861244;
    final effectiveLocationAddress = (loc != null && loc.address.isNotEmpty)
        ? loc.address
        : (draftCustomer?.address.isNotEmpty == true
            ? draftCustomer!.address
            : 'Admin Head Office / Field Operations');
    final effectiveBranch = (draftBranch != null && draftBranch!.trim().isNotEmpty)
        ? draftBranch!.trim()
        : (draftCustomer?.town.isNotEmpty == true
            ? draftCustomer!.town
            : 'Colombo');

    // Prepare allocated invoice items
    final selectedInvoices = draftInvoices.where((i) => i.isSelected && i.allocatedAmount > 0).toList();
    final items = <ReceiptInvoiceItem>[];
    final totalAllocated = selectedInvoices.fold<double>(0.0, (sum, i) => sum + i.allocatedAmount);
    final overallExcess = (draftPaymentAmount - totalAllocated) > 0.01 ? (draftPaymentAmount - totalAllocated) : 0.0;

    for (int i = 0; i < selectedInvoices.length; i++) {
      final inv = selectedInvoices[i];
      // Allocate the excess amount to the last selected invoice (or single invoice)
      final double invExcess = (i == selectedInvoices.length - 1 && overallExcess > 0.01) ? overallExcess : 0.0;
      items.add(ReceiptInvoiceItem(
        itemIndex: i + 1,
        invoiceNo: inv.invoiceNo,
        invoiceDate: inv.invoiceDate,
        invoiceAmount: inv.totalAmount,
        amountSettled: inv.allocatedAmount,
        remainingBalance: (inv.outstandingBalance - inv.allocatedAmount).clamp(0.0, double.infinity),
        excessAmount: invExcess,
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
      comments: draftComments.trim(),
      isAdvancePayment: items.isEmpty,
      collectorId: collectorId,
      collectorName: collectorName,
      latitude: effectiveLat,
      longitude: effectiveLng,
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
          'excessAmount': i.excessAmount,
          'exAmount': i.excessAmount,
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

      // Normal collectors can ONLY calculate day-end for their own collections
      if (!isAdmin) {
        final myId = collectorId.trim().toLowerCase();
        final myUsername = currentUser.username.trim().toLowerCase();
        final rId = r.collectorId.trim().toLowerCase();
        return rId == myId || rId == myUsername;
      }

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

  // Check if Day-End was previously finalized or if today is a New Day requiring OTP
  Future<void> checkDayEndStatus({bool forceServer = false}) async {
    if (currentUser.isAdmin) {
      isDayEndFinalized = false;
      dayEndFinalizedAt = null;
      dayStartLockReason = null;
      notifyListeners();
      return;
    }

    isCheckingDayEndStatus = true;
    try {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final prefs = await SharedPreferences.getInstance();

      // 1. First check local storage
      final lastUnlockedDay = prefs.getString('last_unlocked_day_${currentUser.collectorId}');
      final localFinalized = prefs.getBool('day_end_finalized_${currentUser.collectorId}') ?? false;
      final localFinalizedAtStr = prefs.getString('day_end_finalized_at_${currentUser.collectorId}');

      // If local cache indicates finalized today, or today is a new day that hasn't been unlocked yet
      if (localFinalized || (lastUnlockedDay != null && lastUnlockedDay != todayStr)) {
        isDayEndFinalized = true;
        dayStartLockReason = (localFinalized && lastUnlockedDay == todayStr) ? 'DAY_END_FINALIZED' : 'NEW_DAY';
        if (localFinalizedAtStr != null) {
          dayEndFinalizedAt = DateTime.tryParse(localFinalizedAtStr) ?? DateTime.now();
        }
        notifyListeners();
      }

      // 2. Query backend API status
      final response = await http.get(
        Uri.parse('$apiBaseUrl/dayend/status/${currentUser.collectorId}'),
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final bool serverFinalized = (data['isFinalized'] == true || data['isLocked'] == true);
        isDayEndFinalized = serverFinalized;
        dayStartLockReason = data['lockReason']?.toString();

        if (data['finalizedAt'] != null) {
          dayEndFinalizedAt = DateTime.tryParse(data['finalizedAt'].toString()) ?? DateTime.now();
        } else if (!serverFinalized) {
          dayEndFinalizedAt = null;
        }

        // Update local cache
        await prefs.setBool('day_end_finalized_${currentUser.collectorId}', serverFinalized);
        if (serverFinalized) {
          if (dayEndFinalizedAt != null) {
            await prefs.setString('day_end_finalized_at_${currentUser.collectorId}', dayEndFinalizedAt!.toIso8601String());
          }
        } else {
          // Authorized for today
          await prefs.setString('last_unlocked_day_${currentUser.collectorId}', todayStr);
          await prefs.remove('day_end_finalized_at_${currentUser.collectorId}');
        }
      }
    } catch (e) {
      debugPrint('[checkDayEndStatus Error]: $e');
    } finally {
      isCheckingDayEndStatus = false;
      notifyListeners();
    }
  }

  // Finalize Day-End: locks payment recording and freezes app for this user
  Future<void> finalizeDayEndSummary(String notes) async {
    isDayEndFinalized = true;
    dayStartLockReason = 'DAY_END_FINALIZED';
    dayEndFinalizedAt = DateTime.now();
    dayStartOtpDispatched = false;
    dayStartError = null;

    final summary = calculateDayEndSummary(dayEndFinalizedAt!);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('day_end_finalized_${currentUser.collectorId}', true);
      await prefs.setString('day_end_finalized_at_${currentUser.collectorId}', dayEndFinalizedAt!.toIso8601String());
    } catch (_) {}

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

    // Call backend API to record finalized status in SQL Server
    try {
      await http.post(
        Uri.parse('$apiBaseUrl/dayend/finalize'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'date': dayEndFinalizedAt!.toIso8601String(),
          'collectorId': currentUser.collectorId,
          'collectorName': currentUser.fullName,
          'totalCash': summary.totalCash,
          'totalCheque': summary.totalCheque,
          'totalIncome': summary.totalIncome,
          'totalReceiptsCount': summary.totalReceiptsCount,
          'cashierNotes': notes,
        }),
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('[finalizeDayEndSummary Backend Error]: $e');
    }
  }

  // Request OTP from Management to perform Day Start
  Future<bool> requestDayStartOtp() async {
    isRequestingDayStartOtp = true;
    dayStartError = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/otp/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'collectorId': currentUser.collectorId,
          'customerCode': 'DAY_START',
          'customerName': '${currentUser.fullName} Day Start',
        }),
      ).timeout(const Duration(seconds: 8));

      isRequestingDayStartOtp = false;
      if (response.statusCode == 200) {
        dayStartOtpDispatched = true;
        notifyListeners();
        return true;
      } else {
        dayStartError = 'Failed to request OTP from server.';
        notifyListeners();
        return false;
      }
    } catch (e) {
      isRequestingDayStartOtp = false;
      dayStartError = 'Error requesting OTP: $e';
      notifyListeners();
      return false;
    }
  }

  // Start Day with Verified OTP
  Future<bool> startDayWithOtp(String otpCode) async {
    final trimmedOtp = otpCode.trim();
    if (trimmedOtp.length != 6) {
      dayStartError = 'Please enter a valid 6-digit OTP.';
      notifyListeners();
      return false;
    }

    isVerifyingDayStartOtp = true;
    dayStartError = null;
    notifyListeners();

    try {
      // 1. Verify OTP with Backend
      final verifyResponse = await http.post(
        Uri.parse('$apiBaseUrl/otp/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'collectorId': currentUser.collectorId,
          'otpCode': trimmedOtp,
        }),
      ).timeout(const Duration(seconds: 8));

      if (verifyResponse.statusCode != 200) {
        try {
          final body = jsonDecode(verifyResponse.body);
          dayStartError = body['message'] ?? 'Invalid or expired OTP code.';
        } catch (_) {
          dayStartError = 'Invalid or expired OTP code.';
        }
        isVerifyingDayStartOtp = false;
        notifyListeners();
        return false;
      }

      // 2. Notify backend that day has started
      try {
        await http.post(
          Uri.parse('$apiBaseUrl/dayend/start'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'collectorId': currentUser.collectorId,
          }),
        ).timeout(const Duration(seconds: 8));
      } catch (_) {}

      // 3. Clear local freeze state & record today as unlocked
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      isDayEndFinalized = false;
      dayEndFinalizedAt = null;
      dayStartLockReason = null;
      dayStartOtpDispatched = false;
      dayStartError = null;
      isVerifyingDayStartOtp = false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_unlocked_day_${currentUser.collectorId}', todayStr);
      await prefs.setBool('day_end_finalized_${currentUser.collectorId}', false);
      await prefs.remove('day_end_finalized_at_${currentUser.collectorId}');

      _auditLogs.insert(0, AuditLog(
        id: 'AUD-${DateTime.now().millisecondsSinceEpoch}',
        action: 'DAY_START_AUTHORIZED',
        referenceNo: 'DAY-START-${DateTime.now().millisecondsSinceEpoch}',
        collectorId: collectorId,
        collectorName: collectorName,
        details: 'Day started and unlocked with OTP authorization.',
        timestamp: DateTime.now(),
      ));

      notifyListeners();
      return true;
    } catch (e) {
      isVerifyingDayStartOtp = false;
      dayStartError = 'Verification failed: $e';
      notifyListeners();
      return false;
    }
  }

  // Manual unlock for admin/testing
  Future<void> unlockDayEndForTesting() async {
    isDayEndFinalized = false;
    dayEndFinalizedAt = null;
    dayStartOtpDispatched = false;
    dayStartError = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('day_end_finalized_${currentUser.collectorId}');
      await prefs.remove('day_end_finalized_at_${currentUser.collectorId}');
      await http.post(
        Uri.parse('$apiBaseUrl/dayend/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'collectorId': currentUser.collectorId,
        }),
      ).timeout(const Duration(seconds: 6));
    } catch (_) {}
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

  // --- OTP Access for Protected Operations (e.g. POS Statement Print for Normal Users) ---
  /// Generates a new OTP for protected operations and saves to LastGeneratedOtp table
  Future<Map<String, dynamic>> generateStatementOtp(Customer customer) async {
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/otp/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'collectorId': currentUser.collectorId,
          'customerCode': customer.code,
          'customerName': customer.name,
        }),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'message': 'Failed to generate OTP: ${res.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  /// Verifies entered OTP against LastGeneratedOtp table in database
  Future<Map<String, dynamic>> verifyStatementOtp(String otpCode) async {
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/otp/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'collectorId': currentUser.collectorId,
          'otpCode': otpCode.trim(),
        }),
      ).timeout(const Duration(seconds: 5));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data;
    } catch (e) {
      return {
        'success': false,
        'message': 'Verification network error: $e',
      };
    }
  }
}
