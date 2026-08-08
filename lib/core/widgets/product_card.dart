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
import 'package:account_app/core/utils/formatters.dart';

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
  String? _sellerTenure;
  String? _sellerProfileName;
  bool _isSellerVerified = false;

  @override
  void initState() {
    super.initState();
    _extractColor();
    _loadSellerStats();
  }

  Future<void> _loadSellerStats() async {
    if (widget.item.accountId == null) return;
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final profile =
        await dbService.findPublicProfileByUid(widget.item.accountId!);
    if (profile != null && mounted) {
      setState(() {
        _sellerProfileName = profile['storeName']?.isNotEmpty == true
            ? profile['storeName']
            : profile['name'];
        // Note: isSellerVerified is now used directly from the item model for performance
        if (profile['createdAt'] != null && profile['createdAt']!.isNotEmpty) {
          final date = DateTime.parse(profile['createdAt']!);
          final diff = DateTime.now().difference(date).inDays;
          if (diff > 365) {
            _sellerTenure = "${(diff / 365).floor()}y+";
          } else if (diff > 30) {
            _sellerTenure = "${(diff / 30).floor()}m+";
          } else {
            _sellerTenure = "New";
          }
        }
      });
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
          _dynamicColor =
              palette.vibrantColor?.color ?? palette.dominantColor?.color;
        });
      }
    } catch (e) {
      debugPrint("Color extraction failed: $e");
    }
  }

  String? _calculateDistance() {
    if (widget.userPosition == null ||
        widget.item.latitude == null ||
        widget.item.longitude == null) {
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
    final cardColor = AppTheme.darkColor; // Reverted to darkColor
    final borderColor = Colors.white.withOpacity(0.1);
    final String? distance = _calculateDistance();

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 180, // Increased image height as requested
                    width: double.infinity,
                    child: _buildImage(widget.item.imagePaths.isNotEmpty
                        ? widget.item.imagePaths.first
                        : null),
                  ),
                ),
                // Badges at top left
                Positioned(
                  top: 10,
                  left: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.item.isFeatured)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _buildBadge(widget.isUrdu ? 'نمایاں' : 'Featured',
                              AppTheme.incomeColor.withOpacity(0.9)),
                        ),
                      _buildBadge(
                        widget.isUrdu
                            ? (widget.item.condition == 'New'
                                ? 'نیا'
                                : 'استعمال شدہ')
                            : (widget.item.condition ?? 'New'),
                        Colors.black.withOpacity(0.5),
                      ),
                    ],
                  ),
                ),
                // Action buttons at top right
                Positioned(
                  top: 10,
                  right: 10,
                  child: Column(
                    children: [
                      if (widget.onFavoriteToggle != null && !widget.isMyItem)
                        GestureDetector(
                          onTap: widget.onFavoriteToggle,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: AppTheme.goldColor.withOpacity(0.9),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white24)),
                            child: Icon(
                              widget.isFavorite
                                  ? PhosphorIcons.heart(PhosphorIconsStyle.fill)
                                  : PhosphorIcons.heart(),
                              size: 18,
                              color: widget.isFavorite ? Colors.red : Colors.white,
                            ),
                          ),
                        ),
                      if (widget.isMyItem)
                        _buildOwnerMenu(isGrid: true),
                    ],
                  ),
                ),
                // Expiry Badge at bottom right of image
                if (widget.item.adExpiryDate != null && widget.item.adExpiryDate!.isBefore(DateTime.now()))
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: _buildBadge(
                      widget.isUrdu ? 'ایکسپائرڈ' : 'Expired',
                      Colors.red.withOpacity(0.8),
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
                      Formatters.sanitizeText(widget.item.name),
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: widget.fontFamily),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1), // Reduced line spacing
                    Text(
                      widget.item.category ?? (widget.isUrdu ? 'دیگر' : 'Other'),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.7),
                        fontFamily: widget.fontFamily,
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4), // Reduced spacing
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'Rs ${NumberFormat('#,###').format(widget.item.defaultRate)}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.goldColor, // Reverted to gold for better look on dark
                              fontFamily: ''),
                        ),
                        if (widget.item.unit.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '/ ${widget.item.unit}',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.white.withOpacity(0.6),
                                fontFamily: widget.fontFamily,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4), // Reduced spacing
                    // Rating & Reviews row
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: AppTheme.goldColor), 
                        const SizedBox(width: 4),
                        Text(
                          '${widget.item.rating}',
                          style: const TextStyle(
                              fontSize: 13, 
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(${widget.item.reviewCount})',
                          style: TextStyle(
                              fontSize: 11, 
                              color: Colors.white.withOpacity(0.7)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2), // Reduced spacing
                    // Location/Distance
                    Row(
                      children: [
                        Icon(PhosphorIcons.mapPin(),
                            size: 11, color: Colors.white.withOpacity(0.6)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            distance != null
                                ? "$distance ${widget.isUrdu ? 'دور' : 'away'}"
                                : (widget.item.location ?? ''),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.6),
                              fontFamily: widget.fontFamily,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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
    final cardColor = AppTheme.darkColor; // Reverted
    final borderColor = Colors.white.withOpacity(0.1);
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(16)),
                  child: SizedBox(
                    width: 120,
                    height: 120,
                    child: _buildImage(widget.item.imagePaths.isNotEmpty
                        ? widget.item.imagePaths.first
                        : null),
                  ),
                ),
                Positioned(
                  bottom: 6,
                  left: 6,
                  child: _buildBadge(
                    widget.isUrdu
                        ? (widget.item.condition == 'New'
                            ? 'نیا'
                            : 'استعمال شدہ')
                        : (widget.item.condition ?? 'New'),
                    Colors.black.withOpacity(0.6),
                  ),
                ),
                if (widget.item.adExpiryDate != null && widget.item.adExpiryDate!.isBefore(DateTime.now()))
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: _buildBadge(
                      widget.isUrdu ? 'ایکسپائرڈ' : 'Expired',
                      Colors.red.withOpacity(0.8),
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
                            Formatters.sanitizeText(widget.item.name),
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: widget.fontFamily),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.isFavorite && !widget.isMyItem)
                           Icon(PhosphorIcons.heart(PhosphorIconsStyle.fill),
                                size: 16, color: Colors.red),
                        if (widget.isMyItem)
                           _buildOwnerMenu(isGrid: false),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.item.category ?? (widget.isUrdu ? 'دیگر' : 'Other'),
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.5),
                          fontFamily: widget.fontFamily),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rs ${NumberFormat('#,###').format(widget.item.defaultRate)}',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.goldColor,
                          fontFamily: ''),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(PhosphorIcons.mapPin(),
                                size: 10, color: Colors.white.withOpacity(0.4)),
                            const SizedBox(width: 4),
                            Text(
                              distance != null
                                  ? "$distance ${widget.isUrdu ? 'دور' : 'away'}"
                                  : (widget.item.location ?? ''),
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withOpacity(0.4),
                                  fontFamily: widget.fontFamily),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.star,
                                size: 12, color: AppTheme.goldColor),
                            const SizedBox(width: 4),
                            Text('${widget.item.rating}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
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

  Widget _buildBadge(String label, Color bgColor,
      {Color textColor = Colors.white}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Text(label,
          style: TextStyle(
              color: textColor, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildOwnerMenu({required bool isGrid}) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: isGrid ? BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
        ) : null,
        child: Icon(
          Icons.more_vert,
          color: isGrid ? Colors.white : Colors.white.withOpacity(0.7),
          size: isGrid ? 20 : 24,
        ),
      ),
      onSelected: (value) {
        if (value == 'edit') {
          widget.onEdit?.call();
        } else if (value == 'delete') {
          widget.onDelete?.call();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(PhosphorIcons.pencilSimple(), size: 20, color: AppTheme.darkColor),
              const SizedBox(width: 12),
              Text(
                widget.isUrdu ? 'تبدیل کریں' : 'Edit',
                style: TextStyle(fontFamily: widget.fontFamily, color: AppTheme.darkColor),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(PhosphorIcons.trash(), size: 20, color: Colors.red),
              const SizedBox(width: 12),
              Text(
                widget.isUrdu ? 'ختم کریں' : 'Delete',
                style: TextStyle(
                  fontFamily: widget.fontFamily,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSellerName({double fontSize = 10, Color? color}) {
    return GestureDetector(
      onTap: widget.onSellerTap,
      child: Row(
        children: [
          Icon(PhosphorIcons.storefront(),
              size: fontSize, color: color ?? AppTheme.textSecondary),
          const SizedBox(width: 4),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    widget.sellerName ?? _sellerProfileName ?? '',
                    style: TextStyle(
                        fontSize: fontSize,
                        color: color ?? AppTheme.textSecondary,
                        fontFamily: widget.fontFamily),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.item.isSellerVerified) ...[
                  const SizedBox(width: 4),
                  Icon(
                    PhosphorIcons.sealCheck(PhosphorIconsStyle.fill),
                    size: fontSize + 2,
                    color: AppTheme.verifiedGold,
                  ),
                ],
                if (_sellerTenure != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.darkColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _sellerTenure!,
                      style: TextStyle(
                          fontSize: fontSize - 2,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkColor.withOpacity(0.5)),
                    ),
                  ),
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
          child: Icon(PhosphorIcons.imageBroken(),
              size: 24, color: Colors.grey[400]),
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
            child:
                Icon(PhosphorIcons.image(), size: 32, color: Colors.grey[400]),
          ),
        );
      } else {
        return Container(
          color: Colors.grey[100],
          child:
              Icon(PhosphorIcons.package(), size: 32, color: Colors.grey[400]),
        );
      }
    }
  }
}
