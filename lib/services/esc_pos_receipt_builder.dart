import 'package:flutter/services.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import '../models/receipt.dart';

class EscPosReceiptBuilder {
  /// Builds complete raw ESC/POS bytes matching 80mm thermal receipt specifications
  static Future<List<int>> buildReceiptBytes(
    Receipt receipt, {
    bool is80mm = true,
    bool isReprint = false,
    ReceiptCopyMode copyMode = ReceiptCopyMode.all,
  }) async {
    final profile = await CapabilityProfile.load();
    final paperSize = is80mm ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paperSize, profile);
    List<int> bytes = [];

    // Pre-load and process logo image: auto-crop transparent padding so text sits snugly below
    img.Image? logoImage;
    try {
      final byteData = await rootBundle.load('assets/images/jay_pharma_shield.png');
      final rawBytes = byteData.buffer.asUint8List();
      final decoded = img.decodeImage(rawBytes);
      if (decoded != null) {
        int minX = decoded.width, maxX = 0, minY = decoded.height, maxY = 0;
        for (int y = 0; y < decoded.height; y++) {
          for (int x = 0; x < decoded.width; x++) {
            final pixel = decoded.getPixel(x, y);
            if (pixel.a > 15) {
              if (x < minX) minX = x;
              if (x > maxX) maxX = x;
              if (y < minY) minY = y;
              if (y > maxY) maxY = y;
            }
          }
        }
        img.Image cropped = decoded;
        if (maxX > minX && maxY > minY) {
          cropped = img.copyCrop(decoded, x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1);
        }

        final targetWidth = is80mm ? 130 : 100;
        final resized = img.copyResize(cropped, width: targetWidth);
        final canvas = img.Image(width: resized.width, height: resized.height, numChannels: 4);
        img.fill(canvas, color: img.ColorRgba8(255, 255, 255, 255));
        img.compositeImage(canvas, resized);
        logoImage = canvas;
      }
    } catch (_) {}

    final printCustomer = copyMode == ReceiptCopyMode.all || copyMode == ReceiptCopyMode.customerOnly;
    final printAccounts = copyMode == ReceiptCopyMode.all || copyMode == ReceiptCopyMode.accountsOnly;

    // 1. Copy 1: Customer Copy
    if (printCustomer) {
      bytes += _buildSingleCopy(generator, receipt, 'CUSTOMER COPY', logoImage: logoImage, is80mm: is80mm, isReprint: isReprint);
    }

    // 2. Cut Here Divider with proper spacing
    if (copyMode == ReceiptCopyMode.all) {
      bytes += generator.feed(1);
      bytes += generator.hr(ch: '-');
      bytes += generator.text('- - - - - - - - - CUT HERE - - - - - - - - -', styles: const PosStyles(align: PosAlign.center));
      bytes += generator.hr(ch: '-');
      bytes += generator.feed(1);
    }

    // 3. Copy 2: Accounts Copy
    if (printAccounts) {
      bytes += _buildSingleCopy(generator, receipt, 'ACCOUNTS COPY', logoImage: logoImage, is80mm: is80mm, isReprint: isReprint);
    }

    // Final feed and paper cut: direct ESC/POS cut without generator.cut()'s 5 empty lines
    bytes += generator.feed(1);
    // ESC/POS GS V 1 (partial cut directly at current position)
    bytes += [0x1d, 0x56, 0x01];

