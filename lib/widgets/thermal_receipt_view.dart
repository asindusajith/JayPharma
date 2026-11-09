import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/receipt.dart';
import '../widgets/jay_pharma_logo.dart';

class ThermalReceiptView extends StatefulWidget {
  final Receipt receipt;
  final bool isReprint;

  const ThermalReceiptView({
    super.key,
    required this.receipt,
    this.isReprint = false,
  });

  @override
  State<ThermalReceiptView> createState() => _ThermalReceiptViewState();
}

class _ThermalReceiptViewState extends State<ThermalReceiptView> {
  // 0: All / Continuous Roll (Both Copies), 1: Customer Copy, 2: Accounts Copy
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top Tab Selector & Info Pill
        Container(
          width: 380,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            children: [
              _buildTabButton(0, 'All (2 Copies)'),
              _buildTabButton(1, 'Customer Copy'),
              _buildTabButton(2, 'Accounts Copy'),
            ],
          ),
        ),

        // Thermal Roll Slip Card
        Container(
          width: 380,
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(color: const Color(0xFFD1D5DB), width: 1.2),
          ),
          child: Stack(
            children: [
              if (widget.isReprint || widget.receipt.reprintCount > 0)
                Positioned.fill(
                  child: Center(
                    child: Transform.rotate(
                      angle: -0.5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.4), width: 2.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'DUPLICATE COPY\nREPRINTED UNDER OTP',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.robotoMono(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFDC2626).withValues(alpha: 0.22),
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_selectedTab == 0 || _selectedTab == 1) ...[
                      _buildReceiptSlip(
                        copyTitle: '*** Customer Copy ***',
                      ),
                    ],

                    if (_selectedTab == 0) ...[
                      // Perforated Cut Line between copies
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Column(
                          children: [
                            Text(
                              '============================================',
                              style: GoogleFonts.robotoMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.content_cut, size: 13, color: Color(0xFF475569)),
                                const SizedBox(width: 6),
                                Text(
                                  '- - - - - - CUT HERE - - - - - -',
                                  style: GoogleFonts.robotoMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF334155)),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.content_cut, size: 13, color: Color(0xFF475569)),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '============================================',
                              style: GoogleFonts.robotoMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_selectedTab == 0 || _selectedTab == 2) ...[
                      _buildReceiptSlip(
                        copyTitle: '*** Accounts Copy ***',
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton(int index, String label) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptSlip({required String copyTitle}) {
    final currency = NumberFormat('#,##0.00', 'en_US');
    final dateFormat = DateFormat('dd/MM/yyyy');
    final dateTimeFormat = DateFormat('dd/MM/yyyy hh:mm a');

    final receipt = widget.receipt;
    final totalInvoiced = receipt.allocatedInvoices.fold<double>(0.0, (s, i) => s + i.invoiceAmount);
    final totalSettled = receipt.allocatedInvoices.fold<double>(0.0, (s, i) => s + i.amountSettled);
    final totalBalance = receipt.allocatedInvoices.fold<double>(0.0, (s, i) => s + i.remainingBalance);
    final unallocatedAdvance = (receipt.totalAmount - totalSettled) > 0.01 ? (receipt.totalAmount - totalSettled) : 0.0;

    const dashes = '--------------------------------------------';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Company Header (Centered)
        Center(
          child: Column(
            children: [
              const JayPharmaLogo(size: 34, showText: false),
              const SizedBox(height: 6),
              Text(
                'JAY PHARMA (PVT) LTD',
                style: GoogleFonts.robotoMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF111827),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'No. 123, Main Street, Colombo 07, Sri Lanka',
                style: GoogleFonts.robotoMono(fontSize: 9.5, color: const Color(0xFF374151)),
                textAlign: TextAlign.center,
              ),
              Text(
                'Tel: 011 234 5678 | Email: info@jaypharma.lk',
                style: GoogleFonts.robotoMono(fontSize: 9.5, color: const Color(0xFF374151)),
                textAlign: TextAlign.center,
              ),
              Text(
                'VAT No: 123456789-7000',
                style: GoogleFonts.robotoMono(fontSize: 9.5, color: const Color(0xFF374151)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(dashes, style: GoogleFonts.robotoMono(fontSize: 10, color: const Color(0xFF4B5563)), textAlign: TextAlign.center),
        const SizedBox(height: 4),

        // Copy Title & Receipt Title (Centered)
        Center(
          child: Text(
            copyTitle,
            style: GoogleFonts.robotoMono(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF111827),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Center(
          child: Text(
            '*** OFFICIAL RECEIPT ***',
            style: GoogleFonts.robotoMono(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1E293B),
            ),
          ),
        ),
        if (widget.isReprint || receipt.reprintCount > 0) ...[
          const SizedBox(height: 2),
          Center(
            child: Text(
              '*** DUPLICATE COPY (REPRINT) ***',
              style: GoogleFonts.robotoMono(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFDC2626),
              ),
            ),
          ),
        ],
        const SizedBox(height: 4),
        Text(dashes, style: GoogleFonts.robotoMono(fontSize: 10, color: const Color(0xFF4B5563)), textAlign: TextAlign.center),
        const SizedBox(height: 6),

        // Metadata Key-Value pairs matching sample image
        _buildMetaRow('Receipt No', receipt.manualReceiptNo, isBold: true, highlightColor: const Color(0xFFB91C1C)),
        _buildMetaRow('Receipt Date', dateTimeFormat.format(receipt.createdAt)),
        _buildMetaRow('Customer Code', receipt.customerCode),
        _buildMetaRow('Customer Name', receipt.customerName, isBold: true),
        if (receipt.customerAddress.isNotEmpty)
          _buildMetaRow('Address', receipt.customerAddress),
        if (receipt.customerPhone.isNotEmpty)
          _buildMetaRow('Customer Phone', receipt.customerPhone),
        _buildMetaRow('Payment Type', receipt.paymentMethodDisplay.toUpperCase(), isBold: true),
        if (receipt.paymentMethod == PaymentMethod.cheque) ...[
          _buildMetaRow('Cheque Number', receipt.chequeNumber ?? '', isBold: true),
          if (receipt.chequeDate != null)
            _buildMetaRow('Cheque Date', dateFormat.format(receipt.chequeDate!)),
          _buildMetaRow('Bank / Branch', '${receipt.bank ?? ""} (${receipt.branch ?? ""})'),
        ],
        _buildMetaRow('Collector', '${receipt.collectorName} (${receipt.collectorId})'),

        const SizedBox(height: 6),
        Text(dashes, style: GoogleFonts.robotoMono(fontSize: 10, color: const Color(0xFF4B5563)), textAlign: TextAlign.center),
        const SizedBox(height: 4),

        // Invoices Table Header matching sample image
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              flex: 5,
              child: Text(
                'Description & Inv No',
                style: GoogleFonts.robotoMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF111827)),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                'Inv Amt(LKR)',
                textAlign: TextAlign.right,
                style: GoogleFonts.robotoMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF111827)),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                'Settled(LKR)',
                textAlign: TextAlign.right,
                style: GoogleFonts.robotoMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF111827)),
              ),
            ),
          ],
        ),
        Text(dashes, style: GoogleFonts.robotoMono(fontSize: 10, color: const Color(0xFF4B5563)), textAlign: TextAlign.center),

        // Table Rows
        if (receipt.allocatedInvoices.isEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Advance Payment on Account', style: GoogleFonts.robotoMono(fontSize: 9.5, color: const Color(0xFF1F2937))),
                Text(currency.format(receipt.totalAmount), style: GoogleFonts.robotoMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF111827))),
              ],
            ),
          ),
        ] else ...[
          for (final inv in receipt.allocatedInvoices) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.5),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      '#${inv.invoiceNo} (${dateFormat.format(inv.invoiceDate)})',
                      style: GoogleFonts.robotoMono(fontSize: 9, color: const Color(0xFF1F2937)),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      currency.format(inv.invoiceAmount),
                      textAlign: TextAlign.right,
                      style: GoogleFonts.robotoMono(fontSize: 9, color: const Color(0xFF1F2937)),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      currency.format(inv.amountSettled),
                      textAlign: TextAlign.right,
                      style: GoogleFonts.robotoMono(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF111827)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (unallocatedAdvance > 0.01) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.5),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text('Unallocated Advance', style: GoogleFonts.robotoMono(fontSize: 9, color: const Color(0xFF1F2937))),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text('0.00', textAlign: TextAlign.right, style: GoogleFonts.robotoMono(fontSize: 9, color: const Color(0xFF1F2937))),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      currency.format(unallocatedAdvance),
                      textAlign: TextAlign.right,
                      style: GoogleFonts.robotoMono(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF111827)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],

        Text(dashes, style: GoogleFonts.robotoMono(fontSize: 10, color: const Color(0xFF4B5563)), textAlign: TextAlign.center),
        const SizedBox(height: 4),

        // Financial Totals Block (Matching sample image)
        if (receipt.allocatedInvoices.isNotEmpty) ...[
          _buildTotalRow('Sub Total(LKR)   :', currency.format(totalInvoiced)),
          _buildTotalRow('Total Settled(LKR):', currency.format(totalSettled)),
        ],
        _buildTotalRow('Paid Amount(LKR) :', currency.format(receipt.totalAmount)),
        const SizedBox(height: 4),

        // PROMINENT BOLD BALANCE (Matching sample image!)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Balance(LKR)     :',
                style: GoogleFonts.robotoMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                currency.format(totalBalance),
                style: GoogleFonts.robotoMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 4),
        Text(dashes, style: GoogleFonts.robotoMono(fontSize: 10, color: const Color(0xFF4B5563)), textAlign: TextAlign.center),
        const SizedBox(height: 4),

        // Payment Breakdown block (matching sample image)
        Text(
          '**** Payment Details',
          style: GoogleFonts.robotoMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF111827)),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${receipt.paymentMethodDisplay}(LKR):', style: GoogleFonts.robotoMono(fontSize: 9.5, color: const Color(0xFF1F2937))),
            Text(currency.format(receipt.totalAmount), style: GoogleFonts.robotoMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF111827))),
          ],
        ),
        if (receipt.paymentMethod == PaymentMethod.cheque)
          Text('Chq #${receipt.chequeNumber ?? ""}', style: GoogleFonts.robotoMono(fontSize: 9, color: const Color(0xFF4B5563))),
        if (receipt.comments.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text('Remarks: ${receipt.comments.trim()}', style: GoogleFonts.robotoMono(fontSize: 9, color: const Color(0xFF374151))),
        ],

        const SizedBox(height: 4),
        Text(dashes, style: GoogleFonts.robotoMono(fontSize: 10, color: const Color(0xFF4B5563)), textAlign: TextAlign.center),
        const SizedBox(height: 6),

        // Footer block matching sample photo
        Center(
          child: Text(
            receipt.customerName,
            style: GoogleFonts.robotoMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF111827)),
            textAlign: TextAlign.center,
          ),
        ),
        Center(
          child: Text(
            'Hope to See you Soon',
            style: GoogleFonts.robotoMono(fontSize: 9.5, color: const Color(0xFF374151)),
          ),
        ),
        const SizedBox(height: 2),
        Center(
          child: Text(
            'Received with thanks.',
            style: GoogleFonts.robotoMono(fontSize: 9.5, fontStyle: FontStyle.italic, color: const Color(0xFF4B5563)),
          ),
        ),
        const SizedBox(height: 12),

        // Signatures & Customer Seal Stamping Area
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Left: Collector Signature
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 52), // Space for collector signature
                Container(width: 120, height: 1, color: const Color(0xFF1F2937)),
                const SizedBox(height: 3),
                Text('Collector Signature', style: GoogleFonts.robotoMono(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF374151))),
                Text('(${receipt.collectorName})', style: GoogleFonts.robotoMono(fontSize: 7.5, color: const Color(0xFF6B7280))),
              ],
            ),

            // Right: Customer Official Seal Box & Signature
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Dedicated Rubber Stamp / Seal Box
                Container(
                  width: 145,
                  height: 54,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF94A3B8), width: 1),
                    borderRadius: BorderRadius.circular(4),
                    color: const Color(0xFFF8FAFC),
                  ),
                  child: Center(
                    child: Text(
                      '[ CUSTOMER SEAL ]\n(STAMP HERE)',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.robotoMono(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Container(width: 145, height: 1, color: const Color(0xFF1F2937)),
                const SizedBox(height: 3),
                Text('Customer Signature', style: GoogleFonts.robotoMono(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF374151))),
                Text('(Authorized Seal & Sign)', style: GoogleFonts.robotoMono(fontSize: 7.5, color: const Color(0xFF6B7280))),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Developed By Ceyloninnovation.com',
            style: GoogleFonts.robotoMono(fontSize: 8, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
          ),
        ),
        const SizedBox(height: 2),
        Center(
          child: Text(
            'Hotline 0114 758 900',
            style: GoogleFonts.robotoMono(fontSize: 8, color: const Color(0xFF64748B)),
          ),
        ),
      ],
    );
  }

  Widget _buildMetaRow(String label, String value, {bool isBold = false, Color? highlightColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: GoogleFonts.robotoMono(fontSize: 9.5, color: const Color(0xFF374151)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.robotoMono(
                fontSize: 9.5,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: highlightColor ?? (isBold ? const Color(0xFF111827) : const Color(0xFF1F2937)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.robotoMono(fontSize: 10, color: const Color(0xFF374151))),
          Text(value, style: GoogleFonts.robotoMono(fontSize: 10, color: const Color(0xFF1F2937))),
        ],
      ),
    );
  }
}
