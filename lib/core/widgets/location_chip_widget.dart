import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:account_app/core/services/location_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';

class LocationChipWidget extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final String? address;
  final bool showAddress;
  final bool showTime;
  final bool isUrdu;
  final bool isChip;
  final TextStyle? style;
  final Color? color;
  final VoidCallback? onTap;

  /// Average travel speed in km/h (city driving ~30, walking ~5).
  final double speedKmh;

  const LocationChipWidget({
    super.key,
    this.latitude,
    this.longitude,
    this.address,
    this.showAddress = true,
    this.showTime = true,
    this.isUrdu = true,
    this.isChip = true,
    this.style,
    this.color,
    this.onTap,
    this.speedKmh = 30.0,
  });

  @override
  State<LocationChipWidget> createState() => _LocationChipWidgetState();
}

// ─────────────────────────────────────────────────────────────
// Static shared caches (bounded — no memory leak)
// ─────────────────────────────────────────────────────────────

/// LRU geocode cache — max 100 entries.
final _geocodeCache = <String, Map<String, double>>{};

/// Shared GPS cache — prevents 20 chips = 20 GPS calls.
Position? _cachedPosition;
DateTime? _cachedAt;
Future<Position?>? _inflightPosition;
const _positionTtl = Duration(seconds: 30);

Future<Position?> _getSharedPosition() async {
  // Fresh cache?
  if (_cachedPosition != null &&
      _cachedAt != null &&
      DateTime.now().difference(_cachedAt!) < _positionTtl) {
    return _cachedPosition;
  }

  // Deduplicate concurrent requests
  if (_inflightPosition != null) return _inflightPosition;

  _inflightPosition = _fetchPosition().whenComplete(() {
    _inflightPosition = null;
  });
  return _inflightPosition;
}

Future<Position?> _fetchPosition() async {
  try {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    // Fast path: last known position
    final last = await Geolocator.getLastKnownPosition();
    if (last != null &&
        DateTime.now().difference(last.timestamp) <
            const Duration(minutes: 2)) {
      _cachedPosition = last;
      _cachedAt = DateTime.now();
      return last;
    }

    // Slow path: fresh fix
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 8),
      ),
    );
    _cachedPosition = pos;
    _cachedAt = DateTime.now();
    return pos;
  } catch (e, st) {
    debugPrint('LocationChip GPS error: $e\n$st');
    return _cachedPosition; // stale but usable
  }
}

// ─────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────

class _LocationChipWidgetState extends State<LocationChipWidget> {
  double? _destLat;
  double? _destLon;
  String? _distanceText;
  String? _timeText;
  bool _calculating = true;
  int _requestId = 0; // race-condition guard

  @override
  void initState() {
    super.initState();
    _destLat = widget.latitude;
    _destLon = widget.longitude;
    WidgetsBinding.instance.addPostFrameCallback((_) => _computeDistance());
  }

