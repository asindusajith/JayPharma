import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/receipt.dart';
import '../../theme/app_theme.dart';
import '../../widgets/thermal_receipt_view.dart';
import '../../widgets/receipt_location_map_view.dart';
import '../../services/otp_service.dart';
import '../../services/receipt_printer_service.dart';
import '../../services/localization_service.dart';

class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({super.key});

  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  String _searchQuery = '';
  String _selectedMethodFilter = 'All';
  Receipt? _selectedMapReceipt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppState>(context, listen: false).fetchRealtimeReceipts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final lang = appState.currentLanguage;
    final currency = NumberFormat('#,##0.00', 'en_US');
    final dateFormat = DateFormat('dd/MM/yyyy');

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    // Normal users can only view Today's receipts; Admins can use custom date ranges
    final startOfFrom = appState.isAdmin
        ? DateTime(_fromDate.year, _fromDate.month, _fromDate.day)
        : todayStart;
    final endOfTo = appState.isAdmin
        ? DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59)
        : todayEnd;

    final filteredReceipts = appState.receipts.where((r) {
      // Normal collectors can ONLY see receipts they personally issued; Admins can view all within assigned locations
      final matchesScope = appState.isAdmin
          ? (appState.currentUser.hasAllLocations ||
              appState.currentUser.canAccessCustomer(
                code: r.customerCode,
                name: r.customerName,
                address: r.customerAddress,
              ))
          : (r.collectorId.trim().toLowerCase() == appState.collectorId.trim().toLowerCase() ||
             r.collectorId.trim().toLowerCase() == appState.currentUser.username.trim().toLowerCase());

      final matchesDate = r.createdAt.isAfter(startOfFrom.subtract(const Duration(seconds: 1))) &&
          r.createdAt.isBefore(endOfTo.add(const Duration(seconds: 1)));

      final matchesSearch = r.manualReceiptNo.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r.customerCode.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r.invoiceNumbersDisplay.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesMethod = _selectedMethodFilter == 'All' ||
          (_selectedMethodFilter == 'Cash' && r.paymentMethod == PaymentMethod.cash) ||
          (_selectedMethodFilter == 'Cheque' && r.paymentMethod == PaymentMethod.cheque);

      return matchesScope && matchesDate && matchesSearch && matchesMethod;
    }).toList();

    final isSi = lang == 'si';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          LocalizationService.tr('receipts', lang: lang),
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Section 2.5: Date Range Filter Bar (Default to current date)
            Container(
              padding: const EdgeInsets.all(14),
              color: Colors.white,
              child: Column(
                children: [
                  // Admins have access to custom date range; Normal users are locked to Today only
                  if (appState.isAdmin)
                    Row(
                      children: [
                        // From Date
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _fromDate,
                                firstDate: DateTime(2025),
                                lastDate: DateTime.now().add(const Duration(days: 1)),
                              );
                              if (picked != null) {
                                setState(() {
                                  _fromDate = picked;
                                  if (_fromDate.isAfter(_toDate)) _toDate = _fromDate;
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: isSi ? 'සිට දිනය' : 'From Date',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                prefixIcon: const Icon(Icons.date_range, size: 18),
                              ),
                              child: Text(
                                dateFormat.format(_fromDate),
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // To Date
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _toDate,
                                firstDate: _fromDate,
                                lastDate: DateTime.now().add(const Duration(days: 1)),
                              );
                              if (picked != null) {
                                setState(() => _toDate = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: isSi ? 'දක්වා දිනය' : 'To Date',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                prefixIcon: const Icon(Icons.event, size: 18),
                              ),
                              child: Text(
                                dateFormat.format(_toDate),
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Reset to today button
                        IconButton(
                          tooltip: isSi ? 'අද දිනයට සකසන්න' : 'Reset to Today',
                          icon: const Icon(Icons.today, color: AppTheme.primaryBlue, size: 22),
                          onPressed: () {
                            setState(() {
                              _fromDate = DateTime.now();
                              _toDate = DateTime.now();
                            });
                          },
                        ),
                      ],
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.primaryNavy),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isSi ? 'දින පරාසය' : 'Date Range',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${dateFormat.format(DateTime.now())} (${isSi ? 'අද දින' : 'Today'})',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.lock_outline_rounded, size: 12, color: Color(0xFF475569)),
                                const SizedBox(width: 4),
                                Text(
                                  isSi ? 'අද පමණි' : 'Today Only',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),

                  // Search input & method filter chips
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: isSi ? 'රිසිට්පත් අංකය හෝ පාරිභෝගිකයා සොයන්න...' : 'Search by receipt # or customer...',
                            prefixIcon: const Icon(Icons.search, size: 18),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _selectedMethodFilter,
                        underline: const SizedBox(),
                        items: [
                          DropdownMenuItem(value: 'All', child: Text(isSi ? 'සියල්ල' : 'All', style: GoogleFonts.inter(fontSize: 12))),
                          DropdownMenuItem(value: 'Cash', child: Text(LocalizationService.tr('cash', lang: lang), style: GoogleFonts.inter(fontSize: 12))),
                          DropdownMenuItem(value: 'Cheque', child: Text(LocalizationService.tr('cheque', lang: lang), style: GoogleFonts.inter(fontSize: 12))),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedMethodFilter = val);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Receipts Count & Total Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFF1F5F9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isSi ? 'රිසිට්පත් ${filteredReceipts.length} ක් හමුවිය' : '${filteredReceipts.length} Receipts Found',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                  ),
                  Text(
                    '${isSi ? 'එකතුව' : 'Total'}: Rs. ${currency.format(filteredReceipts.fold<double>(0.0, (sum, r) => sum + r.totalAmount))}',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                  ),
                ],
              ),
            ),

            Expanded(
              child: filteredReceipts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 54, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            isSi
                                ? (!appState.isAdmin
                                    ? 'අද දින සඳහා රිසිට්පත් හමු නොවීය.'
                                    : 'තෝරාගත් දින සහ පෙරහන සඳහා රිසිට්පත් හමු නොවීය.')
                                : (!appState.isAdmin
                                    ? 'No receipts found for today.'
                                    : 'No receipts found for the selected filter.'),
                            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredReceipts.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final r = filteredReceipts[index];
                        final isSelected = _selectedMapReceipt?.manualReceiptNo == r.manualReceiptNo;

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildReceiptCard(context, r, currency, dateFormat, appState, lang),
                            if (isSelected) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 420,
                                child: ReceiptLocationMapView(
                                  receipt: r,
                                  language: lang,
                                  margin: EdgeInsets.zero,
                                  onClose: () {
                                    setState(() {
                                      _selectedMapReceipt = null;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Section 2.5: Display Manual Receipt Number, Invoice Number, Customer Name, Payment Amount
  Widget _buildReceiptCard(
    BuildContext context,
    Receipt r,
    NumberFormat currency,
    DateFormat dateFormat,
    AppState appState,
    String lang,
  ) {
    final isSi = lang == 'si';
    final isSelected = _selectedMapReceipt?.manualReceiptNo == r.manualReceiptNo;

    return Card(
      elevation: isSelected ? 3 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected ? AppTheme.primaryBlue : const Color(0xFFE2E8F0),
          width: isSelected ? 1.8 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          _showReceiptDetailsModal(context, r, appState, lang);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Manual Receipt Number & Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          r.manualReceiptNo,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.receiptRed,
                          ),
                        ),
                      ),
                      if (r.reprintCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isSi ? 'නැවත මුද්‍රණය (${r.reprintCount})' : 'Reprinted (${r.reprintCount})',
                            style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFFD97706)),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    DateFormat('dd/MM/yyyy • HH:mm').format(r.createdAt),
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Customer Name & Code + View Location Button (as requested by user)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      '${r.customerCode} - ${r.customerName}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Location Button (Loads map in bottom area)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        setState(() {
                          if (_selectedMapReceipt?.manualReceiptNo == r.manualReceiptNo) {
                            _selectedMapReceipt = null;
                          } else {
                            _selectedMapReceipt = r;
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryBlue
                              : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primaryBlue
                                : const Color(0xFFBFDBFE),
                            width: 1.2,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppTheme.primaryBlue.withOpacity(0.28),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSelected ? Icons.map : Icons.location_on,
                              size: 15,
                              color: isSelected ? Colors.white : AppTheme.primaryBlue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isSi ? 'ස්ථානය' : 'Location',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : AppTheme.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Invoice Numbers
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSi ? 'ඉන්වොයිසි: ' : 'Invoices: ',
                    style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textMuted),
                  ),
                  Expanded(
                    child: Text(
                      r.allocatedInvoices.isEmpty
                          ? (isSi ? 'අත්තිකාරම් ගෙවීමක්' : 'Advance Payment')
                          : r.invoiceNumbersDisplay,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF334155),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Payment Amount & Type Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        r.paymentMethod == PaymentMethod.cash ? Icons.payments : Icons.account_balance,
                        size: 15,
                        color: AppTheme.primaryBlue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        r.paymentMethod == PaymentMethod.cash
                            ? LocalizationService.tr('cash', lang: lang)
                            : LocalizationService.tr('cheque', lang: lang),
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                      ),
                      if (r.paymentMethod == PaymentMethod.cheque && r.bank != null)
                        Text(
                          ' (${r.bank})',
                          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                        ),
                    ],
                  ),
                  Text(
                    'Rs. ${currency.format(r.totalAmount)}',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // View Receipt Full Modal with Controlled Reprint Action
  void _showReceiptDetailsModal(BuildContext context, Receipt r, AppState appState, String lang) {
    int selectedCopyTab = 0;
    final isSi = lang == 'si';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Modal Handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Column(
                        children: [
                          ThermalReceiptView(
                            receipt: r,
                            selectedTab: selectedCopyTab,
                            onTabChanged: (tab) => setModalState(() => selectedCopyTab = tab),
                          ),
                          const SizedBox(height: 20),

                          // Section 2.2 Page 5 & Section 6: Controlled Reprint with OTP
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.security, color: Color(0xFFD97706), size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      LocalizationService.tr('otp_required', lang: lang),
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF92400E)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  LocalizationService.tr('otp_sub', lang: lang),
                                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF78350F)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Reprint with OTP button
                          ElevatedButton.icon(
                            icon: const Icon(Icons.vpn_key, size: 18),
                            label: Text(
                              selectedCopyTab == 1
                                  ? (isSi ? 'Customer Copy පමණක් නැවත මුද්‍රණය' : 'Reprint Customer Copy Only')
                                  : selectedCopyTab == 2
                                      ? (isSi ? 'Accounts Copy පමණක් නැවත මුද්‍රණය' : 'Reprint Accounts Copy Only')
                                      : (isSi ? 'පිටපත් 2ම නැවත මුද්‍රණය කරන්න (All)' : 'Reprint Receipt (Both Copies)'),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryNavy,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              minimumSize: const Size.fromHeight(48),
                            ),
                            onPressed: () {
                              ReceiptCopyMode copyMode;
                              switch (selectedCopyTab) {
                                case 1:
                                  copyMode = ReceiptCopyMode.customerOnly;
                                  break;
                                case 2:
                                  copyMode = ReceiptCopyMode.accountsOnly;
                                  break;
                                case 0:
                                default:
                                  copyMode = ReceiptCopyMode.all;
                                  break;
                              }
                              _promptOtpForReprint(context, r, appState, lang, copyMode: copyMode);
                            },
                          ),
                          const SizedBox(height: 10),

                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(LocalizationService.tr('cancel', lang: lang)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // OTP Verification Dialog for Reprinting (Page 5 Requirement)
  void _promptOtpForReprint(BuildContext context, Receipt r, AppState appState, String lang, {ReceiptCopyMode copyMode = ReceiptCopyMode.all}) {
    final isSi = lang == 'si';

    // Generate new OTP for this session
    final otpData = OtpService.generateReprintOtp(
      receiptNo: r.manualReceiptNo,
      collectorId: appState.collectorId,
    );
    final demoOtp = otpData['otp'] as String;

    final otpController = TextEditingController();
    final reasonController = TextEditingController(
      text: isSi ? 'මුද්‍රණ යන්ත්‍ර දෝෂය හෝ හානි වූ මුල් පිටපත' : 'Printer paper jam or damaged original',
    );

    showDialog(
      context: context,
      builder: (dlgContext) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.verified_user, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              Text(
                LocalizationService.tr('otp_required', lang: lang),
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSi
                      ? 'අංක #${r.manualReceiptNo} රිසිට්පත නැවත මුද්‍රණය කිරීමට කළමනාකරු අවසරය අවශ්‍ය වේ.'
                      : 'Reprinting receipt #${r.manualReceiptNo} requires manager authorization.',
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textDark),
                ),
                const SizedBox(height: 12),

                // Demo Helper Banner showing generated OTP
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSi ? 'කළමනාකරු OTP අංකය:' : 'Manager OTP Dispatched:',
                        style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(demoOtp, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                          TextButton(
                            onPressed: () => otpController.text = demoOtp,
                            child: Text(
                              isSi ? 'ස්වයංක්‍රීයව ඇතුළත් කරන්න' : 'Auto-Fill OTP',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        isSi ? 'විනාඩි 5ක් වලංගු වේ. (හෝ මාස්ටර් යතුර: 998877)' : 'Valid for 5 minutes. (Or master offline key: 998877)',
                        style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF475569)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8),
                  decoration: InputDecoration(
                    hintText: '000000',
                    labelText: LocalizationService.tr('enter_otp', lang: lang),
                  ),
                ),
                const SizedBox(height: 8),

                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    labelText: isSi ? 'නැවත මුද්‍රණයට හේතුව (විගණනය වේ)' : 'Reprint Reason (Audit Logged)',
                    hintText: isSi ? 'උදා. මුද්‍රණ දෝෂය' : 'e.g. Printer error',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgContext),
              child: Text(LocalizationService.tr('cancel', lang: lang)),
            ),
            ElevatedButton(
              onPressed: () async {
                final entered = otpController.text.trim();
                final reason = reasonController.text.trim();

                final isValid = OtpService.verifyOtp(entered);
                if (!isValid) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isSi ? 'වැරදි හෝ කල් ඉකුත් වූ OTP අංකයකි.' : 'Invalid or expired OTP. Access denied.'),
                      backgroundColor: AppTheme.dangerRed,
                    ),
                  );
                  return;
                }

                Navigator.pop(dlgContext); // close OTP dialog

                // Execute reprint with audit
                appState.reprintReceiptWithOtp(
                  receiptNo: r.manualReceiptNo,
                  enteredOtp: entered,
                  reason: reason.isNotEmpty ? reason : 'Authorized reprint',
                );

                // Trigger print with duplicate watermark and selected copy mode
                await ReceiptPrinterService.printReceiptDirect(r, isReprint: true, copyMode: copyMode);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isSi
                            ? 'අංක #${r.manualReceiptNo} රිසිට්පත සාර්ථකව නැවත මුද්‍රණය කරන ලදී.'
                            : 'Receipt #${r.manualReceiptNo} reprinted and logged to audit trail.',
                      ),
                      backgroundColor: AppTheme.successGreen,
                    ),
                  );
                }
              },
              child: Text(LocalizationService.tr('verify_and_print', lang: lang)),
            ),
          ],
        ),
      ),
    );
  }
}
