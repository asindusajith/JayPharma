import 'package:flutter/foundation.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bluetooth_printer_device.dart';
import 'esc_pos_receipt_builder.dart';
import '../models/receipt.dart';

class BluetoothPrinterService {
  static const String _prefKeyMac = 'selected_printer_mac';
  static const String _prefKeyName = 'selected_printer_name';
  static const String _prefKeyPaper = 'selected_printer_paper';

  static BluetoothPrinterDevice? _connectedDevice;
  static BluetoothPrinterDevice? get connectedDevice => _connectedDevice;

  /// Check if Bluetooth permissions are granted on Android
  static Future<bool> isPermissionGranted() async {
    try {
      return await PrintBluetoothThermal.isPermissionBluetoothGranted;
    } catch (_) {
      return false;
    }
  }

  /// Check if Bluetooth is turned ON
  static Future<bool> isBluetoothEnabled() async {
    try {
      return await PrintBluetoothThermal.bluetoothEnabled;
    } catch (_) {
      return false;
    }
  }

  /// Check if currently connected to a printer
  static Future<bool> isConnected() async {
    try {
      final status = await PrintBluetoothThermal.connectionStatus;
      if (!status) {
        _connectedDevice = null;
      }
      return status;
    } catch (_) {
      return false;
    }
  }

  /// Returns list of paired Bluetooth devices on the system
  static Future<List<BluetoothPrinterDevice>> getPairedDevices() async {
    try {
      final list = await PrintBluetoothThermal.pairedBluetooths;
      final currentConnected = await isConnected();

      final prefs = await SharedPreferences.getInstance();
      final savedMac = prefs.getString(_prefKeyMac);

      return list.map((info) {
        final isCur = currentConnected && (_connectedDevice?.address == info.macAdress || savedMac == info.macAdress);
        return BluetoothPrinterDevice(
          name: info.name.isNotEmpty ? info.name : 'Bluetooth Printer',
          address: info.macAdress,
          isConnected: isCur,
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) print('getPairedDevices error: $e');
      return [];
    }
  }

  /// Connects directly to a printer using its MAC address
  static Future<bool> connect(String macAddress, {String? printerName}) async {
    try {
      // Disconnect current if any
      await disconnect();

      final success = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
      if (success) {
        _connectedDevice = BluetoothPrinterDevice(
          name: printerName ?? 'Bluetooth Thermal Printer',
          address: macAddress,
          isConnected: true,
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefKeyMac, macAddress);
        if (printerName != null) {
          await prefs.setString(_prefKeyName, printerName);
        }
      }
      return success;
    } catch (e) {
      if (kDebugMode) print('connect error: $e');
      return false;
    }
  }

  /// Disconnects from current printer
  static Future<bool> disconnect() async {
    try {
      final res = await PrintBluetoothThermal.disconnect;
      _connectedDevice = null;
      return res;
    } catch (_) {
      _connectedDevice = null;
      return false;
    }
  }

  /// Sends raw ESC/POS bytes directly to the Bluetooth printer (No 3rd party app)
  static Future<bool> printBytes(List<int> bytes) async {
    try {
      final status = await isConnected();
      if (!status) {
        // Try auto-reconnect if saved
        final prefs = await SharedPreferences.getInstance();
        final savedMac = prefs.getString(_prefKeyMac);
        final savedName = prefs.getString(_prefKeyName);
        if (savedMac != null && savedMac.isNotEmpty) {
          final reconnected = await connect(savedMac, printerName: savedName);
          if (!reconnected) return false;
        } else {
          return false;
        }
      }

      return await PrintBluetoothThermal.writeBytes(bytes);
    } catch (e) {
      if (kDebugMode) print('printBytes error: $e');
      return false;
    }
  }

  /// Prints a receipt directly over Bluetooth ESC/POS
  static Future<bool> printReceiptDirect(Receipt receipt, {bool is80mm = true, bool isReprint = false}) async {
    final bytes = await EscPosReceiptBuilder.buildReceiptBytes(receipt, is80mm: is80mm, isReprint: isReprint);
    return await printBytes(bytes);
  }

  /// Prints a test ticket directly over Bluetooth ESC/POS
  static Future<bool> printTestTicket({bool is80mm = true}) async {
    final bytes = await EscPosReceiptBuilder.buildTestPrintBytes(is80mm: is80mm);
    return await printBytes(bytes);
  }

  /// Gets saved printer configuration
  static Future<BluetoothPrinterDevice?> getSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final mac = prefs.getString(_prefKeyMac);
    final name = prefs.getString(_prefKeyName);
    if (mac != null && mac.isNotEmpty) {
      final connected = await isConnected();
      return BluetoothPrinterDevice(
        name: name ?? 'Paired Thermal Printer',
        address: mac,
        isConnected: connected,
      );
    }
    return null;
  }
}