  @override
  void didUpdateWidget(covariant LocationChipWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude ||
        oldWidget.address != widget.address ||
        oldWidget.speedKmh != widget.speedKmh) {
      _destLat = widget.latitude;
      _destLon = widget.longitude;
      _computeDistance();
    }
  }

  Future<void> _computeDistance() async {
    if (!mounted) return;
    final id = ++_requestId; // capture current request

    setState(() => _calculating = true);

    try {
      // 1. Resolve coordinates from address if needed
      await _resolveCoordinates(id);
      if (!mounted || id != _requestId) return;

      if (_destLat == null || _destLon == null) {
        setState(() {
          _calculating = false;
          _distanceText = null;
          _timeText = null;
        });
        return;
      }

      // 2. Get current user position (shared cache)
      final pos = await _getSharedPosition();
      if (!mounted || id != _requestId) return;

      if (pos == null) {
        setState(() => _calculating = false);
        return;
      }

      // 3. Compute distance + ETA
      final distMeters = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        _destLat!,
        _destLon!,
      );

      final km = distMeters / 1000;
      final mins = ((km / widget.speedKmh) * 60).round().clamp(1, 100000);

      if (!mounted || id != _requestId) return;
      setState(() {
        _distanceText = km < 1
            ? '${distMeters.toStringAsFixed(0)} ${widget.isUrdu ? "میٹر" : "m"}'
            : '${km.toStringAsFixed(1)} ${widget.isUrdu ? "کلومیٹر" : "km"}';

        _timeText = mins > 60
            ? '${(mins / 60).toStringAsFixed(1)} ${widget.isUrdu ? "گھنٹے" : "hr"}'
            : '$mins ${widget.isUrdu ? "منٹ" : "min"}';
        _calculating = false;
      });
    } catch (e, st) {
      debugPrint('LocationChip compute error: $e\n$st');
      if (mounted && id == _requestId) {
        setState(() => _calculating = false);
      }
    }
  }

  Future<void> _resolveCoordinates(int id) async {
    if (_destLat != null && _destLon != null) return;
    if (widget.address == null || widget.address!.trim().length < 3) return;

    final clean = widget.address!.trim();
    final key = clean.toLowerCase();

    // Cache hit
    if (_geocodeCache.containsKey(key)) {
      final cached = _geocodeCache.remove(key)!;
      _geocodeCache[key] = cached; // bump to MRU
      _destLat = cached['lat'];
      _destLon = cached['lon'];
      return;
    }

    final results = await LocationService.searchLocations(
      clean,
      language: widget.isUrdu ? 'ur' : 'en',
    );
    if (!mounted || id != _requestId) return;

    if (results.isNotEmpty) {
      final lat = results.first['lat'];
      final lon = results.first['lon'];
      if (lat is double && lon is double) {
        _destLat = lat;
        _destLon = lon;

        // Bounded LRU insert
        _geocodeCache[key] = {'lat': lat, 'lon': lon};
        if (_geocodeCache.length > 100) {
          _geocodeCache.remove(_geocodeCache.keys.first);
        }
      }
    }
  }

  Future<void> _openMaps() async {
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }

    Uri? url;
    if (_destLat != null && _destLon != null) {
      url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$_destLat,$_destLon',
      );
    } else if (widget.address != null && widget.address!.isNotEmpty) {
      url = Uri.parse(
        'https://www.google.com/maps/search/?api=1'
        '&query=${Uri.encodeComponent(widget.address!)}',
      );
    }

    if (url == null) return;

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        _showSnack(widget.isUrdu ? 'نقشہ نہیں کھل سکا' : 'Could not open maps');
      }
    } catch (e, st) {
      debugPrint('LocationChip openMaps error: $e\n$st');
      if (mounted) {
        _showSnack(widget.isUrdu ? 'نقشہ کھولنے میں خرابی' : 'Error opening maps');
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.color ?? AppTheme.themeColor;
    final textStyle = widget.style ??
        TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: themeColor,
        );

    final parts = <String>[];
    if (widget.showAddress &&
        widget.address != null &&
        widget.address!.trim().isNotEmpty) {
      parts.add(widget.address!.trim());
    }

    final dist = _distanceText ?? (widget.isUrdu ? '1.5 کلومیٹر' : '1.5 km');
    parts.add(dist);

    if (widget.showTime && _timeText != null) parts.add(_timeText!);

    final label = parts.join('  •  ');

    final innerRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          PhosphorIcons.navigationArrow(PhosphorIconsStyle.fill),
          size: 12,
          color: themeColor,
        ),
        const SizedBox(width: 4),
        if (_calculating && label.isEmpty)
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: themeColor,
            ),
          )
        else
          Flexible(
            child: UrduAwareText(
              label,
              style: textStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );

    if (!widget.isChip) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openMaps,
          borderRadius: BorderRadius.circular(4),
          child: innerRow,
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openMaps,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: themeColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: themeColor.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: innerRow,
        ),
      ),
    );
  }
}
