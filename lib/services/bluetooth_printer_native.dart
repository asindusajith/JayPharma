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

  static const MethodChannel _nativeBtChannel = MethodChannel('com.jaypharma.app/bluetooth');

  static BluetoothPrinterDevice? _connectedDevice;
  static BluetoothPrinterDevice? get connectedDevice => _connectedDevice;

  static bool _isConnecting = false;

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
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _nativeBtChannel.invokeMethod('requestBluetoothPermissions');
      }
      final granted = await PrintBluetoothThermal.isPermissionBluetoothGranted;
      return granted;
    } catch (_) {
      return false;
    }
  }

  /// Detailed Bluetooth diagnostics for troubleshooting
  static Future<Map<String, dynamic>> getDiagnostics() async {
    final Map<String, dynamic> diag = {};
    try {
      diag['bluetoothEnabled'] = await isBluetoothEnabled();
      diag['permissionGranted'] = await isPermissionGranted();
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final bool? nativeHas = await _nativeBtChannel.invokeMethod<bool>('hasBluetoothPermissions');
        diag['nativePermissionsGranted'] = nativeHas;
        final rawBonded = await _nativeBtChannel.invokeMethod('getBondedDevices');
        diag['bondedDevices'] = rawBonded;
      }
    } catch (e) {
      diag['error'] = e.toString();
    }
    return diag;
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

  /// Open Android App Settings so user can manually enable Bluetooth / Nearby devices permissions
  static Future<void> openAppPermissionSettings() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _nativeBtChannel.invokeMethod('openAppSettings');
      }
    } catch (_) {}
  }

  /// Triggers OS pairing dialog with a discovered device
  static Future<bool> pairDevice(String address) async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final bool? res = await _nativeBtChannel.invokeMethod<bool>('pairDevice', {'address': address});
        return res ?? false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Check if currently connected to a printer
  static Future<bool> isConnected() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final bool? nativeConn = await _nativeBtChannel.invokeMethod<bool>('isPrinterConnected');
        if (nativeConn == true) {
          if (_connectedDevice != null) {
            _connectedDevice = _connectedDevice!.copyWith(isConnected: true);
          }
          return true;
        }
      }
      final status = await PrintBluetoothThermal.connectionStatus;
      if (status) {
        if (_connectedDevice != null) {
          _connectedDevice = _connectedDevice!.copyWith(isConnected: true);
        }
        return true;
      }
      _connectedDevice = null;
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Returns list of paired Bluetooth devices on the system
  static Future<List<BluetoothPrinterDevice>> getPairedDevices({bool requestPerm = true, bool scanNearby = false}) async {
    try {
      if (requestPerm) {
        final hasPerm = await isPermissionGranted();
        if (!hasPerm) {
          await requestPermission();
        }
      }

      final isConn = await isConnected();
      final prefs = await SharedPreferences.getInstance();
      String? savedMac = prefs.getString(_prefKeyMac);
      String? savedName = prefs.getString(_prefKeyName);

      final Map<String, BluetoothPrinterDevice> deviceMap = {};

      // 1. Query Native Android BluetoothAdapter (bonded paired devices in OS - Instant <5ms)
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
                  final isCur = isConn && (_connectedDevice?.address == address || savedMac == address);
                  deviceMap[address] = BluetoothPrinterDevice(
                    name: name.isNotEmpty ? name : 'Bluetooth Printer',
                    address: address,
                    isConnected: isCur,
                  );
                }
              }
            }
          }
        } catch (e) {
          if (kDebugMode) print('[Bluetooth] Native bondedDevices error: $e');
        }
      }

      // 2. Query PrintBluetoothThermal plugin
      try {
        final list = await PrintBluetoothThermal.pairedBluetooths;
        for (final info in list) {
          final mac = info.macAdress.trim();
          if (mac.isNotEmpty) {
            final isCur = isConn && (_connectedDevice?.address == mac || savedMac == mac);
            final devName = info.name.trim().isNotEmpty ? info.name.trim() : 'Bluetooth Printer';
            if (!deviceMap.containsKey(mac) || deviceMap[mac]!.name == 'Bluetooth Printer') {
              deviceMap[mac] = BluetoothPrinterDevice(
                name: devName,
                address: mac,
                isConnected: isCur,
              );
            }
          }
        }
      } catch (e) {
        if (kDebugMode) print('[Bluetooth] PrintBluetoothThermal.pairedBluetooths: $e');
      }

      // 3. Auto-save first thermal printer found if no savedMac exists yet
      if ((savedMac == null || savedMac.isEmpty) && deviceMap.isNotEmpty) {
        final best = deviceMap.values.firstWhere(
          (d) {
            final n = d.name.toUpperCase();
            return n.contains('MTP') || n.contains('POS') || n.contains('RPP') || n.contains('PRINT') || n.contains('THERMAL') || n.contains('58') || n.contains('80');
          },
          orElse: () => deviceMap.values.first,
        );
        savedMac = best.address;
        savedName = best.name;
        await prefs.setString(_prefKeyMac, savedMac);
        await prefs.setString(_prefKeyName, savedName);
      }

      // 4. Always include saved printer so it never disappears from the dropdown
      if (savedMac != null && savedMac.isNotEmpty && !deviceMap.containsKey(savedMac)) {
        deviceMap[savedMac] = BluetoothPrinterDevice(
          name: (savedName != null && savedName.isNotEmpty) ? savedName : 'MTP-3_5F22',
          address: savedMac,
          isConnected: isConn,
        );
      }

      return deviceMap.values.toList();
    } catch (e) {
      if (kDebugMode) print('getPairedDevices error: $e');
      return [];
    }
  }

  /// Automatically connects in the background to the previously saved or bonded printer
  static Future<bool> autoConnectToSavedPrinter() async {
    if (_isConnecting) return false;
    try {
      final isBtOn = await isBluetoothEnabled();
      if (!isBtOn) return false;

      final already = await isConnected();
      if (already) return true;

      final savedPrinter = await getSavedPrinter();
      if (savedPrinter == null || savedPrinter.address.isEmpty) return false;

      return await connect(savedPrinter.address, printerName: savedPrinter.name);
    } catch (_) {
      return false;
    }
  }

  /// Connects directly to a printer using its MAC address
  static Future<bool> connect(String macAddress, {String? printerName}) async {
    final cleanMac = macAddress.trim();
    if (cleanMac.isEmpty) return false;

    if (_isConnecting) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (await isConnected() && _connectedDevice?.address == cleanMac) {
        return true;
      }
    }

    _isConnecting = true;
    try {
      // 1. Permanently save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyMac, cleanMac);
      if (printerName != null && printerName.isNotEmpty) {
        await prefs.setString(_prefKeyName, printerName);
      }

      // 2. Check if already connected
      if (await isConnected() && _connectedDevice?.address == cleanMac) {
        return true;
      }

      // 3. Attempt Native Android 2-stage connection (SPP UUID + Channel 1 Reflection)
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          final bool? nativeSuccess = await _nativeBtChannel.invokeMethod<bool>('connectPrinter', {'address': cleanMac});
          if (nativeSuccess == true) {
            _connectedDevice = BluetoothPrinterDevice(
              name: (printerName != null && printerName.isNotEmpty) ? printerName : 'MTP-3_5F22',
              address: cleanMac,
              isConnected: true,
            );
            return true;
          }
        } catch (e) {
          if (kDebugMode) print('[NativeConnect] error: $e');
        }
      }

      // 4. Fallback to PrintBluetoothThermal plugin
      try {
        await PrintBluetoothThermal.disconnect;
        await Future.delayed(const Duration(milliseconds: 200));
        final pluginSuccess = await PrintBluetoothThermal.connect(macPrinterAddress: cleanMac);
        if (pluginSuccess || await PrintBluetoothThermal.connectionStatus) {
          _connectedDevice = BluetoothPrinterDevice(
            name: (printerName != null && printerName.isNotEmpty) ? printerName : 'MTP-3_5F22',
            address: cleanMac,
            isConnected: true,
          );
          return true;
        }
      } catch (e) {
        if (kDebugMode) print('[PluginConnect] error: $e');
      }

      return false;
    } catch (e) {
      if (kDebugMode) print('connect error: $e');
      return false;
    } finally {
      _isConnecting = false;
    }
  }

  /// Disconnects from current printer
  static Future<bool> disconnect() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          await _nativeBtChannel.invokeMethod('disconnectPrinter');
        } catch (_) {}
      }
      await PrintBluetoothThermal.disconnect;
      _connectedDevice = null;
      return true;
    } catch (_) {
      _connectedDevice = null;
      return false;
    }
  }

  /// Sends raw ESC/POS bytes directly to the Bluetooth printer (Auto-connects if needed)
  static Future<bool> printBytes(List<int> bytes) async {
    try {
      final savedPrinter = await getSavedPrinter();
      final targetMac = savedPrinter?.address ?? '';
      final targetName = savedPrinter?.name ?? 'MTP-3_5F22';

      // 1. Direct Native Android RFCOMM print (Fastest, direct socket with Channel 1 fallback)
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          final bool? nativeSuccess = await _nativeBtChannel.invokeMethod<bool>('printRawBytes', {
            'address': targetMac,
            'bytes': Uint8List.fromList(bytes),
          });
          if (nativeSuccess == true) {
            _connectedDevice = BluetoothPrinterDevice(
              name: targetName,
              address: targetMac,
              isConnected: true,
            );
            return true;
          }
        } catch (e) {
          if (kDebugMode) print('[NativePrint] error: $e');
        }
      }

      // 2. Secondary fallback via PrintBluetoothThermal plugin
      bool connected = await isConnected();
      if (!connected && targetMac.isNotEmpty) {
        final ok = await connect(targetMac, printerName: targetName);
        if (ok) connected = true;
      }

      if (connected) {
        final success = await PrintBluetoothThermal.writeBytes(bytes);
        return success;
      }

      return false;
    } catch (e) {
      if (kDebugMode) print('printBytes error: $e');
      return false;
    }
  }

  /// Prints a receipt directly over Bluetooth ESC/POS
  static Future<bool> printReceiptDirect(
    Receipt receipt, {
    bool is80mm = true,
    bool isReprint = false,
    ReceiptCopyMode copyMode = ReceiptCopyMode.all,
  }) async {
    final bytes = await EscPosReceiptBuilder.buildReceiptBytes(
      receipt,
      is80mm: is80mm,
      isReprint: isReprint,
      copyMode: copyMode,
    );
    return await printBytes(bytes);
  }

  /// Prints a test ticket directly over Bluetooth ESC/POS
  static Future<bool> printTestTicket({bool is80mm = true}) async {
    final bytes = await EscPosReceiptBuilder.buildTestPrintBytes(is80mm: is80mm);
    return await printBytes(bytes);
  }

  /// Gets saved printer configuration, or auto-detects bonded printer from Android OS
  static Future<BluetoothPrinterDevice?> getSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    String? mac = prefs.getString(_prefKeyMac);
    String? name = prefs.getString(_prefKeyName);

    // Auto-detect bonded Bluetooth printer from Android OS if not yet saved in SharedPreferences
    if ((mac == null || mac.isEmpty) && !kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final List<dynamic>? bonded = await _nativeBtChannel.invokeMethod<List<dynamic>>('getBondedDevices');
        if (bonded != null && bonded.isNotEmpty) {
          dynamic printerDev = bonded.firstWhere(
            (d) {
              if (d is! Map) return false;
              final n = (d['name'] ?? '').toString().toUpperCase();
              return n.contains('MTP') || n.contains('POS') || n.contains('RPP') || n.contains('PRINT') || n.contains('THERMAL') || n.contains('58') || n.contains('80');
            },
            orElse: () => bonded.first,
          );
          if (printerDev is Map) {
            mac = (printerDev['address'] ?? '').toString().trim();
            name = (printerDev['name'] ?? '').toString().trim();
            if (mac.isNotEmpty) {
              await prefs.setString(_prefKeyMac, mac);
              await prefs.setString(_prefKeyName, name.isNotEmpty ? name : 'MTP-3_5F22');
            }
          }
        }
      } catch (e) {
        if (kDebugMode) print('[AutoDetectPrinter] error: $e');
      }
    }

    if (mac != null && mac.isNotEmpty) {
      final isConn = await isConnected();
      final dev = BluetoothPrinterDevice(
        name: (name != null && name.isNotEmpty) ? name : 'MTP-3_5F22',
        address: mac,
        isConnected: isConn,
      );
      if (isConn) {
        _connectedDevice = dev;
      }
      return dev;
    }
    return null;
  }
}
