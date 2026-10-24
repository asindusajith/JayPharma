import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/receipt.dart';
import '../../theme/app_theme.dart';
import '../../services/localization_service.dart';
import 'preview_payment_screen.dart';

/// Formatter that automatically inserts dashes: XXXXXX-XXXX-XXX (6 digits - 4 digits - 3 digits, max 13 digits)
class ChequeNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String newText = newValue.text;

    // Handle backspace directly preceding or on a dash
    if (oldValue.text.length > newValue.text.length &&
        oldValue.selection.baseOffset > 0 &&
        oldValue.selection.baseOffset <= oldValue.text.length &&
        oldValue.text[oldValue.selection.baseOffset - 1] == '-') {
      final deletePos = oldValue.selection.baseOffset - 2;
      if (deletePos >= 0) {
        newText = oldValue.text.substring(0, deletePos) +
            oldValue.text.substring(oldValue.selection.baseOffset);
      }
    }

    String digits = newText.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 13) {
      digits = digits.substring(0, 13);
    }

    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 6 || i == 10) {
        buffer.write('-');
      }
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();

    // Adjust cursor position so cursor stays aligned after auto-formatting
    int cursorPosition = formatted.length;
    if (newValue.selection.baseOffset < newValue.text.length) {
      int digitsBefore = 0;
      for (int i = 0; i < newValue.selection.baseOffset && i < newText.length; i++) {
        if (RegExp(r'\d').hasMatch(newText[i])) {
          digitsBefore++;
        }
      }
      int targetOffset = 0;
      int countedDigits = 0;
      while (targetOffset < formatted.length && countedDigits < digitsBefore) {
        if (RegExp(r'\d').hasMatch(formatted[targetOffset])) {
          countedDigits++;
        }
        targetOffset++;
      }
      cursorPosition = targetOffset;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorPosition),
    );
  }
}

class PaymentDetailsScreen extends StatefulWidget {
  const PaymentDetailsScreen({super.key});

  @override
  State<PaymentDetailsScreen> createState() => _PaymentDetailsScreenState();
}

