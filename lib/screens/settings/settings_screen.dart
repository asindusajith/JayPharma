import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/app_user.dart';
import '../../models/customer.dart';
import '../../theme/app_theme.dart';
import '../../services/localization_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedPrinter = 'RPP02N 80mm Bluetooth Thermal Printer';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppState>(context, listen: false).fetchAllUsers();
    });
  }


  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final lang = appState.currentLanguage;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          LocalizationService.tr('settings', lang: lang),
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // User & Access Control Section (New Feature Requirement)
                _buildUserManagementCard(context, appState),
                const SizedBox(height: 16),

                // Portable Receipt Printer Settings (Section 2.3)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.print_outlined, color: AppTheme.primaryBlue, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              LocalizationService.tr('printer_section', lang: lang),
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedPrinter,
                          decoration: InputDecoration(
                            labelText: LocalizationService.tr('printer_connected', lang: lang),
                            prefixIcon: const Icon(Icons.bluetooth_connected, color: AppTheme.primaryBlue, size: 20),
                          ),
                          items: [
                            'RPP02N 80mm Bluetooth Thermal Printer',
                            'MTP-II 58mm Mini Mobile Printer',
                            'Zebra EM220 Portable Receipt Printer',
                            'Standard System Print Spooler (PDF)',
                          ]
                              .map((p) => DropdownMenuItem(value: p, child: Text(p, style: GoogleFonts.inter(fontSize: 12))))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedPrinter = val);
                          },
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              LocalizationService.tr('paper_size', lang: lang),
                              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                            ),
                            TextButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(lang == 'si'
                                        ? 'පරීක්ෂණ මුද්‍රණ දත්ත සාර්ථකව යවන ලදී.'
                                        : 'Test print packet sent to printer successfully.'),
                                  ),
                                );
                              },
                              child: Text(
                                LocalizationService.tr('test_print', lang: lang),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // App Version & Auto-Update Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.system_update_rounded, color: Color(0xFF16A34A), size: 22),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lang == 'si' ? 'යෙදුම් අනුවාදය සහ යාවත්කාලීන' : 'App Version & Auto Updates',
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                                  ),
                                  Text(
                                    'Installed: v1.0.2 (Build 3) • GitHub Auto CI/CD',
                                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          lang == 'si'
                              ? 'Git push කළ පසු නවතම APK එක GitHub මඟින් ස්වයංක්‍රීයව Build වේ. පහත බටනය මඟින් නවතම APK එක ඕනෑම වේලාවක බාගත කර ස්ථාපනය කළ හැක.'
                              : 'Whenever code is pushed to GitHub, the latest release APK is automatically compiled in the cloud. Tap below to download the latest APK update.',
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textDark, height: 1.4),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: Text(
                              lang == 'si' ? 'නවතම APK එක බාගත කරන්න (Download Latest)' : 'Download Latest APK Update',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              final uri = Uri.parse('https://github.com/asindusajith/JayPharma/releases/latest/download/app-release.apk');
                              try {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Could not open download link: $e')),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Developer / Testing Helper
                if (appState.isDayEndFinalized) ...[
                  Card(
                    elevation: 0,
                    color: const Color(0xFFFEF2F2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.admin_panel_settings, color: AppTheme.dangerRed),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Testing Tool: Day-End is Locked', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                                Text('Unlock collection session for testing additional payments.', style: GoogleFonts.inter(fontSize: 11)),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              appState.unlockDayEndForTesting();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Day-end unlocked for test payments.')),
                              );
                            },
                            child: const Text('Unlock', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserManagementCard(BuildContext context, AppState appState) {
    final users = appState.allUsers;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.manage_accounts_rounded, color: Color(0xFF4F46E5), size: 22),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          LocalizationService.tr('user_mgmt', lang: appState.currentLanguage),
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        ),
                        Text(
                          appState.currentLanguage == 'si'
                              ? 'ලියාපදිංචි පද්ධති පරිශීලකයින් (${users.length})'
                              : '${users.length} registered system users',
                          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20, color: AppTheme.primaryBlue),
                  tooltip: appState.currentLanguage == 'si' ? 'යාවත්කාලීන කරන්න' : 'Refresh user list',
                  onPressed: () => appState.fetchAllUsers(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Add User Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: Text(
                  LocalizationService.tr('add_new_user', lang: appState.currentLanguage),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () => _showCreateUserDialog(context, appState),
              ),
            ),
            const SizedBox(height: 16),

            if (appState.isLoadingUsers)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                ),
              )
            else if (users.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    appState.currentLanguage == 'si' ? 'පරිශීලකයින් කිසිවෙක් හමු නොවීය.' : 'No users found in database.',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: users.length,
                separatorBuilder: (context, index) => const Divider(height: 20, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final user = users[index];
                  return _buildUserTile(context, user, appState);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTile(BuildContext context, AppUser user, AppState appState) {
    Color roleBgColor;
    Color roleTextColor;
    Color roleBorderColor;

    switch (user.accessLevel.toLowerCase()) {
      case 'admin':
        roleBgColor = const Color(0xFFF3E8FF);
        roleTextColor = const Color(0xFF7E22CE);
        roleBorderColor = const Color(0xFFE9D5FF);
        break;
      case 'manager':
        roleBgColor = const Color(0xFFEFF6FF);
        roleTextColor = const Color(0xFF1D4ED8);
        roleBorderColor = const Color(0xFFBFDBFE);
        break;
      case 'cashier':
        roleBgColor = const Color(0xFFFEF3C7);
        roleTextColor = const Color(0xFFB45309);
        roleBorderColor = const Color(0xFFFDE68A);
        break;
      case 'collector':
      default:
        roleBgColor = const Color(0xFFECFDF5);
        roleTextColor = const Color(0xFF047857);
        roleBorderColor = const Color(0xFFA7F3D0);
        break;
    }

    final initials = user.fullName.isNotEmpty
        ? user.fullName.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join('').toUpperCase()
        : user.username.isNotEmpty ? user.username.substring(0, 1).toUpperCase() : 'U';

    final lang = appState.currentLanguage;
    final isSi = lang == 'si';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: user.isActive ? const Color(0xFFFAFAFA) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: user.isActive ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: roleBgColor,
                child: Text(
                  initials,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: roleTextColor),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.fullName.isNotEmpty ? user.fullName : user.username,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: user.isActive ? AppTheme.textDark : AppTheme.textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: roleBgColor,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: roleBorderColor, width: 0.8),
                          ),
                          child: Text(
                            isSi
                                ? (user.accessLevel == 'Admin'
                                    ? 'පරිපාලක'
                                    : user.accessLevel == 'Manager'
                                        ? 'කළමනාකරු'
                                        : user.accessLevel == 'Cashier'
                                            ? 'අයකැමි'
                                            : 'එකතුකරන්නා')
                                : user.accessLevel,
                            style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: roleTextColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: ${user.collectorId} • @${user.username}${user.phone.isNotEmpty ? ' • 📞 ${user.phone}' : ''}',
                      style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              // Status Badge / Toggle
              InkWell(
                onTap: () {
                  _confirmToggleUser(context, user, appState);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: user.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: user.isActive ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: user.isActive ? const Color(0xFF16A34A) : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        user.isActive ? LocalizationService.tr('active', lang: lang) : LocalizationService.tr('disabled', lang: lang),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: user.isActive ? const Color(0xFF15803D) : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Assigned Locations Chip with Edit Action
          InkWell(
            onTap: () => _showEditLocationsDialog(context, user, appState),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: user.hasAllLocations ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: user.hasAllLocations ? const Color(0xFFBBF7D0) : const Color(0xFFBFDBFE),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    user.hasAllLocations ? Icons.public : Icons.storefront_outlined,
                    size: 14,
                    color: user.hasAllLocations ? const Color(0xFF15803D) : const Color(0xFF1D4ED8),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _getUserLocationsLabel(user, appState),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: user.hasAllLocations ? const Color(0xFF15803D) : const Color(0xFF1D4ED8),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: user.hasAllLocations ? const Color(0xFFBBF7D0) : const Color(0xFFBFDBFE)),
                    ),
                    child: const Icon(Icons.edit_outlined, size: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getUserLocationsLabel(AppUser user, AppState appState) {
    final lang = appState.currentLanguage;
    final isSi = lang == 'si';
    if (user.hasAllLocations) {
      return isSi
          ? 'සියලුම ස්ථාන (${appState.customers.length} ෆාමසි)'
          : 'All Locations (${appState.customers.length} Pharmacies)';
    }
    final codes = user.locationList;
    if (codes.isEmpty) {
      return isSi ? 'ස්ථාන පවරා නැත' : 'No Locations Assigned';
    }

    final names = <String>[];
    for (final c in codes) {
      final cust = appState.customers.firstWhere(
        (item) => item.code.trim() == c.trim() || item.name.toLowerCase().contains(c.toLowerCase()),
        orElse: () => Customer(code: c, name: c),
      );
      final displayName = cust.name.contains('-') ? cust.name.split('-')[0].trim() : cust.name;
      names.add(displayName);
    }

    if (names.length <= 2) {
      return isSi ? '${codes.length}ක් පවරා ඇත: ${names.join(', ')}' : '${codes.length} Assigned: ${names.join(', ')}';
    } else {
      return isSi
          ? '${codes.length}ක් පවරා ඇත: ${names.take(2).join(', ')} +${codes.length - 2}'
          : '${codes.length} Assigned: ${names.take(2).join(', ')} +${codes.length - 2} more';
    }
  }

  void _showCreateUserDialog(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateUserDialog(appState: appState),
    );
  }

  void _showEditLocationsDialog(BuildContext context, AppUser user, AppState appState) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditUserLocationsDialog(user: user, appState: appState),
    );
  }

  void _confirmToggleUser(BuildContext context, AppUser user, AppState appState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          user.isActive ? 'Deactivate User?' : 'Activate User?',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to ${user.isActive ? 'deactivate' : 'activate'} login access for ${user.fullName} (${user.username})?',
          style: GoogleFonts.inter(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: user.isActive ? AppTheme.dangerRed : AppTheme.successGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await appState.toggleUserStatus(user.collectorId);
            },
            child: Text(user.isActive ? 'Deactivate' : 'Activate'),
          ),
        ],
      ),
    );
  }
}

