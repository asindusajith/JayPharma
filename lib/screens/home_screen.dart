import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/jay_pharma_logo.dart';
import '../services/localization_service.dart';
import '../services/location_service.dart';
import '../services/bluetooth_printer_service.dart';
import 'payment/select_customer_screen.dart';
import 'receipts/receipts_screen.dart';
import 'customers/customers_screen.dart';
import 'day_end/day_end_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'settings/settings_screen.dart';
import '../widgets/day_start_freeze_overlay.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      appState.fetchRealtimeReceipts();
      appState.fetchRealtimeCustomers();
      appState.fetchAllUsers();
      if (!appState.isAdmin && !appState.isGpsOnline) {
        appState.requestAndConnectGps();
      }
      if (!appState.isAdmin) {
        appState.checkDayEndStatus();
      }
      // Silently auto-connect to paired/saved Bluetooth receipt printer in background
      BluetoothPrinterService.autoConnectToSavedPrinter();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final lang = appState.currentLanguage;
    final currency = NumberFormat('#,##0.00', 'en_US');

    final todaySummary = appState.calculateDayEndSummary(DateTime.now());

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        // Prevent back press from exiting app or dropping to launcher
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const JayPharmaLogo(size: 38, isDark: true, showText: true),
        actions: [
          // Language switch
          TextButton(
            onPressed: () {
              appState.toggleLanguage(lang == 'en' ? 'si' : 'en');
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: Row(
              children: [
                const Icon(Icons.language, size: 16, color: Color(0xFF38BDF8)),
                const SizedBox(width: 4),
                Text(
                  lang == 'en' ? 'සිංහල' : 'English',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // Settings Icon Button - ADMIN ONLY
          if (appState.isAdmin)
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              tooltip: LocalizationService.tr('settings', lang: lang),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
            ),
          // Sign Out Icon Button
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            tooltip: LocalizationService.tr('sign_out', lang: lang),
            onPressed: () {
              _confirmLogout(context, appState, lang);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // User & Collector Profile Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: _getRoleBgColor(appState.currentUser.accessLevel),
                        child: Text(
                          appState.currentUser.fullName.isNotEmpty
                              ? appState.currentUser.fullName.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join('').toUpperCase()
                              : 'U',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getRoleTextColor(appState.currentUser.accessLevel),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    appState.currentUser.fullName.isNotEmpty ? appState.currentUser.fullName : appState.collectorName,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textDark,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getRoleBgColor(appState.currentUser.accessLevel),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: _getRoleBorderColor(appState.currentUser.accessLevel), width: 0.8),
                                  ),
                                  child: Text(
                                    lang == 'si'
                                        ? (appState.currentUser.accessLevel == 'Admin'
                                            ? 'පරිපාලක'
                                            : appState.currentUser.accessLevel == 'Manager'
                                                ? 'කළමනාකරු'
                                                : appState.currentUser.accessLevel == 'Cashier'
                                                    ? 'අයකැමි'
                                                    : 'එකතුකරන්නා')
                                        : appState.currentUser.accessLevel,
                                    style: GoogleFonts.inter(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: _getRoleTextColor(appState.currentUser.accessLevel),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(
                                  appState.currentUser.hasAllLocations ? Icons.public : Icons.place_outlined,
                                  size: 12,
                                  color: appState.currentUser.hasAllLocations ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    appState.currentUser.hasAllLocations
                                        ? LocalizationService.tr('all_locations_island', lang: lang)
                                        : '${LocalizationService.tr('areas', lang: lang)}: ${appState.currentUser.assignedLocations}',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: appState.currentUser.hasAllLocations ? const Color(0xFF15803D) : const Color(0xFF1D4ED8),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => _showGpsDialog(context, appState, lang),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (appState.isAdmin || appState.isGpsOnline)
                                ? const Color(0xFFDCFCE7)
                                : (appState.isLocationPermissionNeeded
                                    ? const Color(0xFFFEF3C7)
                                    : const Color(0xFFFEE2E2)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (appState.isAdmin || appState.isGpsOnline)
                                  ? const Color(0xFF86EFAC)
                                  : (appState.isLocationPermissionNeeded
                                      ? const Color(0xFFFCD34D)
                                      : const Color(0xFFFCA5A5)),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: (appState.isAdmin || appState.isGpsOnline)
                                      ? const Color(0xFF16A34A)
                                      : (appState.isLocationPermissionNeeded
                                          ? const Color(0xFFD97706)
                                          : const Color(0xFFDC2626)),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                appState.isAdmin
                                    ? (appState.isGpsOnline
                                        ? (lang == 'si' ? 'GPS සක්‍රීයයි' : 'GPS Online')
                                        : (lang == 'si' ? 'Admin ප්‍රවේශය' : 'Admin Mode'))
                                    : (appState.isGpsOnline
                                        ? (lang == 'si' ? 'GPS සක්‍රීයයි' : 'GPS Online')
                                        : (appState.isLocationPermissionNeeded
                                            ? (lang == 'si' ? 'අවසරය අවශ්‍යයි' : 'Permission Req.')
                                            : (lang == 'si' ? 'GPS අක්‍රියයි' : 'GPS Offline'))),
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: (appState.isAdmin || appState.isGpsOnline)
                                      ? const Color(0xFF15803D)
                                      : (appState.isLocationPermissionNeeded
                                          ? const Color(0xFFB45309)
                                          : const Color(0xFFB91C1C)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // GPS Offline / Permission Alert Banner (Hidden for Admin accounts)
                if (!appState.isAdmin && !appState.isGpsOnline) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: appState.isLocationPermissionNeeded
                          ? const Color(0xFFFFFBEB)
                          : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: appState.isLocationPermissionNeeded
                            ? const Color(0xFFFDE68A)
                            : const Color(0xFFFCA5A5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          appState.isLocationPermissionNeeded
                              ? Icons.security_update_warning_rounded
                              : Icons.location_off_rounded,
                          color: appState.isLocationPermissionNeeded
                              ? const Color(0xFFD97706)
                              : const Color(0xFFDC2626),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            appState.isLocationPermissionNeeded
                                ? (lang == 'si'
                                    ? 'GPS සක්‍රීයයි! බිල්පත් කිරීමට App එකට Location අවසරය ලබා දෙන්න.'
                                    : 'GPS is ON! Please grant Location permission to allow billing.')
                                : (lang == 'si'
                                    ? 'දුරකථනයේ GPS අක්‍රියයි. බිල්පත් කිරීමට Settings වෙතින් GPS සක්‍රීය කරන්න.'
                                    : 'Device GPS is disabled. GPS must be enabled to issue bills.'),
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: appState.isLocationPermissionNeeded
                                  ? const Color(0xFF92400E)
                                  : const Color(0xFF991B1B),
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: appState.isConnectingGps
                              ? null
                              : () async {
                                  final loc = await appState.requestAndConnectGps();
                                  if (loc == null && context.mounted) {
                                    _showGpsDialog(context, appState, lang);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: appState.isLocationPermissionNeeded
                                ? const Color(0xFFD97706)
                                : const Color(0xFFDC2626),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: appState.isConnectingGps
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  appState.isLocationPermissionNeeded
                                      ? (lang == 'si' ? 'අවසර දෙන්න' : 'Allow')
                                      : (lang == 'si' ? 'සක්‍රීය කරන්න' : 'Enable'),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // Day-End Lock Warning Banner (Section 3 Requirement - Hidden for Admin)
                if (!appState.isAdmin && appState.isDayEndFinalized) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lock, color: Color(0xFFDC2626), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang == 'si' ? 'දින අවසානය සම්පූර්ණ කර අගුලු ලා ඇත' : 'Day-End Finalized & Locked',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF991B1B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                LocalizationService.tr('day_end_locked_msg', lang: lang),
                                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFB91C1C)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Today Collection Summary Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F1E36), Color(0xFF1E3A8A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F1E36).withValues(alpha: 0.18),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            LocalizationService.tr('todays_collections', lang: lang),
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${todaySummary.totalReceiptsCount} ${LocalizationService.tr('receipts_issued', lang: lang)}',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Rs. ${currency.format(todaySummary.totalIncome)}',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.payments, color: Color(0xFF34D399), size: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(LocalizationService.tr('cash', lang: lang), style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                                      Text(
                                        'Rs. ${currency.format(todaySummary.totalCash)}',
                                        style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 26, color: Colors.white.withValues(alpha: 0.15)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.account_balance, color: Color(0xFF38BDF8), size: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${LocalizationService.tr('cheque', lang: lang)} (${todaySummary.chequesList.length})', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                                      Text(
                                        'Rs. ${currency.format(todaySummary.totalCheque)}',
                                        style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Primary Action Cards (Section 2.1 Requirements)
                Text(
                  LocalizationService.tr('operations', lang: lang),
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                const SizedBox(height: 10),

                // Option 1: Accept Payment (Create new receipt)
                _buildActionCard(
                  context,
                  title: LocalizationService.tr('accept_payment', lang: lang),
                  subtitle: LocalizationService.tr('accept_payment_sub', lang: lang),
                  icon: Icons.add_circle,
                  color: AppTheme.primaryBlue,
                  badge: (!appState.isAdmin && appState.isDayEndFinalized)
                      ? LocalizationService.tr('day_end_locked', lang: lang)
                      : (!appState.isAdmin && !appState.isGpsOnline ? (lang == 'si' ? 'GPS අවශ්‍යයි' : 'GPS Required') : null),
                  badgeColor: (!appState.isAdmin && appState.isDayEndFinalized) ? AppTheme.dangerRed : const Color(0xFFDC2626),
                  onTap: () => _handleAcceptPaymentTap(context, appState, lang),
                ),
                const SizedBox(height: 10),

                // Option 2: Receipts (View today's receipts)
                _buildActionCard(
                  context,
                  title: LocalizationService.tr('receipts', lang: lang),
                  subtitle: LocalizationService.tr('receipts_sub', lang: lang),
                  icon: Icons.receipt_long,
                  color: const Color(0xFF0D9488),
                  badge: '${appState.receipts.length} ${LocalizationService.tr('recorded', lang: lang)}',
                  badgeColor: const Color(0xFF0D9488),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReceiptsScreen()),
                    );
                  },
                ),
                const SizedBox(height: 10),

                // Option 3: Customers (View customer outstanding balances)
                _buildActionCard(
                  context,
                  title: LocalizationService.tr('customers', lang: lang),
                  subtitle: LocalizationService.tr('customers_sub', lang: lang),
                  icon: Icons.storefront,
                  color: const Color(0xFF6366F1),
                  badge: '${appState.accessibleCustomers.length} ${LocalizationService.tr('accessible', lang: lang)}',
                  badgeColor: const Color(0xFF6366F1),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CustomersScreen()),
                    );
                  },
                ),
                const SizedBox(height: 10),

                // Option 4: Day-End Summary Statement (Section 3 Requirement)
                _buildActionCard(
                  context,
                  title: LocalizationService.tr('day_end', lang: lang),
                  subtitle: LocalizationService.tr('day_end_sub', lang: lang),
                  icon: Icons.assessment,
                  color: const Color(0xFFF59E0B),
                  badge: appState.isDayEndFinalized
                      ? LocalizationService.tr('completed', lang: lang)
                      : LocalizationService.tr('pending', lang: lang),
                  badgeColor: appState.isDayEndFinalized ? AppTheme.successGreen : AppTheme.warningAmber,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DayEndScreen()),
                    );
                  },
                ),
                const SizedBox(height: 10),

                // Option 5: Dashboard (View Visited Locations & Field Monitoring) - ADMIN ONLY
                if (appState.isAdmin) ...[
                  _buildActionCard(
                    context,
                    title: LocalizationService.tr('dashboard', lang: lang),
                    subtitle: LocalizationService.tr('dashboard_sub', lang: lang),
                    icon: Icons.space_dashboard_rounded,
                    color: const Color(0xFF8B5CF6),
                    badge: '${appState.receipts.length} ${LocalizationService.tr('recorded', lang: lang)}',
                    badgeColor: const Color(0xFF8B5CF6),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DashboardScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
      ),
      if (!appState.isAdmin && appState.isDayEndFinalized)
        const DayStartFreezeOverlay(),
    ],
  ),
),
);
}

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    String? badge,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (badgeColor ?? color).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: badgeColor ?? color,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }

  void _showDayEndLockedDialog(BuildContext context, String lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.lock, color: AppTheme.dangerRed),
            const SizedBox(width: 8),
            Text('Collection Locked', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          LocalizationService.tr('day_end_locked_msg', lang: lang),
          style: GoogleFonts.inter(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, AppState appState, String lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          LocalizationService.tr('sign_out', lang: lang),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          lang == 'si'
              ? 'ඔබට නිසැකවම ඔබගේ ගිණුමෙන් ඉවත් වීමට අවශ්‍යද?'
              : 'Are you sure you want to sign out of your account?',
          style: GoogleFonts.inter(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(LocalizationService.tr('cancel', lang: lang)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
            onPressed: () {
              Navigator.pop(ctx);
              appState.logout();
            },
            child: Text(LocalizationService.tr('sign_out', lang: lang)),
          ),
        ],
      ),
    );
  }

  void _handleAcceptPaymentTap(BuildContext context, AppState appState, String lang) async {
    if (!appState.isAdmin && appState.isDayEndFinalized) {
      _showDayEndLockedDialog(context, lang);
      return;
    }

    if (!appState.isAdmin) {
      await appState.checkGpsStatus();

      if (!appState.isGpsOnline) {
        if (!context.mounted) return;
        _showGpsRequiredForBillingDialog(context, appState, lang);
        return;
      }
    }

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SelectCustomerScreen()),
    );
  }

  void _showGpsRequiredForBillingDialog(BuildContext context, AppState appState, String lang) {
    _showGpsDialog(context, appState, lang, fromBillingAttempt: true);
  }

  void _showGpsDialog(BuildContext context, AppState appState, String lang, {bool fromBillingAttempt = false}) {
    final isOnline = appState.isGpsOnline;
    final isPermNeeded = appState.isLocationPermissionNeeded;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isOnline
                  ? Icons.location_on_rounded
                  : (isPermNeeded ? Icons.security_update_warning_rounded : Icons.location_off_rounded),
              color: isOnline
                  ? const Color(0xFF16A34A)
                  : (isPermNeeded ? const Color(0xFFD97706) : const Color(0xFFDC2626)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isOnline
                    ? (lang == 'si' ? 'GPS සක්‍රීයයි' : 'GPS Online')
                    : (fromBillingAttempt
                        ? (lang == 'si' ? 'GPS අවශ්‍යයි - බිල්පත් කිරීම අවහිරයි' : 'GPS Required - Billing Blocked')
                        : (isPermNeeded
                            ? (lang == 'si' ? 'Location අවසරය අවශ්‍යයි' : 'Location Permission Required')
                            : (lang == 'si' ? 'GPS අක්‍රියයි' : 'GPS Offline'))),
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isOnline) ...[
                Text(
                  lang == 'si'
                      ? 'ඔබගේ දුරකථනයේ GPS සක්‍රීයව ක්‍රියාත්මක වේ. බිල්පත් කිරීමේදී නියම ස්ථානය සටහන් වේ.'
                      : 'Device GPS is active and ready. Billing locations will be recorded with high accuracy.',
                  style: GoogleFonts.inter(fontSize: 13.5, height: 1.4),
                ),
              ] else if (kIsWeb) ...[
                Text(
                  lang == 'si'
                      ? 'Browser එකෙන් Location අවසරය (Allow) ලබා ගැනීමට:'
                      : 'How to allow Location in Chrome / Browser:',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF2563EB)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              lang == 'si'
                                  ? '1. Chrome ඉහළ Address Bar එකේ jaypharma.vercel.app ඉදිරියෙන් ඇති 🔒 හෝ 🎛️ (Site Settings) icon එක ඔබන්න.'
                                  : '1. In Chrome, tap the 🔒 or 🎛️ icon next to the URL.',
                              style: GoogleFonts.inter(fontSize: 12, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF16A34A)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              lang == 'si'
                                  ? '2. "Location" (ස්ථානය) Setting එක "Allow" (ඉඩ දෙන්න) ලෙස සකසන්න.'
                                  : '2. Change "Location" to "Allow".',
                              style: GoogleFonts.inter(fontSize: 12, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.phone_android_rounded, size: 18, color: Color(0xFFD97706)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              lang == 'si'
                                  ? '3. දුරකථනයේ/පරිගණකයේ Location / GPS switch එක On කර ඇත්දැයි තහවුරු කරන්න.'
                                  : '3. Ensure phone/PC Location toggle is ON.',
                              style: GoogleFonts.inter(fontSize: 12, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Text(
                  lang == 'si'
                      ? (isPermNeeded
                          ? 'බිල්පතක් නිකුත් කිරීමට App එකට Location අවසරය ලබා දීම අනිවාර්ය වේ. කරුණාකර අවසර ලබා දෙන්න.'
                          : 'දුරකථනයේ GPS අක්‍රිය කර ඇත. බිල්පත් කළ ස්ථානය සටහන් කරගැනීමට GPS සක්‍රීය කර තිබීම අනිවාර්ය වේ.')
                      : (isPermNeeded
                          ? 'Location permission must be granted to issue bills.'
                          : 'Device GPS is disabled. GPS must be enabled to issue bills.'),
                  style: GoogleFonts.inter(fontSize: 13.5, height: 1.4),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang == 'si' ? 'වසන්න' : 'Close'),
          ),
          if (!isOnline) ...[
            if (!kIsWeb)
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  if (isPermNeeded) {
                    await LocationService.openAppSettings();
                  } else {
                    await LocationService.openLocationSettings();
                  }
                },
                icon: const Icon(Icons.settings, size: 16, color: Colors.white),
                label: Text(
                  isPermNeeded
                      ? (lang == 'si' ? 'App Settings වෙත යන්න' : 'Open App Settings')
                      : (lang == 'si' ? 'GPS Settings වෙත යන්න' : 'Open Location Settings'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                final loc = await appState.requestAndConnectGps();
                if (loc != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(lang == 'si' ? 'GPS සාර්ථකව සම්බන්ධ විය!' : 'GPS successfully connected!'),
                      backgroundColor: const Color(0xFF16A34A),
                    ),
                  );
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(lang == 'si'
                          ? 'GPS සම්බන්ධ වීමට නොහැකි විය. කරුණාකර Browser එකෙන් Location Allow කරන්න.'
                          : 'GPS not connected. Please allow Location in Chrome address bar.'),
                      backgroundColor: const Color(0xFFDC2626),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
              label: Text(
                lang == 'si' ? 'නැවත සම්බන්ධ කරන්න' : 'Connect GPS',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getRoleBgColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return const Color(0xFFF3E8FF);
      case 'manager':
        return const Color(0xFFEFF6FF);
      case 'cashier':
        return const Color(0xFFFEF3C7);
      case 'collector':
      default:
        return const Color(0xFFECFDF5);
    }
  }

  Color _getRoleTextColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return const Color(0xFF7E22CE);
      case 'manager':
        return const Color(0xFF1D4ED8);
      case 'cashier':
        return const Color(0xFFB45309);
      case 'collector':
      default:
        return const Color(0xFF047857);
    }
  }

  Color _getRoleBorderColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return const Color(0xFFE9D5FF);
      case 'manager':
        return const Color(0xFFBFDBFE);
      case 'cashier':
        return const Color(0xFFFDE68A);
      case 'collector':
      default:
        return const Color(0xFFA7F3D0);
    }
  }
}

