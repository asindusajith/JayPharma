import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bluetooth_printer_device.dart';
import 'esc_pos_receipt_builder.dart';
import '../models/receipt.dart';

class BluetoothPrinterService {
  static const String _prefKeyMac = 'selected_printer_mac';
  static const String _prefKeyName = 'selected_printer_name';
  static const String _prefKeyPaper = 'selected_printer_paper';

  static const MethodChannel _nativeBtChannel = MethodChannel('com.jaypharma.app/bluetooth');

  static BluetoothPrinterDevice? _connectedDevice;
  static BluetoothPrinterDevice? get connectedDevice => _connectedDevice;

  /// Check if Bluetooth permissions are granted on Android
  static Future<bool> isPermissionGranted() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final bool? nativeHas = await _nativeBtChannel.invokeMethod<bool>('hasBluetoothPermissions');
        if (nativeHas == true) return true;
      }
      return await PrintBluetoothThermal.isPermissionBluetoothGranted;
    } catch (_) {
      return false;
    }
  }

  /// Request Bluetooth permissions (triggers Android system runtime dialog)
  static Future<bool> requestPermission() async {
    try {
      // 1. Trigger plugin's own permission request
      final granted = await PrintBluetoothThermal.isPermissionBluetoothGranted;
      if (granted) return true;

      // 2. Trigger native Android ActivityCompat request
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _nativeBtChannel.invokeMethod('requestBluetoothPermissions');
        await Future.delayed(const Duration(milliseconds: 600));
        final bool? has = await _nativeBtChannel.invokeMethod<bool>('hasBluetoothPermissions');
        return has ?? false;
      }
      return granted;
    } catch (_) {
      return false;
    }
  }

  /// Check if Bluetooth is turned ON on the device
  static Future<bool> isBluetoothEnabled() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final bool? nativeEnabled = await _nativeBtChannel.invokeMethod<bool>('isBluetoothEnabled');
        if (nativeEnabled != null) return nativeEnabled;
      }
      return await PrintBluetoothThermal.bluetoothEnabled;
    } catch (_) {
      return false;
    }
  }

  /// Open Android Bluetooth Settings so user can pair a new printer
  static Future<void> openBluetoothSettings() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _nativeBtChannel.invokeMethod('openBluetoothSettings');
      }
    } catch (_) {}
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
  /// Combines plugin discovery with native Android BluetoothAdapter fallback & Live Discovery
  static Future<List<BluetoothPrinterDevice>> getPairedDevices({bool requestPerm = true, bool scanNearby = true}) async {
    try {
      if (requestPerm) {
        await requestPermission();
      }

      final currentConnected = await isConnected();
      final prefs = await SharedPreferences.getInstance();
      final savedMac = prefs.getString(_prefKeyMac);
      final savedName = prefs.getString(_prefKeyName);

      final Map<String, BluetoothPrinterDevice> deviceMap = {};

      // 1. Query PrintBluetoothThermal plugin
      try {
        final list = await PrintBluetoothThermal.pairedBluetooths;
        for (final info in list) {
          final mac = info.macAdress.trim();
          if (mac.isNotEmpty) {
            final isCur = currentConnected && (_connectedDevice?.address == mac || savedMac == mac);
            final devName = info.name.trim().isNotEmpty ? info.name.trim() : 'Bluetooth Printer';
            deviceMap[mac] = BluetoothPrinterDevice(
              name: devName,
              address: mac,
              isConnected: isCur,
            );
          }
        }
      } catch (e) {
        if (kDebugMode) print('[Bluetooth] PrintBluetoothThermal.pairedBluetooths: $e');
      }

      // 2. Query Native Android BluetoothAdapter (bonded + live discovery of nearby broadcasting printers)
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          final methodName = scanNearby ? 'scanNearbyDevices' : 'getBondedDevices';
          final List<dynamic>? nativeList = await _nativeBtChannel.invokeMethod<List<dynamic>>(methodName);
          if (nativeList != null) {
            for (final item in nativeList) {
              if (item is Map) {
                final address = (item['address'] ?? '').toString().trim();
                final name = (item['name'] ?? '').toString().trim();
                if (address.isNotEmpty) {
                  final isCur = currentConnected && (_connectedDevice?.address == address || savedMac == address);
                  if (!deviceMap.containsKey(address) || deviceMap[address]!.name == 'Bluetooth Printer') {
                    deviceMap[address] = BluetoothPrinterDevice(
                      name: name.isNotEmpty ? name : 'Bluetooth Printer',
                      address: address,
                      isConnected: isCur,
                    );
                  }
                }
              }
            }
          }
        } catch (e) {
          if (kDebugMode) print('[Bluetooth] Native bondedDevices error: $e');
        }
      }

      // 3. If a saved printer exists but wasn't found in current scan, retain it
      if (savedMac != null && savedMac.isNotEmpty && !deviceMap.containsKey(savedMac)) {
        deviceMap[savedMac] = BluetoothPrinterDevice(
          name: savedName ?? 'Saved Bluetooth Printer',
          address: savedMac,
          isConnected: currentConnected && _connectedDevice?.address == savedMac,
        );
      }

      return deviceMap.values.toList();
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

      final cleanMac = macAddress.trim();
      final success = await PrintBluetoothThermal.connect(macPrinterAddress: cleanMac);
      if (success) {
        _connectedDevice = BluetoothPrinterDevice(
          name: printerName ?? 'Bluetooth Thermal Printer',
          address: cleanMac,
          isConnected: true,
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefKeyMac, cleanMac);
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
