import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationData {
  final double latitude;
  final double longitude;
  String address;
  final double accuracy;
  final DateTime timestamp;
  final bool isMocked;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.accuracy,
    required this.timestamp,
    this.isMocked = false,
  });

  bool get isValid =>
      latitude != 0.0 &&
      longitude != 0.0 &&
      !((latitude - 6.927079).abs() < 0.00001 && (longitude - 79.861244).abs() < 0.00001);
}

class GpsStatusResult {
  final bool isServiceEnabled;
  final LocationPermission permission;
  final bool hasPermission;
  final bool isReady;

  const GpsStatusResult({
    required this.isServiceEnabled,
    required this.permission,
    required this.hasPermission,
    required this.isReady,
  });

  bool get isPermissionNeeded => isServiceEnabled && !hasPermission;
}

class LocationService {
  static LocationData? _lastKnownLocation;
  static LocationData? get lastKnownLocation => _lastKnownLocation;
  static bool _isConnecting = false;
  static bool get isConnecting => _isConnecting;
  static bool _deviceHardwareGpsOff = false;

  /// Pure status check — safe to run in periodic timers without prompting the user
  static Future<GpsStatusResult> checkStatus() async {
    try {
      bool serviceEnabled = false;
      try {
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
      } catch (_) {
        serviceEnabled = true;
      }

      if (_deviceHardwareGpsOff) {
        serviceEnabled = false;
      }

      // If phone's hardware GPS toggle is OFF, immediately report offline
      if (!serviceEnabled) {
        return const GpsStatusResult(
          isServiceEnabled: false,
          permission: LocationPermission.denied,
          hasPermission: false,
          isReady: false,
        );
      }

      LocationPermission permission = LocationPermission.denied;
      try {
        permission = await Geolocator.checkPermission();
      } catch (_) {
        permission = LocationPermission.denied;
      }

      bool hasPermission = permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;

      // If genuine GPS coordinates were already captured in this session and permission is not deniedForever:
      if (_lastKnownLocation != null &&
          _lastKnownLocation!.isValid &&
          permission != LocationPermission.deniedForever) {
        hasPermission = true;
      }

      return GpsStatusResult(
        isServiceEnabled: serviceEnabled,
        permission: permission,
        hasPermission: hasPermission,
        isReady: serviceEnabled && hasPermission,
      );
    } catch (e) {
      debugPrint('LocationService.checkStatus error: $e');
      return const GpsStatusResult(
        isServiceEnabled: false,
        permission: LocationPermission.denied,
        hasPermission: false,
        isReady: false,
      );
    }
  }

  /// Request permission and connect to GPS
  static Future<GpsStatusResult> requestPermission() async {
    await requestAndConnectGps();
    return await checkStatus();
  }