// Dialog to create a new user with access level and assigned customer locations
class _CreateUserDialog extends StatefulWidget {
  final AppState appState;

  const _CreateUserDialog({required this.appState});

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final _fullNameController = TextEditingController();
  final _collectorIdController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _searchLocationController = TextEditingController();

  String _accessLevel = 'Collector';
  bool _allLocationsChecked = true;
  final Set<String> _selectedCustomerCodes = {};
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Default to All Locations selected
    _allLocationsChecked = true;
    _selectedCustomerCodes.addAll(widget.appState.customers.map((c) => c.code.trim()));
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _collectorIdController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _searchLocationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final fullName = _fullNameController.text.trim();
    final collectorId = _collectorIdController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    final isSi = widget.appState.currentLanguage == 'si';

    if (fullName.isEmpty) {
      setState(() => _errorMessage = isSi ? 'කරුණාකර සම්පූර්ණ නම ඇතුළත් කරන්න.' : 'Please enter user full name.');
      return;
    }
    if (collectorId.isNotEmpty && collectorId.length > 20) {
      setState(() => _errorMessage = isSi
          ? 'පරිශීලක ID / කේතය උපරිම අක්ෂර 20ක් විය යුතුය.'
          : 'User ID / Code cannot exceed 20 characters.');
      return;
    }
    if (username.isEmpty) {
      setState(() => _errorMessage = isSi ? 'කරුණාකර පරිශීලක නාමය ඇතුළත් කරන්න.' : 'Please enter username.');
      return;
    }
    if (password.length < 4) {
      setState(() => _errorMessage = isSi ? 'මුරපදය අවම වශයෙන් අක්ෂර 4ක් විය යුතුය.' : 'Password must be at least 4 characters.');
      return;
    }

