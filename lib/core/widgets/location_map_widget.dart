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

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
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
      final url = Uri.parse("https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(widget.address)}");
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
      return;
    }

    final url = Uri.parse("https://www.google.com/maps/search/?api=1&query=${widget.latitude},${widget.longitude}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.latitude == null && widget.longitude == null && widget.address.isEmpty) return const SizedBox.shrink();

    // Use a cleaner static map style (Yandex with custom parameters for a lighter look)
    // l=map (standard), l=sat (satellite), l=skl (schematic)
    final String mapUrl = widget.latitude != null && widget.longitude != null
        ? "https://static-maps.yandex.ru/1.x/?ll=${widget.longitude},${widget.latitude}&z=14&l=map&size=650,350&pt=${widget.longitude},${widget.latitude},pm2rdm"
        : "";

    return GestureDetector(
      onTap: _openMap,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F2F5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Background Map
            if (mapUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: mapUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: const Color(0xFFF0F2F5),
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (context, url, error) => _buildPlaceholder(),
              )
            else
              _buildPlaceholder(),
            
            // Route/Design Overlay (Simulated clean look)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Distance Badge (Top Left like in image)
            if (!_calculatingDistance && _distanceStr.isNotEmpty)
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _distanceStr,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.darkColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.isUrdu ? "دور" : "away",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontFamily: widget.isUrdu ? 'NooriNastaleeq' : '',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Center Pin (Design style)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                      color: Colors.black,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 32), // Offset to put pin point in center
                ],
              ),
            ),

            // Open Map Button (Bottom Right) - No Background
            Positioned(
              bottom: 16,
              right: 16,
              child: Icon(
                PhosphorIcons.navigationArrow(PhosphorIconsStyle.bold),
                size: 24,
                color: AppTheme.darkColor,
                shadows: [
                  Shadow(
                    offset: const Offset(0, 0),
                    blurRadius: 10,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ],
              ),
            ),

            // Address Overlay (Bottom Left) - No Background
            Positioned(
              bottom: 16,
              left: 16,
              right: 70, // Avoid overlapping with Open Map button
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                      size: 16, color: AppTheme.darkColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.address,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.darkColor,
                        fontWeight: FontWeight.w900,
                        fontFamily: widget.isUrdu ? 'NooriNastaleeq' : '',
                        shadows: [
                          Shadow(
                            offset: const Offset(0, 0),
                            blurRadius: 10,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
            Icon(PhosphorIcons.mapTrifold(), size: 40, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              "Click to see location",
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
