import 'dart:io';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/models/inventory_item_model.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/database_service.dart';

enum ProductCardView { grid, list, horizontal }

class ProductCard extends StatefulWidget {
  final InventoryItem item;
  final bool isUrdu;
  final String fontFamily;
  final ProductCardView view;
  final bool isFavorite;
  final bool isMyItem;
  final String? sellerName;
  final Position? userPosition;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onSellerTap;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const ProductCard({
    super.key,
    required this.item,
    required this.isUrdu,
    required this.fontFamily,
    this.view = ProductCardView.grid,
    this.isFavorite = false,
    this.isMyItem = false,
    this.sellerName,
    this.userPosition,
    required this.onTap,
    this.onFavoriteToggle,
    this.onSellerTap,
    this.onDelete,
    this.onEdit,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  Color? _dynamicColor;
  bool _isSellerVerified = false;

  @override
  void initState() {
    super.initState();
    _extractColor();
    _checkVerification();
  }

  Future<void> _checkVerification() async {
    if (widget.item.accountId == null) return;
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final verified = await dbService.isSellerVerified(widget.item.accountId!);
    if (mounted) {
      setState(() => _isSellerVerified = verified);
    }
  }

  @override
  void didUpdateWidget(ProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.imagePaths != widget.item.imagePaths) {
      _extractColor();
    }
  }

  Future<void> _extractColor() async {
    if (widget.item.imagePaths.isEmpty) return;
    
    try {
      final String path = widget.item.imagePaths.first;
      ImageProvider imageProvider;
      
      if (path.startsWith('http')) {
        imageProvider = CachedNetworkImageProvider(path);
      } else {
        imageProvider = FileImage(File(path));
      }

      final PaletteGenerator palette = await PaletteGenerator.fromImageProvider(
        imageProvider,
        maximumColorCount: 5,
      );

      if (mounted) {
        setState(() {
          _dynamicColor = palette.vibrantColor?.color ?? palette.dominantColor?.color;
        });
      }
    } catch (e) {
      debugPrint("Color extraction failed: $e");
    }
  }

  String? _calculateDistance() {
    if (widget.userPosition == null || widget.item.latitude == null || widget.item.longitude == null) {
      return null;
    }
    
    final double distanceInMeters = Geolocator.distanceBetween(
      widget.userPosition!.latitude,
      widget.userPosition!.longitude,
      widget.item.latitude!,
      widget.item.longitude!,
    );
    
    if (distanceInMeters < 1000) {
      return "${distanceInMeters.toStringAsFixed(0)}m";
    } else {
      final double distanceInKm = distanceInMeters / 1000;
      return "${distanceInKm.toStringAsFixed(1)}km";
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.view) {
      case ProductCardView.list:
        return _buildListItem(context);
      case ProductCardView.horizontal:
        return _buildHorizontalItem(context);
      case ProductCardView.grid:
      default:
        return _buildGridItem(context);
    }
  }

  Widget _buildGridItem(BuildContext context) {
    final cardColor = AppTheme.goldColor;
    final borderColor = Colors.white.withOpacity(0.15);
    final String? distance = _calculateDistance();

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4), 
              blurRadius: 10, 
              offset: const Offset(0, 4)
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                  child: SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: _buildImage(widget.item.imagePaths.isNotEmpty ? widget.item.imagePaths.first : null),
                  ),
                ),
                if (widget.isMyItem && widget.onDelete != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: widget.onDelete,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.8), shape: BoxShape.circle),
                        child: Icon(PhosphorIcons.trash(), size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                if (widget.isMyItem && widget.onEdit != null)
                  Positioned(
                    top: 8,
                    right: widget.onDelete != null ? 40 : 8,
                    child: GestureDetector(
                      onTap: widget.onEdit,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: AppTheme.themeColor.withOpacity(0.8), shape: BoxShape.circle),
                        child: Icon(PhosphorIcons.pencilSimple(), size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                if (widget.isMyItem)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _buildBadge(widget.isUrdu ? 'میری' : 'Mine', AppTheme.themeColor.withOpacity(0.8)),
                  ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: _buildBadge(
                    widget.isUrdu 
                      ? (widget.item.condition == 'New' ? 'نیا' : 'استعمال شدہ')
                      : (widget.item.condition ?? 'New'),
                    Colors.black.withOpacity(0.6),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.name,
                      style: TextStyle(
                        fontSize: 14, 
                        fontWeight: FontWeight.bold, 
                        color: AppTheme.darkColor, 
                        fontFamily: widget.fontFamily
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rs ${NumberFormat('#,###').format(widget.item.defaultRate)}',
                      style: const TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.w900, 
                        color: AppTheme.darkColor, 
                        fontFamily: ''
                      ),
                    ),
                    const Spacer(),
                    if (distance != null || (widget.item.location != null && widget.item.location!.isNotEmpty))
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 10, color: AppTheme.darkColor),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              distance != null 
                                ? "$distance ${widget.isUrdu ? 'دور' : 'away'}${widget.item.location != null ? ' • ${widget.item.location}' : ''}"
                                : widget.item.location!,
                              style: TextStyle(
                                fontSize: 10, 
                                color: AppTheme.darkColor.withOpacity(0.6), 
                                fontFamily: widget.fontFamily,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                            const Icon(Icons.star, size: 11, color: AppTheme.darkColor),
                            const SizedBox(width: 3),
                            Text('${widget.item.rating}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.darkColor)),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(PhosphorIcons.eye(), size: 11, color: AppTheme.darkColor.withOpacity(0.6)),
                            const SizedBox(width: 3),
                            Text('${widget.item.views}', style: const TextStyle(fontSize: 11, color: AppTheme.darkColor)),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(PhosphorIcons.heart(PhosphorIconsStyle.fill), size: 11, color: AppTheme.darkColor),
                            const SizedBox(width: 3),
                            Text('${widget.item.likes}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.darkColor)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListItem(BuildContext context) {
    final cardColor = AppTheme.goldColor;
    final borderColor = Colors.white.withOpacity(0.15);
    final String? distance = _calculateDistance();

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                  child: SizedBox(
                    width: 110,
                    height: 110,
                    child: _buildImage(widget.item.imagePaths.isNotEmpty ? widget.item.imagePaths.first : null),
                  ),
                ),
                Positioned(
                  bottom: 6,
                  left: 6,
                  child: _buildBadge(
                    widget.isUrdu 
                      ? (widget.item.condition == 'New' ? 'نیا' : 'استعمال شدہ')
                      : (widget.item.condition ?? 'New'),
                    Colors.black.withOpacity(0.6),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.item.name,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.darkColor, fontFamily: widget.fontFamily),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.isMyItem) ...[
                          if (widget.onEdit != null)
                            GestureDetector(
                              onTap: widget.onEdit,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(color: AppTheme.themeColor.withOpacity(0.1), shape: BoxShape.circle),
                                child: Icon(PhosphorIcons.pencilSimple(), size: 16, color: AppTheme.themeColor),
                              ),
                            ),
                          const SizedBox(width: 8),
                          _buildBadge(widget.isUrdu ? 'میری' : 'Mine', AppTheme.themeColor.withOpacity(0.8)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (widget.sellerName != null)
                      _buildSellerName(fontSize: 11, color: AppTheme.darkColor.withOpacity(0.7)),
                    const SizedBox(height: 8),
                    Text(
                      'Rs ${NumberFormat('#,###').format(widget.item.defaultRate)}',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.darkColor, fontFamily: ''),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 10, color: AppTheme.darkColor),
                            const SizedBox(width: 4),
                            Text(
                              distance != null 
                                ? "$distance ${widget.isUrdu ? 'دور' : 'away'}${widget.item.location != null ? ' • ${widget.item.location}' : ''}"
                                : (widget.item.location ?? ''),
                              style: TextStyle(fontSize: 10, color: AppTheme.darkColor.withOpacity(0.6), fontFamily: widget.fontFamily),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(PhosphorIcons.eye(), size: 11, color: AppTheme.darkColor.withOpacity(0.6)),
                            const SizedBox(width: 4),
                            Text('${widget.item.views}', style: const TextStyle(fontSize: 11, color: AppTheme.darkColor)),
                            const SizedBox(width: 12),
                            Icon(PhosphorIcons.heart(PhosphorIconsStyle.fill), size: 11, color: AppTheme.darkColor),
                            const SizedBox(width: 4),
                            Text('${widget.item.likes}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.darkColor)),
                            const SizedBox(width: 12),
                            const Icon(Icons.star, size: 12, color: AppTheme.darkColor),
                            const SizedBox(width: 4),
                            Text('${widget.item.rating}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.darkColor)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalItem(BuildContext context) {
    return SizedBox(
      width: 220,
      child: _buildGridItem(context),
    );
  }

  Widget _buildBadge(String label, Color bgColor, {Color textColor = Colors.white}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: textColor, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSellerName({double fontSize = 10, Color? color}) {
    return GestureDetector(
      onTap: widget.onSellerTap,
      child: Row(
        children: [
          Icon(PhosphorIcons.storefront(), size: fontSize, color: color ?? AppTheme.textSecondary),
          const SizedBox(width: 4),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    widget.sellerName!,
                    style: TextStyle(fontSize: fontSize, color: color ?? AppTheme.textSecondary, fontFamily: widget.fontFamily),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_isSellerVerified) ...[
                  const SizedBox(width: 4),
                  Icon(PhosphorIcons.sealCheck(PhosphorIconsStyle.fill), size: fontSize + 2, color: Colors.blue),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String? path) {
    if (path == null) {
      return Container(
        color: Colors.grey[100],
        child: Icon(PhosphorIcons.package(), size: 32, color: Colors.grey[400]),
      );
    }
    if (path.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: path,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 300),
        fadeOutDuration: const Duration(milliseconds: 300),
        memCacheWidth: 400, 
        placeholder: (context, url) => Container(
          color: Colors.grey[100],
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[100],
          child: Icon(PhosphorIcons.imageBroken(), size: 24, color: Colors.grey[400]),
        ),
      );
    } else {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.grey[100],
            child: Icon(PhosphorIcons.image(), size: 32, color: Colors.grey[400]),
          ),
        );
      } else {
        return Container(
          color: Colors.grey[100],
          child: Icon(PhosphorIcons.package(), size: 32, color: Colors.grey[400]),
        );
      }
    }
  }
}