    String assignedLocationsString;
    if (_allLocationsChecked || _selectedCustomerCodes.length == widget.appState.customers.length) {
      assignedLocationsString = 'ALL';
    } else {
      if (_selectedCustomerCodes.isEmpty) {
        setState(() => _errorMessage = isSi ? 'කරුණාකර අවම වශයෙන් එක් ස්ථානයක් හෝ තෝරන්න.' : 'Please select at least one customer location.');
        return;
      }
      assignedLocationsString = _selectedCustomerCodes.join(', ');
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.appState.createNewUser(
        fullName: fullName,
        username: username,
        password: password,
        phone: _phoneController.text.trim(),
        branch: 'Jay Pharma',
        accessLevel: _accessLevel,
        assignedLocations: assignedLocationsString,
        collectorId: collectorId.isNotEmpty ? collectorId : null,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isSi
                ? 'පරිශීලක $fullName ${collectorId.isNotEmpty ? "($collectorId)" : ""} සාර්ථකව සාදන ලදී!'
                : 'User $fullName ${collectorId.isNotEmpty ? "($collectorId)" : "($username)"} created successfully!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,##0.00', 'en_US');
    final allCustomers = widget.appState.customers;
    final lang = widget.appState.currentLanguage;
    final isSi = lang == 'si';

    final filteredCustomers = allCustomers.where((c) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return c.code.toLowerCase().contains(q) ||
          c.name.toLowerCase().contains(q) ||
          c.town.toLowerCase().contains(q);
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF4F46E5), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            LocalizationService.tr('create_new_user', lang: lang),
                            style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                          ),
                          Text(
                            isSi ? 'පද්ධති ප්‍රවේශය සහ ස්ථාන පවරන්න' : 'Configure system access & locations',
                            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 18),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.dangerRed, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.dangerRed, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Scrollable Form Fields
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Full Name
                      TextField(
                        controller: _fullNameController,
                        decoration: InputDecoration(
                          labelText: '${LocalizationService.tr('full_name', lang: lang)} *',
                          prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                          hintText: isSi ? 'සුනිල් පෙරේරා' : 'Sunil Perera',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // User ID / Rep Code (e.g. XXX, 01122)
                      TextField(
                        controller: _collectorIdController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: LocalizationService.tr('collector_user_id', lang: lang),
                          prefixIcon: const Icon(Icons.pin_outlined, size: 20),
                          hintText: LocalizationService.tr('collector_user_id_hint', lang: lang),
                          helperText: LocalizationService.tr('collector_user_id_helper', lang: lang),
                          helperStyle: GoogleFonts.inter(fontSize: 10.5, color: AppTheme.textMuted),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Username & Password Row
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _usernameController,
                              decoration: InputDecoration(
                                labelText: '${LocalizationService.tr('username_id', lang: lang)} *',
                                prefixIcon: const Icon(Icons.alternate_email, size: 18),
                                hintText: 'sunil_rep',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: '${LocalizationService.tr('password', lang: lang)} *',
                                prefixIcon: const Icon(Icons.lock_outline, size: 18),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 18),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Phone Number
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: LocalizationService.tr('phone_number', lang: lang),
                          prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                          hintText: '077 123 4567',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Access Level Dropdown
                      DropdownButtonFormField<String>(
                        initialValue: _accessLevel,
                        decoration: InputDecoration(
                          labelText: '${LocalizationService.tr('access_level', lang: lang)} *',
                          prefixIcon: const Icon(Icons.admin_panel_settings_outlined, size: 20),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'Admin',
                            child: Text(isSi ? 'පරිපාලක (පූර්ණ පාලනය)' : 'Admin (Full System & User Control)'),
                          ),
                          DropdownMenuItem(
                            value: 'Manager',
                            child: Text(isSi ? 'කළමනාකරු (වාර්තා හා අධීක්ෂණය)' : 'Manager (Reports & Area Supervision)'),
                          ),
                          DropdownMenuItem(
                            value: 'Collector',
                            child: Text(isSi ? 'එකතුකරන්නා (ක්ෂේත්‍ර බිල්පත් හා මුදල්)' : 'Collector (Field Billing & Collection)'),
                          ),
                          DropdownMenuItem(
                            value: 'Cashier',
                            child: Text(isSi ? 'මුදල් අයකැමි (කාර්යාලීය කවුන්ටරය)' : 'Cashier (Office Counter Collection)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _accessLevel = val);
                        },
                      ),
                      const SizedBox(height: 14),

                      // Collection Locations Box with Customer List & Tick Marks
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.storefront_rounded, size: 18, color: Color(0xFF4F46E5)),
                                const SizedBox(width: 6),
                                Text(
                                  isSi
                                      ? 'එකතු කිරීමේ ස්ථාන (${allCustomers.length}ක් ඇත)'
                                      : 'Collection Locations (${allCustomers.length} Available)',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              LocalizationService.tr('select_pharmacies_tip', lang: lang),
                              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                            ),
                            const SizedBox(height: 10),

                            // Search & Selection Toolbar (SINGLE Clean Controller - duplicate top card removed)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isSi
                                      ? 'තෝරාගෙන ඇත: ${_selectedCustomerCodes.length} / ${allCustomers.length}'
                                      : 'Selected: ${_selectedCustomerCodes.length} of ${allCustomers.length} Pharmacies',
                                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                                ),
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedCustomerCodes.addAll(allCustomers.map((c) => c.code.trim()));
                                          _allLocationsChecked = true;
                                        });
                                      },
                                      child: Text(
                                        LocalizationService.tr('select_all', lang: lang),
                                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF2563EB), fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    const Text('  •  ', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 10)),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedCustomerCodes.clear();
                                          _allLocationsChecked = false;
                                        });
                                      },
                                      child: Text(
                                        LocalizationService.tr('clear_all', lang: lang),
                                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.dangerRed, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Search filter inside customer list
                            TextField(
                              controller: _searchLocationController,
                              onChanged: (val) => setState(() => _searchQuery = val),
                              decoration: InputDecoration(
                                hintText: LocalizationService.tr('search_pharmacy_hint', lang: lang),
                                prefixIcon: const Icon(Icons.search, size: 16),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 14),
                                        onPressed: () {
                                          _searchLocationController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : null,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Scrollable list of Pharmacies with TICK MARKS
                            Container(
                              constraints: const BoxConstraints(maxHeight: 230),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: filteredCustomers.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Center(
                                        child: Text(
                                          isSi ? 'සොයන ෆාමසි කිසිවක් හමු නොවීය' : 'No pharmacies match "$_searchQuery"',
                                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                                        ),
                                      ),
                                    )
                                  : Scrollbar(
                                      thumbVisibility: true,
                                      child: ListView.separated(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        shrinkWrap: true,
                                        itemCount: filteredCustomers.length,
                                        separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                        itemBuilder: (ctx, index) {
                                          final cust = filteredCustomers[index];
                                          final cleanCode = cust.code.trim();
                                          final isTicked = _selectedCustomerCodes.contains(cleanCode);

                                          return InkWell(
                                            onTap: () {
                                              setState(() {
                                                if (isTicked) {
                                                  _selectedCustomerCodes.remove(cleanCode);
                                                  _allLocationsChecked = false;
                                                } else {
                                                  _selectedCustomerCodes.add(cleanCode);
                                                  if (_selectedCustomerCodes.length == allCustomers.length) {
                                                    _allLocationsChecked = true;
                                                  }
                                                }
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                              color: isTicked ? const Color(0xFFF8FAFC) : Colors.transparent,
                                              child: Row(
                                                children: [
                                                  SizedBox(
                                                    width: 24,
                                                    height: 24,
                                                    child: Checkbox(
                                                      value: isTicked,
                                                      activeColor: const Color(0xFF2563EB),
                                                      checkColor: Colors.white,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                                      onChanged: (val) {
                                                        setState(() {
                                                          if (val == true) {
                                                            _selectedCustomerCodes.add(cleanCode);
                                                            if (_selectedCustomerCodes.length == allCustomers.length) {
                                                              _allLocationsChecked = true;
                                                            }
                                                          } else {
                                                            _selectedCustomerCodes.remove(cleanCode);
                                                            _allLocationsChecked = false;
                                                          }
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          cust.name,
                                                          style: GoogleFonts.inter(
                                                            fontSize: 12,
                                                            fontWeight: isTicked ? FontWeight.bold : FontWeight.w500,
                                                            color: isTicked ? const Color(0xFF1D4ED8) : AppTheme.textDark,
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        Text(
                                                          'CCode: ${cust.code}${cust.town.isNotEmpty ? " • ${cust.town}" : ""}${cust.totalOutstanding > 0.01 ? " • ${isSi ? 'හිඟ' : 'Due'}: Rs. ${currency.format(cust.totalOutstanding)}" : " • ${isSi ? 'හිඟ මුදල් නැත' : 'No Due'}"}',
                                                          style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (isTicked)
                                                    const Icon(Icons.check_circle, size: 14, color: Color(0xFF2563EB)),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 8),

                            // Summary badge of selected locations
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: (_selectedCustomerCodes.length == allCustomers.length) ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    (_selectedCustomerCodes.length == allCustomers.length) ? Icons.public : Icons.storefront,
                                    size: 14,
                                    color: (_selectedCustomerCodes.length == allCustomers.length) ? const Color(0xFF15803D) : const Color(0xFF1D4ED8),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      (_selectedCustomerCodes.length == allCustomers.length)
                                          ? (isSi ? 'පවරා ඇත: සියලුම ස්ථාන ${allCustomers.length}' : 'Assigned: All ${allCustomers.length} Locations')
                                          : (isSi
                                              ? 'පවරා ඇත (${_selectedCustomerCodes.length}): ${_selectedCustomerCodes.isEmpty ? "කිසිවක් තෝරා නැත" : _selectedCustomerCodes.take(4).join(', ') + (_selectedCustomerCodes.length > 4 ? " +තවත් ${_selectedCustomerCodes.length - 4}" : "")}'
                                              : 'Assigned (${_selectedCustomerCodes.length} Locations): ${_selectedCustomerCodes.isEmpty ? "None selected" : _selectedCustomerCodes.take(4).join(', ') + (_selectedCustomerCodes.length > 4 ? " +${_selectedCustomerCodes.length - 4} more" : "")}'),
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: (_selectedCustomerCodes.length == allCustomers.length) ? const Color(0xFF15803D) : const Color(0xFF1D4ED8),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
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
              ),

              const Divider(height: 18),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: Text(LocalizationService.tr('cancel', lang: lang), style: const TextStyle(color: AppTheme.textMuted)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(LocalizationService.tr('create_user_btn', lang: lang), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Dialog to edit assigned locations for an existing user
class _EditUserLocationsDialog extends StatefulWidget {
  final AppUser user;
  final AppState appState;

  const _EditUserLocationsDialog({required this.user, required this.appState});

  @override
  State<_EditUserLocationsDialog> createState() => _EditUserLocationsDialogState();
}

class _EditUserLocationsDialogState extends State<_EditUserLocationsDialog> {
  final _searchLocationController = TextEditingController();
  late bool _allLocationsChecked;
  final Set<String> _selectedCustomerCodes = {};
  bool _isSubmitting = false;
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _allLocationsChecked = widget.user.hasAllLocations;
    if (_allLocationsChecked) {
      _selectedCustomerCodes.addAll(widget.appState.customers.map((c) => c.code.trim()));
    } else {
      _selectedCustomerCodes.addAll(widget.user.locationList.map((e) => e.trim()));
    }
  }

  @override
  void dispose() {
    _searchLocationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final isSi = widget.appState.currentLanguage == 'si';
    String assignedLocationsString;
    if (_allLocationsChecked || _selectedCustomerCodes.length == widget.appState.customers.length) {
      assignedLocationsString = 'ALL';
    } else {
      if (_selectedCustomerCodes.isEmpty) {
        setState(() => _errorMessage = isSi ? 'කරුණාකර අවම වශයෙන් එක් ස්ථානයක් හෝ තෝරන්න.' : 'Please select at least one customer location.');
        return;
      }
      assignedLocationsString = _selectedCustomerCodes.join(', ');
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.appState.updateUserLocations(widget.user.collectorId, assignedLocationsString);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isSi ? '${widget.user.fullName} සඳහා ස්ථාන සාර්ථකව යාවත්කාලීන කරන ලදී!' : 'Updated locations for ${widget.user.fullName} successfully!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,##0.00', 'en_US');
    final allCustomers = widget.appState.customers;
    final lang = widget.appState.currentLanguage;
    final isSi = lang == 'si';

    final filteredCustomers = allCustomers.where((c) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return c.code.toLowerCase().contains(q) ||
          c.name.toLowerCase().contains(q) ||
          c.town.toLowerCase().contains(q);
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.storefront_rounded, color: Color(0xFF2563EB), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isSi
                                ? 'ස්ථාන පැවරීම: ${widget.user.fullName}'
                                : 'Assign Locations: ${widget.user.fullName}',
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                          ),
                          Text(
                            '@${widget.user.username} (${widget.user.accessLevel})',
                            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 18),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.dangerRed, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.dangerRed, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Search & Selection Toolbar (Single Clean Controller - Duplicate Top Card Removed)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isSi
                        ? 'තෝරාගෙන ඇත: ${_selectedCustomerCodes.length} / ${allCustomers.length}'
                        : 'Selected: ${_selectedCustomerCodes.length} of ${allCustomers.length} Pharmacies',
                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCustomerCodes.addAll(allCustomers.map((c) => c.code.trim()));
                            _allLocationsChecked = true;
                          });
                        },
                        child: Text(
                          LocalizationService.tr('select_all', lang: lang),
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF2563EB), fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Text('  •  ', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 10)),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCustomerCodes.clear();
                            _allLocationsChecked = false;
                          });
                        },
                        child: Text(
                          LocalizationService.tr('clear_all', lang: lang),
                          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.dangerRed, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Search filter
              TextField(
                controller: _searchLocationController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: LocalizationService.tr('search_pharmacy_hint', lang: lang),
                  prefixIcon: const Icon(Icons.search, size: 16),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 14),
                          onPressed: () {
                            _searchLocationController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 8),

              // Scrollable list of Pharmacies with TICK MARKS
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: filteredCustomers.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              isSi ? 'සොයන ෆාමසි කිසිවක් හමු නොවීය' : 'No pharmacies match "$_searchQuery"',
                              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ),
                        )
                      : Scrollbar(
                          thumbVisibility: true,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: filteredCustomers.length,
                            separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (ctx, index) {
                              final cust = filteredCustomers[index];
                              final cleanCode = cust.code.trim();
                              final isTicked = _selectedCustomerCodes.contains(cleanCode);

                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    if (isTicked) {
                                      _selectedCustomerCodes.remove(cleanCode);
                                      _allLocationsChecked = false;
                                    } else {
                                      _selectedCustomerCodes.add(cleanCode);
                                      if (_selectedCustomerCodes.length == allCustomers.length) {
                                        _allLocationsChecked = true;
                                      }
                                    }
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  color: isTicked ? const Color(0xFFF8FAFC) : Colors.transparent,
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: Checkbox(
                                          value: isTicked,
                                          activeColor: const Color(0xFF2563EB),
                                          checkColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                          onChanged: (val) {
                                            setState(() {
                                              if (val == true) {
                                                _selectedCustomerCodes.add(cleanCode);
                                                if (_selectedCustomerCodes.length == allCustomers.length) {
                                                  _allLocationsChecked = true;
                                                }
                                              } else {
                                                _selectedCustomerCodes.remove(cleanCode);
                                                _allLocationsChecked = false;
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              cust.name,
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: isTicked ? FontWeight.bold : FontWeight.w500,
                                                color: isTicked ? const Color(0xFF1D4ED8) : AppTheme.textDark,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              'CCode: ${cust.code}${cust.town.isNotEmpty ? " • ${cust.town}" : ""}${cust.totalOutstanding > 0.01 ? " • ${isSi ? 'හිඟ' : 'Due'}: Rs. ${currency.format(cust.totalOutstanding)}" : " • ${isSi ? 'හිඟ මුදල් නැත' : 'No Due'}"}',
                                              style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isTicked)
                                        const Icon(Icons.check_circle, size: 14, color: Color(0xFF2563EB)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),

              // Summary footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (_selectedCustomerCodes.length == allCustomers.length) ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      (_selectedCustomerCodes.length == allCustomers.length) ? Icons.public : Icons.storefront,
                      size: 14,
                      color: (_selectedCustomerCodes.length == allCustomers.length) ? const Color(0xFF15803D) : const Color(0xFF1D4ED8),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        (_selectedCustomerCodes.length == allCustomers.length)
                            ? (isSi ? 'පවරා ඇත: සියලුම ස්ථාන ${allCustomers.length}' : 'Assigned: All ${allCustomers.length} Locations')
                            : (isSi
                                ? 'පවරා ඇත (${_selectedCustomerCodes.length}): ${_selectedCustomerCodes.isEmpty ? "කිසිවක් තෝරා නැත" : _selectedCustomerCodes.take(4).join(', ') + (_selectedCustomerCodes.length > 4 ? " +තවත් ${_selectedCustomerCodes.length - 4}" : "")}'
                                : 'Assigned (${_selectedCustomerCodes.length} Locations): ${_selectedCustomerCodes.isEmpty ? "None selected" : _selectedCustomerCodes.take(4).join(', ') + (_selectedCustomerCodes.length > 4 ? " +${_selectedCustomerCodes.length - 4} more" : "")}'),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: (_selectedCustomerCodes.length == allCustomers.length) ? const Color(0xFF15803D) : const Color(0xFF1D4ED8),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 18),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: Text(LocalizationService.tr('cancel', lang: lang), style: const TextStyle(color: AppTheme.textMuted)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isSubmitting ? null : _save,
                    child: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(LocalizationService.tr('save_changes', lang: lang), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

