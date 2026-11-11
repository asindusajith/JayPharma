import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/receipt.dart';
import '../../theme/app_theme.dart';
import '../../widgets/thermal_receipt_view.dart';
import '../../services/receipt_printer_service.dart';
import '../../services/localization_service.dart';

import '../../services/bluetooth_printer_service.dart';

class ReceiptSuccessScreen extends StatefulWidget {
  final Receipt receipt;

  const ReceiptSuccessScreen({super.key, required this.receipt});

  @override
  State<ReceiptSuccessScreen> createState() => _ReceiptSuccessScreenState();
}

class _ReceiptSuccessScreenState extends State<ReceiptSuccessScreen> {
  bool _isPrinting = false;
  int _selectedCopyTab = 0; // 0: All, 1: Customer Copy, 2: Accounts Copy

  @override
  void initState() {
    super.initState();
    // Auto-connect to saved printer when receipt success screen opens
    BluetoothPrinterService.autoConnectToSavedPrinter();
  }

  void _printReceipt() async {
    setState(() => _isPrinting = true);
    try {
      ReceiptCopyMode copyMode;
      switch (_selectedCopyTab) {
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
      await ReceiptPrinterService.printReceiptDirect(widget.receipt, copyMode: copyMode);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print dialog error: $e'), backgroundColor: AppTheme.dangerRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final lang = appState.currentLanguage;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          lang == 'si' ? 'රිසිට්පත නිකුත් කරන ලදී' : 'Receipt Issued',
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            tooltip: lang == 'si' ? 'මුල් පිටුව' : 'Return to Home',
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                children: [
                  // Success Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF16A34A),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang == 'si' ? 'ගෙවීම සාර්ථකව සටහන් විය!' : 'Payment Recorded Successfully!',
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF166534)),
                              ),
                              Text(
                                lang == 'si'
                                    ? 'රිසිට්පත් #${widget.receipt.manualReceiptNo} දත්ත පද්ධතියේ සුරැකිණි.'
                                    : 'Receipt #${widget.receipt.manualReceiptNo} has been saved to database.',
                                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF15803D)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Section 2.2: SMS Confirmation Banner (Page 5)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sms, color: AppTheme.primaryBlue, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${LocalizationService.tr('sms_sent', lang: lang)} (${widget.receipt.customerPhone})',
                            style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF1E40AF), fontWeight: FontWeight.w500),
                          ),
                        ),
                        const Icon(Icons.done_all, color: AppTheme.primaryBlue, size: 16),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Interactive Thermal Receipt Layout matching Page 5
                  ThermalReceiptView(
                    receipt: widget.receipt,
                    selectedTab: _selectedCopyTab,
                    onTabChanged: (tab) => setState(() => _selectedCopyTab = tab),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  ElevatedButton(
                    onPressed: _isPrinting ? null : _printReceipt,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryNavy,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: _isPrinting
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                              const SizedBox(width: 10),
                              Text(lang == 'si' ? 'තාප මුද්‍රණ යන්ත්‍රය වෙත යවමින්...' : 'Sending to Thermal Printer...'),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.print, size: 20),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _selectedCopyTab == 1
                                      ? (lang == 'si' ? 'Customer Copy පමණක් මුද්‍රණය කරන්න' : 'Print Customer Copy Only')
                                      : _selectedCopyTab == 2
                                          ? (lang == 'si' ? 'Accounts Copy පමණක් මුද්‍රණය කරන්න' : 'Print Accounts Copy Only')
                                          : (lang == 'si' ? 'පිටපත් 2ම මුද්‍රණය කරන්න (All Copies)' : 'Print Receipt (Both Copies)'),
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 10),

                  OutlinedButton(
                    onPressed: () {
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(
                      lang == 'si' ? 'මුල් පිටුව වෙත ආපසු' : 'Back to Dashboard',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
