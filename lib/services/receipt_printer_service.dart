import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/receipt.dart';
import '../models/day_end_summary.dart';

class ReceiptPrinterService {
  static final currencyFormat = NumberFormat('#,##0.00', 'en_US');
  static final dateFormat = DateFormat('dd/MM/yyyy');

  /// Generates thermal/standard PDF document matching the sample in Page 5
  static Future<Uint8List> generateReceiptPdf(Receipt receipt, {bool isReprint = false}) async {
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    try {
      final bytes = await rootBundle.load('assets/images/jay_pharma_logo.png');
      logoImage = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {}

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
                      pw.Text(
                        'VAT No: 123456789-7000',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 6),
                
                // Customer Copy Label
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    if (isReprint)
                      pw.Text(
                        '** DUPLICATE COPY **',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.red900),
                      )
                    else
                      pw.SizedBox(),
                    pw.Text(
                      'CUSTOMER COPY',
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

                if (receipt.comments.isNotEmpty) ...[
                  pw.SizedBox(height: 3),
                  pw.Text('Notes: ${receipt.comments}', style: const pw.TextStyle(fontSize: 7)),
                ],

                pw.SizedBox(height: 6),
                pw.Text('Received with thanks.', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
                pw.SizedBox(height: 18),

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
                      pw.Text("Collector's Signature", style: const pw.TextStyle(fontSize: 7.5)),
                      pw.Text('(${receipt.collectorName} - ${receipt.collectorId})', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
                    ],
                  ),
                ),

                pw.SizedBox(height: 6),
                pw.Center(
                  child: pw.Text(
                    'GPS: ${receipt.latitude.toStringAsFixed(4)}, ${receipt.longitude.toStringAsFixed(4)} | Device Verified',
                    style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
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

  /// Triggers device printing or portable Bluetooth thermal printer dialog
  static Future<void> printReceiptDirect(Receipt receipt, {bool isReprint = false}) async {
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
}
