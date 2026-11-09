import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/app_user.dart';
import '../../models/customer.dart';
import '../../theme/app_theme.dart';
import '../../services/localization_service.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../models/receipt.dart';
import '../../services/receipt_printer_service.dart';
import '../../services/bluetooth_printer_service.dart';
import '../../services/app_lock_service.dart';
import 'user_management_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<BluetoothPrinterDevice> _pairedPrinters = [];
  BluetoothPrinterDevice? _selectedPrinterDevice;
  bool _isScanningPrinters = false;
  bool _isConnectingPrinter = false;
  bool _isPrintingTest = false;
  bool _is80mm = true;
  bool _isBluetoothEnabled = true;

  bool _isAppLockEnabled = false;
  bool _isTogglingAppLock = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppState>(context, listen: false).fetchAllUsers();
      _loadBluetoothPrinters();
      _checkAppLockStatus();
    });
  }

  Future<void> _checkAppLockStatus() async {
    final enabled = await AppLockService.isAppLockEnabled();
    if (mounted) setState(() => _isAppLockEnabled = enabled);
  }

  Future<void> _handleToggleAppLock(bool enable, String lang) async {
    final isSi = lang == 'si';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              enable ? Icons.screen_lock_portrait_rounded : Icons.lock_open_rounded,
              color: enable ? const Color(0xFF16A34A) : const Color(0xFFD97706),
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              enable
                  ? (isSi ? 'App Lock සක්‍රීය කරන්නද?' : 'Enable App Lock?')
                  : (isSi ? 'App Lock අක්‍රිය කරන්නද?' : 'Disable App Lock?'),
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          enable
              ? (isSi
                  ? 'මෙම පහසුකම සක්‍රීය කළ විට:\n\n• Device එක On කළ සැනින් Home screen එක මඟහැර JayPharma App එක පමණක් විවෘත වේ.\n• Reps ලාට වෙනත් කිසිදු App එකක් භාවිත කළ නොහැක.\n• Settings වෙතින් මෙය OFF කරන තුරු සාමාන්‍ය Android Home screen එකට පිවිසිය නොහැක.\n\nමෙය සක්‍රීය කිරීමට ඔබට අවශ්‍යද?'
                  : 'Enabling App Lock will lock this device to JayPharma as a dedicated kiosk terminal:\n\n• The device will boot directly into JayPharma and bypass the home screen.\n• All other apps on the device will be blocked.\n• Normal access can be restored only by turning this OFF in Settings.\n\nDo you want to proceed?')
              : (isSi
                  ? 'App Lock අක්‍රිය කළ පසු සාමාන්‍ය පරිදි Device එකේ Home screen එකට සහ අනෙකුත් Apps වෙත ප්‍රවේශ වීමට අවසර ලැබේ.\n\nApp Lock අක්‍රිය කිරීමට ඔබට අවශ්‍යද?'
                  : 'Disabling App Lock will restore standard device access, home screen launcher, and other apps.\n\nDo you want to disable App Lock?'),
          style: GoogleFonts.inter(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(LocalizationService.tr('cancel', lang: lang)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: enable ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(enable
                ? (isSi ? 'ඔව්, Lock කරන්න' : 'Enable Lock')
                : (isSi ? 'අක්‍රිය කරන්න' : 'Disable & Unlock')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isTogglingAppLock = true);
    try {
      final success = await AppLockService.setAppLockEnabled(enable);
      if (mounted) {
        setState(() => _isAppLockEnabled = enable);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enable
                  ? (isSi
                      ? '🔒 App Lock සක්‍රීය කරන ලදී! Device එක JayPharma වලට Lock කර ඇත.'
                      : '🔒 App Lock activated! Device is now locked to JayPharma.')
                  : (isSi
                      ? '🔓 App Lock අක්‍රිය කරන ලදී. සාමාන්‍ය Device Access ලබා දෙන ලදී.'
                      : '🔓 App Lock deactivated. Normal device access restored.'),
            ),
            backgroundColor: enable ? const Color(0xFF16A34A) : const Color(0xFF1E293B),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTogglingAppLock = false);
    }
  }

  Future<void> _loadBluetoothPrinters() async {
    setState(() => _isScanningPrinters = true);
    try {
      final isBtOn = await BluetoothPrinterService.isBluetoothEnabled();
      _isBluetoothEnabled = isBtOn;

      final devices = await BluetoothPrinterService.getPairedDevices(requestPerm: true);
      final saved = await BluetoothPrinterService.getSavedPrinter();

      BluetoothPrinterDevice? current;
      if (saved != null) {
        current = devices.firstWhere(
          (d) => d.address == saved.address,
          orElse: () => saved,
        );
      } else if (devices.isNotEmpty) {
        current = devices.first;
      }

      if (mounted) {
        setState(() {
          _pairedPrinters = devices;
          _selectedPrinterDevice = current;
          _isScanningPrinters = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isScanningPrinters = false);
      }
    }
  }

  Future<void> _connectToPrinter(BluetoothPrinterDevice device, String lang) async {
    setState(() => _isConnectingPrinter = true);
    try {
      final success = await BluetoothPrinterService.connect(device.address, printerName: device.name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? (lang == 'si'
                      ? '${device.name} මුද්‍රණ යන්ත්‍රය සාර්ථකව සම්බන්ධ විය!'
                      : '${device.name} connected successfully!')
                  : (lang == 'si'
                      ? 'සම්බන්ධ වීමට නොහැකි විය. මුද්‍රණ යන්ත්‍රය ක්‍රියාත්මක කර ඇත්දැයි බලන්න.'
                      : 'Connection failed. Please ensure the printer is turned ON and nearby.'),
            ),
            backgroundColor: success ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          ),
        );
      }
      await _loadBluetoothPrinters();
    } finally {
      if (mounted) setState(() => _isConnectingPrinter = false);
    }
  }

  Future<void> _disconnectPrinter(String lang) async {
    await BluetoothPrinterService.disconnect();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang == 'si' ? 'මුද්‍රණ යන්ත්‍රය විසන්ධි කරන ලදී.' : 'Printer disconnected.'),
        ),
      );
    }
    await _loadBluetoothPrinters();
  }

  Future<void> _runTestPrint(String lang) async {
    setState(() => _isPrintingTest = true);
    try {
      final isConn = await BluetoothPrinterService.isConnected();
      if (!isConn && _selectedPrinterDevice != null) {
        await BluetoothPrinterService.connect(_selectedPrinterDevice!.address, printerName: _selectedPrinterDevice!.name);
      }

      final success = await BluetoothPrinterService.printTestTicket(is80mm: _is80mm);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? (lang == 'si'
                      ? 'පරීක්ෂණ බිල්පත ${_selectedPrinterDevice?.name ?? "මුද්‍රණ යන්ත්‍රය"} වෙත සාර්ථකව යවන ලදී!'
                      : 'Test print sent to ${_selectedPrinterDevice?.name ?? "Printer"} successfully!')
                  : (lang == 'si'
                      ? 'මුද්‍රණය අසාර්ථක විය. බ්ලූටූත් සම්බන්ධතාව පරීක්ෂා කරන්න.'
                      : 'Print failed. Please verify Bluetooth connection.'),
            ),
            backgroundColor: success ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Test print error: $e'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrintingTest = false);
    }
  }

  void _showManualMacDialog(BuildContext context, String lang) {
    final isSi = lang == 'si';
    final macController = TextEditingController(text: _selectedPrinterDevice?.address ?? '');
    final nameController = TextEditingController(text: _selectedPrinterDevice?.name ?? 'Bluetooth Thermal Printer');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.bluetooth_searching, color: AppTheme.primaryBlue, size: 22),
            const SizedBox(width: 8),
            Text(
              isSi ? 'සෘජු MAC ලිපිනයෙන් සම්බන්ධ වන්න' : 'Connect by MAC Address',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSi
                  ? 'Bluetooth මුද්‍රණ යන්ත්‍රයේ යට ඇති ලේබලයේ හෝ Self-Test රිසිට්පතේ සඳහන් Bluetooth MAC Address එක ඇතුළත් කරන්න:'
                  : 'Enter the Bluetooth MAC Address from the thermal printer label or self-test printout:',
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: isSi ? 'මුද්‍රණ යන්ත්‍රයේ නම' : 'Printer Model / Name',
                hintText: 'e.g. POS-80 / RPP02N / MTP-II',
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: macController,
              decoration: InputDecoration(
                labelText: isSi ? 'Bluetooth MAC Address (අනිවාර්යයි)' : 'Bluetooth MAC Address (Required)',
                hintText: 'e.g. 66:02:BD:06:18:7B',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(LocalizationService.tr('cancel', lang: lang)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final mac = macController.text.trim();
              final name = nameController.text.trim().isNotEmpty ? nameController.text.trim() : 'Bluetooth POS Printer';
              if (mac.isEmpty) return;
              Navigator.pop(ctx);
              final device = BluetoothPrinterDevice(name: name, address: mac);
              setState(() {
                if (!_pairedPrinters.any((p) => p.address == mac)) {
                  _pairedPrinters.add(device);
                }
                _selectedPrinterDevice = device;
              });
              await _connectToPrinter(device, lang);
            },
            child: Text(isSi ? 'සම්බන්ධ වන්න' : 'Connect'),
          ),
        ],
      ),
    );
  }

  Future<void> _showBluetoothDiagnostics(BuildContext context, String lang) async {
    final isSi = lang == 'si';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final diag = await BluetoothPrinterService.getDiagnostics();
    if (context.mounted) Navigator.pop(context);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final bool isBtOn = diag["bluetoothEnabled"] == true;
          final bool isPermGranted = diag["permissionGranted"] == true;
          final bonded = diag['bondedDevices'] as List<dynamic>? ?? [];

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.troubleshoot, color: AppTheme.primaryBlue, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isSi ? 'Bluetooth දෝෂ විනිශ්චය' : 'Bluetooth Diagnostics',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Bluetooth Power
                  Row(
                    children: [
                      Icon(
                        isBtOn ? Icons.check_circle : Icons.cancel,
                        color: isBtOn ? const Color(0xFF16A34A) : AppTheme.dangerRed,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Bluetooth Power: ${isBtOn ? (isSi ? "ක්‍රියාත්මකයි (ON)" : "Enabled (ON)") : (isSi ? "ක්‍රියා විරහිතයි (OFF)" : "Disabled (OFF)")}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // 2. Permission Status
                  Row(
                    children: [
                      Icon(
                        isPermGranted ? Icons.check_circle : Icons.warning_amber_rounded,
                        color: isPermGranted ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Permissions: ${isPermGranted ? (isSi ? "ලබා දී ඇත (Granted)" : "Granted") : (isSi ? "ලබා දී නැත (Denied)" : "Denied")}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  if (diag.containsKey('btConnect'))
                    Padding(
                      padding: const EdgeInsets.only(left: 22, top: 2),
                      child: Text('BLUETOOTH_CONNECT: ${diag["btConnect"]}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    ),
                  if (diag.containsKey('btScan'))
                    Padding(
                      padding: const EdgeInsets.only(left: 22, top: 2),
                      child: Text('BLUETOOTH_SCAN: ${diag["btScan"]}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    ),

                  if (!isPermGranted) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.security, size: 16),
                        label: Text(
                          isSi ? 'Bluetooth Permissions ලබා දෙන්න (Allow)' : 'Grant Bluetooth Permissions',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await BluetoothPrinterService.requestPermission();
                          await BluetoothPrinterService.openAppPermissionSettings();
                          if (context.mounted) _loadBluetoothPrinters();
                        },
                      ),
                    ),
                  ],

                  const Divider(height: 20),

                  // 3. Paired Devices in Android OS
                  Text(
                    isSi ? 'Android OS හි ඇති Paired Devices:' : 'Bonded Devices in Android OS:',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  if (bonded.isNotEmpty)
                    ...bonded.map((d) {
                      final name = d is Map ? (d['name'] ?? 'Device') : d.toString();
                      final addr = d is Map ? (d['address'] ?? '') : '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '$name\n$addr',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                final dev = BluetoothPrinterDevice(name: name.toString(), address: addr.toString());
                                setState(() {
                                  if (!_pairedPrinters.any((p) => p.address == addr)) _pairedPrinters.add(dev);
                                  _selectedPrinterDevice = dev;
                                });
                                _connectToPrinter(dev, lang);
                              },
                              child: Text(isSi ? 'Connect' : 'Connect', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                    })
                  else
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isSi
                                ? 'Android OS හි Paired උපාංග කිසිවක් හමු නොවීය.\n\nකරුණාකර දුරකථනයේ Settings -> Bluetooth වෙත ගොස් Printer එක Pair (PIN: 0000 හෝ 1234) කරගන්න.'
                                : 'No bonded Bluetooth devices found in Android OS.\n\nPlease pair the printer in phone Bluetooth Settings (PIN: 0000 or 1234) first.',
                            style: const TextStyle(fontSize: 11, color: AppTheme.dangerRed, height: 1.4),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.settings_bluetooth, size: 16),
                            label: Text(isSi ? 'දුරකථනයේ Bluetooth Settings' : 'Open Phone BT Settings', style: const TextStyle(fontSize: 11)),
                            onPressed: () {
                              Navigator.pop(ctx);
                              BluetoothPrinterService.openBluetoothSettings();
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(isSi ? 'වසන්න' : 'Close'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.radar, size: 16),
                label: Text(isSi ? 'අවට පරිලෝකනය (Live Scan)' : 'Live Scan Nearby'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryNavy,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _loadBluetoothPrinters();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _runSystemTestPrint(String lang) async {
    try {
      final dummyReceipt = Receipt(
        manualReceiptNo: 'TEST-0001',
        customerCode: 'CUST-001',
        customerName: 'Test Pharmacy Customer',
        customerAddress: 'Colombo, Sri Lanka',
        customerPhone: '0770000000',
        paymentMethod: PaymentMethod.cash,
        totalAmount: 1500.0,
        allocatedInvoices: [],
        collectorId: 'TEST-USER',
        collectorName: 'JayPharma Test Cashier',
        latitude: 6.9271,
        longitude: 79.8612,
        locationAddress: 'Colombo, Sri Lanka',
        createdAt: DateTime.now(),
      );
      final pdfBytes = await ReceiptPrinterService.generateReceiptPdf(dummyReceipt);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'JayPharma_Test_Print',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Print Spooler Error: $e')));
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final lang = appState.currentLanguage;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          LocalizationService.tr('settings', lang: lang),
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. User & Access Control Section (Compact Tile opening UserManagementScreen)
                _buildUserManagementCard(context, appState),
                const SizedBox(height: 16),

                // 2. App Lock (Dedicated Device / Kiosk Mode)
                _buildAppLockCard(context, lang),
                const SizedBox(height: 16),

                // Portable Receipt Printer Settings (Direct Bluetooth POS)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.print_outlined, color: AppTheme.primaryBlue, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  LocalizationService.tr('printer_section', lang: lang),
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: _isScanningPrinters
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.refresh, size: 20, color: AppTheme.primaryBlue),
                              tooltip: lang == 'si' ? 'බ්ලූටූත් මුද්‍රණ යන්ත්‍ර සොයන්න' : 'Scan for Bluetooth Printers',
                              onPressed: _isScanningPrinters ? null : _loadBluetoothPrinters,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (!_isBluetoothEnabled)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.bluetooth_disabled, color: AppTheme.dangerRed, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    lang == 'si' ? 'බ්ලූටූත් ක්‍රියාත්මක කර නැත. දුරකථනයේ Bluetooth On කරන්න.' : 'Bluetooth is turned OFF. Please turn on Bluetooth.',
                                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.dangerRed, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => BluetoothPrinterService.openBluetoothSettings(),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    child: Text(
                                      lang == 'si' ? 'On කරන්න' : 'Settings',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.dangerRed),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Dropdown with Paired Bluetooth Devices
                        DropdownButtonFormField<BluetoothPrinterDevice>(
                          value: _selectedPrinterDevice != null && _pairedPrinters.any((p) => p.address == _selectedPrinterDevice!.address)
                              ? _pairedPrinters.firstWhere((p) => p.address == _selectedPrinterDevice!.address)
                              : (_pairedPrinters.isNotEmpty ? _pairedPrinters.first : null),
                          decoration: InputDecoration(
                            labelText: LocalizationService.tr('printer_connected', lang: lang),
                            prefixIcon: Icon(
                              _selectedPrinterDevice?.isConnected == true ? Icons.bluetooth_connected : Icons.bluetooth,
                              color: _selectedPrinterDevice?.isConnected == true ? const Color(0xFF16A34A) : AppTheme.primaryBlue,
                              size: 20,
                            ),
                            suffixIcon: _isConnectingPrinter
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                  )
                                : null,
                          ),
                          isExpanded: true,
                          hint: Text(
                            lang == 'si' ? 'බ්ලූටූත් මුද්‍රණ යන්ත්‍රයක් තෝරන්න...' : 'Select paired Bluetooth printer...',
                            style: GoogleFonts.inter(fontSize: 12),
                          ),
                          items: _pairedPrinters.isEmpty
                              ? [
                                  DropdownMenuItem<BluetoothPrinterDevice>(
                                    value: null,
                                    enabled: false,
                                    child: Text(
                                      lang == 'si' ? 'සම්බන්ධිත බ්ලූටූත් මුද්‍රණ යන්ත්‍ර නැත' : 'No Paired Bluetooth Printers Found',
                                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                                    ),
                                  ),
                                ]
                              : _pairedPrinters.map((p) {
                                  return DropdownMenuItem<BluetoothPrinterDevice>(
                                    value: p,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.circle,
                                          size: 8,
                                          color: p.isConnected ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${p.name} (${p.address})',
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: p.isConnected ? FontWeight.bold : FontWeight.normal,
                                              color: p.isConnected ? const Color(0xFF166534) : AppTheme.textDark,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                          onChanged: (device) {
                            if (device != null) {
                              setState(() => _selectedPrinterDevice = device);
                              _connectToPrinter(device, lang);
                            }
                          },
                        ),
                        const SizedBox(height: 8),

                        // Action Buttons: Manual MAC + Phone Settings + Scan
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.add_link_rounded, size: 16),
                                label: Text(
                                  lang == 'si' ? '+ MAC ලිපිනය' : '+ Enter MAC',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  foregroundColor: AppTheme.primaryBlue,
                                ),
                                onPressed: () => _showManualMacDialog(context, lang),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.settings_bluetooth_rounded, size: 16),
                                label: Text(
                                  lang == 'si' ? 'BT Settings' : 'Pair in Settings',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  foregroundColor: const Color(0xFF334155),
                                ),
                                onPressed: () => BluetoothPrinterService.openBluetoothSettings(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: _isScanningPrinters
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.refresh_rounded, size: 20, color: AppTheme.primaryBlue),
                              tooltip: lang == 'si' ? 'අවසර ලබා ගෙන නැවත සොයන්න (Scan)' : 'Grant Permission & Re-scan',
                              onPressed: _isScanningPrinters ? null : _loadBluetoothPrinters,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.troubleshoot, size: 15, color: Color(0xFF1D4ED8)),
                            label: Text(
                              lang == 'si' ? 'Bluetooth දෝෂ විනිශ්චය (Diagnostics & Help)' : 'Bluetooth Diagnostics & Help',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              side: const BorderSide(color: Color(0xFFBFDBFE)),
                              backgroundColor: const Color(0xFFEFF6FF),
                            ),
                            onPressed: () => _showBluetoothDiagnostics(context, lang),
                          ),
                        ),

                        if (_pairedPrinters.isEmpty && !_isScanningPrinters) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.info_outline, size: 14, color: Color(0xFF1D4ED8)),
                                    const SizedBox(width: 6),
                                    Text(
                                      lang == 'si' ? 'මුද්‍රණ යන්ත්‍රය හමු නොවූයේද?' : 'Printer not showing in list?',
                                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF1D4ED8)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  lang == 'si'
                                      ? '1. දුරකථනයේ "BT Settings" වෙත ගොස් Printer එක Pair කර ඇත්දැයි බලන්න.\n2. ඉහත Refresh (🔄) ඔබා Android Bluetooth Permission "Allow" කරන්න.\n3. නැතහොත් "+ MAC ලිපිනය" ඔබා Printer එකේ MAC Address එක සෘජුව ඇතුළත් කරන්න.'
                                      : '1. Check "BT Settings" to confirm the printer is paired.\n2. Tap Refresh (🔄) and tap "Allow" on Bluetooth permission dialog.\n3. Or tap "+ Enter MAC" to connect directly using its MAC address.',
                                  style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF1E3A8A), height: 1.35),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),

                        // Connection Status Banner & Action Button
                        if (_selectedPrinterDevice != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedPrinterDevice!.isConnected ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _selectedPrinterDevice!.isConnected ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _selectedPrinterDevice!.isConnected ? Icons.check_circle : Icons.warning_amber_rounded,
                                      size: 16,
                                      color: _selectedPrinterDevice!.isConnected ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _selectedPrinterDevice!.isConnected
                                          ? (lang == 'si' ? 'සම්බන්ධයි (Direct ESC/POS Ready)' : 'Connected (Direct ESC/POS Ready)')
                                          : (lang == 'si' ? 'විසන්ධි වී ඇත' : 'Disconnected'),
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: _selectedPrinterDevice!.isConnected ? const Color(0xFF166534) : const Color(0xFF92400E),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_selectedPrinterDevice!.isConnected)
                                  InkWell(
                                    onTap: () => _disconnectPrinter(lang),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      child: Text(
                                        lang == 'si' ? 'විසන්ධි කරන්න' : 'Disconnect',
                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFDC2626)),
                                      ),
                                    ),
                                  )
                                else
                                  InkWell(
                                    onTap: () => _connectToPrinter(_selectedPrinterDevice!, lang),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      child: Text(
                                        lang == 'si' ? 'සම්බන්ධ වන්න' : 'Connect',
                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF1D4ED8)),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],

                        // Paper Size & Direct Test Print + System Print Fallback
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  lang == 'si' ? 'පත්‍ර: ' : 'Paper: ',
                                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                                ),
                                DropdownButton<bool>(
                                  value: _is80mm,
                                  isDense: true,
                                  underline: const SizedBox(),
                                  items: const [
                                    DropdownMenuItem(value: true, child: Text('80mm POS', style: TextStyle(fontSize: 11.5))),
                                    DropdownMenuItem(value: false, child: Text('58mm Mini', style: TextStyle(fontSize: 11.5))),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _is80mm = val);
                                  },
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: 6,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _runSystemTestPrint(lang),
                                  icon: const Icon(Icons.share, size: 13),
                                  label: Text(
                                    lang == 'si' ? 'Printer App' : 'App Print',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    side: const BorderSide(color: Color(0xFF0284C7)),
                                    foregroundColor: const Color(0xFF0284C7),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _isPrintingTest ? null : () => _runTestPrint(lang),
                                  icon: _isPrintingTest
                                      ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.print, size: 14),
                                  label: Text(
                                    LocalizationService.tr('test_print', lang: lang),
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryNavy,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // App Version & Auto-Update Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.system_update_rounded, color: Color(0xFF16A34A), size: 22),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lang == 'si' ? 'යෙදුම් අනුවාදය සහ යාවත්කාලීන' : 'App Version & Auto Updates',
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                                  ),
                                  Text(
                                    'Installed: v1.0.2 (Build 3) • GitHub Auto CI/CD',
                                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          lang == 'si'
                              ? 'Git push කළ පසු නවතම APK එක GitHub මඟින් ස්වයංක්‍රීයව Build වේ. පහත බටනය මඟින් නවතම APK එක ඕනෑම වේලාවක බාගත කර ස්ථාපනය කළ හැක.'
                              : 'Whenever code is pushed to GitHub, the latest release APK is automatically compiled in the cloud. Tap below to download the latest APK update.',
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textDark, height: 1.4),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: Text(
                              lang == 'si' ? 'නවතම APK එක බාගත කරන්න (Download Latest)' : 'Download Latest APK Update',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              final githubUrl = 'https://github.com/asindusajith/JayPharma/releases/download/latest/app-release.apk';
                              final localWifiUrl = 'http://192.168.1.18:8090/JayPharma-release.apk';
                              final serverApkUrl = '${appState.apiBaseUrl}/app/download-apk';
                              try {
                                final uri = Uri.parse(githubUrl);
                                final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
                                if (!launched) {
                                  await launchUrl(Uri.parse(localWifiUrl), mode: LaunchMode.externalApplication);
                                }
                              } catch (e) {
                                try {
                                  await launchUrl(Uri.parse(localWifiUrl), mode: LaunchMode.externalApplication);
                                } catch (_) {
                                  try {
                                    await launchUrl(Uri.parse(serverApkUrl), mode: LaunchMode.externalApplication);
                                  } catch (e2) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Could not open download link: $e2')),
                                      );
                                    }
                                  }
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Developer / Testing Helper
                if (appState.isDayEndFinalized) ...[
                  Card(
                    elevation: 0,
                    color: const Color(0xFFFEF2F2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.admin_panel_settings, color: AppTheme.dangerRed),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Testing Tool: Day-End is Locked', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                                Text('Unlock collection session for testing additional payments.', style: GoogleFonts.inter(fontSize: 11)),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              appState.unlockDayEndForTesting();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Day-end unlocked for test payments.')),
                              );
                            },
                            child: const Text('Unlock', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserManagementCard(BuildContext context, AppState appState) {
    final users = appState.allUsers;
    final lang = appState.currentLanguage;
    final isSi = lang == 'si';
    final activeCount = users.where((u) => u.isActive).length;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UserManagementScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.manage_accounts_rounded, color: Color(0xFF4F46E5), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              LocalizationService.tr('user_mgmt', lang: lang),
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF86EFAC)),
                              ),
                              child: Text(
                                isSi ? '$activeCountක් සක්‍රීයයි' : '$activeCount Active',
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isSi
                              ? 'ලියාපදිංචි පද්ධති පරිශීලකයින් (${users.length})'
                              : '${users.length} registered system users',
                          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.people_alt_rounded, size: 18),
                  label: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isSi ? 'පරිශීලකයින් (Users) කළමනාකරණය' : 'Manage Users (${users.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UserManagementScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppLockCard(BuildContext context, String lang) {
    final isSi = lang == 'si';

    return Card(
      elevation: 0,
      color: _isAppLockEnabled ? const Color(0xFFF0FDF4) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _isAppLockEnabled ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
          width: _isAppLockEnabled ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isAppLockEnabled ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isAppLockEnabled ? Icons.screen_lock_portrait_rounded : Icons.lock_open_rounded,
                    color: _isAppLockEnabled ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isSi ? 'App Lock (කැපවූ උපාංග ක්‍රමය)' : 'App Lock (Kiosk Mode)',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _isAppLockEnabled ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _isAppLockEnabled ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Text(
                              _isAppLockEnabled
                                  ? (isSi ? 'ක්‍රියාත්මකයි (ON)' : 'ACTIVE')
                                  : (isSi ? 'අක්‍රියයි (OFF)' : 'OFF'),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _isAppLockEnabled ? const Color(0xFF15803D) : AppTheme.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isSi ? 'JayPharma පමණක් විවෘත වන ලෙස දුරකථනය Lock කිරීම' : 'Lock device exclusively to JayPharma app',
                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: 0.9,
                  child: Switch(
                    value: _isAppLockEnabled,
                    activeColor: const Color(0xFF16A34A),
                    onChanged: _isTogglingAppLock ? null : (val) => _handleToggleAppLock(val, lang),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isAppLockEnabled ? const Color(0xFFDCFCE7).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isAppLockEnabled ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _isAppLockEnabled ? Icons.security_rounded : Icons.info_outline_rounded,
                    size: 16,
                    color: _isAppLockEnabled ? const Color(0xFF15803D) : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isSi
                          ? (_isAppLockEnabled
                              ? 'App Lock ක්‍රියාත්මකයි: දුරකථනය Restart කළද Home screen එක මඟහැර JayPharma පමණක් විවෘත වේ. වෙනත් කිසිදු App එකක් open කළ නොහැක. සාමාන්‍ය භාවිතයට ගැනීමට නම් මෙම Settings වෙතින් App Lock එක OFF කරන්න.'
                              : 'ON කළ විට: Device එක On කළ සැනින් Home screen එක මඟහැර කෙලින්ම JayPharma පමණක් විවෘත වේ. වෙනත් කිසිදු App එකක් open විය නොහැක. Settings වෙතින් OFF කළ පසු නැවත සාමාන්‍ය තත්වයට පත් වේ.')
                          : (_isAppLockEnabled
                              ? 'App Lock is Active: Device boots straight into JayPharma, bypassing the home screen. All other apps and task switching are blocked. Turn OFF here to restore normal Android access.'
                              : 'When ON: The device boots directly into JayPharma and prevents opening any other apps. Normal phone access can be restored at any time by turning this OFF here.'),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: _isAppLockEnabled ? const Color(0xFF14532D) : AppTheme.textDark,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_isAppLockEnabled && !kIsWeb) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.home_outlined, size: 16),
                  label: Text(
                    isSi ? 'Home Launcher Settings විවෘත කරන්න' : 'Open Default Home Settings',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF15803D),
                    side: const BorderSide(color: Color(0xFF86EFAC)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () => AppLockService.openHomeSettings(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
