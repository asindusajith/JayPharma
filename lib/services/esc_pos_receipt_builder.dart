import 'package:flutter/services.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import '../models/receipt.dart';

class EscPosReceiptBuilder {
  /// Builds complete raw ESC/POS bytes matching the Ceylon Innovation ERP format with Logo
  static Future<List<int>> buildReceiptBytes(Receipt receipt, {bool is80mm = true, bool isReprint = false}) async {
    final profile = await CapabilityProfile.load();
    final paperSize = is80mm ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paperSize, profile);
    List<int> bytes = [];

    // Pre-load and process logo image on clean white canvas
    img.Image? logoImage;
    try {
      final byteData = await rootBundle.load('assets/images/jay_pharma_shield.png');
      final rawBytes = byteData.buffer.asUint8List();
      final decoded = img.decodeImage(rawBytes);
      if (decoded != null) {
        final targetWidth = is80mm ? 150 : 120;
        final resized = img.copyResize(decoded, width: targetWidth);
        final canvas = img.Image(width: resized.width, height: resized.height, numChannels: 4);
        img.fill(canvas, color: img.ColorRgba8(255, 255, 255, 255));
        img.compositeImage(canvas, resized);
        logoImage = canvas;
      }
    } catch (_) {}

    // 1. Copy 1: Customer Copy
    bytes += _buildSingleCopy(generator, receipt, 'CUSTOMER COPY', logoImage: logoImage, isReprint: isReprint);

    // 2. Cut Here Divider
    bytes += generator.feed(1);
    bytes += generator.hr(ch: '-');
    bytes += generator.text('- - - - - - - - - CUT HERE - - - - - - - - -', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.hr(ch: '-');
    bytes += generator.feed(1);

    // 3. Copy 2: Accounts Copy
    bytes += _buildSingleCopy(generator, receipt, 'ACCOUNTS COPY', logoImage: logoImage, isReprint: isReprint);

    // Final feed and paper cut
    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
  }

