import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/receipt.dart';
import '../../theme/app_theme.dart';
import '../../services/receipt_printer_service.dart';
import '../../services/localization_service.dart';

class DayEndScreen extends StatefulWidget {
  const DayEndScreen({super.key});

  @override
  State<DayEndScreen> createState() => _DayEndScreenState();
}

class _DayEndScreenState extends State<DayEndScreen> {
  final DateTime _selectedDate = DateTime.now();
  final _notesController = TextEditingController();
  bool _isPrinting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final lang = appState.currentLanguage;
    final currency = NumberFormat('#,##0.00', 'en_US');
    final dateFormat = DateFormat('dd/MM/yyyy');

    final summary = appState.calculateDayEndSummary(_selectedDate);

    // Receipts for the selected date
    final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);
    final dayReceipts = appState.receipts.where((r) {
      if (r.isCancelled) return false;
      if (r.createdAt.isBefore(startOfDay) || r.createdAt.isAfter(endOfDay)) return false;
      if (!appState.isAdmin) {
        final myId = appState.collectorId.trim().toLowerCase();
        final myUsername = appState.currentUser.username.trim().toLowerCase();
        final rId = r.collectorId.trim().toLowerCase();
        return rId == myId || rId == myUsername;
      }
      return true;
    }).toList();

    final isSi = lang == 'si';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          LocalizationService.tr('day_end', lang: lang),
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: Colors.white),
            tooltip: isSi ? 'වාර්තාව මුද්‍රණය කරන්න' : 'Print Statement',
            onPressed: () => _printDayEndStatement(summary, dayReceipts),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Date & Finalization Status Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isSi ? 'ගිණුම්කරණ දිනය' : 'Reconciliation Date', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                            const SizedBox(height: 2),
                            Text(
                              dateFormat.format(_selectedDate),
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: summary.isFinalized ? AppTheme.successLight : AppTheme.warningLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                summary.isFinalized ? Icons.check_circle : Icons.pending,
                                size: 14,
                                color: summary.isFinalized ? AppTheme.successGreen : AppTheme.warningAmber,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                summary.isFinalized
                                    ? (isSi ? 'අවසන් කර අගුලු ලා ඇත' : 'FINALIZED & LOCKED')
                                    : (isSi ? 'ඉදිරිපත් කිරීමට නියමිතයි' : 'PENDING SUBMISSION'),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: summary.isFinalized ? AppTheme.successGreen : AppTheme.warningAmber,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Financial Summary Totals Card (Section 3 Requirement)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F1E36), Color(0xFF1B2A4A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSi ? 'මුළු එකතු කළ මුදල (මුදල් + චෙක්පත්)' : 'TOTAL INCOME COLLECTED (CASH + CHEQUE)',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF94A3B8),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Rs. ${currency.format(summary.totalIncome)}',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            // Total Cash
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.payments, size: 14, color: Color(0xFF34D399)),
                                      const SizedBox(width: 4),
                                      Text(isSi ? 'මුළු මුදල්' : 'Total Cash', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Rs. ${currency.format(summary.totalCash)}',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.2)),
                            const SizedBox(width: 12),
                            // Total Cheque
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.account_balance, size: 14, color: Color(0xFF38BDF8)),
                                      const SizedBox(width: 4),
                                      Text(isSi ? 'මුළු චෙක්පත්' : 'Total Cheque', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Rs. ${currency.format(summary.totalCheque)}',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Cheque Numbers Breakdown (Section 3 Requirement)
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
                            Text(
                              isSi ? 'ලැබුණු චෙක්පත් (${summary.chequesList.length})' : 'Cheques Received (${summary.chequesList.length})',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                            ),
                            Text(
                              '${isSi ? 'එකතුව' : 'Total'}: Rs. ${currency.format(summary.totalCheque)}',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        if (summary.chequesList.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Text(
                                isSi ? 'අද දින චෙක්පත් ගෙවීම් ලැබී නොමැත.' : 'No cheque payments received today.',
                                style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic, color: AppTheme.textMuted),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: summary.chequesList.length,
                            separatorBuilder: (context, index) => const Divider(height: 12),
                            itemBuilder: (context, index) {
                              final chq = summary.chequesList[index];
                              return Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.lightBlueBg,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.confirmation_number, size: 16, color: AppTheme.primaryBlue),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Chq: ${chq.chequeNumber} • ${chq.bank}',
                                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                                        ),
                                        Text(
                                          '${chq.customerCode} - ${chq.customerName}',
                                          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'Rs. ${currency.format(chq.amount)}',
                                    style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                                  ),
                                ],
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Receipts Itemized List for Today
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
                        Text(
                          isSi ? 'දෛනික රිසිට්පත් සාරාංශය (${dayReceipts.length})' : 'Daily Receipts Summary (${dayReceipts.length})',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        ),
                        const SizedBox(height: 10),

                        if (dayReceipts.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Text(
                                isSi ? 'අද දින නිකුත් කළ රිසිට්පත් නොමැත.' : 'No receipts issued today yet.',
                                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: dayReceipts.length,
                            separatorBuilder: (context, index) => const Divider(height: 10),
                            itemBuilder: (context, index) {
                              final r = dayReceipts[index];
                              return Row(
                                children: [
                                  Text(
                                    r.manualReceiptNo,
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.receiptRed),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      r.customerName,
                                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textDark),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      r.paymentMethod == PaymentMethod.cash
                                          ? LocalizationService.tr('cash', lang: lang)
                                          : LocalizationService.tr('cheque', lang: lang),
                                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Rs. ${currency.format(r.totalAmount)}',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                                  ),
                                ],
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Actions: Print Statement & Finalize Day-End
                ElevatedButton.icon(
                  icon: _isPrinting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.print, size: 20),
                  label: Text(isSi ? 'දින අවසාන සාරාංශය මුද්‍රණය කරන්න' : 'Print Day-End Summary Statement'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryNavy,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _isPrinting ? null : () => _printDayEndStatement(summary, dayReceipts),
                ),
                const SizedBox(height: 10),

                if (!summary.isFinalized) ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.lock, size: 20),
                    label: Text(isSi ? 'දින අවසාන වාර්තාව තහවුරු කර අවසන් කරන්න' : 'Finalize & Submit Day-End Statement'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () => _confirmFinalizeDayEnd(context, appState, lang),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock, size: 16, color: Color(0xFF15803D)),
                        const SizedBox(width: 8),
                        Text(
                          isSi ? 'දින අවසානය සම්පූර්ණ කර ඇත. අද දිනට ගෙවීම් ලබාගැනීම අගුලු ලා ඇත.' : 'Day-End finalized. Collections locked for today.',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF166534)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _printDayEndStatement(dynamic summary, List<Receipt> receipts) async {
    setState(() => _isPrinting = true);
    try {
      await ReceiptPrinterService.printDayEndSummary(summary, receipts);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print error: $e'), backgroundColor: AppTheme.dangerRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  // Section 3 Requirement: Once finalized, cash collector must not be allowed to record any further payments for that day!
  void _confirmFinalizeDayEnd(BuildContext context, AppState appState, String lang) {
    final isSi = lang == 'si';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
            const SizedBox(width: 8),
            Text(
              isSi ? 'දින අවසානය තහවුරු කරනවාද?' : 'Finalize Day-End?',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSi
                  ? 'ඔබ දින අවසාන ගිණුම්කරණ ප්‍රකාශනය සම්පූර්ණ කළ පසු:'
                  : 'Once you finalize and submit the day-end reconciliation statement:',
              style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.textDark),
            ),
            const SizedBox(height: 8),
            Text(
              isSi
                  ? '• අද දින සඳහා තවදුරටත් ගෙවීම් ලබාගැනීමට නොහැක.\n• එකතු කිරීමේ ලේඛනය ස්ථිරවම අගුලු වැටෙනු ඇත.\n• වාර්තාව කැෂියර් අත්සන සඳහා සූදානම් කෙරේ.'
                  : '• You will NOT be allowed to record any further payments for today.\n• The collection register will be permanently locked.\n• The statement will be marked for cashier signature.',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFB91C1C), height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: isSi ? 'කැෂියර් භාරදීමේ සටහන් (විකල්ප)' : 'Cashier Handover Notes (Optional)',
                hintText: isSi ? 'උදා. කොළඹ කැෂියර් වෙත මුදල් හා චෙක්පත් භාර දෙන ලදී' : 'e.g. Handed over cash and cheques to Colombo cashier',
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () async {
              Navigator.pop(ctx);
              await appState.finalizeDayEndSummary(_notesController.text.trim());
              if (context.mounted && !appState.isAdmin) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isSi
                          ? 'දින අවසාන ප්‍රකාශනය සම්පූර්ණ කරන ලදී. පද්ධතිය අගුලු ලන ලදී.'
                          : 'Day-end statement finalized. System locked until next Day Start.',
                    ),
                    backgroundColor: AppTheme.successGreen,
                  ),
                );
              }
            },
            child: Text(isSi ? 'තහවුරු කර අගුලු ලන්න' : 'Confirm & Lock Day-End'),
          ),
        ],
      ),
    );
  }
}
