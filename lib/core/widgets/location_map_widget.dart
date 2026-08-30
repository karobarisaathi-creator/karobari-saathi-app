// lib/core/widgets/location_map_widget.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:account_app/core/theme/app_theme.dart';

class LocationMapWidget extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final String address;
  final bool isUrdu;

  const LocationMapWidget({
    super.key,
    this.latitude,
    this.longitude,
    required this.address,
    this.isUrdu = false,
  });

  @override
  State<LocationMapWidget> createState() => _LocationMapWidgetState();
}

class _LocationMapWidgetState extends State<LocationMapWidget> {
  String _distanceStr = "";
  bool _calculatingDistance = true;

  @override
  void initState() {
    super.initState();
    _calculateDistance();
  }

  Future<void> _calculateDistance() async {
    if (widget.latitude == null || widget.longitude == null) {
      if (mounted) setState(() => _calculatingDistance = false);
      return;
    }

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        Position currentPosition = await Geolocator.getCurrentPosition();

        double distanceInMeters = Geolocator.distanceBetween(
          currentPosition.latitude,
          currentPosition.longitude,
          widget.latitude!,
          widget.longitude!,
        );

        double km = distanceInMeters / 1000;
        if (mounted) {
          setState(() {
            _distanceStr = km < 1
                ? "${(distanceInMeters).toStringAsFixed(0)} m"
                : "${km.toStringAsFixed(1)} km";
            _calculatingDistance = false;
          });
        }
      } else {
        if (mounted) setState(() => _calculatingDistance = false);
      }
    } catch (e) {
      debugPrint("Distance calc error: $e");
      if (mounted) setState(() => _calculatingDistance = false);
    }
  }

  Future<void> _openMap() async {
    if (widget.latitude == null || widget.longitude == null) {
      final url = Uri.parse(
          "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(widget.address)}"
      );
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
      return;
    }

    // Google Maps پر کھولیں
    final url = Uri.parse(
        "https://www.google.com/maps/search/?api=1&query=${widget.latitude},${widget.longitude}&zoom=15"
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.latitude == null && widget.longitude == null && widget.address.isEmpty) {
      return const SizedBox.shrink();
    }

    // ✅ بڑا نقشہ (سادہ)
    String mapUrl = "";
    if (widget.latitude != null && widget.longitude != null) {
      mapUrl = "https://static-maps.yandex.ru/1.x/"
          "?ll=${widget.longitude},${widget.latitude}"
          "&z=13"  // 2-3 کلومیٹر
          "&l=map"  // سادہ نقشہ
          "&size=650,450"
          "&pt=${widget.longitude},${widget.latitude},pm2rdl"
          "&lang=en_US"
          "&scale=2";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _openMap,
          child: Container(
            height: 280,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 0),
            child: Stack(
              children: [
                // 1. نقشہ (بیک گراؤنڈ میں اور کلپ شدہ)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: mapUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: mapUrl,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: const Color(0xFFF0F2F5),
                              child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2)),
                            ),
                            errorWidget: (context, url, error) => _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                  ),
                ),

                // 2. معلومات کی پٹی (نیچے)
                Positioned(
                  bottom: 4, // باڈر کی موٹائی کے لحاظ سے تھوڑی جگہ
                  left: 4,
                  right: 4,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      color: Colors.white.withOpacity(0.95),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 18,
                            color: AppTheme.themeColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.address,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.darkColor,
                                fontWeight: FontWeight.bold,
                                fontFamily: widget.isUrdu ? 'NooriNastaleeq' : '',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!_calculatingDistance && _distanceStr.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.themeColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _distanceStr,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.themeColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // 3. باڈر (سب سے اوپر تاکہ کونے نہ کٹیں)
                IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.goldColor, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                  ),
                ),

                // 4. زوم بیج (اوپر دائیں)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_in, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          "2 km",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFFF0F2F5),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map_outlined,
              size: 40,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              widget.isUrdu ? 'مقام دستیاب نہیں' : 'Location not available',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ✅ مثلث پینٹر
class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter({this.color = Colors.blue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}