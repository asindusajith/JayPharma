class LocationData {
  final double latitude;
  final double longitude;
  final String address;
  final double accuracy;
  final DateTime timestamp;

  const LocationData({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.accuracy,
    required this.timestamp,
  });
}

class LocationService {
  static bool _isLocationEnabled = true;

  static bool get isLocationServiceEnabled => _isLocationEnabled;

  static void setLocationServiceEnabled(bool enabled) {
    _isLocationEnabled = enabled;
  }

  // Captures collector's current coordinates
  static Future<LocationData> getCurrentLocation() async {
    // Simulated realistic field GPS tracking in Sri Lanka
    await Future.delayed(const Duration(milliseconds: 300));
    
    return LocationData(
      latitude: 6.927079,
      longitude: 79.861244,
      address: 'Galle Road, Colombo 03, Western Province, Sri Lanka',
      accuracy: 4.8, // 4.8 meters accuracy
      timestamp: DateTime.now(),
    );
  }
}
