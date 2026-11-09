import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/app_user.dart';
import '../../models/customer.dart';
import '../../theme/app_theme.dart';
import '../../services/localization_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchFilter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final lang = appState.currentLanguage;
    final isSi = lang == 'si';

    final allUsers = appState.allUsers;
    final filteredUsers = _searchFilter.trim().isEmpty
        ? allUsers
        : allUsers.where((u) {
            final q = _searchFilter.toLowerCase().trim();
            return u.fullName.toLowerCase().contains(q) ||
                u.username.toLowerCase().contains(q) ||
                u.collectorId.toLowerCase().contains(q) ||
                u.accessLevel.toLowerCase().contains(q);
          }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          LocalizationService.tr('user_mgmt', lang: lang),
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: isSi ? 'යාවත්කාලීන කරන්න' : 'Refresh user list',
            onPressed: () => appState.fetchAllUsers(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Header Card with User count & Add button
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.manage_accounts_rounded, color: Color(0xFF4F46E5), size: 26),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isSi ? 'පරිශීලක කළමනාකරණය' : 'System Users & Access',
                                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                                  ),
                                  Text(
                                    isSi
                                        ? 'ලියාපදිංචි පරිශීලකයින් ${allUsers.length} ක් පද්ධතියේ ඇත'
                                        : '${allUsers.length} total registered accounts',
                                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                            label: Text(
                              LocalizationService.tr('add_new_user', lang: lang),
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Search Bar
                  TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchFilter = val),
                    decoration: InputDecoration(
                      hintText: isSi ? 'නම, ID හෝ username මඟින් සොයන්න...' : 'Search by name, ID or username...',
                      hintStyle: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
                      prefixIcon: const Icon(Icons.search, color: AppTheme.primaryBlue, size: 20),
                      suffixIcon: _searchFilter.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchFilter = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Users List
                  if (appState.isLoadingUsers)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                      ),
                    )
                  else if (filteredUsers.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.person_search_rounded, size: 40, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 8),
                            Text(
                              isSi ? 'පරිශීලකයින් කිසිවෙක් හමු නොවීය.' : 'No users found matching search.',
                              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredUsers.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final user = filteredUsers[index];
                        return _buildUserTile(context, user, appState);
                      },
                    ),
                ],
              ),
            ),
          ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: user.isActive ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 19,
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
                              fontSize: 13.5,
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
                onTap: () => _confirmToggleUser(context, user, appState),
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
          const SizedBox(height: 10),
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
      assignedLocationsString = _selectedCustomerCodes.join(',');
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.appState.createNewUser(
        collectorId: collectorId,
        fullName: fullName,
        username: username,
        password: password,
        accessLevel: _accessLevel,
        phone: _phoneController.text.trim(),
        assignedLocations: assignedLocationsString,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isSi ? 'පරිශීලකයා සාර්ථකව ලියාපදිංචි කරන ලදී!' : 'User created successfully!'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.appState.currentLanguage;
    final isSi = lang == 'si';
    final customers = widget.appState.customers;

    final filteredCustomers = _searchQuery.isEmpty
        ? customers
        : customers.where((c) =>
            c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            c.code.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            c.town.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 700),
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
                        child: const Icon(Icons.person_add_rounded, color: Color(0xFF4F46E5), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        LocalizationService.tr('add_new_user', lang: lang),
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF94A3B8)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF991B1B)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Full Name
                      Text(isSi ? 'සම්පූර්ණ නම *' : 'Full Name *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _fullNameController,
                        decoration: InputDecoration(
                          hintText: isSi ? 'උදා. කමල් පෙරේරා' : 'e.g. Kamal Perera',
                          hintStyle: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                          prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Collector ID & Role Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(isSi ? 'පරිශීලක ID (Collector Code)' : 'Collector / User ID', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: _collectorIdController,
                                  decoration: InputDecoration(
                                    hintText: isSi ? 'හිස්ව තැබුවහොත් ස්වයංක්‍රීයව සෑදේ' : 'Auto if left blank',
                                    hintStyle: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(isSi ? 'භූමිකාව (Role / Access) *' : 'Access Level *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                DropdownButtonFormField<String>(
                                  value: _accessLevel,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  items: ['Collector', 'Cashier', 'Manager', 'Admin']
                                      .map((r) => DropdownMenuItem(value: r, child: Text(r, style: GoogleFonts.inter(fontSize: 13))))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _accessLevel = val);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Username & Password Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(isSi ? 'පරිශීලක නාමය (Username) *' : 'Username *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: _usernameController,
                                  decoration: InputDecoration(
                                    hintText: 'e.g. kamalp',
                                    hintStyle: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                                    prefixIcon: const Icon(Icons.person_outline, size: 18),
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(isSi ? 'මුරපදය (Password) *' : 'Password *', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    hintText: '••••••••',
                                    isDense: true,
                                    prefixIcon: const Icon(Icons.lock_outline, size: 18),
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 18),
                                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                    ),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Phone Number
                      Text(isSi ? 'දුරකථන අංකය' : 'Phone Number (Optional)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: '077 123 4567',
                          hintStyle: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
                          prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Assigned Customer Locations Section
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.storefront_rounded, size: 18, color: Color(0xFF4F46E5)),
                                    const SizedBox(width: 6),
                                    Text(
                                      isSi ? 'පවරන ලද ෆාමසි / ස්ථාන' : 'Assigned Locations',
                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                                    ),
                                  ],
                                ),
                                Switch(
                                  value: _allLocationsChecked,
                                  activeColor: const Color(0xFF4F46E5),
                                  onChanged: (val) {
                                    setState(() {
                                      _allLocationsChecked = val;
                                      if (val) {
                                        _selectedCustomerCodes.addAll(customers.map((c) => c.code.trim()));
                                      } else {
                                        _selectedCustomerCodes.clear();
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                            Text(
                              _allLocationsChecked
                                  ? (isSi ? 'සියලුම ෆාමසි වෙත පිවිසීමට අවසර ඇත (${customers.length})' : 'All ${customers.length} customer locations assigned')
                                  : (isSi ? 'තෝරාගත් ෆාමසි ${_selectedCustomerCodes.length} ක් පමණි' : '${_selectedCustomerCodes.length} locations selected'),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: _allLocationsChecked ? const Color(0xFF16A34A) : const Color(0xFF4F46E5),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (!_allLocationsChecked) ...[
                              const SizedBox(height: 10),
                              TextField(
                                controller: _searchLocationController,
                                onChanged: (val) => setState(() => _searchQuery = val),
                                decoration: InputDecoration(
                                  hintText: isSi ? 'ෆාමසි නම හෝ නගරය මඟින් සොයන්න...' : 'Filter pharmacies by name / town...',
                                  hintStyle: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                                  prefixIcon: const Icon(Icons.search, size: 16),
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 160,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: ListView.builder(
                                  itemCount: filteredCustomers.length,
                                  itemBuilder: (context, i) {
                                    final cust = filteredCustomers[i];
                                    final isSelected = _selectedCustomerCodes.contains(cust.code.trim());
                                    return CheckboxListTile(
                                      value: isSelected,
                                      dense: true,
                                      visualDensity: VisualDensity.compact,
                                      title: Text(cust.name, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                                      subtitle: Text('${cust.code} • ${cust.town}', style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted)),
                                      activeColor: const Color(0xFF4F46E5),
                                      onChanged: (checked) {
                                        setState(() {
                                          if (checked == true) {
                                            _selectedCustomerCodes.add(cust.code.trim());
                                          } else {
                                            _selectedCustomerCodes.remove(cust.code.trim());
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: Text(LocalizationService.tr('cancel', lang: lang)),
                  ),
                  const SizedBox(width: 8),
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

// Dialog to edit existing user's assigned customer locations
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
      assignedLocationsString = _selectedCustomerCodes.join(',');
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.appState.updateUserLocations(
        widget.user.collectorId,
        assignedLocationsString,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isSi ? 'ස්ථාන පැවරීම සාර්ථකව යාවත්කාලීන කරන ලදී!' : 'Locations updated successfully!'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.appState.currentLanguage;
    final isSi = lang == 'si';
    final customers = widget.appState.customers;

    final filteredCustomers = _searchQuery.isEmpty
        ? customers
        : customers.where((c) =>
            c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            c.code.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            c.town.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
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
                        child: const Icon(Icons.edit_location_alt_rounded, color: Color(0xFF4F46E5), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isSi ? 'ස්ථාන පැවරීම සංස්කරණය' : 'Edit Assigned Locations',
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                          ),
                          Text(
                            '${widget.user.fullName} (${widget.user.collectorId})',
                            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF94A3B8)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF991B1B)),
                  ),
                ),
              ],

              // All Locations Toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSi ? 'සියලුම ස්ථාන (All Locations)' : 'Assign All Locations',
                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          isSi ? 'පද්ධතියේ ඇති සියලුම ෆාමසි (${customers.length})' : 'All ${customers.length} registered customers',
                          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                    Switch(
                      value: _allLocationsChecked,
                      activeColor: const Color(0xFF4F46E5),
                      onChanged: (val) {
                        setState(() {
                          _allLocationsChecked = val;
                          if (val) {
                            _selectedCustomerCodes.addAll(customers.map((c) => c.code.trim()));
                          } else {
                            _selectedCustomerCodes.clear();
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              if (!_allLocationsChecked) ...[
                TextField(
                  controller: _searchLocationController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: isSi ? 'ෆාමසි නම හෝ නගරය මඟින් සොයන්න...' : 'Filter pharmacies...',
                    hintStyle: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                    prefixIcon: const Icon(Icons.search, size: 16),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: ListView.builder(
                      itemCount: filteredCustomers.length,
                      itemBuilder: (context, i) {
                        final cust = filteredCustomers[i];
                        final isSelected = _selectedCustomerCodes.contains(cust.code.trim());
                        return CheckboxListTile(
                          value: isSelected,
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          title: Text(cust.name, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                          subtitle: Text('${cust.code} • ${cust.town}', style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted)),
                          activeColor: const Color(0xFF4F46E5),
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _selectedCustomerCodes.add(cust.code.trim());
                              } else {
                                _selectedCustomerCodes.remove(cust.code.trim());
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),
              ] else
                const Spacer(),

              const SizedBox(height: 16),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: Text(LocalizationService.tr('cancel', lang: lang)),
                  ),
                  const SizedBox(width: 8),
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
