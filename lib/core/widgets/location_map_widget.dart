import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/services/logging_service.dart';

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
  final _logger = LoggingService();
  String _distanceStr = "";
  bool _calculatingDistance = true;
  bool _mapLoadFailed = false;
  double _currentZoom = 15.0; // ڈیفالٹ زوم لیول

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
        
        // وقت کا اندازہ: اوسطاً 30 کلومیٹر فی گھنٹہ کی رفتار سے
        // (km / 30) * 60 = km * 2 منٹ
        int minutes = (km * 2).round();
        if (minutes < 1) minutes = 1;

        if (mounted) {
          setState(() {
            final String dist = km < 1
                ? "${distanceInMeters.toStringAsFixed(0)} m"
                : "${km.toStringAsFixed(1)} km";
            
            final String time = minutes > 60 
                ? "${(minutes / 60).toStringAsFixed(1)} ${widget.isUrdu ? 'گھنٹے' : 'hr'}"
                : "$minutes ${widget.isUrdu ? 'منٹ' : 'min'}";

            _distanceStr = "$dist ($time)";
            _calculatingDistance = false;
          });
        }
      } else {
        if (mounted) setState(() => _calculatingDistance = false);
      }
    } catch (e, stack) {
      _logger.error("Distance calculation error", e, stack);
      if (mounted) setState(() => _calculatingDistance = false);
    }
  }

  Future<void> _openMap() async {
    try {
      Uri url;
      
      if (widget.latitude == null || widget.longitude == null) {
        url = Uri.parse(
          "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(widget.address)}",
        );
      } else {
        url = Uri.parse(
          "https://www.google.com/maps/search/?api=1&query=${widget.latitude},${widget.longitude}&zoom=15",
        );
      }

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e, stack) {
      _logger.error("Open map error", e, stack);
      if (mounted) {
        AppToast.error(
          context,
          widget.isUrdu ? 'نقشہ کھولنے میں ناکامی' : 'Failed to open map',
        );
      }
    }
  }

  String _getMapUrl() {
    if (widget.latitude == null || widget.longitude == null) return "";
    
    // متحرک زوم کے ساتھ یانڈیکس نقشہ
    return "https://static-maps.yandex.ru/1.x/"
        "?ll=${widget.longitude},${widget.latitude}"
        "&z=${_currentZoom.toInt()}" 
        "&l=map"
        "&size=650,450"
        "&pt=${widget.longitude},${widget.latitude},pm2rdl"
        "&lang=en_US"
        "&scale=2";
  }

  @override
  Widget build(BuildContext context) {
    if (widget.latitude == null &&
        widget.longitude == null &&
        widget.address.isEmpty) {
      return const SizedBox.shrink();
    }

    final mapUrl = _getMapUrl();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 280,
          width: double.infinity,
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: mapUrl.isNotEmpty && !_mapLoadFailed
                      ? CachedNetworkImage(
                          imageUrl: mapUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: const Color(0xFFF0F2F5),
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) {
                            if (mounted && !_mapLoadFailed) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  setState(() {
                                    _mapLoadFailed = true;
                                  });
                                }
                              });
                            }
                            return _buildPlaceholder();
                          },
                        )
                      : _buildPlaceholder(),
                ),
              ),
              Positioned(
                bottom: 4,
                left: 4,
                right: 4,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    color: Colors.white.withValues(alpha: 0.95),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.themeColor.withValues(alpha: 0.1),
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
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.goldColor,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                ),
              ),
              // زوم کنٹرول بٹنز
              Positioned(
                top: 16,
                right: 16,
                child: Column(
                  children: [
                    _buildZoomButton(
                      icon: Icons.add,
                      onTap: () {
                        if (_currentZoom < 18) {
                          setState(() => _currentZoom++);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildZoomButton(
                      icon: Icons.remove,
                      onTap: () {
                        if (_currentZoom > 2) {
                          setState(() => _currentZoom--);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildZoomButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: AppTheme.darkColor, size: 20),
      ),
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
              PhosphorIcons.mapTrifold(),
              size: 40,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              widget.isUrdu ? 'نقشہ لوڈ کرنے کے لیے تھپتھپائیں' : 'Tap to load map',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 13,
                fontFamily: widget.isUrdu ? 'NooriNastaleeq' : '',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
