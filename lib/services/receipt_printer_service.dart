import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'bluetooth_printer_service.dart';
import '../models/receipt.dart';
import '../models/day_end_summary.dart';
import '../models/customer.dart';
import '../models/invoice.dart';

class ReceiptPrinterService {
  static final currencyFormat = NumberFormat('#,##0.00', 'en_US');
  static final dateFormat = DateFormat('dd/MM/yyyy');

  /// Generates thermal/standard PDF document with Dual Copies (Customer Copy + Accounts Copy)
  /// formatted matching the user's POS thermal receipt specification.
  static Future<Uint8List> generateReceiptPdf(Receipt receipt, {bool isReprint = false}) async {
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    try {
      final bytes = await rootBundle.load('assets/images/jay_pharma_logo.png');
      logoImage = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {}

    final fontNormal = pw.Font.courier();
    final fontBold = pw.Font.courierBold();

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 4 * PdfPageFormat.mm),
        theme: pw.ThemeData.withFont(
          base: fontNormal,
          bold: fontBold,
        ),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // 1. First Copy: Customer Copy
                _buildReceiptCopy(
                  receipt: receipt,
                  copyTitle: '*** Customer Copy ***',
                  fontNormal: fontNormal,
                  fontBold: fontBold,
                  logoImage: logoImage,
                  isReprint: isReprint,
                ),

                // 2. Perforated Cut / Tear Separator
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 12),
                  child: pw.Column(
                    children: [
                      pw.Text('============================================', style: pw.TextStyle(font: fontBold, fontSize: 7.5), textAlign: pw.TextAlign.center),
                      pw.SizedBox(height: 2),
                      pw.Text('- - - - - - - - - CUT HERE - - - - - - - - -', style: pw.TextStyle(font: fontBold, fontSize: 7.5), textAlign: pw.TextAlign.center),
                      pw.SizedBox(height: 2),
                      pw.Text('============================================', style: pw.TextStyle(font: fontBold, fontSize: 7.5), textAlign: pw.TextAlign.center),
                    ],
                  ),
                ),

                // 3. Second Copy: Accounts Copy
                _buildReceiptCopy(
                  receipt: receipt,
                  copyTitle: '*** Accounts Copy ***',
                  fontNormal: fontNormal,
                  fontBold: fontBold,
                  logoImage: logoImage,
                  isReprint: isReprint,
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Builds a single thermal receipt slip copy matching the sample format
  static pw.Widget _buildReceiptCopy({
    required Receipt receipt,
    required String copyTitle,
    required pw.Font fontNormal,
    required pw.Font fontBold,
    pw.MemoryImage? logoImage,
    bool isReprint = false,
  }) {
    final currency = NumberFormat('#,##0.00', 'en_US');
    final dateFormat = DateFormat('dd/MM/yyyy');
    final dateTimeFormat = DateFormat('dd/MM/yyyy hh:mm a');

    final totalInvoiced = receipt.allocatedInvoices.fold<double>(0.0, (s, i) => s + i.invoiceAmount);
    final totalSettled = receipt.allocatedInvoices.fold<double>(0.0, (s, i) => s + i.amountSettled);
    final totalBalance = receipt.allocatedInvoices.fold<double>(0.0, (s, i) => s + i.remainingBalance);
    final unallocatedAdvance = (receipt.totalAmount - totalSettled) > 0.01 ? (receipt.totalAmount - totalSettled) : 0.0;

    const dashes = '--------------------------------------------';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Company Header (Centered)
        pw.Center(
          child: pw.Column(
            children: [
              if (logoImage != null) ...[
                pw.Image(logoImage, height: 26, fit: pw.BoxFit.contain),
                pw.SizedBox(height: 3),
              ],
              pw.Text(
                'JAY PHARMA (PVT) LTD',
                style: pw.TextStyle(font: fontBold, fontSize: 11),
              ),
              pw.SizedBox(height: 1),
              pw.Text(
                'No. 123, Main Street, Colombo 07, Sri Lanka',
                style: pw.TextStyle(font: fontNormal, fontSize: 7),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'Tel: 011 234 5678 | Email: info@jaypharma.lk',
                style: pw.TextStyle(font: fontNormal, fontSize: 7),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'VAT No: 123456789-7000',
                style: pw.TextStyle(font: fontNormal, fontSize: 7),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(dashes, style: pw.TextStyle(font: fontNormal, fontSize: 7.5), textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 2),

        // Copy Title & Document Title (Centered)
        pw.Center(
          child: pw.Text(
            copyTitle,
            style: pw.TextStyle(font: fontBold, fontSize: 9.5),
          ),
        ),
        pw.SizedBox(height: 1),
        pw.Center(
          child: pw.Text(
            '*** OFFICIAL RECEIPT ***',
            style: pw.TextStyle(font: fontBold, fontSize: 9),
          ),
        ),
        if (isReprint || receipt.reprintCount > 0) ...[
          pw.SizedBox(height: 1),
          pw.Center(
            child: pw.Text(
              '*** DUPLICATE COPY (REPRINT) ***',
              style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.red900),
            ),
          ),
        ],
        pw.SizedBox(height: 2),
        pw.Text(dashes, style: pw.TextStyle(font: fontNormal, fontSize: 7.5), textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 3),

        // Metadata Key-Value pairs matching sample image layout
        _pdfMetaRow('Receipt No', receipt.manualReceiptNo, fontNormal, fontBold, isBoldVal: true),
        _pdfMetaRow('Receipt Date', dateTimeFormat.format(receipt.createdAt), fontNormal, fontBold),
        _pdfMetaRow('Customer Code', receipt.customerCode, fontNormal, fontBold),
        _pdfMetaRow('Customer Name', receipt.customerName, fontNormal, fontBold, isBoldVal: true),
        if (receipt.customerAddress.isNotEmpty)
          _pdfMetaRow('Address', receipt.customerAddress, fontNormal, fontBold),
        if (receipt.customerPhone.isNotEmpty)
          _pdfMetaRow('Customer Phone', receipt.customerPhone, fontNormal, fontBold),
        _pdfMetaRow('Payment Type', receipt.paymentMethodDisplay.toUpperCase(), fontNormal, fontBold, isBoldVal: true),
        if (receipt.paymentMethod == PaymentMethod.cheque) ...[
          _pdfMetaRow('Cheque Number', receipt.chequeNumber ?? '', fontNormal, fontBold, isBoldVal: true),
          if (receipt.chequeDate != null)
            _pdfMetaRow('Cheque Date', dateFormat.format(receipt.chequeDate!), fontNormal, fontBold),
          _pdfMetaRow('Bank / Branch', '${receipt.bank ?? ""} (${receipt.branch ?? ""})', fontNormal, fontBold),
        ],
        _pdfMetaRow('Collector', '${receipt.collectorName} (${receipt.collectorId})', fontNormal, fontBold),

        pw.SizedBox(height: 3),
        pw.Text(dashes, style: pw.TextStyle(font: fontNormal, fontSize: 7.5), textAlign: pw.TextAlign.center),

        // Table Header
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              flex: 5,
              child: pw.Text('Description & Inv No', style: pw.TextStyle(font: fontBold, fontSize: 7.5)),
            ),
            pw.Expanded(
              flex: 3,
              child: pw.Text('Inv Amt(LKR)', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: fontBold, fontSize: 7.5)),
            ),
            pw.Expanded(
              flex: 3,
              child: pw.Text('Settled(LKR)', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: fontBold, fontSize: 7.5)),
            ),
          ],
        ),
        pw.Text(dashes, style: pw.TextStyle(font: fontNormal, fontSize: 7.5), textAlign: pw.TextAlign.center),

        // Invoices Rows
        if (receipt.allocatedInvoices.isEmpty) ...[
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Advance Payment on Account', style: pw.TextStyle(font: fontNormal, fontSize: 7.5)),
                pw.Text(currency.format(receipt.totalAmount), style: pw.TextStyle(font: fontBold, fontSize: 7.5)),
              ],
            ),
          ),
        ] else ...[
          for (final inv in receipt.allocatedInvoices) ...[
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: pw.Text(
                      '#${inv.invoiceNo} (${dateFormat.format(inv.invoiceDate)})',
                      style: pw.TextStyle(font: fontNormal, fontSize: 7.2),
                    ),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      currency.format(inv.invoiceAmount),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(font: fontNormal, fontSize: 7.2),
                    ),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      currency.format(inv.amountSettled),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(font: fontBold, fontSize: 7.2),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (unallocatedAdvance > 0.01) ...[
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: pw.Text('Unallocated Advance', style: pw.TextStyle(font: fontNormal, fontSize: 7.2)),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text('0.00', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: fontNormal, fontSize: 7.2)),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      currency.format(unallocatedAdvance),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(font: fontBold, fontSize: 7.2),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],

        pw.Text(dashes, style: pw.TextStyle(font: fontNormal, fontSize: 7.5), textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 2),

        // Financial Totals block (matching sample image format)
        if (receipt.allocatedInvoices.isNotEmpty) ...[
          _pdfTotalRow('Sub Total(LKR)   :', currency.format(totalInvoiced), fontNormal, fontBold),
          _pdfTotalRow('Total Settled(LKR):', currency.format(totalSettled), fontNormal, fontBold),
        ],
        _pdfTotalRow('Paid Amount(LKR) :', currency.format(receipt.totalAmount), fontNormal, fontBold),
        pw.SizedBox(height: 2),

        // PROMINENT BOLD BALANCE (matching sample image!)
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Balance(LKR)     :',
              style: pw.TextStyle(font: fontBold, fontSize: 9.5),
            ),
            pw.Text(
              currency.format(totalBalance),
              style: pw.TextStyle(font: fontBold, fontSize: 9.5),
            ),
          ],
        ),

        pw.SizedBox(height: 2),
        pw.Text(dashes, style: pw.TextStyle(font: fontNormal, fontSize: 7.5), textAlign: pw.TextAlign.center),

        // Payment Breakdown block
        pw.Text('**** Payment Details', style: pw.TextStyle(font: fontBold, fontSize: 7.5)),
        pw.SizedBox(height: 1),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('${receipt.paymentMethodDisplay}(LKR):', style: pw.TextStyle(font: fontNormal, fontSize: 7.2)),
            pw.Text(currency.format(receipt.totalAmount), style: pw.TextStyle(font: fontBold, fontSize: 7.2)),
          ],
        ),
        if (receipt.paymentMethod == PaymentMethod.cheque)
          pw.Text('Chq #${receipt.chequeNumber ?? ""}', style: pw.TextStyle(font: fontNormal, fontSize: 7)),
        if (receipt.comments.trim().isNotEmpty) ...[
          pw.SizedBox(height: 1),
          pw.Text('Remarks: ${receipt.comments.trim()}', style: pw.TextStyle(font: fontNormal, fontSize: 7)),
        ],

        pw.SizedBox(height: 2),
        pw.Text(dashes, style: pw.TextStyle(font: fontNormal, fontSize: 7.5), textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 3),

        // Footer block matching sample photo
        pw.Center(
          child: pw.Text(
            receipt.customerName,
            style: pw.TextStyle(font: fontBold, fontSize: 7.5),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.Center(
          child: pw.Text(
            'Hope to See you Soon',
            style: pw.TextStyle(font: fontNormal, fontSize: 7.5),
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text(
            'Received with thanks.',
            style: pw.TextStyle(font: fontNormal, fontSize: 7),
          ),
        ),
        pw.SizedBox(height: 8),

        // Signatures & Customer Seal Stamping Area
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            // Left: Collector Signature
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(height: 42), // Signing space
                pw.Container(width: 82, height: 0.6, color: PdfColors.black),
                pw.SizedBox(height: 2),
                pw.Text('Collector Signature', style: pw.TextStyle(font: fontBold, fontSize: 6.5)),
                pw.Text('(${receipt.collectorName})', style: pw.TextStyle(font: fontNormal, fontSize: 5.8)),
              ],
            ),

            // Right: Customer Official Seal Box & Signature
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Dedicated Rubber Stamp / Seal Box
                pw.Container(
                  width: 96,
                  height: 40,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey500, width: 0.6),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      '[ CUSTOMER SEAL ]\n(STAMP HERE)',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(font: fontNormal, fontSize: 5.5, color: PdfColors.grey600),
                    ),
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Container(width: 96, height: 0.6, color: PdfColors.black),
                pw.SizedBox(height: 2),
                pw.Text('Customer Signature', style: pw.TextStyle(font: fontBold, fontSize: 6.5)),
                pw.Text('(Authorized Seal & Sign)', style: pw.TextStyle(font: fontNormal, fontSize: 5.5)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Center(
          child: pw.Text(
            'Developed By Ceyloninnovation.com',
            style: pw.TextStyle(font: fontBold, fontSize: 6.5, color: PdfColors.grey800),
          ),
        ),
        pw.SizedBox(height: 1),
        pw.Center(
          child: pw.Text(
            'Hotline 0114 758 900',
            style: pw.TextStyle(font: fontNormal, fontSize: 6, color: PdfColors.grey800),
          ),
        ),
      ],
    );
  }

  static pw.Widget _pdfMetaRow(String label, String value, pw.Font normal, pw.Font bold, {bool isBoldVal = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 70,
            child: pw.Text('$label:', style: pw.TextStyle(font: normal, fontSize: 7)),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(font: isBoldVal ? bold : normal, fontSize: 7),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _pdfTotalRow(String label, String value, pw.Font normal, pw.Font bold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: normal, fontSize: 7.8)),
          pw.Text(value, style: pw.TextStyle(font: normal, fontSize: 7.8)),
        ],
      ),
    );
  }

  /// Generates the Printable Day-End Summary Statement required by Section 3
  static Future<Uint8List> generateDayEndSummaryPdf(DayEndSummary summary, List<Receipt> receipts) async {
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    try {
      final bytes = await rootBundle.load('assets/images/jay_pharma_logo.png');
      logoImage = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {}

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    if (logoImage != null) ...[
                      pw.Image(logoImage, height: 42, fit: pw.BoxFit.contain),
                      pw.SizedBox(height: 6),
                    ],
                    pw.Text('JAY PHARMA (PVT) LTD', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text('DAY-END CASH COLLECTION SUMMARY STATEMENT', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.Text('Official Representative Settlement Document', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Divider(thickness: 1.5),

              // Collector & Date Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Collector: ${summary.collectorName} (${summary.collectorId})', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Branch: Colombo Central Division', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Statement Date: ${dateFormat.format(summary.date)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Status: ${summary.isFinalized ? "FINALIZED & LOCKED" : "DRAFT"}', style: pw.TextStyle(fontSize: 9, color: summary.isFinalized ? PdfColors.green800 : PdfColors.amber800)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),

              // Summary Metric Cards Box
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text('TOTAL CASH COLLECTED', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                        pw.SizedBox(height: 3),
                        pw.Text('Rs. ${currencyFormat.format(summary.totalCash)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text('TOTAL CHEQUE AMOUNT', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                        pw.SizedBox(height: 3),
                        pw.Text('Rs. ${currencyFormat.format(summary.totalCheque)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text('TOTAL INCOME (CASH + CHQ)', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                        pw.SizedBox(height: 3),
                        pw.Text('Rs. ${currencyFormat.format(summary.totalIncome)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // Cheque Numbers List (Section 3 Requirement)
              pw.Text('Cheques Received Summary:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              if (summary.chequesList.isEmpty)
                pw.Text('No cheque payments recorded for this date.', style: const pw.TextStyle(fontSize: 8.5, fontStyle: pw.FontStyle.italic))
              else
                pw.TableHelper.fromTextArray(
                  headers: ['#', 'Cheque Number', 'Bank', 'Customer', 'Cheque Date', 'Amount (Rs.)'],
                  data: [
                    for (int i = 0; i < summary.chequesList.length; i++)
                      [
                        '${i + 1}',
                        summary.chequesList[i].chequeNumber,
                        summary.chequesList[i].bank,
                        '${summary.chequesList[i].customerCode} - ${summary.chequesList[i].customerName}',
                        dateFormat.format(summary.chequesList[i].chequeDate),
                        currencyFormat.format(summary.chequesList[i].amount),
                      ]
                  ],
                  headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  cellStyle: const pw.TextStyle(fontSize: 8),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                ),
              pw.SizedBox(height: 14),

              // Itemized Receipts List
              pw.Text('Daily Receipts Breakdown (${receipts.length} receipts issued):', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.TableHelper.fromTextArray(
                headers: ['Receipt No.', 'Time', 'Customer', 'Type', 'Invoices', 'Amount (Rs.)'],
                data: [
                  for (final r in receipts)
                    [
                      r.manualReceiptNo,
                      DateFormat('HH:mm').format(r.createdAt),
                      '${r.customerCode} - ${r.customerName}',
                      r.paymentMethodDisplay,
                      r.invoiceNumbersDisplay,
                      currencyFormat.format(r.totalAmount),
                    ]
                ],
                headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 7.5),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              ),

              pw.Spacer(),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 25),

              // Signature Section (Section 3 Requirement: Signed by representative and cashier)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(width: 180, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.8)))),
                      pw.SizedBox(height: 4),
                      pw.Text('Representative / Cash Collector Signature', style: const pw.TextStyle(fontSize: 8.5)),
                      pw.Text('Date: ____________________', style: const pw.TextStyle(fontSize: 7.5)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(width: 180, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.8)))),
                      pw.SizedBox(height: 4),
                      pw.Text('Back-Office Cashier Signature', style: const pw.TextStyle(fontSize: 8.5)),
                      pw.Text('Date: ____________________', style: const pw.TextStyle(fontSize: 7.5)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  'One signed copy must be retained by the cash collector for record-keeping purposes.',
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Triggers direct Bluetooth thermal printing if connected, or falls back to system print dialog
  static Future<void> printReceiptDirect(Receipt receipt, {bool isReprint = false}) async {
    try {
      final isBtConnected = await BluetoothPrinterService.isConnected();
      if (isBtConnected) {
        final success = await BluetoothPrinterService.printReceiptDirect(receipt, isReprint: isReprint);
        if (success) return;
      }
    } catch (_) {}

    final pdfBytes = await generateReceiptPdf(receipt, isReprint: isReprint);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'JayPharma_Receipt_${receipt.manualReceiptNo}',
    );
  }

  /// Triggers printing of Day-End Summary Statement
  static Future<void> printDayEndSummary(DayEndSummary summary, List<Receipt> receipts) async {
    final pdfBytes = await generateDayEndSummaryPdf(summary, receipts);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'JayPharma_DayEnd_${DateFormat('yyyyMMdd').format(summary.date)}',
    );
  }

  /// Generates 80mm POS Thermal Statement for a Customer
  static Future<Uint8List> generateCustomerStatementPdf(
    Customer customer,
    List<Invoice> invoices, {
    required bool onlyOutstanding,
    required String collectorName,
    required String collectorId,
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    try {
      final bytes = await rootBundle.load('assets/images/jay_pharma_logo.png');
      logoImage = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {}

    final filteredInvoices = onlyOutstanding
        ? invoices.where((i) => i.outstandingBalance > 0.01).toList()
        : List<Invoice>.from(invoices);

    final totalInvAmount = filteredInvoices.fold<double>(0.0, (sum, i) => sum + i.totalAmount);
    final totalSettledAmount = filteredInvoices.fold<double>(0.0, (sum, i) => sum + i.setAmt);
    final totalOutstanding = filteredInvoices.fold<double>(0.0, (sum, i) => sum + i.outstandingBalance);

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 4 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Column(
                    children: [
                      if (logoImage != null) ...[
                        pw.Image(logoImage, height: 32, fit: pw.BoxFit.contain),
                        pw.SizedBox(height: 4),
                      ],
                      pw.Text(
                        'JAY PHARMA (PVT) LTD',
                        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'No. 123, Main Street, Colombo 07, Sri Lanka',
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.Text(
                        'Tel: 011 234 5678 | Email: info@jaypharma.lk',
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Divider(thickness: 0.8),

                // Statement Title
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'CUSTOMER STATEMENT',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: pw.BoxDecoration(
                          color: onlyOutstanding ? PdfColors.amber100 : PdfColors.blue100,
                          borderRadius: pw.BorderRadius.circular(4),
                          border: pw.Border.all(color: onlyOutstanding ? PdfColors.amber800 : PdfColors.blue800, width: 0.5),
                        ),
                        child: pw.Text(
                          onlyOutstanding ? 'OUTSTANDING INVOICES ONLY' : 'ALL INVOICES (FULL HISTORY)',
                          style: pw.TextStyle(
                            fontSize: 7.5,
                            fontWeight: pw.FontWeight.bold,
                            color: onlyOutstanding ? PdfColors.amber900 : PdfColors.blue900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Divider(thickness: 0.8),

                // Customer Details Table
                pw.Table(
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3.0),
                    1: const pw.FlexColumnWidth(0.5),
                    2: const pw.FlexColumnWidth(7.5),
                  },
                  children: [
                    pw.TableRow(
                      children: [
                        pw.Text('Customer No', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text(':', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text(customer.code, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Text('Customer Name', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text(':', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text(customer.name, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    if (customer.town.isNotEmpty)
                      pw.TableRow(
                        children: [
                          pw.Text('Town / Area', style: const pw.TextStyle(fontSize: 8)),
                          pw.Text(':', style: const pw.TextStyle(fontSize: 8)),
                          pw.Text(customer.town, style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                    if (customer.address.isNotEmpty)
                      pw.TableRow(
                        children: [
                          pw.Text('Address', style: const pw.TextStyle(fontSize: 8)),
                          pw.Text(':', style: const pw.TextStyle(fontSize: 8)),
                          pw.Text(customer.address, style: const pw.TextStyle(fontSize: 7.5)),
                        ],
                      ),
                    if (customer.phone.isNotEmpty)
                      pw.TableRow(
                        children: [
                          pw.Text('Contact No', style: const pw.TextStyle(fontSize: 8)),
                          pw.Text(':', style: const pw.TextStyle(fontSize: 8)),
                          pw.Text(customer.phone, style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                    pw.TableRow(
                      children: [
                        pw.Text('Statement Date', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text(':', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text(DateFormat('dd/MM/yyyy  HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Text('Prepared By', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text(':', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text('$collectorName ($collectorId)', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Divider(thickness: 0.8),

                // Table Header
                pw.Row(
                  children: [
                    pw.Expanded(flex: 1, child: pw.Text('#', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(flex: 3, child: pw.Text('Inv No', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(flex: 3, child: pw.Text('Date (Age)', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(flex: 3, child: pw.Text('Inv Amt (Rs)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(flex: 3, child: pw.Text('Balance (Rs)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                  ],
                ),
                pw.Divider(thickness: 0.5),

                // Invoices Rows
                if (filteredInvoices.isEmpty) ...[
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 8),
                    child: pw.Center(
                      child: pw.Text(
                        onlyOutstanding ? 'No outstanding invoices. All settled!' : 'No invoices on record.',
                        style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic),
                      ),
                    ),
                  ),
                ] else ...[
                  for (int i = 0; i < filteredInvoices.length; i++) ...[
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2),
                      child: pw.Row(
                        children: [
                          pw.Expanded(flex: 1, child: pw.Text('${i + 1}', style: const pw.TextStyle(fontSize: 7))),
                          pw.Expanded(flex: 3, child: pw.Text(filteredInvoices[i].invoiceNo, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                          pw.Expanded(
                            flex: 3,
                            child: pw.Text(
                              '${dateFormat.format(filteredInvoices[i].invoiceDate)} (${filteredInvoices[i].deliveryAgeDays}d)',
                              style: const pw.TextStyle(fontSize: 6.5),
                            ),
                          ),
                          pw.Expanded(
                            flex: 3,
                            child: pw.Text(
                              currencyFormat.format(filteredInvoices[i].totalAmount),
                              textAlign: pw.TextAlign.right,
                              style: const pw.TextStyle(fontSize: 7),
                            ),
                          ),
                          pw.Expanded(
                            flex: 3,
                            child: pw.Text(
                              filteredInvoices[i].outstandingBalance <= 0.01
                                  ? '0.00'
                                  : currencyFormat.format(filteredInvoices[i].outstandingBalance),
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(
                                fontSize: 7.5,
                                fontWeight: filteredInvoices[i].outstandingBalance > 0.01 ? pw.FontWeight.bold : pw.FontWeight.normal,
                                color: filteredInvoices[i].outstandingBalance > 0.01 ? PdfColors.black : PdfColors.grey700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],

                pw.Divider(thickness: 0.8),
                pw.SizedBox(height: 2),

                // Summary
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Invoices Count:', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('${filteredInvoices.length}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Invoiced Value:', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('Rs. ${currencyFormat.format(totalInvAmount)}', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Settled Amount:', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('Rs. ${currencyFormat.format(totalSettledAmount)}', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
                pw.Divider(thickness: 1),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL OUTSTANDING DUE:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Rs. ${currencyFormat.format(totalOutstanding)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 16),

                // Collector Signature
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(
                        width: 110,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(top: pw.BorderSide(width: 0.8, color: PdfColors.black)),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text("Representative's Signature", style: const pw.TextStyle(fontSize: 7.5)),
                      pw.Text('($collectorName)', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.Text(
                    'Computer generated POS statement. Retain for records.',
                    style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Triggers POS thermal printing for Customer History / Statement
  static Future<void> printCustomerStatement(
    Customer customer,
    List<Invoice> invoices, {
    required bool onlyOutstanding,
    required String collectorName,
    required String collectorId,
  }) async {
    final pdfBytes = await generateCustomerStatementPdf(
      customer,
      invoices,
      onlyOutstanding: onlyOutstanding,
      collectorName: collectorName,
      collectorId: collectorId,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'JayPharma_${customer.code}_Statement',
    );
  }
}
