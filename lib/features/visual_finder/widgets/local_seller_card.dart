import 'dart:io';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/inventory_item_model.dart';
import '../../../core/services/database_service.dart';
import '../../../core/widgets/profile_info_widget.dart';
import 'package:provider/provider.dart';
import '../../inventory/item_detail_screen.dart';

class LocalSellerCard extends StatelessWidget {
  final InventoryItem item;
  final bool isUrdu;
  final String distance;
  final String Function(String?, bool) getFont;

  const LocalSellerCard({
    super.key,
    required this.item,
    required this.isUrdu,
    required this.distance,
    required this.getFont,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasCoords = distance.isNotEmpty;
    final db = Provider.of<DatabaseService>(context, listen: false);
    
    final account = item.accountId != null ? db.getAccount(item.accountId!) : null;
    final sellerName = account?.name ?? (isUrdu ? "نامعلوم دکاندار" : "Unknown Seller");
    final bool isVerified = account?.isVerified ?? false;

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ItemDetailScreen(item: item))),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.darkColor, 
          borderRadius: BorderRadius.circular(12), 
          border: Border.all(color: Colors.white10)
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProfileInfoWidget(
                    name: item.name,
                    phone: '',
                    profileImage: item.imagePaths.isNotEmpty ? item.imagePaths[0] : null,
                    isVerified: false, // Item name is shown here, verified badge should be next to SELLER name
                    isLarge: false,
                    textColor: Colors.white,
                    subtitleColor: Colors.white70,
                  ),
                  const SizedBox(height: 8),
                  
                  // Seller Info & Address Row
                  Row(
                    children: [
                      Icon(PhosphorIcons.storefront(PhosphorIconsStyle.fill), size: 10, color: AppTheme.themeColor),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          sellerName.toUpperCase(), 
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white70, 
                            fontSize: 10, 
                            fontWeight: FontWeight.w600,
                            fontFamily: getFont(sellerName, isUrdu)
                          ),
                        ),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: 4),
                        Icon(PhosphorIcons.sealCheck(PhosphorIconsStyle.fill), size: 11, color: AppTheme.verifiedGold),
                      ],
                      if (item.location != null && item.location!.isNotEmpty) ...[
                        const Text(" | ", style: TextStyle(color: Colors.white24, fontSize: 10)),
                        Flexible(
                          child: Text(
                            item.location!, 
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white38, 
                              fontSize: 10,
                              fontFamily: getFont(item.location, isUrdu)
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  
                  // Price and Distance Row
                  Row(
                    children: [
                      const SizedBox(width: 48), // Align with profile text
                      Text(
                        "Rs ${item.defaultRate.toStringAsFixed(0)}", 
                        style: const TextStyle(
                          color: AppTheme.themeColor, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 14
                        ),
                      ),
                      if (hasCoords) ...[
                        const SizedBox(width: 12),
                        Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.fill), size: 10, color: Colors.amber),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            distance, 
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.amber, 
                              fontSize: 11, 
                              fontWeight: FontWeight.bold
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(PhosphorIcons.caretRight(), color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String? path) {
    if (path == null) {
      return Container(
        color: AppTheme.themeColor.withValues(alpha: 0.1), 
        child: Icon(PhosphorIcons.storefront(), color: AppTheme.themeColor, size: 24)
      );
    }

    if (path.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: path,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: Colors.white10),
        errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white24),
      );
    } else {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white24),
      );
    }
  }
}
