import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import 'visited_locations_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _filterTodayOnly = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      appState.fetchRealtimeReceipts();
      appState.fetchRealtimeCustomers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final lang = appState.currentLanguage;
    final isSi = lang == 'si';
    final currency = NumberFormat('#,##0.00', 'en_US');

    final now = DateTime.now();

    // Filter real receipts based on toggle (Today vs All-time)
    final allReceipts = appState.receipts;
    final activeReceipts = _filterTodayOnly
        ? allReceipts.where((r) {
            return r.createdAt.year == now.year &&
                r.createdAt.month == now.month &&
                r.createdAt.day == now.day;
          }).toList()
        : allReceipts;

    final totalCollected = activeReceipts.fold<double>(0.0, (sum, r) => sum + r.totalAmount);

    // Active collectors set for the selected timeframe
    final collectorIds = <String>{};
    for (final r in activeReceipts) {
      if (r.collectorId.isNotEmpty) collectorIds.add(r.collectorId);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1E36),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSi ? 'දළ විශ්ලේෂණ පුවරුව' : 'Operations Dashboard',
              style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              isSi ? 'සජීවී ක්ෂේත්‍ර දත්ත සහ නිරීක්ෂණ' : 'Live Field Progress & Collector Monitoring',
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: isSi ? 'නැවත පූරණය කරන්න' : 'Refresh Realtime Data',
            onPressed: () {
              appState.fetchRealtimeReceipts();
              appState.fetchRealtimeCustomers();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // -------------------------------------------------------------
                // 1ST BUTTON / PRIMARY FEATURE CARD: "VIEW VISITED LOCATIONS"
                // (User requirement: "eka athule udin hadanna 1st button eka widiyata View Visited Locations kiyala")
                // -------------------------------------------------------------
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E3A8A).withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const VisitedLocationsScreen(),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                                  ),
                                  child: const Icon(
                                    Icons.map_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.touch_app, size: 14, color: Colors.white),
                                      const SizedBox(width: 4),
                                      Text(
                                        isSi ? 'විවෘත කරන්න' : 'Tap to View',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isSi ? 'පිවිසි ස්ථාන නිරීක්ෂණය' : 'View Visited Locations',
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isSi
                                  ? 'මුදල් එකතුකරන්නන් ගමන් කළ මාර්ගය, පිවිසි ස්ථාන අනුපිළිවෙල (1, 2, 3...) සහ බිල්පත් කළ දත්ත සිතියමෙන් බලන්න.'
                                  : 'Explore collector routes, sequence of visited places (1, 2, 3...) and detailed billing receipts on interactive map.',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                color: const Color(0xFFDBEAFE),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.timeline, color: Color(0xFF93C5FD), size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    isSi
                                        ? '${activeReceipts.length} ක් පිවිසි ස්ථාන සටහන්ව ඇත'
                                        : '${activeReceipts.length} Visited Stops Recorded',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.arrow_forward, color: Colors.white, size: 14),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // Quick Analytics / Summary Section Header with Filter
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isSi ? 'ක්ෂේත්‍ර එකතු කිරීමේ සාරාංශය' : 'Collection Overview',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                    // Today vs All Toggle
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => setState(() => _filterTodayOnly = true),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _filterTodayOnly ? const Color(0xFF0F1E36) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isSi ? 'අද දින' : 'Today',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _filterTodayOnly ? Colors.white : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => setState(() => _filterTodayOnly = false),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: !_filterTodayOnly ? const Color(0xFF0F1E36) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isSi ? 'සියලු දින' : 'All Time',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: !_filterTodayOnly ? Colors.white : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Stat Cards Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: isSi ? 'මුළු එකතු කිරීම' : 'Total Collected',
                        value: 'Rs. ${currency.format(totalCollected)}',
                        icon: Icons.payments,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        title: isSi ? 'නිකුත් කළ රිසිට්පත්' : 'Receipts Issued',
                        value: '${activeReceipts.length}',
                        icon: Icons.receipt_long,
                        color: const Color(0xFF0284C7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: isSi ? 'සක්‍රීය එකතුකරන්නන්' : 'Active Collectors',
                        value: '${collectorIds.isEmpty ? 0 : collectorIds.length}',
                        icon: Icons.people_alt,
                        color: const Color(0xFF8B5CF6),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        title: isSi ? 'පාරිභෝගිකයින්' : 'Customers',
                        value: '${appState.accessibleCustomers.length}',
                        icon: Icons.storefront,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
