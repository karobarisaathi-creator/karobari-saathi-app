// lib/features/artisans/widgets/artisan_card.dart
import 'package:flutter/material.dart';
import 'package:account_app/core/models/artisan_profile_model.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'dart:async';

class ArtisanCard extends StatefulWidget {
  final ArtisanProfile artisan;
  final bool isUrdu;
  final String fontFamily;
  final VoidCallback onTap;
  final double? distanceKm;

  const ArtisanCard({
    super.key,
    required this.artisan,
    required this.isUrdu,
    required this.fontFamily,
    required this.onTap,
    this.distanceKm,
  });

  @override
  State<ArtisanCard> createState() => _ArtisanCardState();
}

class _ArtisanCardState extends State<ArtisanCard> {
  final ArtisanService _artisanService = ArtisanService();
  StreamSubscription<bool>? _favoriteSubscription;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadFavoriteStatus();
  }

  void _loadFavoriteStatus() {
    _favoriteSubscription?.cancel();
    _favoriteSubscription = _artisanService
        .isFavorite(widget.artisan.id)
        .listen(
          (isFav) {
            if (mounted && isFav != _isFavorite) {
              setState(() => _isFavorite = isFav);
            }
          },
          onError: (error) {
            // Silent fail for favorite status
          },
        );
  }

  @override
  void dispose() {
    _favoriteSubscription?.cancel();
    super.dispose();
  }

  String _getRateText() {
    if (widget.artisan.rate == null || widget.artisan.rate!.isEmpty) {
      return widget.isUrdu ? 'ریٹ دستیاب نہیں' : 'N/A';
    }
    
    final unit = widget.isUrdu
        ? _getUnitUr(widget.artisan.rateUnit)
        : _getUnitEn(widget.artisan.rateUnit);
    
    return 'Rs. ${widget.artisan.rate} / $unit';
  }

  String _getUnitUr(String? unit) {
    switch (unit) {
      case 'hour': return 'فی گھنٹہ';
      case 'day': return 'فی دیہاڑی';
      case 'month': return 'فی مہینہ';
      case 'fixed': return 'مکمل کام';
      default: return 'کام';
    }
  }

  String _getUnitEn(String? unit) {
    switch (unit) {
      case 'hour': return 'Hr';
      case 'day': return 'Day';
      case 'month': return 'Mo';
      case 'fixed': return 'Fixed';
      default: return 'Job';
    }
  }

  @override
  Widget build(BuildContext context) {
    final rateText = _getRateText();

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  ProfileInfoWidget(
                    name: widget.artisan.name,
                    phone: '',
                    profileImage: widget.artisan.profileImage,
                    category: widget.isUrdu
                        ? widget.artisan.professionUrdu
                        : widget.artisan.profession,
                    isVerified: widget.artisan.isVerified ||
                        widget.artisan.verificationStatus == 'approved',
                    isFavorite: false,
                    customSize: 70,
                    isVerticalCategory: true,
                    verticalSpacing: 6.0,
                    textColor: Colors.black87,
                    subtitleColor: Colors.grey.shade600,
                    categoryColor: Colors.grey.shade600,
                    suffix: Text(
                      rateText,
                      style: TextStyle(
                        fontSize: widget.isUrdu ? 14 : 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                        fontFamily: widget.isUrdu ? widget.fontFamily : null,
                      ),
                    ),
                    bottom: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: AppTheme.darkColor,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.artisan.rating} (${widget.artisan.totalReviews} ${widget.isUrdu ? 'ریٹنگز' : 'ratings'})',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                fontFamily: widget.isUrdu ? widget.fontFamily : null,
                              ),
                            ),
                            if (widget.artisan.rating >= 4.5) ...[
                              const SizedBox(width: 8),
                              _buildBadge(
                                widget.isUrdu ? 'بہترین سروس' : 'GREAT VALUE',
                                AppTheme.incomeColor.withValues(alpha: 0.15),
                                AppTheme.incomeColor,
                              ),
                            ],
                            if (_isFavorite) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppTheme.themeColor.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  PhosphorIcons.heart(PhosphorIconsStyle.fill),
                                  size: 12,
                                  color: AppTheme.themeColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${widget.artisan.workCount} ${widget.isUrdu ? 'خدمات فراہم کیں' : 'tasks completed'}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF27AE60),
                            fontFamily: widget.isUrdu ? widget.fontFamily : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.artisan.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Colors.grey.shade700,
                  fontFamily: widget.isUrdu ? widget.fontFamily : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            text == 'GREAT VALUE' || text == 'بہترین سروس'
                ? PhosphorIcons.star(PhosphorIconsStyle.fill)
                : PhosphorIcons.sealCheck(PhosphorIconsStyle.fill),
            size: 12,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: textColor,
              fontFamily: widget.isUrdu ? widget.fontFamily : null,
            ),
          ),
        ],
      ),
    );
  }
}
