import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/receipt.dart';
import '../../providers/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/collector_route_map_view.dart';

enum DateFilterPreset { today, yesterday, thisWeek, all, custom }

class CollectorVisitSummary {
  final String collectorId;
  final String collectorName;
  final List<Receipt> receipts;
  final double totalAmount;

  CollectorVisitSummary({
    required this.collectorId,
    required this.collectorName,
    required this.receipts,
    required this.totalAmount,
  });
}

class VisitedLocationsScreen extends StatefulWidget {
  final String? initialCollectorId;
  const VisitedLocationsScreen({super.key, this.initialCollectorId});

  @override
  State<VisitedLocationsScreen> createState() => _VisitedLocationsScreenState();
}

class _VisitedLocationsScreenState extends State<VisitedLocationsScreen> {
  DateFilterPreset _preset = DateFilterPreset.all;
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now().add(const Duration(days: 1)),
  );

  String? _selectedCollectorId;
  int? _selectedWaypointIndex;

  @override
  void initState() {
    super.initState();
    _selectedCollectorId = widget.initialCollectorId;
    _setPreset(DateFilterPreset.today);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppState>(context, listen: false).fetchRealtimeReceipts();
    });
  }

  void _setPreset(DateFilterPreset preset) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (preset) {
      case DateFilterPreset.today:
        start = DateTime(now.year, now.month, now.day, 0, 0, 0);
        break;
      case DateFilterPreset.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        start = DateTime(yesterday.year, yesterday.month, yesterday.day, 0, 0, 0);
        end = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
        break;
      case DateFilterPreset.thisWeek:
        start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        break;
      case DateFilterPreset.all:
        start = DateTime(2025, 1, 1);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case DateFilterPreset.custom:
        return;
    }

    setState(() {
      _preset = preset;
      _dateRange = DateTimeRange(start: start, end: end);
    });
  }

  Future<void> _selectCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F1E36),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _preset = DateFilterPreset.custom;
        _dateRange = DateTimeRange(
          start: DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0),
          end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
        );
      });
    }
  }

  // Known town coordinates in Sri Lanka to place markers accurately when available
  static const Map<String, List<double>> _townCoordinates = {
    'matale': [7.4675, 80.6234],
    'akurana': [7.3667, 80.6167],
    'kandy': [7.2906, 80.6337],
    'peradeniya': [7.2600, 80.5950],
    'chilaw': [7.5758, 79.7953],
    'ja-ela': [7.0744, 79.8913],
    'ja ela': [7.0744, 79.8913],
    'colombo': [6.9271, 79.8612],
    'galle': [6.0535, 80.2210],
    'kurunegala': [7.4863, 80.3623],
    'katugastota': [7.3200, 80.6200],
    'gampaha': [7.0840, 79.9942],
    'negombo': [7.2008, 79.8736],
  };

  VisitedWaypoint _resolveWaypoint(Receipt receipt, int sequence, int index, int totalCount) {
    double lat = receipt.latitude;
    double lng = receipt.longitude;
    final bool hasGenuineGps = (lat != 0.0 && lng != 0.0) &&
        !((lat - 6.927079).abs() < 0.0001 && (lng - 79.861244).abs() < 0.0001);

    if (!hasGenuineGps) {
      // Check if customer name, address, or branch mentions a known town
      final combinedText = '${receipt.customerName} ${receipt.customerAddress} ${receipt.branch ?? ''} ${receipt.locationAddress}'.toLowerCase();
      
      List<double>? townCoords;
      for (final entry in _townCoordinates.entries) {
        if (combinedText.contains(entry.key)) {
          townCoords = entry.value;
          break;
        }
      }

      if (townCoords != null) {
        lat = townCoords[0];
        lng = townCoords[1];
      } else if (lat == 0 || lng == 0) {
        // Default fallback to Sri Lanka central hub
        lat = 7.4675;
        lng = 80.6234;
      }

      // Spread approximate town waypoints so stops don't stack directly on top of each other
      if (totalCount > 1) {
        final spreadFactor = 0.0035;
        lat += (index * spreadFactor * 0.7);
        lng += math.sin(index * 1.2) * spreadFactor;
      }
    }

    return VisitedWaypoint(
      sequence: sequence,
      receipt: receipt,
      lat: lat,
      lng: lng,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final lang = appState.currentLanguage;
    final isSi = lang == 'si';
    final currency = NumberFormat('#,##0.00', 'en_US');
    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('hh:mm a');

    // 1. Filter receipts by selected Date Range
    final filteredReceipts = appState.receipts.where((r) {
      return r.createdAt.isAfter(_dateRange.start.subtract(const Duration(seconds: 1))) &&
          r.createdAt.isBefore(_dateRange.end.add(const Duration(seconds: 1)));
    }).toList();

    // 2. Group by Collector
    final Map<String, List<Receipt>> collectorMap = {};
    for (final r in filteredReceipts) {
      final key = r.collectorId.isNotEmpty ? r.collectorId : 'UNKNOWN';
      collectorMap.putIfAbsent(key, () => []).add(r);
    }

    final List<CollectorVisitSummary> collectorSummaries = [];
    collectorMap.forEach((colId, list) {
      final colName = list.first.collectorName.isNotEmpty
          ? list.first.collectorName
          : colId;
      final total = list.fold<double>(0.0, (sum, r) => sum + r.totalAmount);
      collectorSummaries.add(
        CollectorVisitSummary(
          collectorId: colId,
          collectorName: colName,
          receipts: list,
          totalAmount: total,
        ),
      );
    });

    // Sort collectors by receipt count descending
    collectorSummaries.sort((a, b) => b.receipts.length.compareTo(a.receipts.length));

    // Auto-select first collector if none selected or if selected collector has no data
    if (_selectedCollectorId == null || !collectorMap.containsKey(_selectedCollectorId)) {
      if (collectorSummaries.isNotEmpty) {
        _selectedCollectorId = collectorSummaries.first.collectorId;
      } else {
        _selectedCollectorId = null;
      }
    }

    // Active selected collector's receipts sorted strictly by createdAt ascending (Chronological visit order)
    List<Receipt> activeCollectorReceipts = [];
    if (_selectedCollectorId != null && collectorMap.containsKey(_selectedCollectorId)) {
      activeCollectorReceipts = List.from(collectorMap[_selectedCollectorId]!);
      activeCollectorReceipts.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    // Map receipts to sequential waypoints (1, 2, 3...)
    final List<VisitedWaypoint> waypoints = [];
    for (int i = 0; i < activeCollectorReceipts.length; i++) {
      waypoints.add(_resolveWaypoint(
        activeCollectorReceipts[i],
        i + 1, // Stop 1, Stop 2, etc.
        i,
        activeCollectorReceipts.length,
      ));
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
              isSi ? 'පිවිසි ස්ථාන නිරීක්ෂණය' : 'View Visited Locations',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              isSi ? 'ක්ෂේත්‍ර එකතුකරන්නන්ගේ ගමන් මාර්ගය' : 'Collector Route & Billing Stops',
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: isSi ? 'නැවත පූරණය කරන්න' : 'Refresh Data',
            onPressed: () {
              appState.fetchRealtimeReceipts();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. TOP DATE RANGE SELECTOR CARD
                _buildDateRangeFilterCard(isSi, dateFormat),
                const SizedBox(height: 16),

                // 2. CASH COLLECTORS LIST
                _buildCollectorSelectorSection(
                  isSi: isSi,
                  summaries: collectorSummaries,
                  currency: currency,
                ),
                const SizedBox(height: 16),

                // 3. MAP VIEW & ROUTE TIMELINE (If collector selected)
                if (_selectedCollectorId != null && waypoints.isNotEmpty) ...[
                  // Route Map
                  SizedBox(
                    height: 380,
                    child: CollectorRouteMapView(
                      waypoints: waypoints,
                      selectedIndex: _selectedWaypointIndex,
                      language: lang,
                      onSelectWaypoint: (idx) {
                        setState(() {
                          _selectedWaypointIndex = idx;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Route Sequence Timeline Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F1E36).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.timeline, color: Color(0xFF0F1E36), size: 18),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isSi ? 'පිවිසි ස්ථාන අනුපිළිවෙල (Timeline)' : 'Chronological Visit Sequence',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${waypoints.length} ${isSi ? 'ස්ථාන' : 'Stops'}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Timeline Stops Cards
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: waypoints.length,
                    separatorBuilder: (_, __) => _buildTimelineConnector(),
                    itemBuilder: (context, idx) {
                      final wp = waypoints[idx];
                      final isSelected = _selectedWaypointIndex == idx;
                      return _buildWaypointCard(
                        wp: wp,
                        isSi: isSi,
                        currency: currency,
                        timeFormat: timeFormat,
                        dateFormat: dateFormat,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                            _selectedWaypointIndex = idx;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ] else if (collectorSummaries.isEmpty) ...[
                  // Empty State when no collectors in range
                  _buildNoCollectorsCard(isSi),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 1. Date Range Filter Card
  Widget _buildDateRangeFilterCard(bool isSi, DateFormat dateFormat) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.date_range, color: Color(0xFF0F1E36), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    isSi ? 'දින පරාසය තෝරන්න' : 'Select Date Range',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                  ),
                ],
              ),
              InkWell(
                onTap: _selectCustomDateRange,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _preset == DateFilterPreset.custom
                        ? const Color(0xFF0F1E36)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_calendar,
                        size: 14,
                        color: _preset == DateFilterPreset.custom ? Colors.white : const Color(0xFF475569),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isSi ? 'දින තෝරන්න' : 'Custom',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _preset == DateFilterPreset.custom ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Preset Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPresetChip(
                  label: isSi ? 'සියලු දින' : 'All Dates',
                  preset: DateFilterPreset.all,
                ),
                const SizedBox(width: 8),
                _buildPresetChip(
                  label: isSi ? 'අද' : 'Today',
                  preset: DateFilterPreset.today,
                ),
                const SizedBox(width: 8),
                _buildPresetChip(
                  label: isSi ? 'ඊයේ' : 'Yesterday',
                  preset: DateFilterPreset.yesterday,
                ),
                const SizedBox(width: 8),
                _buildPresetChip(
                  label: isSi ? 'මෙම සතිය' : 'This Week',
                  preset: DateFilterPreset.thisWeek,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Active Date Range Label Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_available, color: Color(0xFF2563EB), size: 16),
                const SizedBox(width: 8),
                Text(
                  isSi ? 'තෝරාගත් දින:' : 'Active Range:',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${dateFormat.format(_dateRange.start)}  ➔  ${dateFormat.format(_dateRange.end)}',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip({required String label, required DateFilterPreset preset}) {
    final isSelected = _preset == preset;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _setPreset(preset),
      selectedColor: const Color(0xFF0F1E36),
      labelStyle: GoogleFonts.inter(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : const Color(0xFF475569),
      ),
      backgroundColor: const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? const Color(0xFF0F1E36) : const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
  }

  // 2. Collector Selector Section
  Widget _buildCollectorSelectorSection({
    required bool isSi,
    required List<CollectorVisitSummary> summaries,
    required NumberFormat currency,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.badge_outlined, color: Color(0xFF0F1E36), size: 18),
                const SizedBox(width: 8),
                Text(
                  isSi ? 'බිල්පත් කළ එකතුකරන්නන්ගේ ලැයිස්තුව' : 'Cash Collectors Active in Range',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${summaries.length} ${isSi ? 'දෙනෙක්' : 'Collectors'}',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF7C3AED)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (summaries.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Text(
                isSi
                    ? 'මෙම දින පරාසය තුළ බිල්පත් කළ මුදල් එකතුකරන්නන් නොමැත.'
                    : 'No cash collectors issued bills during the selected date range.',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
              ),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: summaries.map((summary) {
                final isSelected = summary.collectorId == _selectedCollectorId;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCollectorId = summary.collectorId;
                        _selectedWaypointIndex = null;
                      });
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 230,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF0F1E36) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFFCBD5E1),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected
                                ? const Color(0xFF0F1E36).withOpacity(0.2)
                                : Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: isSelected
                                    ? const Color(0xFF38BDF8)
                                    : const Color(0xFF8B5CF6).withOpacity(0.15),
                                child: Text(
                                  summary.collectorName.isNotEmpty
                                      ? summary.collectorName[0].toUpperCase()
                                      : 'C',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? const Color(0xFF0F1E36) : const Color(0xFF6D28D9),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      summary.collectorName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      summary.collectorId,
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: isSelected ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle, color: Color(0xFF38BDF8), size: 18),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withOpacity(0.12)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${summary.receipts.length} ${isSi ? 'ස්ථාන' : 'Stops'}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF2563EB),
                                  ),
                                ),
                                Text(
                                  'Rs. ${currency.format(summary.totalAmount)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  // 3. Chronological Waypoint Card
  Widget _buildWaypointCard({
    required VisitedWaypoint wp,
    required bool isSi,
    required NumberFormat currency,
    required DateFormat timeFormat,
    required DateFormat dateFormat,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final r = wp.receipt;
    final isFirst = wp.sequence == 1;
    final isCash = r.paymentMethod == PaymentMethod.cash;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stop Number Badge (1, 2, 3...)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isFirst ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isFirst ? const Color(0xFF16A34A) : const Color(0xFF2563EB)).withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${wp.sequence}',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Stop Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          r.customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isCash
                              ? const Color(0xFF10B981).withOpacity(0.12)
                              : const Color(0xFF38BDF8).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isCash ? (isSi ? 'මුදල්' : 'Cash') : (isSi ? 'චෙක්පත්' : 'Cheque'),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isCash ? const Color(0xFF059669) : const Color(0xFF0284C7),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF64748B)),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          r.customerAddress.isNotEmpty ? r.customerAddress : (r.locationAddress.isNotEmpty ? r.locationAddress : 'Location Recorded'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.receipt, size: 12, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Text(
                            r.manualReceiptNo,
                            style: GoogleFonts.robotoMono(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeFormat.format(r.createdAt),
                            style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                      Text(
                        'Rs. ${currency.format(r.totalAmount)}',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F1E36),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineConnector() {
    return Padding(
      padding: const EdgeInsets.only(left: 30),
      child: Container(
        width: 2,
        height: 14,
        color: const Color(0xFFCBD5E1),
      ),
    );
  }

  Widget _buildNoCollectorsCard(bool isSi) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_search_outlined, size: 40, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          Text(
            isSi ? 'දත්ත හමු නොවීය' : 'No Activity in Selected Range',
            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
          ),
          const SizedBox(height: 6),
          Text(
            isSi
                ? 'තෝරාගත් දින පරාසය තුළ බිල්පත් කළ එකතුකරන්නන් නැත. "සියලු දින" තෝරා නැවත පරීක්ෂා කරන්න.'
                : 'No cash collectors issued receipts during this window. Select "All Dates" to view recorded trips.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F1E36),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _setPreset(DateFilterPreset.all),
            icon: const Icon(Icons.history, size: 16),
            label: Text(
              isSi ? 'සියලු දින පෙන්වන්න' : 'Show All Dates',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
