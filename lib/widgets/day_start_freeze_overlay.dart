import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../services/localization_service.dart';

class DayStartFreezeOverlay extends StatefulWidget {
  const DayStartFreezeOverlay({super.key});

  @override
  State<DayStartFreezeOverlay> createState() => _DayStartFreezeOverlayState();
}

class _DayStartFreezeOverlayState extends State<DayStartFreezeOverlay> with SingleTickerProviderStateMixin {
  final _otpController = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _otpController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _handleRequestOtp(AppState appState, String lang) async {
    final success = await appState.requestDayStartOtp();
    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocalizationService.tr('otp_sent_to_mgmt', lang: lang),
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleStartDay(AppState appState, String lang) async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang == 'si'
                ? 'කරුණාකර අංක 6 කින් යුත් නිවැරදි OTP කේතය ඇතුළත් කරන්න.'
                : 'Please enter a valid 6-digit OTP code.',
          ),
          backgroundColor: AppTheme.dangerRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final success = await appState.startDayWithOtp(otp);
    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  LocalizationService.tr('day_started_success', lang: lang),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final lang = appState.currentLanguage;
    final isSi = lang == 'si';

    final finalizedTimeFormatted = appState.dayEndFinalizedAt != null
        ? DateFormat('yyyy-MM-dd • hh:mm a').format(appState.dayEndFinalizedAt!)
        : DateFormat('yyyy-MM-dd').format(DateTime.now());

    final isNewDay = appState.dayStartLockReason == 'NEW_DAY';
    final badgeText = isNewDay
        ? LocalizationService.tr('day_start_new_day_badge', lang: lang)
        : LocalizationService.tr('day_start_frozen_badge', lang: lang);
    final subText = isNewDay
        ? LocalizationService.tr('day_start_new_day_sub', lang: lang)
        : LocalizationService.tr('day_start_sub', lang: lang);

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. LIQUID GLASS FROZEN BACKDROP
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xDD030712), // Deep icy midnight
                        const Color(0x990C2540), // Frosted arctic teal sheen
                        const Color(0xCC0A1124),
                        const Color(0xEE020617),
                      ],
                      stops: const [0.0, 0.35, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // Subtle frost crystal aura particles
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x1F38BDF8),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2638BDF8),
                      blurRadius: 90,
                      spreadRadius: 30,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -60,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x1A0284C7),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x200284C7),
                      blurRadius: 90,
                      spreadRadius: 30,
                    ),
                  ],
                ),
              ),
            ),

            // 2. CENTER LIQUID GLASS MODAL CARD
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0x38FFFFFF), // Top specular glass sheen
                            Color(0x241E293B),
                            Color(0x3B0F172A),
                          ],
                          stops: [0.0, 0.45, 1.0],
                        ),
                        border: Border.all(
                          color: const Color(0x5538BDF8), // Glowing cyan crystal border
                          width: 1.4,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x99000000),
                            blurRadius: 40,
                            offset: Offset(0, 20),
                          ),
                          BoxShadow(
                            color: Color(0x330284C7), // Liquid cyan ambient glow
                            blurRadius: 45,
                            spreadRadius: 4,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 30),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Top Highlight bar
                                Center(
                                  child: Container(
                                    width: 48,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: const Color(0x6638BDF8),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Frost Lock Status Badge
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0x2238BDF8),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(0x5538BDF8),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          '❄️',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          badgeText,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF38BDF8),
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),

                                // Animated Sun/Unlock Icon
                                Center(
                                  child: ScaleTransition(
                                    scale: _pulseAnimation,
                                    child: Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFF0284C7),
                                            Color(0xFF0F766E),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: const Color(0x887DD3FC),
                                          width: 2,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x440284C7),
                                            blurRadius: 24,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.wb_sunny_rounded,
                                        color: Colors.white,
                                        size: 38,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),

                                // Modal Title
                                Text(
                                  LocalizationService.tr('day_start_title', lang: lang),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Subtitle
                                Text(
                                  subText,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    color: const Color(0xFF94A3B8),
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 18),

                                // User Profile Capsule
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0x1F0F172A),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0x33475569),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: const Color(0x3338BDF8),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.person,
                                          color: Color(0xFF38BDF8),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              appState.currentUser.fullName.isNotEmpty
                                                  ? appState.currentUser.fullName
                                                  : 'Field Collector',
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'ID: ${appState.userReceiptPrefix} • Locked: $finalizedTimeFormatted',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: const Color(0xFF94A3B8),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Request OTP from Management Button
                                OutlinedButton.icon(
                                  onPressed: appState.isRequestingDayStartOtp
                                      ? null
                                      : () => _handleRequestOtp(appState, lang),
                                  icon: appState.isRequestingDayStartOtp
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                                          ),
                                        )
                                      : const Icon(Icons.send_rounded, size: 18, color: Color(0xFF38BDF8)),
                                  label: Text(
                                    appState.isRequestingDayStartOtp
                                        ? (isSi ? 'OTP ඉල්ලුම් කරමින්...' : 'Requesting OTP...')
                                        : LocalizationService.tr('req_otp_management', lang: lang),
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF38BDF8),
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    side: const BorderSide(color: Color(0x6638BDF8), width: 1.2),
                                    backgroundColor: const Color(0x140284C7),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Dispatched Notice Pill
                                if (appState.dayStartOtpDispatched) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0x1F059669),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0x55059669),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: Color(0xFF34D399),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            LocalizationService.tr('otp_sent_to_mgmt', lang: lang),
                                            style: GoogleFonts.inter(
                                              fontSize: 11.5,
                                              color: const Color(0xFF6EE7B7),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                ],

                                // Error Banner
                                if (appState.dayStartError != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0x24DC2626),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0x66DC2626),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.error_outline_rounded,
                                          color: Color(0xFFF87171),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            appState.dayStartError!,
                                            style: GoogleFonts.inter(
                                              fontSize: 11.5,
                                              color: const Color(0xFFFCA5A5),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                ],

                                // 6-Digit OTP Text Field
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0x1F0F172A),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0x4464748B),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _otpController,
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 10,
                                      color: const Color(0xFF38BDF8),
                                    ),
                                    decoration: InputDecoration(
                                      counterText: '',
                                      hintText: '• • • • • •',
                                      hintStyle: GoogleFonts.jetBrainsMono(
                                        fontSize: 22,
                                        letterSpacing: 8,
                                        color: const Color(0x4494A3B8),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),

                                // Start Day & Unlock App Button
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF0D9488), // Emerald / Teal
                                        Color(0xFF0284C7), // Sky Blue
                                      ],
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x400284C7),
                                        blurRadius: 18,
                                        offset: Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: appState.isVerifyingDayStartOtp
                                        ? null
                                        : () => _handleStartDay(appState, lang),
                                    icon: appState.isVerifyingDayStartOtp
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : const Icon(Icons.lock_open_rounded, size: 20, color: Colors.white),
                                    label: Text(
                                      appState.isVerifyingDayStartOtp
                                          ? (isSi ? 'සත්‍යාපනය කරමින්...' : 'Verifying & Unlocking...')
                                          : LocalizationService.tr('start_day_unlock', lang: lang),
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Sign Out link
                                Center(
                                  child: TextButton.icon(
                                    onPressed: () {
                                      appState.logout();
                                    },
                                    icon: const Icon(Icons.logout, size: 16, color: Color(0xFF94A3B8)),
                                    label: Text(
                                      isSi ? 'ගිණුමෙන් ඉවත් වන්න' : 'Sign out of this account',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        color: const Color(0xFF94A3B8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
