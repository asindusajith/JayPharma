import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/customer.dart';
import '../../models/invoice.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../services/localization_service.dart';
import '../../services/receipt_printer_service.dart';
import '../payment/payment_details_screen.dart';

enum CustomerFilterTab { all, hasBalance, settled }

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  CustomerFilterTab _selectedTab = CustomerFilterTab.all;
  final Set<String> _expandedCustomerCodes = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppState>(context, listen: false).fetchRealtimeCustomers(force: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Requires OTP verification for Normal Users (Admin bypassed)
  Future<bool> _showOtpDialog(Customer customer) async {
    final appState = Provider.of<AppState>(context, listen: false);
    final isSi = appState.currentLanguage == 'si';

    // Show initial loading while generating OTP
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 14),
              Text(
                isSi ? 'OTP අංකයක් ජනනය වෙමින් පවතී...' : 'Generating security OTP...',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
              ),
            ],
          ),
        ),
      ),
    );

    final otpRes = await appState.generateStatementOtp(customer);
    if (!mounted) return false;
    Navigator.pop(context); // close generating dialog

    if (otpRes['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(otpRes['message']?.toString() ?? 'Failed to generate OTP.'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return false;
    }

    // Show interactive OTP entry dialog
    final bool? isVerified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final otpController = TextEditingController();
        String? errorMessage;
        bool isVerifying = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield_outlined, color: Color(0xFF1D4ED8), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSi ? 'OTP ආරක්ෂක තහවුරු කිරීම' : 'OTP Security Verification',
                          style: GoogleFonts.outfit(fontSize: 16.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                        ),
                        Text(
                          isSi ? 'කළමනාකාරීත්ව අනුමැතිය අවශ්‍යයි' : 'Management Authorization Required',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF1D4ED8), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isSi
                          ? 'මෙම පාරිභෝගිකයාගේ ගිණුම් ප්‍රකාශනය මුද්‍රණය කිරීමට කළමනාකාරීත්ව අනුමැතිය (Management Authorization) අවශ්‍ය වේ.'
                          : 'Management authorization is required to print this customer statement.',
                      style: GoogleFonts.inter(fontSize: 12.5, height: 1.35, color: const Color(0xFF334155)),
                    ),
                    const SizedBox(height: 12),

                    // Official Notice Banner: OTP sent to Management Team
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isSi
                                      ? 'OTP අංකය Management Team වෙත යොමු කරන ලදී.'
                                      : 'OTP has been sent to the Management Team.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1E3A8A),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  isSi
                                      ? 'මුද්‍රණය සඳහා අනුමැතිය ලබා ගැනීමට Management Team එකෙන් ලැබෙන ඉලක්කම් 6 ක OTP අංකය ඇතුළත් කරන්න.'
                                      : 'Please obtain the 6-digit authorization OTP from the Management Team and enter it below.',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xFF3B82F6),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // OTP Input Box
                    TextField(
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      autofocus: true,
                      style: GoogleFonts.robotoMono(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                        color: const Color(0xFF0F1E36),
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '------',
                        hintStyle: GoogleFonts.robotoMono(letterSpacing: 8, color: const Color(0xFFCBD5E1)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                        ),
                      ),
                      onChanged: (val) {
                        if (errorMessage != null) {
                          setDialogState(() => errorMessage = null);
                        }
                      },
                    ),

                    if (errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        errorMessage!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFFDC2626)),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying ? null : () => Navigator.pop(ctx, false),
                  child: Text(
                    isSi ? 'අවලංගු කරන්න' : 'Cancel',
                    style: GoogleFonts.inter(color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                  ),
                ),
                ElevatedButton(
                  onPressed: isVerifying
                      ? null
                      : () async {
                          final code = otpController.text.trim();
                          if (code.length != 6) {
                            setDialogState(() {
                              errorMessage = isSi ? 'කරුණාකර ඉලක්කම් 6 ක OTP අංකය ඇතුළත් කරන්න.' : 'Please enter the 6-digit OTP code.';
                            });
                            return;
                          }

                          setDialogState(() {
                            isVerifying = true;
                            errorMessage = null;
                          });

                          final vRes = await appState.verifyStatementOtp(code);
                          if (!ctx.mounted) return;

                          if (vRes['success'] == true) {
                            Navigator.pop(ctx, true);
                          } else {
                            setDialogState(() {
                              isVerifying = false;
                              errorMessage = vRes['message']?.toString() ?? (isSi ? 'වැරදි OTP අංකයකි.' : 'Invalid OTP code.');
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F1E36),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isVerifying
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(
                          isSi ? 'තහවුරු කරන්න' : 'Verify & Print',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    return isVerified ?? false;
  }

  Future<void> _handlePrintCustomerStatement(Customer customer) async {
    final appState = Provider.of<AppState>(context, listen: false);
    final isSi = appState.currentLanguage == 'si';
    final currency = NumberFormat('#,##0.00', 'en_US');

    // 0. Security Check: Normal Users require OTP verification before printing statement
    if (!appState.isAdmin) {
      final isOtpValid = await _showOtpDialog(customer);
      if (!mounted) return;
      if (!isOtpValid) return; // User cancelled or failed OTP verification
    }

    // 1. Fetch invoices if not already cached
    var invoices = appState.getCustomerInvoices(customer.code);
    if (invoices.isEmpty) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 14),
                Text(
                  isSi ? 'ඉන්වොයිසි දත්ත පූරණය වෙමින් පවතී...' : 'Fetching customer invoices...',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
        ),
      );

      await appState.fetchInvoicesForCustomerRealtime(customer.code);
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      invoices = appState.getCustomerInvoices(customer.code);
    }

    if (invoices.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isSi ? 'මෙම පාරිභෝගිකයා සඳහා ඉන්වොයිසි නොමැත.' : 'No invoices found for this customer.'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    final outstandingInvoices = invoices.where((i) => i.outstandingBalance > 0.01).toList();
    final outstandingSum = customer.totalOutstanding > 0.01
        ? customer.totalOutstanding
        : outstandingInvoices.fold<double>(0.0, (sum, i) => sum + i.outstandingBalance);

    if (!mounted) return;

    // 2. Ask user: Outstanding only or All invoices?
    final bool? printOnlyOutstanding = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.print_rounded, color: Color(0xFF1D4ED8), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSi ? 'POS ප්‍රකාශනය මුද්‍රණය' : 'POS Statement Print',
                      style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    ),
                    Text(
                      '${customer.code} • ${customer.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isSi
                    ? 'මුද්‍රණය කළ යුත්තේ හිඟ මුදල් පමණක් ද නැතහොත් සියලු ඉන්වොයිසි ද?'
                    : 'Print Outstanding invoices only or All invoice history?',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
              ),
              const SizedBox(height: 16),

              // Option 1: Outstanding Only
              InkWell(
                onTap: () => Navigator.pop(ctx, true),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.pending_actions_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isSi ? 'හිඟ මුදල් පමණක් (Outstanding Only)' : 'Outstanding Only',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF92400E)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isSi
                                  ? 'හිඟ ඉන්වොයිසි ${outstandingInvoices.length} ක් • Rs. ${currency.format(outstandingSum)}'
                                  : '${outstandingInvoices.length} due invoices • Rs. ${currency.format(outstandingSum)}',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFB45309), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Color(0xFFB45309)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Option 2: All Invoices (History)
              InkWell(
                onTap: () => Navigator.pop(ctx, false),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F1E36),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isSi ? 'සියලු ඉන්වොයිසි (All History)' : 'All Invoices (Full History)',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isSi
                                  ? 'සමථය වූ සහ හිඟ සියලු ඉන්වොයිසි ${invoices.length} ම'
                                  : 'All ${invoices.length} invoices including settled ones',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF475569), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Color(0xFF475569)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text(
                isSi ? 'අවලංගු කරන්න' : 'Cancel',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
              ),
            ),
          ],
        );
      },
    );

    if (printOnlyOutstanding == null) return; // User cancelled

    // 3. Trigger POS thermal print layout
    try {
      await ReceiptPrinterService.printCustomerStatement(
        customer,
        invoices,
        onlyOutstanding: printOnlyOutstanding,
        collectorName: appState.currentUser.fullName,
        collectorId: appState.currentUser.collectorId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print dialog error: $e'), backgroundColor: AppTheme.dangerRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final lang = appState.currentLanguage;
    final isSi = lang == 'si';
    final currency = NumberFormat('#,##0.00', 'en_US');
    final dateFormat = DateFormat('dd/MM/yyyy');

    // Filter accessible customers by search query
    final accessible = appState.accessibleCustomers;
    final searchedCustomers = accessible.where((c) {
      final q = _searchQuery.toLowerCase().trim();
      if (q.isEmpty) return true;
      return c.code.toLowerCase().contains(q) ||
          c.name.toLowerCase().contains(q) ||
          c.town.toLowerCase().contains(q) ||
          c.address.toLowerCase().contains(q);
    }).toList();

    // Tab filtering (All vs Has Balance vs Settled)
    final filteredCustomers = searchedCustomers.where((c) {
      final invoices = appState.getCustomerInvoices(c.code);
      final localOutstanding = invoices.fold<double>(0.0, (sum, i) => sum + i.outstandingBalance);
      final outstanding = c.totalOutstanding > 0 ? c.totalOutstanding : localOutstanding;

      switch (_selectedTab) {
        case CustomerFilterTab.hasBalance:
          return outstanding > 0.01;
        case CustomerFilterTab.settled:
          return outstanding <= 0.01;
        case CustomerFilterTab.all:
          return true;
      }
    }).toList();

    // Summary calculations
    final totalAccessibleOutstanding = accessible.fold<double>(0.0, (sum, c) => sum + c.totalOutstanding);
    final countWithBalance = accessible.where((c) => c.totalOutstanding > 0.01).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1E36),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocalizationService.tr('customers', lang: lang),
              style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              isSi ? 'පාරිභෝගික ගිණුම් සහ හිඟ ශේෂයන්' : 'Customer Directory & Outstanding Dues',
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: isSi ? 'නැවත පූරණය කරන්න' : 'Refresh Customers',
            onPressed: () {
              appState.fetchRealtimeCustomers(force: true);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Controls & Territory Scope
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Search Box
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: LocalizationService.tr('search_customer', lang: lang),
                        hintStyle: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF2563EB), size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.cancel, size: 18, color: Color(0xFF64748B)),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Filter Tabs (All, With Due, Settled)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterTab(
                          label: isSi ? 'සියලු දෙනා (${searchedCustomers.length})' : 'All (${searchedCustomers.length})',
                          tab: CustomerFilterTab.all,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterTab(
                          label: isSi ? 'හිඟ මුදල් සහිත ($countWithBalance)' : 'With Dues ($countWithBalance)',
                          tab: CustomerFilterTab.hasBalance,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterTab(
                          label: isSi
                              ? 'සමථය කර ඇති (${accessible.length - countWithBalance})'
                              : 'Settled (${accessible.length - countWithBalance})',
                          tab: CustomerFilterTab.settled,
                        ),
                      ],
                    ),
                  ),

                  // Territory Scoped Tag (if collector is territory restricted)
                  if (!appState.currentUser.hasAllLocations) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: Color(0xFF1D4ED8)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              isSi
                                  ? 'පවරා ඇති ප්‍රදේශ: ${appState.currentUser.assignedLocations} (${appState.customers.length} න් ${accessible.length})'
                                  : 'Territory Scoped: ${appState.currentUser.assignedLocations} (${accessible.length} of ${appState.customers.length} accessible)',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1D4ED8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Overall Outstanding Metric Banner
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance_wallet, size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Text(
                              isSi ? 'මුළු හිඟ ශේෂය:' : 'Total Outstanding:',
                              style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        Text(
                          'Rs. ${currency.format(totalAccessibleOutstanding)}',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F1E36),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Customers Directory List
            Expanded(
              child: filteredCustomers.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              isSi ? 'ගැලපෙන පාරිභෝගිකයෙකු හමු නොවීය.' : 'No matching customers found.',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isSi ? 'සෙවුම් පදය හෝ පෙරහන වෙනස් කර බලන්න.' : 'Try adjusting your search query or filter tab.',
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      itemCount: filteredCustomers.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final customer = filteredCustomers[index];
                        final isExpanded = _expandedCustomerCodes.contains(customer.code);
                        final invoices = appState.getCustomerInvoices(customer.code);
                        final localOutstanding = invoices.fold<double>(0.0, (sum, i) => sum + i.outstandingBalance);
                        final outstanding = customer.totalOutstanding > 0 ? customer.totalOutstanding : localOutstanding;
                        final invCount = customer.pendingInvoiceCount > 0 ? customer.pendingInvoiceCount : invoices.length;

                        return _buildCustomerCard(
                          customer: customer,
                          isExpanded: isExpanded,
                          invoices: invoices,
                          invCount: invCount,
                          outstanding: outstanding,
                          currency: currency,
                          dateFormat: dateFormat,
                          appState: appState,
                          isSi: isSi,
                          lang: lang,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab({required String label, required CustomerFilterTab tab}) {
    final isSelected = _selectedTab == tab;
    return InkWell(
      onTap: () => setState(() => _selectedTab = tab),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F1E36) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF0F1E36) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerCard({
    required Customer customer,
    required bool isExpanded,
    required List<Invoice> invoices,
    required int invCount,
    required double outstanding,
    required NumberFormat currency,
    required DateFormat dateFormat,
    required AppState appState,
    required bool isSi,
    required String lang,
  }) {
    final hasBalance = outstanding > 0.01;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isExpanded ? const Color(0xFF2563EB).withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Header Bar: Code, Town, and Outstanding Amount
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedCustomerCodes.remove(customer.code);
                } else {
                  _expandedCustomerCodes.add(customer.code);
                  appState.fetchInvoicesForCustomerRealtime(customer.code);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Code Pill, Town Pill & Amount
                  Row(
                    children: [
                      // Customer Code Badge - FIXED WIDTH / NEVER WRAPS
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.tag, size: 12, color: Color(0xFF2563EB)),
                            const SizedBox(width: 3),
                            Text(
                              customer.code,
                              style: GoogleFonts.robotoMono(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1D4ED8),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (customer.town.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            customer.town,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),

                      // Outstanding Balance Badge
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Rs. ${currency.format(outstanding)}',
                            style: GoogleFonts.outfit(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: hasBalance ? const Color(0xFF0F1E36) : const Color(0xFF16A34A),
                            ),
                          ),
                          Text(
                            hasBalance ? (isSi ? 'හිඟ ශේෂය' : 'Due Amount') : (isSi ? 'සමථය කර ඇත' : 'Settled'),
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: hasBalance ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),

                      // Quick POS Print Button
                      IconButton(
                        icon: const Icon(Icons.print_outlined, size: 19, color: Color(0xFF1D4ED8)),
                        tooltip: isSi ? 'ගිණුම් ප්‍රකාශනය මුද්‍රණය (POS)' : 'Print POS Statement',
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFEFF6FF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Color(0xFFBFDBFE)),
                          ),
                          padding: const EdgeInsets.all(6),
                          minimumSize: const Size(34, 34),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _handlePrintCustomerStatement(customer),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Customer Name
                  Text(
                    customer.name,
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Bottom Info Row: Invoice count, Address & Chevron
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: hasBalance
                              ? const Color(0xFFFEF3C7)
                              : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              hasBalance ? Icons.receipt_long : Icons.check_circle_outline,
                              size: 12,
                              color: hasBalance ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              hasBalance
                                  ? (isSi ? 'හිඟ ඉන්වොයිසි $invCount' : '$invCount due invoices')
                                  : (isSi ? 'ඉන්වොයිසි හිඟ නැත' : 'All Settled'),
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: hasBalance ? const Color(0xFFB45309) : const Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (customer.address.isNotEmpty)
                        Expanded(
                          child: Text(
                            customer.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                          ),
                        )
                      else
                        const Spacer(),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: const Color(0xFF64748B),
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expanded Content (Invoices & Payment Actions)
          if (isExpanded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Full Address & Phone
                  if (customer.address.isNotEmpty || customer.phone.isNotEmpty) ...[
                    Row(
                      children: [
                        if (customer.address.isNotEmpty) ...[
                          const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              customer.address,
                              style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF475569)),
                            ),
                          ),
                        ],
                        if (customer.phone.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            customer.phone,
                            style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF475569)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Outstanding Invoices Table
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        LocalizationService.tr('outstanding_invoices', lang: lang),
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      ),
                      if (appState.isLoadingInvoices && invoices.isEmpty)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  if (invoices.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Center(
                        child: Text(
                          isSi
                              ? 'හිඟ ශේෂයක් නොමැත. සියලු ඉන්වොයිසි සමථයකට පත් කර ඇත.'
                              : 'No outstanding balance. All invoices are settled.',
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF16A34A)),
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          // Table Header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            color: const Color(0xFFF1F5F9),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    LocalizationService.tr('inv_no', lang: lang),
                                    style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                                  ),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    LocalizationService.tr('delivery_age', lang: lang),
                                    style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    LocalizationService.tr('balance', lang: lang),
                                    textAlign: TextAlign.right,
                                    style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Table Rows
                          for (int i = 0; i < invoices.length; i++) ...[
                            if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      invoices[i].invoiceNo,
                                      style: GoogleFonts.robotoMono(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      '${invoices[i].deliveryAgeDays} ${LocalizationService.tr('days', lang: lang)} (${dateFormat.format(invoices[i].deliveryDate)})',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: invoices[i].deliveryAgeDays > 30 ? const Color(0xFFD97706) : const Color(0xFF64748B),
                                        fontWeight: invoices[i].deliveryAgeDays > 30 ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'Rs. ${currency.format(invoices[i].outstandingBalance)}',
                                      textAlign: TextAlign.right,
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0F1E36),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),

                  // Action Buttons: Quick Collect & POS Statement Print
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add_card, size: 16),
                          label: Text(
                            isSi ? 'මුදල් අයකරගන්න' : 'Collect Payment',
                            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F1E36),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            if (appState.isDayEndFinalized) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(LocalizationService.tr('day_end_locked_msg', lang: lang)),
                                  backgroundColor: AppTheme.dangerRed,
                                ),
                              );
                              return;
                            }
                            appState.startNewPayment(customer);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const PaymentDetailsScreen()),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.print, size: 16, color: Color(0xFF1D4ED8)),
                          label: Text(
                            isSi ? 'POS Print' : 'POS Print',
                            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF1D4ED8)),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFBFDBFE), width: 1.2),
                            backgroundColor: const Color(0xFFEFF6FF),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _handlePrintCustomerStatement(customer),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
