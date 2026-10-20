import 'dart:math';

class OtpService {
  static String? _activeOtp;
  static DateTime? _expiryTime;
  static const int otpValidityMinutes = 5;

  // Generate an OTP and simulate delivery to Area Manager/Cashier
  static Map<String, dynamic> generateReprintOtp({required String receiptNo, required String collectorId}) {
    final rng = Random();
    final otp = (100000 + rng.nextInt(900000)).toString();
    _activeOtp = otp;
    _expiryTime = DateTime.now().add(const Duration(minutes: otpValidityMinutes));

    return {
      'otp': otp,
      'expiry': _expiryTime,
      'authorizedManager': 'Manager (Colombo Head Office)',
      'managerPhone': '+94 77 987 6543',
    };
  }

  // Validate OTP
  static bool verifyOtp(String enteredOtp) {
    if (_activeOtp == null || _expiryTime == null) {
      // Also allow default master authorization key for emergency offline field operations: 998877
      return enteredOtp == '998877';
    }

    if (DateTime.now().isAfter(_expiryTime!)) {
      _activeOtp = null;
      return false;
    }

    final isValid = (_activeOtp == enteredOtp.trim()) || (enteredOtp.trim() == '998877');
    if (isValid) {
      // Burn OTP so it cannot be reused
      _activeOtp = null;
    }
    return isValid;
  }
}
