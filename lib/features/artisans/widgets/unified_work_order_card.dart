import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/models/artisan_work_order_model.dart';
import 'package:account_app/core/models/artisan_profile_model.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:intl/intl.dart';

class UnifiedWorkOrderCard extends StatelessWidget {
  final ArtisanWorkOrder order;
  final bool isArtisanMode;
  final bool isUrdu;
  final String fontFamily;
  final VoidCallback? onAction;
  final VoidCallback? onTap;

  const UnifiedWorkOrderCard({
    super.key,
    required this.order,
    required this.isArtisanMode,
    required this.isUrdu,
    required this.fontFamily,
    this.onAction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColors = {
      'negotiating': Colors.orange,
      'confirmed': Colors.blue,
      'in_progress': Colors.indigo,
      'completed': Colors.green,
      'rated': AppTheme.verifiedGold,
      'rejected': Colors.red,
    };

    final statusLabels = {
      'negotiating': isUrdu ? 'ڈیل ہو رہی ہے' : 'Negotiating',
      'confirmed': isUrdu ? 'منظور شدہ' : 'Confirmed',
      'in_progress': isUrdu ? 'جاری ہے' : 'In Progress',
      'completed': isUrdu ? 'مکمل' : 'Completed',
      'rated': isUrdu ? 'فیڈ بیک موصول' : 'Rated',
      'rejected': isUrdu ? 'مسترد' : 'Rejected',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Bar: Info & Status
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: isArtisanMode
                        ? ProfileInfoWidget(
                            name: order.customerName,
                            phone: isUrdu ? 'گاہک / مالک' : 'Customer',
                            customSize: 42,
                            borderRadius: 6,
                          )
                        : FutureBuilder<ArtisanProfile?>(
                            future: ArtisanService().getProfile(order.artisanId),
                            builder: (context, snapshot) {
                              final name = snapshot.data?.name ?? (isUrdu ? 'کاریگر' : 'Artisan');
                              final profession = isUrdu 
                                  ? (snapshot.data?.professionUrdu ?? '') 
                                  : (snapshot.data?.profession ?? '');
                              
                              return ProfileInfoWidget(
                                name: name,
                                phone: profession,
                                profileImage: snapshot.data?.profileImage,
                                customSize: 42,
                                borderRadius: 6,
                              );
                            },
                          ),
                  ),
                  _buildStatusBadge(statusLabels[order.status] ?? order.status, statusColors[order.status] ?? Colors.grey),
                ],
              ),
            ),

            // 2. Full Stamp Paper Section (Matched with JobDetailScreen)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7), // Traditional Amber/Gold
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Text(
                          isUrdu ? 'اسٹام پیپر' : 'STAMP PAPER',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: Colors.amber.shade900,
                            fontFamily: fontFamily,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isUrdu ? 'کام کی مکمل تفصیل' : 'FULL WORK DETAILS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade800,
                            fontFamily: fontFamily,
                          ),
                        ),
                        const Divider(thickness: 1.5, color: Colors.amber, indent: 40, endIndent: 40),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildScopeWithExclusions(order.lockedScope ?? order.workDescription),
                  const SizedBox(height: 20),
                  const Divider(thickness: 1, color: Colors.amber),
                  const SizedBox(height: 8),
                  
                  // Terms at bottom
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStampTextItem(
                        label: isUrdu ? 'طے شدہ رقم' : 'Agreed Amount',
                        value: order.amount != null && order.amount! > 0 
                            ? 'Rs. ${order.amount!.toStringAsFixed(0)}' 
                            : (isUrdu ? 'طے ہونا باقی' : 'N/A'),
                        fontFamily: fontFamily,
                      ),
                      _buildStampTextItem(
                        label: isUrdu ? 'معاہدے کی تاریخ' : 'Agreement Date',
                        value: DateFormat('dd/MM/yyyy').format(order.createdAt),
                        fontFamily: fontFamily,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 3. Action Buttons Area
            _buildActionArea(context),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeWithExclusions(String scope) {
    // Check for common exclusion markers
    final List<String> markers = [
      'اس کام میں شامل نہیں ہے:',
      'EXCLUSIONS:',
      'NOT INCLUDED:',
    ];

    String? foundMarker;
    int markerIndex = -1;

    for (var marker in markers) {
      markerIndex = scope.indexOf(marker);
      if (markerIndex != -1) {
        foundMarker = marker;
        break;
      }
    }

    if (markerIndex == -1 || foundMarker == null) {
      return Text(
        scope,
        style: TextStyle(
          fontSize: 15,
          height: 1.7,
          color: Colors.brown.shade900,
          fontFamily: fontFamily,
        ),
      );
    }

    final mainText = scope.substring(0, markerIndex).trim();
    final exclusionText = scope.substring(markerIndex + foundMarker.length).trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          mainText,
          style: TextStyle(
            fontSize: 15,
            height: 1.7,
            color: Colors.brown.shade900,
            fontFamily: fontFamily,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(thickness: 1, color: Color(0xFFFDE68A)),
        ),
        Text(
          isUrdu ? 'اس کام میں شامل نہیں ہے:' : 'NOT INCLUDED:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.red.shade700,
            fontFamily: fontFamily,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          exclusionText,
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: Colors.red.shade900,
            fontFamily: fontFamily,
          ),
        ),
      ],
    );
  }

  Widget _buildStampTextItem({required String label, required String value, required String fontFamily}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 9, color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontFamily: fontFamily)),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: Colors.brown.shade900,
            fontFamily: value.contains('Rs') ? '' : fontFamily,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
          fontFamily: fontFamily,
        ),
      ),
    );
  }

  Widget _buildActionArea(BuildContext context) {
    Widget? actionButton;

    if (isArtisanMode) {
      // Artisan Actions
      if (order.status == 'confirmed') {
        actionButton = _buildButton(
          text: isUrdu ? '🚀 کام شروع کریں' : 'Start Work',
          color: Colors.blue,
          icon: PhosphorIcons.play(),
        );
      } else if (order.status == 'in_progress') {
        actionButton = _buildButton(
          text: isUrdu ? '✅ مکمل کریں' : 'Complete',
          color: Colors.green,
          icon: PhosphorIcons.checkCircle(),
        );
      }
    } else {
      // Customer Actions
      if (order.status == 'completed') {
        actionButton = _buildButton(
          text: isUrdu ? '⭐ ریٹنگ دیں' : 'Rate Now',
          color: AppTheme.verifiedGold,
          icon: PhosphorIcons.star(),
        );
      }
    }

    if (actionButton == null && order.status != 'rated') {
      return const SizedBox(height: 8);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          if (actionButton != null) Expanded(child: actionButton),
          if (order.status == 'rated') 
            _buildRatingDisplay(),
        ],
      ),
    );
  }

  Widget _buildButton({required String text, required Color color, required IconData icon}) {
    return AppButton(
      text: text,
      onPressed: onAction,
      color: color,
      icon: icon,
      size: AppButtonSize.small,
      isFullWidth: true,
    );
  }

  Widget _buildRatingDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.goldColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.goldColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(PhosphorIcons.star(PhosphorIconsStyle.fill), color: AppTheme.goldColor, size: 16),
          const SizedBox(width: 8),
          Text(
            '${order.rating ?? 0.0}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.goldColor),
          ),
          const SizedBox(width: 8),
          Text(
            isUrdu ? 'ریٹنگ دی گئی' : 'Rating Given',
            style: TextStyle(fontSize: 12, color: AppTheme.goldColor, fontFamily: fontFamily),
          ),
        ],
      ),
    );
  }
}
