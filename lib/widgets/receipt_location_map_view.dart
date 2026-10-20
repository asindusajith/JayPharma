import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/receipt.dart';
import '../theme/app_theme.dart';

class ReceiptLocationMapView extends StatefulWidget {
  final Receipt receipt;
  final String language;
  final VoidCallback onClose;
  final EdgeInsetsGeometry margin;

  const ReceiptLocationMapView({
    super.key,
    required this.receipt,
    required this.language,
    required this.onClose,
    this.margin = EdgeInsets.zero,
  });

  @override
  State<ReceiptLocationMapView> createState() => _ReceiptLocationMapViewState();
}

class _ReceiptLocationMapViewState extends State<ReceiptLocationMapView>
    with SingleTickerProviderStateMixin {
  int _zoom = 15;
  Offset _panOffset = Offset.zero;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: false);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 2.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutQuad),
    );
  }

  @override
  void didUpdateWidget(covariant ReceiptLocationMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.receipt.manualReceiptNo != widget.receipt.manualReceiptNo) {
      setState(() {
        _panOffset = Offset.zero;
        _zoom = 15;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // Fallback to Colombo / Sri Lanka if coordinates are missing/zero
  double get _lat => widget.receipt.latitude != 0.0 ? widget.receipt.latitude : 6.927079;
  double get _lng => widget.receipt.longitude != 0.0 ? widget.receipt.longitude : 79.861244;

  void _openInGoogleMaps() async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$_lat,$_lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _zoomIn() {
    if (_zoom < 18) {
      setState(() {
        _zoom++;
        _panOffset = Offset.zero;
      });
    }
  }

  void _zoomOut() {
    if (_zoom > 10) {
      setState(() {
        _zoom--;
        _panOffset = Offset.zero;
      });
    }
  }

  void _recenter() {
    setState(() {
      _panOffset = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSi = widget.language == 'si';
    final currency = NumberFormat('#,##0.00', 'en_US');
    final dateFormat = DateFormat('dd/MM/yyyy • hh:mm a');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      margin: widget.margin,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // 1. Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A), // Dark navy header
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.location_on, color: const Color(0xFFF97316), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isSi ? 'බිල්පත නිකුත් කල ස්ථානය' : 'Bill Issued Location',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${widget.receipt.manualReceiptNo} • ${widget.receipt.customerName}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF94A3B8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Open in Google Maps action
                TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _openInGoogleMaps,
                  icon: const Icon(Icons.open_in_new, color: Color(0xFF38BDF8), size: 14),
                  label: Text(
                    isSi ? 'Google Maps' : 'Google Maps',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF38BDF8)),
                  ),
                ),
                const SizedBox(width: 6),
                // Close Button
                IconButton(
                  tooltip: isSi ? 'වසන්න' : 'Close',
                  icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                  onPressed: widget.onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // 2. Interactive Map Viewport
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;

                // Tile calculations for center
                final n = 1 << _zoom;
                final xFloat = (_lng + 180.0) / 360.0 * n;
                final latRad = _lat * math.pi / 180.0;
                final yFloat = (1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) / 2.0 * n;

                final tileSize = 256.0;
                final centerPxX = width / 2 + _panOffset.dx;
                final centerPxY = height / 2 + _panOffset.dy;

                // Visible range of tiles
                final colMin = (xFloat - (centerPxX / tileSize)).floor();
                final colMax = (xFloat + ((width - centerPxX) / tileSize)).ceil();
                final rowMin = (yFloat - (centerPxY / tileSize)).floor();
                final rowMax = (yFloat + ((height - centerPxY) / tileSize)).ceil();

                final tiles = <Widget>[];

                for (int col = colMin; col <= colMax; col++) {
                  for (int row = rowMin; row <= rowMax; row++) {
                    if (row < 0 || row >= n) continue;
                    final wrappedCol = (col % n + n) % n;
                    final left = centerPxX + (col - xFloat) * tileSize;
                    final top = centerPxY + (row - yFloat) * tileSize;

                    tiles.add(
                      Positioned(
                        left: left,
                        top: top,
                        width: tileSize,
                        height: tileSize,
                        child: Image.network(
                          'https://tile.openstreetmap.org/$_zoom/$wrappedCol/$row.png',
                          headers: const {'User-Agent': 'JayPharmaApp/1.0'},
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFFF1F5F9),
                            child: const Center(
                              child: Icon(Icons.map_outlined, color: Colors.black26),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                }

                return GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _panOffset += details.delta;
                    });
                  },
                  child: Stack(
                    clipBehavior: Clip.antiAlias,
                    children: [
                      // Background Tile Canvas
                      Container(color: const Color(0xFFE2E8F0)),
                      ...tiles,

                      // Pulsing radar ring
                      Positioned(
                        left: centerPxX - 32,
                        top: centerPxY - 32,
                        width: 64,
                        height: 64,
                        child: IgnorePointer(
                          child: AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, _) {
                              return Center(
                                child: Container(
                                  width: 24 * _pulseAnimation.value,
                                  height: 24 * _pulseAnimation.value,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFF97316).withOpacity(
                                      (1.0 - (_pulseController.value)).clamp(0.0, 1.0) * 0.45,
                                    ),
                                    border: Border.all(
                                      color: const Color(0xFFF97316).withOpacity(
                                        (1.0 - (_pulseController.value)).clamp(0.0, 1.0) * 0.8,
                                      ),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // Location Pin & Marker
                      Positioned(
                        left: centerPxX - 20,
                        top: centerPxY - 44,
                        child: IgnorePointer(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  widget.receipt.manualReceiptNo,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.location_on,
                                size: 38,
                                color: Color(0xFFEF4444),
                                shadows: [
                                  Shadow(
                                    color: Colors.black38,
                                    blurRadius: 6,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Controls: Zoom + / -, Recenter
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildMapBtn(
                              icon: Icons.my_location,
                              tooltip: isSi ? 'ස්ථානයට යන්න' : 'Recenter',
                              onPressed: _recenter,
                            ),
                            const SizedBox(height: 6),
                            _buildMapBtn(
                              icon: Icons.add,
                              tooltip: isSi ? 'විශාල කරන්න' : 'Zoom In',
                              onPressed: _zoomIn,
                            ),
                            const SizedBox(height: 4),
                            _buildMapBtn(
                              icon: Icons.remove,
                              tooltip: isSi ? 'කුඩා කරන්න' : 'Zoom Out',
                              onPressed: _zoomOut,
                            ),
                          ],
                        ),
                      ),

                      // OpenStreetMap Attribution badge
                      Positioned(
                        left: 8,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '© OpenStreetMap contributors',
                            style: GoogleFonts.inter(fontSize: 9, color: Colors.black54),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // 3. Bottom Information Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.pin_drop, size: 14, color: AppTheme.primaryBlue),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.receipt.locationAddress.isNotEmpty
                                  ? widget.receipt.locationAddress
                                  : (widget.receipt.customerAddress.isNotEmpty
                                      ? widget.receipt.customerAddress
                                      : (isSi ? 'ස්ථාන ලිපිනය සටහන්ව නැත' : 'Location recorded at Matale/Field')),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            'GPS: ${_lat.toStringAsFixed(6)}, ${_lng.toStringAsFixed(6)}',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              color: AppTheme.textMuted,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(width: 4, height: 4, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black38)),
                          const SizedBox(width: 10),
                          Text(
                            dateFormat.format(widget.receipt.createdAt),
                            style: GoogleFonts.inter(fontSize: 10.5, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Rs. ${currency.format(widget.receipt.totalAmount)}',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                    Text(
                      widget.receipt.collectorName.isNotEmpty
                          ? widget.receipt.collectorName
                          : widget.receipt.collectorId,
                      style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 18, color: const Color(0xFF1E293B)),
        tooltip: tooltip,
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
