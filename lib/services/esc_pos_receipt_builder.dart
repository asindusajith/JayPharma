import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import '../models/receipt.dart';

class EscPosReceiptBuilder {
  static Future<List<int>> buildReceiptBytes(Receipt receipt, {bool is80mm = true, bool isReprint = false}) async {
    final profile = await CapabilityProfile.load();
    final paperSize = is80mm ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paperSize, profile);
    List<int> bytes = [];

    // 1. Copy 1: Customer Copy
    bytes += _buildSingleCopy(generator, receipt, '*** Customer Copy ***', isReprint: isReprint);

    // 2. Cut Here Divider
    bytes += generator.feed(1);
    bytes += generator.text('============================================', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('- - - - - - - - - CUT HERE - - - - - - - - -', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('============================================', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.feed(1);

    // 3. Copy 2: Accounts Copy
    bytes += _buildSingleCopy(generator, receipt, '*** Accounts Copy ***', isReprint: isReprint);

    // Final feed and paper cut
    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
  }

  static List<int> _buildSingleCopy(Generator generator, Receipt receipt, String copyTitle, {bool isReprint = false}) {
    List<int> bytes = [];
    final currency = NumberFormat('#,##0.00', 'en_US');
    final dateFormat = DateFormat('dd/MM/yyyy');
    final dateTimeFormat = DateFormat('dd/MM/yyyy hh:mm a');

    final totalInvoiced = receipt.allocatedInvoices.fold<double>(0.0, (s, i) => s + i.invoiceAmount);
    final totalSettled = receipt.allocatedInvoices.fold<double>(0.0, (s, i) => s + i.amountSettled);
    final totalBalance = receipt.allocatedInvoices.fold<double>(0.0, (s, i) => s + i.remainingBalance);
    final unallocatedAdvance = (receipt.totalAmount - totalSettled) > 0.01 ? (receipt.totalAmount - totalSettled) : 0.0;

    // Header
    bytes += generator.text(
      'JAY PHARMA (PVT) LTD',
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size1, width: PosTextSize.size1),
    );
    bytes += generator.text('No. 123, Main Street, Colombo 07', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('Tel: 011 234 5678 | info@jaypharma.lk', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('VAT No: 123456789-7000', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.hr();

    // Copy Title & Document Title
    bytes += generator.text(copyTitle, styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('*** OFFICIAL RECEIPT ***', styles: const PosStyles(align: PosAlign.center, bold: true));
    if (isReprint || receipt.reprintCount > 0) {
      bytes += generator.text('*** DUPLICATE COPY (REPRINT) ***', styles: const PosStyles(align: PosAlign.center, bold: true));
    }
    bytes += generator.hr();

    // Metadata
    bytes += generator.row([
      PosColumn(text: 'Receipt No :', width: 4, styles: const PosStyles(bold: true)),
      PosColumn(text: receipt.manualReceiptNo, width: 8, styles: const PosStyles(bold: true)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Date       :', width: 4),
      PosColumn(text: dateTimeFormat.format(receipt.createdAt), width: 8),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Customer   :', width: 4),
      PosColumn(text: '${receipt.customerCode} - ${receipt.customerName}', width: 8, styles: const PosStyles(bold: true)),
    ]);
    if (receipt.customerAddress.isNotEmpty) {
      bytes += generator.row([
        PosColumn(text: 'Address    :', width: 4),
        PosColumn(text: receipt.customerAddress, width: 8),
      ]);
    }
    bytes += generator.row([
      PosColumn(text: 'Payment    :', width: 4),
      PosColumn(text: receipt.paymentMethodDisplay.toUpperCase(), width: 8, styles: const PosStyles(bold: true)),
    ]);
    if (receipt.paymentMethod == PaymentMethod.cheque) {
      bytes += generator.row([
        PosColumn(text: 'Cheque No  :', width: 4),
        PosColumn(text: receipt.chequeNumber ?? '', width: 8, styles: const PosStyles(bold: true)),
      ]);
      if (receipt.chequeDate != null) {
        bytes += generator.row([
          PosColumn(text: 'Chq Date   :', width: 4),
          PosColumn(text: dateFormat.format(receipt.chequeDate!), width: 8),
        ]);
      }
      bytes += generator.row([
        PosColumn(text: 'Bank/Branch:', width: 4),
        PosColumn(text: '${receipt.bank ?? ""} (${receipt.branch ?? ""})', width: 8),
      ]);
    }
    bytes += generator.row([
      PosColumn(text: 'Collector  :', width: 4),
      PosColumn(text: '${receipt.collectorName} (${receipt.collectorId})', width: 8),
    ]);

    bytes += generator.hr();

    // Invoices table
    bytes += generator.row([
      PosColumn(text: 'Description / Inv No', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(text: 'Inv Amt', width: 3, styles: const PosStyles(align: PosAlign.right, bold: true)),
      PosColumn(text: 'Settled', width: 3, styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]);
    bytes += generator.hr();

    if (receipt.allocatedInvoices.isEmpty) {
      bytes += generator.row([
        PosColumn(text: 'Advance Payment', width: 6),
        PosColumn(text: '0.00', width: 3, styles: const PosStyles(align: PosAlign.right)),
        PosColumn(text: currency.format(receipt.totalAmount), width: 3, styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);
    } else {
      for (final inv in receipt.allocatedInvoices) {
        bytes += generator.text('#${inv.invoiceNo} (${dateFormat.format(inv.invoiceDate)})');
        bytes += generator.row([
          PosColumn(text: '', width: 4),
          PosColumn(text: currency.format(inv.invoiceAmount), width: 4, styles: const PosStyles(align: PosAlign.right)),
          PosColumn(text: currency.format(inv.amountSettled), width: 4, styles: const PosStyles(align: PosAlign.right, bold: true)),
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

    bytes += generator.hr();

    // Financial Totals
    if (receipt.allocatedInvoices.isNotEmpty) {
      bytes += generator.row([
        PosColumn(text: 'Sub Total(LKR)   :', width: 7),
        PosColumn(text: currency.format(totalInvoiced), width: 5, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Total Settled(LKR):', width: 7),
        PosColumn(text: currency.format(totalSettled), width: 5, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    bytes += generator.row([
      PosColumn(text: 'Paid Amount(LKR) :', width: 7),
      PosColumn(text: currency.format(receipt.totalAmount), width: 5, styles: const PosStyles(align: PosAlign.right)),
    ]);

    // BOLD PROMINENT BALANCE
    bytes += generator.row([
      PosColumn(text: 'Balance(LKR)     :', width: 7, styles: const PosStyles(bold: true, height: PosTextSize.size1, width: PosTextSize.size1)),
      PosColumn(text: currency.format(totalBalance), width: 5, styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size1, width: PosTextSize.size1)),
    ]);

    bytes += generator.hr();

    // Payment details
    bytes += generator.text('**** Payment Details', styles: const PosStyles(bold: true));
    bytes += generator.row([
      PosColumn(text: '${receipt.paymentMethodDisplay}(LKR):', width: 6),
      PosColumn(text: currency.format(receipt.totalAmount), width: 6, styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]);
    if (receipt.comments.trim().isNotEmpty) {
      bytes += generator.text('Remarks: ${receipt.comments.trim()}');
    }

    bytes += generator.hr();

    // Footer
    bytes += generator.text(receipt.customerName, styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('Hope to See you Soon', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('Received with thanks.', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(1);

    // Signatures & Customer Seal Box
    bytes += generator.text('+------------------+  +--------------------+');
    bytes += generator.text('|                  |  |                    |');
    bytes += generator.text('|                  |  |   CUSTOMER SEAL    |');
    bytes += generator.text('|                  |  |   (STAMP HERE)     |');
    bytes += generator.text('|                  |  |                    |');
    bytes += generator.text('+------------------+  +--------------------+');
    bytes += generator.text('____________________  ______________________');
    bytes += generator.text('Collector Signature   Customer Signature    ');
    bytes += generator.text('(${receipt.collectorName})   (Authorized Seal)    ');

    bytes += generator.feed(1);
    bytes += generator.text('Developed By Ceyloninnovation.com', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('Hotline 0114 758 900', styles: const PosStyles(align: PosAlign.center));

    return bytes;
  }

  /// Builds a quick Test Print slip to test Bluetooth connection
  static Future<List<int>> buildTestPrintBytes({bool is80mm = true}) async {
    final profile = await CapabilityProfile.load();
    final paperSize = is80mm ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paperSize, profile);
    List<int> bytes = [];

    bytes += generator.text(
      'JAY PHARMA (PVT) LTD',
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size1, width: PosTextSize.size1),
    );
    bytes += generator.text('DIRECT BLUETOOTH THERMAL PRINT TEST', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.hr();
    bytes += generator.text('Bluetooth Status : CONNECTED OK', styles: const PosStyles(bold: true));
    bytes += generator.text('Driver           : Direct ESC/POS');
    bytes += generator.text('Paper Size       : ${is80mm ? "80mm POS Thermal" : "58mm Mini"}');
    bytes += generator.text('Date & Time      : ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}');
    bytes += generator.hr();
    bytes += generator.text('*** TEST PRINT SUCCESSFUL ***', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('Ready to issue receipts without 3rd party apps.', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
  }
}

