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
  // 0: All (Both Copies), 1: Customer Copy, 2: Accounts Copy
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tab Selector (Switch between Copies or Both)
        Container(
          width: 360,
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

        // Main Thermal Slip
        Container(
          width: 360,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
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
                          border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.35), width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'DUPLICATE COPY\nREPRINTED UNDER OTP',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFDC2626).withValues(alpha: 0.25),
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_selectedTab == 0 || _selectedTab == 1) ...[
                      _buildReceiptCopy(
                        copyTitle: 'CUSTOMER COPY',
                        isReprint: widget.isReprint,
                      ),
                    ],

                    if (_selectedTab == 0) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Row(
                          children: [
                            const Expanded(child: Divider(color: Color(0xFF94A3B8), thickness: 1)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                children: [
                                  const Icon(Icons.content_cut, size: 14, color: Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'CUT HERE',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF64748B),
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Expanded(child: Divider(color: Color(0xFF94A3B8), thickness: 1)),
                          ],
                        ),
                      ),
                    ],

                    if (_selectedTab == 0 || _selectedTab == 2) ...[
                      _buildReceiptCopy(
                        copyTitle: 'ACCOUNTS COPY',
                        isReprint: widget.isReprint,
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

  Widget _buildReceiptCopy({required String copyTitle, bool isReprint = false}) {
    final currency = NumberFormat('#,##0.00', 'en_US');
    final dateFormat = DateFormat('dd/MM/yyyy');
    final receipt = widget.receipt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Header (Centered Logo & Company Details matching ERP)
        Center(
          child: Column(
            children: [
              const JayPharmaLogo(size: 42, showText: false),
              const SizedBox(height: 6),
              Text(
                'JAY PHARMA (PVT) LTD',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F1E36),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'No. 123, Main Street, Colombo 07, Sri Lanka\nTel: 011 234 5678 | Email: info@jaypharma.lk\nVAT No: 123456789-7000',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 8.5,
                  color: const Color(0xFF475569),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              const Divider(color: Color(0xFF94A3B8), thickness: 1),
              Text(
                copyTitle,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'OFFICIAL RECEIPT',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                ),
              ),
              if (isReprint || receipt.reprintCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    '*** DUPLICATE (REPRINT) ***',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ),
              const Divider(color: Color(0xFF94A3B8), thickness: 1),
            ],
          ),
        ),

        // RECEIPT No. and Date
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'RECEIPT  ',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'No. ${receipt.manualReceiptNo}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFB91C1C),
                  ),
                ),
              ],
            ),
            Text(
              'Date: ${dateFormat.format(receipt.createdAt)}',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Customer & Payment Info Grid
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReceiptField('Customer No', receipt.customerCode, isBold: true),
                  const SizedBox(height: 4),
                  _buildReceiptField('Customer Name', receipt.customerName, isBold: true),
                  const SizedBox(height: 4),
                  _buildReceiptField('Address', receipt.customerAddress),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReceiptField('Payment Type', receipt.paymentMethodDisplay, isBold: true),
                  const SizedBox(height: 4),
                  _buildReceiptField('Amount (Rs.)', currency.format(receipt.totalAmount), isBold: true),
                ],
              ),
            ),
          ],
        ),

        if (receipt.paymentMethod == PaymentMethod.cheque) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Cheque: #${receipt.chequeNumber ?? ""} | ${receipt.bank ?? ""} (${receipt.branch ?? ""}) | Date: ${receipt.chequeDate != null ? dateFormat.format(receipt.chequeDate!) : ""}',
              style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF334155)),
            ),
          ),
        ],

        const SizedBox(height: 10),
        const Divider(color: Color(0xFF94A3B8), thickness: 1, height: 12),

        // Table Header
        Row(
          children: [
            _tableHeaderCell('#', flex: 1),
            _tableHeaderCell('Invoice No.', flex: 3),
            _tableHeaderCell('Invoice Date', flex: 3),
            _tableHeaderCell('Invoice Amount (Rs.)', flex: 3, align: TextAlign.right),
            _tableHeaderCell('Amount Settled (Rs.)', flex: 3, align: TextAlign.right),
          ],
        ),
        const Divider(color: Color(0xFFCBD5E1), thickness: 0.8, height: 10),

        // Table Rows
        if (receipt.allocatedInvoices.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: Text(
                'Advance Payment on Account (No invoices attached)',
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
          )
        else
          for (final inv in receipt.allocatedInvoices)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  _tableDataCell('${inv.itemIndex}', flex: 1),
                  _tableDataCell(inv.invoiceNo, flex: 3),
                  _tableDataCell(dateFormat.format(inv.invoiceDate), flex: 3),
                  _tableDataCell(currency.format(inv.invoiceAmount), flex: 3, align: TextAlign.right),
                  _tableDataCell(currency.format(inv.amountSettled), flex: 3, align: TextAlign.right, isBold: true),
                ],
              ),
            ),

        const Divider(color: Color(0xFF94A3B8), thickness: 1, height: 14),

        // Total Paid Row
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Total Paid',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 28),
            Text(
              currency.format(receipt.totalAmount),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const Divider(color: Color(0xFF94A3B8), thickness: 1, height: 14),

        if (receipt.comments.trim().isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Remarks: ${receipt.comments.trim()}',
              style: GoogleFonts.inter(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        Text(
          'Received with thanks.',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontStyle: FontStyle.italic,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 18),

        // Signatures: Collector on Left, Customer Signature with Stamp Area on Right
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Left: Collector Signature
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 1,
                    color: const Color(0xFF0F172A),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Collector's Signature",
                    style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF0F172A)),
                  ),
                  Text(
                    '(${receipt.collectorName})',
                    style: GoogleFonts.inter(fontSize: 8, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Right: Customer Signature & Stamp Space (Box removed, open space preserved)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 64),
                  Container(width: 120, height: 1, color: const Color(0xFF1E293B)),
                  const SizedBox(height: 4),
                  Text(
                    'Customer Signature',
                    style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w500, color: const Color(0xFF0F172A)),
                  ),
                  Text(
                    '(Authorized Sign)',
                    style: GoogleFonts.inter(fontSize: 7.5, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Ceylon Innovation Hotline Footer
        Center(
          child: Column(
            children: [
              Text(
                'Developed By Ceyloninnovation.com',
                style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
              ),
              const SizedBox(height: 1),
              Text(
                'Hotline 0114 758 900',
                style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptField(String label, String value, {bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 75,
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF475569)),
          ),
        ),
        Text(': ', style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF475569))),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 9.5,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tableHeaderCell(String text, {required int flex, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: align,
        style: GoogleFonts.inter(
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF0F172A),
        ),
      ),
    );
  }

  Widget _tableDataCell(String text, {required int flex, TextAlign align = TextAlign.left, bool isBold = false}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: align,
        style: GoogleFonts.inter(
          fontSize: 8.5,
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
          color: const Color(0xFF0F172A),
        ),
      ),
    );
  }
}
