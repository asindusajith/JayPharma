import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/receipt.dart';

class VisitedWaypoint {
  final int sequence; // 1, 2, 3...
  final Receipt receipt;
  final double lat;
  final double lng;

  const VisitedWaypoint({
    required this.sequence,
    required this.receipt,
    required this.lat,
    required this.lng,
  });
}

class CollectorRouteMapView extends StatefulWidget {
  final List<VisitedWaypoint> waypoints;
  final int? selectedIndex;
  final ValueChanged<int>? onSelectWaypoint;
  final String language;

  const CollectorRouteMapView({
    super.key,
    required this.waypoints,
    this.selectedIndex,
    this.onSelectWaypoint,
    required this.language,
  });

  @override
  State<CollectorRouteMapView> createState() => _CollectorRouteMapViewState();
}

class _CollectorRouteMapViewState extends State<CollectorRouteMapView> {
  int _zoom = 13;
  Offset _panOffset = Offset.zero;
  double _centerLat = 7.4675;
  double _centerLng = 80.6234;

  @override
  void initState() {
    super.initState();
    _recalcBounds();
  }

  @override
  void didUpdateWidget(covariant CollectorRouteMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.waypoints.length != widget.waypoints.length ||
        (widget.selectedIndex != null && widget.selectedIndex != oldWidget.selectedIndex)) {
      if (widget.selectedIndex != null &&
          widget.selectedIndex! >= 0 &&
          widget.selectedIndex! < widget.waypoints.length) {
        // Center on selected waypoint
        final wp = widget.waypoints[widget.selectedIndex!];
        setState(() {
          _centerLat = wp.lat;
          _centerLng = wp.lng;
          _panOffset = Offset.zero;
          _zoom = math.max(_zoom, 14);
        });
      } else {
        _recalcBounds();
      }
    }
  }

  void _recalcBounds() {
    if (widget.waypoints.isEmpty) return;

    double minLat = 90.0, maxLat = -90.0;
    double minLng = 180.0, maxLng = -180.0;

    for (final wp in widget.waypoints) {
      if (wp.lat < minLat) minLat = wp.lat;
      if (wp.lat > maxLat) maxLat = wp.lat;
      if (wp.lng < minLng) minLng = wp.lng;
      if (wp.lng > maxLng) maxLng = wp.lng;
    }

    _centerLat = (minLat + maxLat) / 2.0;
    _centerLng = (minLng + maxLng) / 2.0;
    _panOffset = Offset.zero;

    final latSpan = (maxLat - minLat).abs();
    final lngSpan = (maxLng - minLng).abs();
    final maxSpan = math.max(latSpan, lngSpan);

    if (maxSpan > 0.8) {
      _zoom = 10;
    } else if (maxSpan > 0.3) {
      _zoom = 11;
    } else if (maxSpan > 0.1) {
      _zoom = 12;
    } else if (maxSpan > 0.04) {
      _zoom = 13;
    } else if (maxSpan > 0.015) {
      _zoom = 14;
    } else {
      _zoom = 15;
    }
    setState(() {});
  }

  void _openGoogleMapsRoute() async {
    if (widget.waypoints.isEmpty) return;

    if (widget.waypoints.length == 1) {
      final wp = widget.waypoints.first;
      final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${wp.lat},${wp.lng}');
      if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
      return;
    }

    final origin = '${widget.waypoints.first.lat},${widget.waypoints.first.lng}';
    final destination = '${widget.waypoints.last.lat},${widget.waypoints.last.lng}';
    final waypointsList = widget.waypoints
        .skip(1)
        .take(widget.waypoints.length - 2)
        .map((w) => '${w.lat},${w.lng}')
        .join('|');

    String urlStr = 'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination';
    if (waypointsList.isNotEmpty) {
      urlStr += '&waypoints=$waypointsList';
    }
    final url = Uri.parse(urlStr);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSi = widget.language == 'si';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: const Color(0xFF0F172A),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.route, color: Color(0xFFA78BFA), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isSi ? 'සජීවී ගමන් මාර්ග සිතියම' : 'Field Route & Visited Places',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        isSi
                            ? 'පිවිසි ස්ථාන ${widget.waypoints.length} ක් (අනුපිළිවෙලින්)'
                            : '${widget.waypoints.length} Visited Places (In Chronological Order)',
                        style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _openGoogleMapsRoute,
                  icon: const Icon(Icons.directions, color: Color(0xFF38BDF8), size: 14),
                  label: Text(
                    isSi ? 'Google Route' : 'Google Route',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF38BDF8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Map Viewport
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;

                final n = 1 << _zoom;
                final xFloat = (_centerLng + 180.0) / 360.0 * n;
                final latRad = _centerLat * math.pi / 180.0;
                final yFloat = (1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) / 2.0 * n;

                final tileSize = 256.0;
                final centerPxX = width / 2 + _panOffset.dx;
                final centerPxY = height / 2 + _panOffset.dy;

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
                            color: const Color(0xFFE2E8F0),
                            child: const Center(
                              child: Icon(Icons.map_outlined, color: Colors.black26),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                }

                // Calculate screen offsets for waypoints
                final waypointPoints = <Offset>[];
                for (final wp in widget.waypoints) {
                  final wpX = (wp.lng + 180.0) / 360.0 * n;
                  final wpLatRad = wp.lat * math.pi / 180.0;
                  final wpY = (1.0 - math.log(math.tan(wpLatRad) + 1.0 / math.cos(wpLatRad)) / math.pi) / 2.0 * n;

                  final px = centerPxX + (wpX - xFloat) * tileSize;
                  final py = centerPxY + (wpY - yFloat) * tileSize;
                  waypointPoints.add(Offset(px, py));
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
                      Container(color: const Color(0xFFE2E8F0)),
                      ...tiles,

                      // Polyline connecting the stops
                      if (waypointPoints.length > 1)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _RoutePolylinePainter(
                                points: waypointPoints,
                                color: const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ),

                      // Waypoint Pins (1, 2, 3...)
                      for (int i = 0; i < widget.waypoints.length; i++)
                        _buildWaypointMarker(
                          index: i,
                          wp: widget.waypoints[i],
                          screenPos: waypointPoints[i],
                          isSelected: widget.selectedIndex == i,
                        ),

                      // Map Control Buttons
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildControlBtn(
                              icon: Icons.crop_free,
                              tooltip: isSi ? 'සියලු ස්ථාන පෙන්වන්න' : 'Fit Entire Route',
                              onPressed: _recalcBounds,
                            ),
                            const SizedBox(height: 6),
                            _buildControlBtn(
                              icon: Icons.add,
                              tooltip: isSi ? 'විශාල කරන්න' : 'Zoom In',
                              onPressed: () {
                                if (_zoom < 18) setState(() => _zoom++);
                              },
                            ),
                            const SizedBox(height: 4),
                            _buildControlBtn(
                              icon: Icons.remove,
                              tooltip: isSi ? 'කුඩා කරන්න' : 'Zoom Out',
                              onPressed: () {
                                if (_zoom > 8) setState(() => _zoom--);
                              },
                            ),
                          ],
                        ),
                      ),

                      // Attribution
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
                            style: GoogleFonts.inter(fontSize: 8.5, color: Colors.black54),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaypointMarker({
    required int index,
    required VisitedWaypoint wp,
    required Offset screenPos,
    required bool isSelected,
  }) {
    final isFirst = index == 0;
    final isLast = index == widget.waypoints.length - 1 && widget.waypoints.length > 1;

    Color badgeColor;
    if (isFirst) {
      badgeColor = const Color(0xFF16A34A); // Emerald green for start
    } else if (isLast) {
      badgeColor = const Color(0xFFDC2626); // Red for destination
    } else {
      badgeColor = const Color(0xFF2563EB); // Royal Blue for middle stops
    }

    return Positioned(
      left: screenPos.dx - 18,
      top: screenPos.dy - 36,
      child: GestureDetector(
        onTap: () {
          widget.onSelectWaypoint?.call(index);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Stop Callout Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF0F172A) : badgeColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.28),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${wp.sequence}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 4),
                    Text(
                      wp.receipt.customerName,
                      style: GoogleFonts.inter(fontSize: 9.5, color: Colors.white),
                    ),
                  ],
                ],
              ),
            ),
            // Pin Icon with sequence badge
            Icon(
              Icons.location_on,
              size: isSelected ? 34 : 28,
              color: isSelected ? const Color(0xFFF59E0B) : badgeColor,
              shadows: const [
                Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlBtn({
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
        icon: Icon(icon, size: 17, color: const Color(0xFF1E293B)),
        tooltip: tooltip,
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _RoutePolylinePainter extends CustomPainter {
  final List<Offset> points;
  final Color color;

  _RoutePolylinePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    // Outer glow / casing
    final casingPaint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, casingPaint);

    // Inner route line with arrows
    final routePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, routePaint);

    // Directional arrows along the segments
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      final angle = math.atan2(p2.dy - p1.dy, p2.dx - p1.dx);

      final arrowPaint = Paint()
        ..color = const Color(0xFF1E3A8A)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(mid.dx, mid.dy);
      canvas.rotate(angle);

      final arrowPath = Path()
        ..moveTo(-4, -4)
        ..lineTo(4, 0)
        ..lineTo(-4, 4)
        ..close();
      canvas.drawPath(arrowPath, arrowPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePolylinePainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
  }
}