  static List<int> _buildSingleCopy(
    Generator generator,
    Receipt receipt,
    String copyTitle, {
    img.Image? logoImage,
    bool isReprint = false,
  }) {
    List<int> bytes = [];
    final currency = NumberFormat('#,##0.00', 'en_US');
    final dateFormat = DateFormat('dd/MM/yyyy');
    final dateTimeFormat = DateFormat('dd/MM/yyyy hh:mm a');

    final totalInvoiced = receipt.allocatedInvoices.fold<double>(0.0, (s, i) => s + i.invoiceAmount);
    final totalSettled = receipt.allocatedInvoices.fold<double>(0.0, (s, i) => s + i.amountSettled);
    final totalBalance = receipt.allocatedInvoices.fold<double>(0.0, (s, i) => s + i.remainingBalance);
    final unallocatedAdvance = (receipt.totalAmount - totalSettled) > 0.01 ? (receipt.totalAmount - totalSettled) : 0.0;

    // 1. Graphic Logo
    if (logoImage != null) {
      bytes += generator.image(logoImage, align: PosAlign.center);
      bytes += generator.feed(1);
    }

    // 2. Header (Matching ERP Style in Suwa Piyasa Cafe)
    bytes += generator.text(
      'JAY PHARMA (PVT) LTD',
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size1, width: PosTextSize.size1),
    );
    bytes += generator.text('No. 123, Main Street, Colombo 07', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('Tel: 011 234 5678 | info@jaypharma.lk', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('VAT No: 123456789-7000', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.hr(ch: '-');

    // 3. Copy Title & Document Title
    bytes += generator.text(copyTitle, styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('OFFICIAL RECEIPT', styles: const PosStyles(align: PosAlign.center, bold: true));
    if (isReprint || receipt.reprintCount > 0) {
      bytes += generator.text('DUPLICATE COPY (REPRINT)', styles: const PosStyles(align: PosAlign.center, bold: true));
    }
    bytes += generator.hr(ch: '-');

    // 4. Metadata (Clean full-width layout matching Ceylon Innovation ERP)
    bytes += generator.text('Receipt No : ${receipt.manualReceiptNo}', styles: const PosStyles(bold: true));
    bytes += generator.text('Order Date/Time: ${dateTimeFormat.format(receipt.createdAt)}');
    bytes += generator.text('Customer   : ${receipt.customerCode} - ${receipt.customerName}', styles: const PosStyles(bold: true));
    if (receipt.customerAddress.trim().isNotEmpty) {
      bytes += generator.text('Address    : ${receipt.customerAddress.trim()}');
    }
    bytes += generator.text('Payment    : ${receipt.paymentMethodDisplay.toUpperCase()}', styles: const PosStyles(bold: true));
    if (receipt.paymentMethod == PaymentMethod.cheque) {
      bytes += generator.text('Cheque No  : ${receipt.chequeNumber ?? ""}');
      if (receipt.chequeDate != null) {
        bytes += generator.text('Chq Date   : ${dateFormat.format(receipt.chequeDate!)}');
      }
      bytes += generator.text('Bank/Branch: ${receipt.bank ?? ""} (${receipt.branch ?? ""})');
    }
    bytes += generator.text('Collector  : ${receipt.collectorName} (${receipt.collectorId})');
    bytes += generator.hr(ch: '-');

    // 5. Invoices Table Header (Matching Description & Price, Qty, Total layout)
    bytes += generator.row([
      PosColumn(text: 'Description & Price', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(text: 'Inv Amt', width: 3, styles: const PosStyles(align: PosAlign.right, bold: true)),
      PosColumn(text: 'Settled', width: 3, styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]);
    bytes += generator.hr(ch: '-');

    // Invoices Rows
    if (receipt.allocatedInvoices.isEmpty) {
      bytes += generator.row([
        PosColumn(text: 'Advance Payment', width: 6),
        PosColumn(text: '0.00', width: 3, styles: const PosStyles(align: PosAlign.right)),
        PosColumn(text: currency.format(receipt.totalAmount), width: 3, styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);
    } else {
      for (final inv in receipt.allocatedInvoices) {
        // Line 1: Invoice number and date
        bytes += generator.text('#${inv.invoiceNo} (${dateFormat.format(inv.invoiceDate)})', styles: const PosStyles(bold: true));
        // Line 2: Balance remaining on left, amounts on right
        final balStr = inv.remainingBalance > 0.01 ? ' Bal: ${currency.format(inv.remainingBalance)}' : ' Settled';
        bytes += generator.row([
          PosColumn(text: balStr, width: 6),
          PosColumn(text: currency.format(inv.invoiceAmount), width: 3, styles: const PosStyles(align: PosAlign.right)),
          PosColumn(text: currency.format(inv.amountSettled), width: 3, styles: const PosStyles(align: PosAlign.right, bold: true)),
        ]);
      }
      if (unallocatedAdvance > 0.01) {
        bytes += generator.row([
          PosColumn(text: 'Advance Credit', width: 6),
          PosColumn(text: '0.00', width: 3, styles: const PosStyles(align: PosAlign.right)),
          PosColumn(text: currency.format(unallocatedAdvance), width: 3, styles: const PosStyles(align: PosAlign.right, bold: true)),
        ]);
      }
    }
    bytes += generator.hr(ch: '-');

    // 6. Totals (Sub Total & GrandTotal double-height bold matching Image 2!)
    if (receipt.allocatedInvoices.isNotEmpty) {
      bytes += generator.row([
        PosColumn(text: 'Sub Total :', width: 6),
        PosColumn(text: currency.format(totalInvoiced), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    bytes += generator.row([
      PosColumn(
        text: 'GrandTotal:',
        width: 6,
        styles: const PosStyles(bold: true, height: PosTextSize.size1),
      ),
      PosColumn(
        text: currency.format(receipt.totalAmount),
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size1),
      ),
    ]);

    // 7. Payments Section (Matching ********* Payments ********* in Image 2)
    bytes += generator.text('********* Payments *********', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.row([
      PosColumn(text: '${receipt.paymentMethodDisplay.toUpperCase()}(LKR):', width: 6),
      PosColumn(text: currency.format(receipt.totalAmount), width: 6, styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]);
    if (receipt.comments.trim().isNotEmpty) {
      bytes += generator.text('Remarks: ${receipt.comments.trim()}');
    }

    // 8. Outstanding Balance Section
    if (receipt.allocatedInvoices.isNotEmpty && totalBalance > 0.01) {
      bytes += generator.text('********* Outstanding *********', styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.row([
        PosColumn(text: 'Remaining Balance:', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(text: currency.format(totalBalance), width: 6, styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);
    }
    bytes += generator.hr(ch: '-');

    // 9. Order / Receipt Number Highlight (Matching Image 2: -Order Number- 1031)
    bytes += generator.feed(1);
    bytes += generator.text('- Receipt Number -', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text(
      receipt.manualReceiptNo,
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size1, width: PosTextSize.size1),
    );
    bytes += generator.feed(1);

    // 10. Customer Stamp Box & Signatures (Clean centered, non-wrapping layout)
    bytes += generator.text('+--------------------------+', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('|                          |', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('|      CUSTOMER SEAL       |', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('|       (STAMP HERE)       |', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('|                          |', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('+--------------------------+', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(1);

    bytes += generator.row([
      PosColumn(text: '..................', width: 6, styles: const PosStyles(align: PosAlign.center)),
      PosColumn(text: '..................', width: 6, styles: const PosStyles(align: PosAlign.center)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Collector Signature', width: 6, styles: const PosStyles(align: PosAlign.center, bold: true)),
      PosColumn(text: 'Customer Signature', width: 6, styles: const PosStyles(align: PosAlign.center, bold: true)),
    ]);
    bytes += generator.row([
      PosColumn(text: '(${receipt.collectorName})', width: 6, styles: const PosStyles(align: PosAlign.center)),
      PosColumn(text: '(Authorized Sign)', width: 6, styles: const PosStyles(align: PosAlign.center)),
    ]);
    bytes += generator.feed(1);

    // 11. Footer (Exact match to Ceylon Innovation ERP in Image 2)
    bytes += generator.text('Thank You, Come Again !!!', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('Developed By CeylonInnovation.com', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('Hotline 0114 758 900', styles: const PosStyles(align: PosAlign.center));

    return bytes;
  }

  /// Builds a quick Test Print slip matching the Suwa Piyasa / Z-Report ERP format
  static Future<List<int>> buildTestPrintBytes({bool is80mm = true}) async {
    final profile = await CapabilityProfile.load();
    final paperSize = is80mm ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paperSize, profile);
    List<int> bytes = [];

    // Pre-load and process logo image
    img.Image? logoImage;
    try {
      final byteData = await rootBundle.load('assets/images/jay_pharma_shield.png');
      final rawBytes = byteData.buffer.asUint8List();
      final decoded = img.decodeImage(rawBytes);
      if (decoded != null) {
        final targetWidth = is80mm ? 150 : 120;
        final resized = img.copyResize(decoded, width: targetWidth);
        final canvas = img.Image(width: resized.width, height: resized.height, numChannels: 4);
        img.fill(canvas, color: img.ColorRgba8(255, 255, 255, 255));
        img.compositeImage(canvas, resized);
        logoImage = canvas;
      }
    } catch (_) {}

    if (logoImage != null) {
      bytes += generator.image(logoImage, align: PosAlign.center);
      bytes += generator.feed(1);
    }

    bytes += generator.text(
      'JAY PHARMA (PVT) LTD',
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size1, width: PosTextSize.size1),
    );
    bytes += generator.text('BLUETOOTH THERMAL PRINTER TEST', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.hr(ch: '-');
    bytes += generator.text('Status      : CONNECTED OK', styles: const PosStyles(bold: true));
    bytes += generator.text('Paper Width : ${is80mm ? "80mm POS Thermal" : "58mm Portable"}');
    bytes += generator.text('Date & Time : ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}');
    bytes += generator.hr(ch: '-');
    bytes += generator.text('*** TEST PRINT SUCCESSFUL ***', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('Ready to print receipts with official logo.', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(1);
    bytes += generator.text('Developed By CeylonInnovation.com', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('Hotline 0114 758 900', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
  }
}
