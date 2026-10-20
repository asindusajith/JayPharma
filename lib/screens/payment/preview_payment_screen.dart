import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/receipt.dart';
import '../../theme/app_theme.dart';
import '../../services/localization_service.dart';
import '../../services/location_service.dart';
import 'receipt_success_screen.dart';

class PreviewPaymentScreen extends StatefulWidget {
  const PreviewPaymentScreen({super.key});

  @override
  State<PreviewPaymentScreen> createState() => _PreviewPaymentScreenState();
}

class _PreviewPaymentScreenState extends State<PreviewPaymentScreen> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final lang = appState.currentLanguage;
    final customer = appState.draftCustomer!;
    final currency = NumberFormat('#,##0.00', 'en_US');
    final dateFormat = DateFormat('dd/MM/yyyy');

    final selectedInvoices = appState.draftInvoices.where((i) => i.isSelected && i.allocatedAmount > 0).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          LocalizationService.tr('preview_payment', lang: lang),
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(16),
          child: Container(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStepIndicator(1, LocalizationService.tr('step_customer', lang: lang), true),
                _buildStepDivider(true),
                _buildStepIndicator(2, LocalizationService.tr('step_payment', lang: lang), true),
                _buildStepDivider(true),
                _buildStepIndicator(3, LocalizationService.tr('step_review', lang: lang), true),
              ],
            ),
          ),
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
                // Review Header Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified, color: AppTheme.primaryBlue, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          lang == 'si' ? 'නිල රිසිට්පත නිකුත් කිරීමට පෙර කරුණාකර සියලු විස්තර පරීක්ෂා කරන්න.' : 'Please verify all details carefully before generating the official receipt.',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF1E3A8A), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Review Container (Card)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Customer Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(LocalizationService.tr('select_customer', lang: lang), style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.lightBlueBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                customer.code,
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          customer.name,
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        ),
                        const SizedBox(height: 14),
                        const Divider(),
                        const SizedBox(height: 14),

                        // Receipt Number & Payment Method
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(LocalizationService.tr('manual_receipt_no', lang: lang), style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                                  const SizedBox(height: 2),
                                  Text(
                                    appState.draftManualReceiptNo,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.receiptRed,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(LocalizationService.tr('payment_method', lang: lang), style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(
                                        appState.draftPaymentMethod == PaymentMethod.cash ? Icons.payments : Icons.account_balance,
                                        size: 16,
                                        color: AppTheme.primaryBlue,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        appState.draftPaymentMethod == PaymentMethod.cash ? LocalizationService.tr('cash', lang: lang) : LocalizationService.tr('cheque', lang: lang),
                                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Cheque Details (Only when Cheque is selected - Page 4 requirement)
                        if (appState.draftPaymentMethod == PaymentMethod.cheque) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              children: [
                                _buildPreviewRow(LocalizationService.tr('bank', lang: lang), appState.draftBank ?? 'N/A'),
                                const SizedBox(height: 4),
                                _buildPreviewRow(LocalizationService.tr('branch', lang: lang), appState.draftBranch ?? 'N/A'),
                                const SizedBox(height: 4),
                                _buildPreviewRow(LocalizationService.tr('cheque_number', lang: lang), appState.draftChequeNumber ?? 'N/A', isBold: true),
                                const SizedBox(height: 4),
                                _buildPreviewRow(
                                  LocalizationService.tr('cheque_date', lang: lang),
                                  appState.draftChequeDate != null ? dateFormat.format(appState.draftChequeDate!) : 'N/A',
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        const Divider(),
                        const SizedBox(height: 14),

                        // Total Payment Amount Highlight
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              LocalizationService.tr('payment_amount', lang: lang),
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                            ),
                            Text(
                              'Rs. ${currency.format(appState.draftPaymentAmount)}',
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(),
                        const SizedBox(height: 14),

                        // Selected Invoices Table Breakdown
                        Text(
                          lang == 'si' ? 'ගෙවීම් වෙන් කිරීමේ සාරාංශය (${selectedInvoices.length})' : 'Settlement Breakdown (${selectedInvoices.length} invoices)',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        ),
                        const SizedBox(height: 8),

                        if (selectedInvoices.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    LocalizationService.tr('advance_payment_notice', lang: lang),
                                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF92400E)),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Table(
                              border: TableBorder.symmetric(
                                inside: const BorderSide(color: Color(0xFFF1F5F9), width: 1),
                              ),
                              children: [
                                TableRow(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                                  ),
                                  children: [
                                    _buildTableHeaderCell(LocalizationService.tr('inv_no', lang: lang)),
                                    _buildTableHeaderCell(LocalizationService.tr('balance', lang: lang), align: TextAlign.right),
                                    _buildTableHeaderCell(LocalizationService.tr('allocated', lang: lang), align: TextAlign.right),
                                  ],
                                ),
                                for (final inv in selectedInvoices)
                                  TableRow(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Text(
                                          inv.invoiceNo,
                                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Text(
                                          currency.format(inv.outstandingBalance),
                                          textAlign: TextAlign.right,
                                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        child: Text(
                                          currency.format(inv.allocatedAmount),
                                          textAlign: TextAlign.right,
                                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.successGreen),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),

                        if (appState.draftComments.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text('${LocalizationService.tr('add_comment', lang: lang)}:', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                          const SizedBox(height: 2),
                          Text(
                            appState.draftComments,
                            style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic, color: AppTheme.textDark),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons matching Page 4 ("Generate Receipt" & "Edit Details")
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleGenerateReceipt,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryNavy,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSubmitting
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                            const SizedBox(width: 12),
                            Text(lang == 'si' ? 'රිසිට්පත සුරකිමින් පවතී...' : 'Saving and Generating Receipt...'),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.print, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              LocalizationService.tr('generate_receipt', lang: lang),
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 10),

                OutlinedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          // Return to Step 2 to edit details
                          Navigator.pop(context);
                        },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    LocalizationService.tr('edit_details', lang: lang),
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleGenerateReceipt() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final lang = appState.currentLanguage;

    // Verify hardware GPS is active so real location can be recorded
    final isGpsOn = await LocationService.isGpsAvailable();
    if (!isGpsOn && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.location_off_rounded, color: Color(0xFFDC2626)),
              const SizedBox(width: 8),
              Text(
                lang == 'si' ? 'GPS අක්‍රියයි' : 'GPS Offline',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Text(
            lang == 'si'
                ? 'බිල්පත නිකුත් කරන ස්ථානය නිවැරදිව සටහන් වීමට ඔබගේ දුරකථනයේ GPS සක්‍රීය කර තිබීම අනිවාර්ය වේ. කරුණාකර GPS සක්‍රීය කරන්න.'
                : 'Device GPS is disabled. GPS must be enabled so the exact billing location can be recorded.',
            style: GoogleFonts.inter(fontSize: 13.5, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(lang == 'si' ? 'අවලංගු කරන්න' : 'Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx, true);
                await LocationService.openLocationSettings();
              },
              icon: const Icon(Icons.settings, size: 16, color: Colors.white),
              label: Text(
                lang == 'si' ? 'GPS සක්‍රීය කරන්න' : 'Open Location Settings',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      );
      if (proceed != true) return;
      await appState.checkGpsStatus();
    }

    setState(() => _isSubmitting = true);

    try {
      final receipt = await appState.confirmAndGenerateReceipt();

      if (mounted) {
        // Navigate to Receipt Success & Thermal Printer Screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ReceiptSuccessScreen(receipt: receipt)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.dangerRed),
        );
      }
    }
  }

  Widget _buildPreviewRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: AppTheme.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeaderCell(String text, {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        text,
        textAlign: align,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppTheme.textDark,
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, bool active) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white24,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$step',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: active ? AppTheme.primaryNavy : Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? Colors.white : Colors.white60,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider(bool active) {
    return Container(
      width: 24,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: active ? Colors.white : Colors.white24,
    );
  }
}
