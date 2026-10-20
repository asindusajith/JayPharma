import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationData {
  final double latitude;
  final double longitude;
  final String address;
  final double accuracy;
  final DateTime timestamp;
  final bool isMocked;

  const LocationData({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.accuracy,
    required this.timestamp,
    this.isMocked = false,
  });

  bool get isValid => latitude != 0.0 && longitude != 0.0;
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
  /// Pure status check — NEVER prompts or spams in background
  static Future<GpsStatusResult> checkStatus() async {
    try {
      bool serviceEnabled = false;
      try {
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
      } catch (_) {
        serviceEnabled = true;
      }

      LocationPermission permission = LocationPermission.denied;
      try {
        permission = await Geolocator.checkPermission();
      } catch (_) {
        permission = LocationPermission.denied;
      }

      final hasPermission = permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;

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

  /// Quick boolean check whether GPS is currently active and ready for billing
  static Future<bool> isGpsAvailable() async {
    final status = await checkStatus();
    return status.isReady;
  }

  /// Explicitly requests location permission from user (MUST be triggered by user action)
  static Future<GpsStatusResult> requestPermission() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return await checkStatus();
    } catch (e) {
      debugPrint('LocationService.requestPermission error: $e');
      return await checkStatus();
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

    if (!serviceEnabled) {
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
      position = await Geolocator.getLastKnownPosition();
      if (position == null) {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        );
      }
    }

    if (position == null || (position.latitude == 0.0 && position.longitude == 0.0)) {
      throw Exception(
        'නියම GPS සංඥාව ලබා ගැනීමට නොහැකි විය. කරුණාකර විවෘත ස්ථානයකට ගොස් නැවත උත්සාහ කරන්න. (Unable to acquire satellite GPS lock)',
      );
    }

    // 4. Reverse geocode coordinates into a human-readable street address in Sri Lanka
    String address = 'GPS: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1',
      );
      final res = await http.get(url, headers: {
        'User-Agent': 'JayPharmaFieldApp/1.0',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 3));

      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body);
        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          address = displayName;
        }
      }
    } catch (_) {
      // Offline fallback: retains exact coordinates string
    }

    return LocationData(
      latitude: position.latitude,
      longitude: position.longitude,
      address: address,
      accuracy: position.accuracy,
      timestamp: position.timestamp,
      isMocked: position.isMocked,
    );
  }
}
