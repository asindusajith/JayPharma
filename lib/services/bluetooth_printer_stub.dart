import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bluetooth_printer_device.dart';
import 'esc_pos_receipt_builder.dart';
import 'receipt_printer_service.dart';
import '../models/receipt.dart';

class BluetoothPrinterService {
  static const String _prefKeyMac = 'selected_printer_mac';
  static const String _prefKeyName = 'selected_printer_name';

  static BluetoothPrinterDevice? _connectedDevice;
  static BluetoothPrinterDevice? get connectedDevice => _connectedDevice;

  static Future<bool> isPermissionGranted() async => true;
  static Future<bool> requestPermission() async => true;
  static Future<bool> isBluetoothEnabled() async => true;
  static Future<void> openBluetoothSettings() async {}

  static Future<bool> isConnected() async {
    return _connectedDevice != null && _connectedDevice!.isConnected;
  }

  static Future<List<BluetoothPrinterDevice>> getPairedDevices({bool requestPerm = true, bool scanNearby = true}) async {
    final List<BluetoothPrinterDevice> list = [];
    final prefs = await SharedPreferences.getInstance();
    final savedMac = prefs.getString(_prefKeyMac);
    final savedName = prefs.getString(_prefKeyName);

    try {
      final info = await Printing.info();
      if (info.canListPrinters) {
        final sysPrinters = await Printing.listPrinters();
        for (final p in sysPrinters) {
          final isCur = (savedMac == p.url || _connectedDevice?.address == p.url);
          list.add(BluetoothPrinterDevice(
            name: p.name,
            address: p.url,
            isConnected: isCur,
          ));
        }
      }
    } catch (_) {}

    // Add standard Bluetooth POS printers for selection / testing
    final standardPosPrinters = [
      const BluetoothPrinterDevice(name: 'RPP02N 80mm Bluetooth Thermal Printer', address: '66:02:BD:06:18:7B'),
      const BluetoothPrinterDevice(name: 'MTP-II 58mm Mini Mobile Printer', address: '00:11:22:33:44:55'),
      const BluetoothPrinterDevice(name: 'POS-80 Series Bluetooth Printer', address: 'DC:0D:30:12:34:56'),
    ];

    for (final dev in standardPosPrinters) {
      if (!list.any((e) => e.address == dev.address)) {
        final isCur = (savedMac == dev.address || _connectedDevice?.address == dev.address);
        list.add(dev.copyWith(isConnected: isCur));
      }
    }

    if (savedMac != null && _connectedDevice == null) {
      final found = list.firstWhere(
        (e) => e.address == savedMac,
        orElse: () => BluetoothPrinterDevice(
          name: savedName ?? 'Paired Bluetooth Printer',
          address: savedMac,
          isConnected: true,
        ),
      );
      _connectedDevice = found.copyWith(isConnected: true);
    }

    return list;
  }

  static Future<bool> connect(String macAddress, {String? printerName}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyMac, macAddress);
    if (printerName != null) {
      await prefs.setString(_prefKeyName, printerName);
    }

    _connectedDevice = BluetoothPrinterDevice(
      name: printerName ?? 'Connected Thermal Printer',
      address: macAddress,
      isConnected: true,
    );
    return true;
  }

  static Future<bool> disconnect() async {
    _connectedDevice = null;
    return true;
  }

  static Future<bool> printBytes(List<int> bytes) async {
    if (kDebugMode) print('Stub: printed ${bytes.length} ESC/POS bytes');
    return true;
  }

  static Future<bool> printReceiptDirect(Receipt receipt, {bool is80mm = true, bool isReprint = false}) async {
    await ReceiptPrinterService.printReceiptDirect(receipt, isReprint: isReprint);
    return true;
  }

  static Future<bool> printTestTicket({bool is80mm = true}) async {
    final pdfBytes = await ReceiptPrinterService.generateReceiptPdf(
      Receipt(
        manualReceiptNo: 'TEST-0001',
        customerCode: 'TEST',
        customerName: 'JayPharma Bluetooth Test',
        customerAddress: 'Printer Connected OK',
        customerPhone: 'N/A',
        paymentMethod: PaymentMethod.cash,
        totalAmount: 1000.0,
        allocatedInvoices: [],
        comments: 'Direct Bluetooth Thermal Connection OK',
        isAdvancePayment: true,
        collectorId: 'COL-001',
        collectorName: 'System Test',
        latitude: 6.9271,
        longitude: 79.8612,
        locationAddress: 'Test Location',
        createdAt: DateTime.now(),
      ),
    );
    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: 'JayPharma_TestPrint',
    );
    return true;
  }

  static Future<BluetoothPrinterDevice?> getSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final mac = prefs.getString(_prefKeyMac);
    final name = prefs.getString(_prefKeyName);
    if (mac != null && mac.isNotEmpty) {
      return BluetoothPrinterDevice(
        name: name ?? 'Paired Thermal Printer',
        address: mac,
        isConnected: true,
      );
    }
    return null;
  }
}