class _PaymentDetailsScreenState extends State<PaymentDetailsScreen> {
  final _amountController = TextEditingController();
  final _receiptNoController = TextEditingController();
  final _chequeNoController = TextEditingController();
  final _commentsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _receiptNoController.text = appState.draftManualReceiptNo;
    if (appState.draftPaymentAmount > 0) {
      _amountController.text = appState.draftPaymentAmount.toStringAsFixed(0);
    }
    if (appState.draftChequeNumber != null && appState.draftChequeNumber!.isNotEmpty) {
      _chequeNoController.text = appState.draftChequeNumber!;
    }
    appState.fetchNextSuggestedReceiptNo().then((_) {
      if (mounted && appState.draftManualReceiptNo.isNotEmpty) {
        setState(() {
          _receiptNoController.text = appState.draftManualReceiptNo;
        });
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _receiptNoController.dispose();
    _chequeNoController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final lang = appState.currentLanguage;
    final customer = appState.draftCustomer;
    final currency = NumberFormat('#,##0.00', 'en_US');
    final dateFormat = DateFormat('dd/MM/yyyy');

    if (customer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('No customer selected.')),
      );
    }

    final totalAllocated = appState.totalAllocatedAmount;
    final remainingPayment = appState.remainingPaymentAmount;
    final isUniqueReceiptNo = appState.isReceiptNumberUnique(appState.draftManualReceiptNo);

    final outstandingInvoices = appState.draftInvoices.where((i) => i.outstandingBalance > 0 && i.status != 'Settled').toList();
    final paidInvoices = appState.draftInvoices.where((i) => i.outstandingBalance <= 0 || i.status == 'Settled').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          LocalizationService.tr('payment_details', lang: lang),
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(16),
          child: Container(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStepIndicator(1, lang == 'si' ? 'පාරිභෝගිකයා' : 'Customer', true),
                _buildStepDivider(true),
                _buildStepIndicator(2, lang == 'si' ? 'ගෙවීම' : 'Payment', true),
                _buildStepDivider(false),
                _buildStepIndicator(3, lang == 'si' ? 'සමාලෝචනය' : 'Review', false),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Section 2.2: Selected Customer Details Card
                      // CRITICAL RULE: "Do not display the customer's total outstanding balance in the customer details section."
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 78,
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryNavy,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      customer.code,
                                      style: GoogleFonts.outfit(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 0.3,
                                      ),
                                      maxLines: 1,
                                      softWrap: false,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      customer.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textDark,
                                        height: 1.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Payment Method Selector (Cash / Cheque)
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
                                LocalizationService.tr('payment_method', lang: lang),
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildMethodButton(
                                      title: LocalizationService.tr('cash', lang: lang),
                                      icon: Icons.payments_outlined,
                                      isSelected: appState.draftPaymentMethod == PaymentMethod.cash,
                                      onTap: () {
                                        appState.setDraftPaymentMethod(PaymentMethod.cash);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildMethodButton(
                                      title: LocalizationService.tr('cheque', lang: lang),
                                      icon: Icons.account_balance_outlined,
                                      isSelected: appState.draftPaymentMethod == PaymentMethod.cheque,
                                      onTap: () {
                                        appState.setDraftPaymentMethod(PaymentMethod.cheque);
                                      },
                                    ),
                                  ),
                                ],
                              ),

                              // Cheque Fields (Full Cheque Number & Cheque Date)
                              if (appState.draftPaymentMethod == PaymentMethod.cheque) ...[
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 12),
                                Text(
                                  lang == 'si' ? 'චෙක්පත් විස්තර (අනිවාර්යයි)' : 'Cheque Details (Mandatory)',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                                ),
                                const SizedBox(height: 12),

                                // Single Row with Cheque Number Textbox & Cheque Date Picker
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: TextField(
                                        controller: _chequeNoController,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [ChequeNumberFormatter()],
                                        onChanged: (val) {
                                          final digits = val.replaceAll(RegExp(r'\D'), '');
                                          final bankCode = digits.length > 6 ? digits.substring(6, digits.length.clamp(6, 10)) : '';
                                          final branchCode = digits.length > 10 ? digits.substring(10, digits.length.clamp(10, 13)) : '';

                                          appState.setDraftChequeDetails(
                                            bank: bankCode.isNotEmpty ? bankCode : null,
                                            branch: branchCode.isNotEmpty ? branchCode : null,
                                            chequeNumber: val, // Sent with dashes: e.g. 123456-1234-123
                                            chequeDate: appState.draftChequeDate,
                                          );
                                          setState(() {});
                                        },
                                        style: GoogleFonts.outfit(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.6,
                                          color: AppTheme.textDark,
                                        ),
                                        decoration: InputDecoration(
                                          labelText: lang == 'si' ? 'චෙක්පත් අංකය' : 'Cheque Number',
                                          hintText: '123456-1234-123',
                                          hintStyle: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade400, letterSpacing: 0.6),
                                          prefixIcon: const Icon(Icons.confirmation_number_outlined, size: 20),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          InkWell(
                                            borderRadius: BorderRadius.circular(12),
                                            onTap: () => _pickChequeDate(appState, dateFormat),
                                            child: InputDecorator(
                                              decoration: InputDecoration(
                                                labelText: LocalizationService.tr('cheque_date', lang: lang),
                                                prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                                              ),
                                              child: Text(
                                                appState.draftChequeDate != null
                                                    ? dateFormat.format(appState.draftChequeDate!)
                                                    : (lang == 'si' ? 'දිනය' : 'Date'),
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: appState.draftChequeDate != null ? AppTheme.textDark : AppTheme.textLight,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                          if (appState.draftChequeDate != null) ...[
                                            Builder(
                                              builder: (_) {
                                                final now = DateTime.now();
                                                final today = DateTime(now.year, now.month, now.day);
                                                final chosen = DateTime(appState.draftChequeDate!.year, appState.draftChequeDate!.month, appState.draftChequeDate!.day);
                                                final diffDays = chosen.difference(today).inDays;
                                                if (diffDays > 30) {
                                                  return Padding(
                                                    padding: const EdgeInsets.only(top: 4, left: 2),
                                                    child: Row(
                                                      children: [
                                                        const Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFD97706)),
                                                        const SizedBox(width: 3),
                                                        Expanded(
                                                          child: Text(
                                                            'More than 30 days ($diffDays days)',
                                                            style: GoogleFonts.inter(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.bold,
                                                              color: const Color(0xFFB45309),
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }
                                                return const SizedBox.shrink();
                                              },
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                // Display breakdown table directly below as requested in Image 2
                                _buildChequeBreakdown(_chequeNoController.text, lang),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Total Payment Amount & Manual Receipt Number
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
                              // Payment Amount Field
                              Text(
                                LocalizationService.tr('payment_amount', lang: lang),
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _amountController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (val) {
                                  final amount = double.tryParse(val.replaceAll(',', '')) ?? 0.0;
                                  appState.setDraftPaymentAmount(amount);
                                },
                                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                                decoration: InputDecoration(
                                  prefixText: 'Rs. ',
                                  prefixStyle: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                                  hintText: '0.00',
                                  suffixIcon: _amountController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, size: 18),
                                          onPressed: () {
                                            _amountController.clear();
                                            appState.setDraftPaymentAmount(0.0);
                                          },
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 10),

                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 12),

                              // Manual Receipt Number Field (Unique & Validated - Section 6)
                              Row(
                                children: [
                                  Text(
                                    LocalizationService.tr('manual_receipt_no', lang: lang),
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                                  ),
                                  const Spacer(),
                                  if (appState.draftManualReceiptNo.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isUniqueReceiptNo ? AppTheme.successLight : AppTheme.dangerLight,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isUniqueReceiptNo ? Icons.check_circle : Icons.error,
                                            size: 13,
                                            color: isUniqueReceiptNo ? AppTheme.successGreen : AppTheme.dangerRed,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isUniqueReceiptNo
                                                ? (lang == 'si' ? 'වලංගු අංකයකි' : 'Unique & Valid')
                                                : (lang == 'si' ? 'දැනටමත් භාවිතා කර ඇත' : 'Duplicate Number'),
                                            style: GoogleFonts.inter(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: isUniqueReceiptNo ? AppTheme.successGreen : AppTheme.dangerRed,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _receiptNoController,
                                readOnly: true,
                                canRequestFocus: false,
                                enableInteractiveSelection: false,
                                mouseCursor: SystemMouseCursors.basic,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.receiptRed,
                                ),
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.receipt, size: 20, color: AppTheme.receiptRed),
                                  suffixIcon: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 10),
                                    child: Icon(Icons.lock_rounded, size: 18, color: Color(0xFF64748B)),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Allocation Status Summary Bar
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: remainingPayment == 0 && appState.draftPaymentAmount > 0
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: remainingPayment == 0 && appState.draftPaymentAmount > 0
                                ? const Color(0xFFA7F3D0)
                                : const Color(0xFFBFDBFE),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    LocalizationService.tr('allocated', lang: lang),
                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF475569)),
                                  ),
                                  Text(
                                    'Rs. ${currency.format(totalAllocated)}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 30, color: const Color(0xFFCBD5E1)),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    LocalizationService.tr('remaining', lang: lang),
                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF475569)),
                                  ),
                                  Text(
                                    'Rs. ${currency.format(remainingPayment)}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: remainingPayment > 0 ? AppTheme.primaryBlue : AppTheme.successGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Outstanding Invoices List Header (Pending & Part Settled)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            lang == 'si'
                                ? 'හිඟ ඉන්වොයිසි (ගෙවිය යුතු සහ අර්ධ වශයෙන් ගෙවූ)'
                                : 'Outstanding Invoices (Pending & Part Settled)',
                            style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                          ),
                          Text(
                            '${outstandingInvoices.length} ${lang == 'si' ? 'ඉන්වොයිසි' : 'Invoices'}',
                            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (appState.isLoadingInvoices)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primaryBlue),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  lang == 'si' ? 'දත්ත පද්ධතියෙන් ඉන්වොයිසි ලබාගනිමින් පවතී...' : 'Loading customer invoices from JayPharma ERP...',
                                  style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (outstandingInvoices.isEmpty)
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Center(
                              child: Text(
                                lang == 'si'
                                    ? 'මෙම පාරිභෝගිකයා සඳහා හිඟ ඉන්වොයිසි නොමැත.\nඔබට අත්තිකාරම් ගෙවීමක් සටහන් කළ හැක.'
                                    : 'No outstanding (pending/part-settled) invoices for this customer.\nYou can proceed to record an Advance Payment.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.textMuted),
                              ),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: outstandingInvoices.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final inv = outstandingInvoices[index];
                            return _buildInvoiceRow(context, index, inv, appState, currency, dateFormat, lang);
                          },
                        ),

                      // Settled / Paid Invoices Section (Shown at the bottom of the list)
                      if (!appState.isLoadingInvoices && paidInvoices.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              lang == 'si' ? 'ගෙවා නිමකළ ඉන්වොයිසි' : 'Settled Invoices (Paid History)',
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle, size: 12, color: Color(0xFF047857)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${paidInvoices.length} ${lang == 'si' ? 'සමථය' : 'Settled'}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF047857),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: paidInvoices.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final inv = paidInvoices[index];
                            return _buildPaidInvoiceRow(context, inv, currency, dateFormat, lang);
                          },
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Optional Comment Text Box (Page 4)
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
                                LocalizationService.tr('add_comment', lang: lang),
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _commentsController,
                                maxLines: 2,
                                onChanged: (val) => appState.setDraftComments(val),
                                decoration: InputDecoration(
                                  hintText: lang == 'si'
                                      ? 'සටහන් හෝ අදාළ ඉන්වොයිසි විස්තර (විකල්ප)...'
                                      : 'Enter notes or specific invoice references (optional)...',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 80), // spacing for bottom bar
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Sticky Action Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang == 'si' ? 'මුළු ගෙවීම් මුදල' : 'Payment Total',
                          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                        ),
                        Text(
                          'Rs. ${currency.format(appState.draftPaymentAmount)}',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryNavy,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      final error = appState.validateDraftPayment();
                      if (error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error), backgroundColor: AppTheme.dangerRed),
                        );
                        return;
                      }

                      // Navigate to Step 3: Review Payment Details
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PreviewPaymentScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          LocalizationService.tr('confirm_payment', lang: lang),
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceRow(
    BuildContext context,
    int index,
    dynamic inv,
    AppState appState,
    NumberFormat currency,
    DateFormat dateFormat,
    String lang,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: inv.isSelected ? const Color(0xFFF0F9FF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: inv.isSelected ? AppTheme.primaryBlue : const Color(0xFFE2E8F0),
          width: inv.isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (appState.draftPaymentAmount <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(LocalizationService.tr('payment_amount_required', lang: lang)),
                backgroundColor: AppTheme.warningAmber,
              ),
            );
            return;
          }

          final errorMsg = appState.toggleInvoice(inv);
          if (errorMsg != null) {
            // Section 2.2 Requirement: "Prevent users from selecting additional invoices once the entire payment amount has been allocated. Display an appropriate message when this occurs."
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMsg),
                backgroundColor: AppTheme.dangerRed,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: inv.isSelected,
                    activeColor: AppTheme.primaryBlue,
                    onChanged: (_) {
                      if (appState.draftPaymentAmount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(LocalizationService.tr('payment_amount_required', lang: lang)),
                            backgroundColor: AppTheme.warningAmber,
                          ),
                        );
                        return;
                      }
                      final errorMsg = appState.toggleInvoice(inv);
                      if (errorMsg != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(errorMsg), backgroundColor: AppTheme.dangerRed),
                        );
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Invoice Details (Spacious layout with no overflow)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Line 1: Invoice No + Status Tag + Delivery Age
                    Row(
                      children: [
                        Text(
                          '#${inv.invoiceNo}',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Status Badge: Part Settled vs Pending
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: inv.status == 'Part Settled' ? const Color(0xFFEFF6FF) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: inv.status == 'Part Settled' ? const Color(0xFFBFDBFE) : const Color(0xFFFDE68A),
                            ),
                          ),
                          child: Text(
                            inv.status == 'Part Settled' ? LocalizationService.tr('part_settled', lang: lang) : LocalizationService.tr('pending', lang: lang),
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: inv.status == 'Part Settled' ? const Color(0xFF1D4ED8) : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Delivery Age Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: inv.deliveryAgeDays > 30 ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: inv.deliveryAgeDays > 30 ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            '${LocalizationService.tr('age_prefix', lang: lang)}${inv.deliveryAgeDays} ${LocalizationService.tr('days', lang: lang)}',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: inv.deliveryAgeDays > 30 ? const Color(0xFFB45309) : AppTheme.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Line 2: Spacious 2-Column Info (Left: Date & Paid | Right: Due Amount)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Left Column: Date & Paid Amount
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF94A3B8)),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${LocalizationService.tr('date_prefix', lang: lang)}${dateFormat.format(inv.invoiceDate)}',
                                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              if (inv.setAmt > 0) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline, size: 12, color: Color(0xFF2563EB)),
                                    const SizedBox(width: 5),
                                    Text(
                                      '${LocalizationService.tr('paid_prefix', lang: lang)}Rs. ${currency.format(inv.setAmt)}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF2563EB),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Right Column: Due Amount (High visibility, never overflows)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              LocalizationService.tr('due_amount', lang: lang),
                              style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Rs. ${currency.format(inv.outstandingBalance)}',
                              style: GoogleFonts.outfit(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Allocated Pay Amount (if selected)
                    if (inv.isSelected) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${LocalizationService.tr('pay_amount', lang: lang)}:',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF166534)),
                            ),
                            Text(
                              'Rs. ${currency.format(inv.allocatedAmount)}',
                              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF166534)),
                            ),
                          ],
                        ),
                      ),
                      if (inv.allocatedAmount < inv.outstandingBalance) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${LocalizationService.tr('partial_payment_tag', lang: lang)} (${LocalizationService.tr('remaining_prefix', lang: lang)}Rs. ${currency.format(inv.remainingBalanceAfterAllocation)})',
                          style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFD97706), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMethodButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryNavy : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryNavy : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: isSelected ? Colors.white : AppTheme.textMuted),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppTheme.textDark,
              ),
            ),
          ],
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

  Widget _buildPaidInvoiceRow(
    BuildContext context,
    dynamic inv,
    NumberFormat currency,
    DateFormat dateFormat,
    String lang,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.check, size: 15, color: Color(0xFF047857)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Line 1: Invoice No + Settled Tag + Delivery Age
                Row(
                  children: [
                    Text(
                      '#${inv.invoiceNo}',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Text(
                        LocalizationService.tr('settled', lang: lang),
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF047857),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        '${LocalizationService.tr('age_prefix', lang: lang)}${inv.deliveryAgeDays} ${LocalizationService.tr('days', lang: lang)}',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Line 2: 2-Column Info (Left: Date & Paid | Right: Due Rs. 0.00)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 5),
                              Text(
                                '${LocalizationService.tr('date_prefix', lang: lang)}${dateFormat.format(inv.invoiceDate)}',
                                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.check_circle_outline, size: 12, color: Color(0xFF047857)),
                              const SizedBox(width: 5),
                              Text(
                                '${LocalizationService.tr('paid_prefix', lang: lang)}Rs. ${currency.format(inv.setAmt > 0 ? inv.setAmt : inv.totalAmount)}',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF047857),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          LocalizationService.tr('due_amount', lang: lang),
                          style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Rs. 0.00',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
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

  /// Display breakdown table directly matching Image 2
  Widget _buildChequeBreakdown(String rawText, String lang) {
    final digits = rawText.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return const SizedBox.shrink();
    }

    final chequeNo = digits.isNotEmpty ? digits.substring(0, digits.length.clamp(0, 6)) : '------';
    final bankCode = digits.length > 6 ? digits.substring(6, digits.length.clamp(6, 10)) : (digits.length == 6 ? '----' : '-');
    final branchCode = digits.length > 10 ? digits.substring(10, digits.length.clamp(10, 13)) : (digits.length >= 10 ? '---' : '-');

    final StringBuffer sysBuffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 6 || i == 10) sysBuffer.write('-');
      sysBuffer.write(digits[i]);
    }
    final systemChequeNo = sysBuffer.toString();
    final isComplete = digits.length == 13;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isComplete ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Display',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  color: const Color(0xFF0F172A),
                ),
              ),
              if (isComplete)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF16A34A)),
                      const SizedBox(width: 4),
                      Text(
                        lang == 'si' ? 'අංක 13 සම්පූර්ණයි' : '13 Digits Complete',
                        style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF15803D)),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  '${digits.length}/13 Digits',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildBreakdownRow('Cheque No:', chequeNo),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                _buildBreakdownRow('Bank Code:', bankCode),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                _buildBreakdownRow('Branch Code:', branchCode),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Cheque No (On System) in red text as depicted in user's image
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(fontSize: 12.5),
                children: [
                  TextSpan(
                    text: 'Cheque No (On System) - ',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF991B1B),
                    ),
                  ),
                  TextSpan(
                    text: systemChequeNo,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: const Color(0xFFB91C1C),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickChequeDate(AppState appState, DateFormat dateFormat) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: appState.draftChequeDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (picked != null) {
      appState.setDraftChequeDetails(
        bank: appState.draftBank,
        branch: appState.draftBranch,
        chequeNumber: appState.draftChequeNumber,
        chequeDate: picked,
      );
      if (!mounted) return;
      setState(() {});

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final chosen = DateTime(picked.year, picked.month, picked.day);
      final diffDays = chosen.difference(today).inDays;

      if (diffDays > 30) {
        if (!mounted) return;
        // Show Alert Dialog in English informing the user
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cheque Date Notice',
                    style: GoogleFonts.outfit(
                      fontSize: 16.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              'This selected cheque date (${dateFormat.format(picked)}) is more than 30 days from today ($diffDays days post-dated).',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: const Color(0xFF334155),
                height: 1.45,
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                ),
                child: Text(
                  'OK',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This selected cheque date is more than 30 days ($diffDays days from today).',
                    style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFD97706),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }
}