    return bytes;
  }

  static List<int> _buildSingleCopy(
    Generator generator,
    Receipt receipt,
    String copyTitle, {
    img.Image? logoImage,
    bool is80mm = true,
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
      // Reduce line spacing to 8 dots to pull the company title snugly up to the logo tip
      bytes += [27, 51, 8];
    }

    // 2. Header (Positioned higher, small gap directly below the logo)
    bytes += generator.text(
      'JAY PHARMA (PVT) LTD',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size1,
        width: PosTextSize.size1,
      ),
    );
    // Reset standard line spacing
    bytes += [27, 50];

    bytes += generator.text('No. 123, Main Street, Colombo 07', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('Tel: 011 234 5678 | info@jaypharma.lk', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('VAT No: 123456789-7000', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.hr(ch: '-');

    // 3. Copy Title & Document Title (Centered, clean)
    bytes += generator.text(copyTitle, styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('OFFICIAL RECEIPT', styles: const PosStyles(align: PosAlign.center));
    if (isReprint || receipt.reprintCount > 0) {
      bytes += generator.text('DUPLICATE COPY (REPRINT)', styles: const PosStyles(align: PosAlign.center));
    }
    bytes += generator.hr(ch: '-');

    // 4. Metadata (Clean 18-char colon alignment with indented word-wrapping)
    bytes += generator.text('Receipt No      : ${receipt.manualReceiptNo}');
    bytes += generator.text('Order Date/Time : ${dateTimeFormat.format(receipt.createdAt)}');
    bytes += generator.text('Customer        : ${receipt.customerCode}');
    // Indent customer name under the value of the colon (18 spaces) so it never wraps awkwardly
    bytes += generator.text('                  ${receipt.customerName}');
    if (receipt.customerAddress.trim().isNotEmpty) {
      bytes += generator.text('Address         : ${receipt.customerAddress.trim()}');
    }
    bytes += generator.text('Payment         : ${receipt.paymentMethodDisplay.toUpperCase()}');
    if (receipt.paymentMethod == PaymentMethod.cheque) {
      bytes += generator.text('Cheque No       : ${receipt.chequeNumber ?? ""}');
      if (receipt.chequeDate != null) {
        bytes += generator.text('Chq Date        : ${dateFormat.format(receipt.chequeDate!)}');
      }
      bytes += generator.text('Bank/Branch     : ${receipt.bank ?? ""} (${receipt.branch ?? ""})');
    }
    bytes += generator.text('Collector       : ${receipt.collectorName} (${receipt.collectorId})');
    bytes += generator.hr(ch: '-');

    // 5. Invoices Table Header (80mm safe column allocation: 6 + 3 + 3 = 12 columns)
    bytes += generator.row([
      PosColumn(text: 'Description & Price', width: 6),
      PosColumn(text: 'Inv Amt', width: 3, styles: const PosStyles(align: PosAlign.right)),
      PosColumn(text: 'Settled', width: 3, styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.hr(ch: '-');

    // Invoices Rows
    if (receipt.allocatedInvoices.isEmpty) {
      bytes += generator.row([
        PosColumn(text: 'Advance Payment', width: 6),
        PosColumn(text: '0.00', width: 3, styles: const PosStyles(align: PosAlign.right)),
        PosColumn(text: currency.format(receipt.totalAmount), width: 3, styles: const PosStyles(align: PosAlign.right)),
      ]);
    } else {
      for (final inv in receipt.allocatedInvoices) {
        // Line 1: Invoice number and date
        bytes += generator.text('#${inv.invoiceNo} (${dateFormat.format(inv.invoiceDate)})');
        // Line 2: Balance on left, Inv Amt & Settled on right (fits 80mm without any line wrap)
        final balStr = inv.remainingBalance > 0.01 ? ' Bal: ${currency.format(inv.remainingBalance)}' : ' Settled';
        bytes += generator.row([
          PosColumn(text: balStr, width: 6),
          PosColumn(text: currency.format(inv.invoiceAmount), width: 3, styles: const PosStyles(align: PosAlign.right)),
          PosColumn(text: currency.format(inv.amountSettled), width: 3, styles: const PosStyles(align: PosAlign.right)),
        ]);
        // Excess payment on invoice is designated as ExAmount (no separate Advance row)
        final excessOnThisInv = inv.excessAmount > 0.01
            ? inv.excessAmount
            : ((inv == receipt.allocatedInvoices.last && unallocatedAdvance > 0.01) ? unallocatedAdvance : 0.0);
        if (excessOnThisInv > 0.01) {
          bytes += generator.row([
            PosColumn(text: ' ExAmount (Excess):', width: 6),
            PosColumn(text: '0.00', width: 3, styles: const PosStyles(align: PosAlign.right)),
            PosColumn(text: currency.format(excessOnThisInv), width: 3, styles: const PosStyles(align: PosAlign.right)),
          ]);
        }
      }
    }
    bytes += generator.hr(ch: '-');

    // 6. Totals Section (Cleanly bordered & orderly)
    if (receipt.allocatedInvoices.isNotEmpty) {
      bytes += generator.row([
        PosColumn(text: 'Sub Total(LKR)   :', width: 6),
        PosColumn(text: currency.format(totalInvoiced), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    bytes += generator.row([
      PosColumn(
        text: 'GrandTotal(LKR)  :',
        width: 6,
        styles: const PosStyles(bold: true, height: PosTextSize.size1),
      ),
      PosColumn(
        text: currency.format(receipt.totalAmount),
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size1),
      ),
    ]);
    bytes += generator.hr(ch: '-');

    // 7. Payments Section (Properly framed and spaced)
    bytes += generator.text('********* Payments *********', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.row([
      PosColumn(text: '${receipt.paymentMethodDisplay.toUpperCase()}(LKR):', width: 6),
      PosColumn(text: currency.format(receipt.totalAmount), width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]);
    if (receipt.comments.trim().isNotEmpty) {
      bytes += generator.text('Remarks: ${receipt.comments.trim()}');
    }

    // 8. Outstanding Balance Section
    if (receipt.allocatedInvoices.isNotEmpty && totalBalance > 0.01) {
      bytes += generator.feed(1);
      bytes += generator.text('********* Outstanding *********', styles: const PosStyles(align: PosAlign.center));
      bytes += generator.row([
        PosColumn(text: 'Remaining Balance:', width: 6),
        PosColumn(text: currency.format(totalBalance), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    bytes += generator.hr(ch: '-');

    // 9. Customer Stamp Space & Signatures
    // 6 blank lines for physical rubber seal stamp (as requested by user):
    bytes += generator.feed(6);

    bytes += generator.row([
      PosColumn(text: '..................', width: 6, styles: const PosStyles(align: PosAlign.center)),
      PosColumn(text: '..................', width: 6, styles: const PosStyles(align: PosAlign.center)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Collector Signature', width: 6, styles: const PosStyles(align: PosAlign.center)),
      PosColumn(text: 'Customer Signature', width: 6, styles: const PosStyles(align: PosAlign.center)),
    ]);
    bytes += generator.row([
      PosColumn(text: '(${receipt.collectorName})', width: 6, styles: const PosStyles(align: PosAlign.center)),
      PosColumn(text: '(Authorized Sign)', width: 6, styles: const PosStyles(align: PosAlign.center)),
    ]);

    // Small gap before Footer
    bytes += generator.feed(1);

    // 10. Footer (Ceylon Innovation Hotline - 'Thank You, Come Again !!!' removed as requested)
    bytes += generator.text('Developed By CeylonInnovation.com', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('Hotline 0114 758 900', styles: const PosStyles(align: PosAlign.center));

    return bytes;
  }

  /// Builds a quick Test Print slip matching 80mm format
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
        int minX = decoded.width, maxX = 0, minY = decoded.height, maxY = 0;
        for (int y = 0; y < decoded.height; y++) {
          for (int x = 0; x < decoded.width; x++) {
            final pixel = decoded.getPixel(x, y);
            if (pixel.a > 15) {
              if (x < minX) minX = x;
              if (x > maxX) maxX = x;
              if (y < minY) minY = y;
              if (y > maxY) maxY = y;
            }
          }
        }
        img.Image cropped = decoded;
        if (maxX > minX && maxY > minY) {
          cropped = img.copyCrop(decoded, x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1);
        }

        final targetWidth = is80mm ? 130 : 100;
        final resized = img.copyResize(cropped, width: targetWidth);
        final canvas = img.Image(width: resized.width, height: resized.height, numChannels: 4);
        img.fill(canvas, color: img.ColorRgba8(255, 255, 255, 255));
        img.compositeImage(canvas, resized);
        logoImage = canvas;
      }
    } catch (_) {}

    if (logoImage != null) {
      bytes += generator.image(logoImage, align: PosAlign.center);
      bytes += [27, 51, 8];
    }

    bytes += generator.text(
      'JAY PHARMA (PVT) LTD',
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size1, width: PosTextSize.size1),
    );
    bytes += [27, 50];

    bytes += generator.text('BLUETOOTH THERMAL PRINTER TEST', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.hr(ch: '-');
    bytes += generator.text('Status      : CONNECTED OK');
    bytes += generator.text('Paper Width : ${is80mm ? "80mm POS Thermal" : "58mm Portable"}');
    bytes += generator.text('Date & Time : ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}');
    bytes += generator.hr(ch: '-');
    bytes += generator.text('*** TEST PRINT SUCCESSFUL ***', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('Ready to print receipts with official logo.', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(1);
    bytes += generator.text('Developed By CeylonInnovation.com', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('Hotline 0114 758 900', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(1);
    bytes += [0x1d, 0x56, 0x01];

    return bytes;
  }
}