  /// Actively connects to device hardware GPS, prompts permission if needed,
  /// acquires accurate coordinates, and locks live GPS status.
  static Future<LocationData?> requestAndConnectGps() async {
    if (_isConnecting) return _lastKnownLocation;
    _isConnecting = true;

    try {
      // 1. Verify hardware Location service switch
      bool serviceEnabled = false;
      try {
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
      } catch (_) {
        serviceEnabled = true;
      }

      if (!serviceEnabled) {
        debugPrint('Location hardware switch is disabled on device');
        _deviceHardwareGpsOff = true;
        _isConnecting = false;
        return null;
      }

      // 2. Request permission if not yet granted
      LocationPermission permission = LocationPermission.denied;
      try {
        permission = await Geolocator.checkPermission();
      } catch (_) {}

      if (permission == LocationPermission.denied) {
        try {
          permission = await Geolocator.requestPermission();
        } catch (_) {}
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permission deniedForever');
        _isConnecting = false;
        return null;
      }

      // 3. Acquire live hardware position
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 12),
          ),
        );
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('service') && errStr.contains('disabled')) {
          _deviceHardwareGpsOff = true;
          _isConnecting = false;
          return null;
        }

        debugPrint('High accuracy GPS timed out ($e), trying medium accuracy...');
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 8),
            ),
          );
        } catch (e2) {
          final errStr2 = e2.toString().toLowerCase();
          if (errStr2.contains('service') && errStr2.contains('disabled')) {
            _deviceHardwareGpsOff = true;
            _isConnecting = false;
            return null;
          }
          try {
            position = await Geolocator.getLastKnownPosition();
          } catch (_) {}
        }
      }

      if (position != null && position.latitude != 0.0 && position.longitude != 0.0) {
        _deviceHardwareGpsOff = false;
        final loc = LocationData(
          latitude: position.latitude,
          longitude: position.longitude,
          address: 'GPS: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
          accuracy: position.accuracy,
          timestamp: position.timestamp,
          isMocked: position.isMocked,
        );

        _lastKnownLocation = loc;
        _reverseGeocodeInBackground(loc);
        _isConnecting = false;
        return loc;
      }

      _isConnecting = false;
      return null;
    } catch (e) {
      debugPrint('requestAndConnectGps error: $e');
      _isConnecting = false;
      return null;
    }
  }

  /// Open device Location Settings screen (Android/iOS)
  static Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }

  /// Open App Settings screen (to toggle permissions)
  static Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  /// Captures collector's exact current GPS coordinates from device hardware.
  /// Throws descriptive exceptions if GPS is off or permission is denied so billing is strictly blocked.
  static Future<LocationData> getCurrentLocation() async {
    // 1. Verify hardware GPS switch
    bool serviceEnabled = false;
    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      serviceEnabled = true;
    }

    if (!serviceEnabled || _deviceHardwareGpsOff) {
      throw Exception(
        'දුරකථනයේ GPS අක්‍රිය කර ඇත. බිල්පත නිකුත් කිරීමට කරුණාකර දුරකථනයේ GPS / Location Services සක්‍රීය කරන්න. (Device GPS is disabled)',
      );
    }

    // 2. Verify & request permission
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception(
          'Location අවසරය ප්‍රතික්ෂේප කර ඇත. බිල්පත නිකුත් කිරීමට App එකට Location අවසරය ලබා දෙන්න. (Location permission denied)',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location අවසරය අක්‍රිය කර ඇත. කරුණාකර App Settings වෙත ගොස් Location අවසරය සක්‍රීය කරන්න. (Location permission denied forever)',
      );
    }

    // 3. Acquire live hardware position
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } catch (e) {
      debugPrint('High accuracy GPS timed out, trying last known position: $e');
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {}
      if (position == null && _lastKnownLocation != null) {
        return _lastKnownLocation!;
      }
    }

    if (position == null || (position.latitude == 0.0 && position.longitude == 0.0)) {
      if (_lastKnownLocation != null && _lastKnownLocation!.isValid) {
        return _lastKnownLocation!;
      }
      throw Exception(
        'නියම GPS සංඥාව ලබා ගැනීමට නොහැකි විය. කරුණාකර විවෘත ස්ථානයකට ගොස් නැවත උත්සාහ කරන්න. (Unable to acquire satellite GPS lock)',
      );
    }

    String address = 'GPS: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
    final loc = LocationData(
      latitude: position.latitude,
      longitude: position.longitude,
      address: address,
      accuracy: position.accuracy,
      timestamp: position.timestamp,
      isMocked: position.isMocked,
    );

    _lastKnownLocation = loc;
    _reverseGeocodeInBackground(loc);
    return loc;
  }

  static void _reverseGeocodeInBackground(LocationData loc) {
    Future.microtask(() async {
      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${loc.latitude}&lon=${loc.longitude}&zoom=18&addressdetails=1',
        );
        final res = await http.get(url, headers: {
          'User-Agent': 'JayPharmaFieldApp/1.0',
          'Accept': 'application/json',
        }).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(res.body);
          final displayName = data['display_name'] as String?;
          if (displayName != null && displayName.isNotEmpty) {
            loc.address = displayName;
          }
        }
      } catch (_) {}
    });
  }
}
