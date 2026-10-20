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

class LocationService {
  static StreamSubscription<ServiceStatus>? _statusSubscription;
  static bool _lastKnownGpsStatus = false;

  /// Check if device hardware GPS is turned on AND permission is granted
  static Future<bool> isGpsAvailable() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _lastKnownGpsStatus = false;
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      final hasPermission = permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
      _lastKnownGpsStatus = hasPermission;
      return hasPermission;
    } catch (e) {
      debugPrint('Error checking GPS availability: $e');
      _lastKnownGpsStatus = false;
      return false;
    }
  }

  /// Check specifically if the device Location Service (GPS toggle) is switched ON
  static Future<bool> isServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
  }

  /// Request permission if needed
  static Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
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

  /// Captures collector's exact current GPS coordinates from device hardware
  static Future<LocationData> getCurrentLocation() async {
    // 1. Check if hardware GPS is enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
        'GPS is disabled on your device. Please turn on Location/GPS to proceed.',
      );
    }

    // 2. Check & request permission
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception(
          'Location permission was denied. Please allow location access to record bills.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is permanently denied. Please enable location permissions in App Settings.',
      );
    }

    // 3. Obtain real GPS coordinates from hardware
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
        // Last effort with lower accuracy setting
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        );
      }
    }

    if (position == null) {
      throw Exception('Unable to acquire GPS satellite signal. Please move to an open area and try again.');
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
      // Offline fallback: retains the exact GPS coordinates string
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
