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
  /// formatted matching the original clean Jay Pharma receipt layout.
  static Future<Uint8List> generateReceiptPdf(
    Receipt receipt, {
    bool isReprint = false,
    ReceiptCopyMode copyMode = ReceiptCopyMode.all,
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    try {
      final bytes = await rootBundle.load('assets/images/jay_pharma_logo.png');
      logoImage = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {}

    final printCustomer = copyMode == ReceiptCopyMode.all || copyMode == ReceiptCopyMode.customerOnly;
    final printAccounts = copyMode == ReceiptCopyMode.all || copyMode == ReceiptCopyMode.accountsOnly;

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 4 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // 1. Customer Copy
                if (printCustomer)
                  _buildReceiptCopy(
                    receipt: receipt,
                    copyTitle: 'CUSTOMER COPY',
                    logoImage: logoImage,
                    isReprint: isReprint,
                  ),

                // 2. Cut / Tear Line
                if (copyMode == ReceiptCopyMode.all)
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 10),
                    child: pw.Row(
                      children: [
                        pw.Expanded(child: pw.Divider(color: PdfColors.grey500, thickness: 0.8)),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6),
                          child: pw.Text(
                            '- - - - CUT HERE - - - -',
                            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                          ),
                        ),
                        pw.Expanded(child: pw.Divider(color: PdfColors.grey500, thickness: 0.8)),
                      ],
                    ),
                  ),

                // 3. Accounts Copy
                if (printAccounts)
                  _buildReceiptCopy(
                    receipt: receipt,
                    copyTitle: 'ACCOUNTS COPY',
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

  /// Builds a single thermal receipt slip copy in the original clean Jay Pharma format
  static pw.Widget _buildReceiptCopy({
    required Receipt receipt,
    required String copyTitle,
    pw.MemoryImage? logoImage,
    bool isReprint = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 4),
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
                pw.Text(
                  'VAT No: 123456789-7000',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 6),

          // Copy Label
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (isReprint || receipt.reprintCount > 0)
                pw.Text(
                  '** DUPLICATE COPY **',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.red900),
                )
              else
                pw.SizedBox(),
              pw.Text(
                copyTitle,
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.Divider(thickness: 0.8),

          // Receipt Title & No
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(
                children: [
                  pw.Text('RECEIPT  ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                    'No. ${receipt.manualReceiptNo}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.red800,
                    ),
                  ),
                ],
              ),
              pw.Text(
                'Date: ${dateFormat.format(receipt.createdAt)}',
                style: const pw.TextStyle(fontSize: 8.5),
              ),
            ],
          ),
          pw.SizedBox(height: 4),

          // Customer Info Table
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(3.0),
              1: const pw.FlexColumnWidth(0.5),
              2: const pw.FlexColumnWidth(4.5),
              3: const pw.FlexColumnWidth(3.0),
              4: const pw.FlexColumnWidth(0.5),
              5: const pw.FlexColumnWidth(3.5),
            },
            children: [
              pw.TableRow(
                children: [
                  pw.Text('Customer No', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(':', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(receipt.customerCode, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Payment Type', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(':', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(receipt.paymentMethodDisplay, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Text('Customer Name', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(':', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(receipt.customerName, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Amount (Rs.)', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(':', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(currencyFormat.format(receipt.totalAmount), style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Text('Address', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(':', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(receipt.customerAddress, style: const pw.TextStyle(fontSize: 7.5)),
                  pw.SizedBox(),
                  pw.SizedBox(),
                  pw.SizedBox(),
                ],
              ),
            ],
          ),

          if (receipt.paymentMethod == PaymentMethod.cheque) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              'Cheque: #${receipt.chequeNumber ?? ""} | ${receipt.bank ?? ""} (${receipt.branch ?? ""}) | Date: ${receipt.chequeDate != null ? dateFormat.format(receipt.chequeDate!) : ""}',
              style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800),
            ),
          ],

          pw.SizedBox(height: 6),
          pw.Divider(thickness: 0.8),

          // Invoices Table Header
          pw.Row(
            children: [
              pw.Expanded(flex: 1, child: pw.Text('#', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
              pw.Expanded(flex: 3, child: pw.Text('Invoice No.', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
              pw.Expanded(flex: 3, child: pw.Text('Inv Date', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
              pw.Expanded(flex: 3, child: pw.Text('Inv Amt (Rs.)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
              pw.Expanded(flex: 3, child: pw.Text('Settled (Rs.)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
            ],
          ),
          pw.Divider(thickness: 0.5),

          // Invoices Rows
          if (receipt.allocatedInvoices.isEmpty) ...[
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Text('Advance Payment on Account', style: const pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
            ),
          ] else ...[
            for (final inv in receipt.allocatedInvoices)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                child: pw.Row(
                  children: [
                    pw.Expanded(flex: 1, child: pw.Text('${inv.itemIndex}', style: const pw.TextStyle(fontSize: 7.5))),
                    pw.Expanded(flex: 3, child: pw.Text(inv.invoiceNo, style: const pw.TextStyle(fontSize: 7.5))),
                    pw.Expanded(flex: 3, child: pw.Text(dateFormat.format(inv.invoiceDate), style: const pw.TextStyle(fontSize: 7))),
                    pw.Expanded(flex: 3, child: pw.Text(currencyFormat.format(inv.invoiceAmount), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7.5))),
                    pw.Expanded(flex: 3, child: pw.Text(currencyFormat.format(inv.amountSettled), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                  ],
                ),
              ),
          ],

          pw.Divider(thickness: 0.8),

          // Total Row
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text('Total Paid:   ', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
              pw.Text('Rs. ${currencyFormat.format(receipt.totalAmount)}', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.Divider(thickness: 0.8),

          if (receipt.comments.trim().isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                'Remarks: ${receipt.comments.trim()}',
                style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
              ),
            ),
          ],

          pw.SizedBox(height: 6),
          pw.Text('Received with thanks.', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
          pw.SizedBox(height: 14),

          // Signatures: Collector on Left, Customer Stamp Box on Right
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              // Collector Signature
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 90,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(top: pw.BorderSide(width: 0.8, color: PdfColors.black)),
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text("Collector's Signature", style: const pw.TextStyle(fontSize: 7.5)),
                  pw.Text('(${receipt.collectorName})', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
                ],
              ),

              // Customer Signature & Stamp Space (Box removed, blank space preserved)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.SizedBox(height: 55),
                  pw.Container(width: 95, height: 0.6, color: PdfColors.black),
                  pw.SizedBox(height: 1),
                  pw.Text('Customer Signature', style: const pw.TextStyle(fontSize: 7)),
                  pw.Text('(Authorized Sign)', style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.grey700)),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 10),

          // Footer
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  'Developed By Ceyloninnovation.com',
                  style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                ),
                pw.SizedBox(height: 1),
                pw.Text(
                  'Hotline 0114 758 900',
                  style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
                ),
              ],
            ),
          ),
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
  static Future<void> printReceiptDirect(
    Receipt receipt, {
    bool isReprint = false,
    ReceiptCopyMode copyMode = ReceiptCopyMode.all,
  }) async {
    try {
      final isBtConnected = await BluetoothPrinterService.isConnected();
      if (isBtConnected) {
        final success = await BluetoothPrinterService.printReceiptDirect(
          receipt,
          isReprint: isReprint,
          copyMode: copyMode,
        );
        if (success) return;
      } else {
        // Try auto-connect to saved printer if available before falling back
        final savedConnected = await BluetoothPrinterService.autoConnectToSavedPrinter();
        if (savedConnected) {
          final success = await BluetoothPrinterService.printReceiptDirect(
            receipt,
            isReprint: isReprint,
            copyMode: copyMode,
          );
          if (success) return;
        }
      }
    } catch (_) {}

    final pdfBytes = await generateReceiptPdf(receipt, isReprint: isReprint, copyMode: copyMode);
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
