// lib/features/artisans/widgets/artisan_card.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/models/artisan_profile_model.dart';
import 'package:account_app/core/services/notification_service.dart';
import 'artisan_rating_stars.dart';

import 'package:account_app/core/widgets/profile_info_widget.dart';

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
  bool _isSending = false;
  String? _requestStatus; // 'pending', 'accepted', 'rejected' or null
  StreamSubscription<String?>? _requestStatusSub;

  @override
  void initState() {
    super.initState();
    _listenRequestStatus();
  }

  @override
  void dispose() {
    _requestStatusSub?.cancel();
    super.dispose();
  }

  void _listenRequestStatus() {
    final nService = Provider.of<NotificationService>(context, listen: false);
    _requestStatusSub =
        nService.artisanRequestStatusStream(widget.artisan.id).listen((status) {
      if (mounted) {
        setState(() {
          _requestStatus = status;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.artisan.id == FirebaseAuth.instance.currentUser?.uid;
    final distanceText = widget.distanceKm != null
        ? ' \u200E(${widget.distanceKm!.toStringAsFixed(1)} km)'
        : ' \u200E(0.0 km)';

    final bool isAvailable = widget.artisan.availability == 'available';

    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppTheme.themeColor.withOpacity(0.3), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                ProfileInfoWidget(
                  name: widget.artisan.name,
                  phone: '',
                  profileImage: widget.artisan.profileImage,
                  category: widget.artisan.professionUrdu,
                  address: '${widget.artisan.location}$distanceText',
                  isVerified: widget.artisan.isVerified ||
                      widget.artisan.verificationStatus == 'approved',
                  customSize: 70,
                  isVerticalCategory: true,
                  suffix: null,
                ),
                const Divider(height: 16, thickness: 0.5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        ArtisanRatingStars(
                          rating: widget.artisan.rating,
                          size: 14,
                          color: AppTheme.darkColor,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${widget.artisan.rating}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '(${widget.artisan.totalReviews} ${widget.isUrdu ? 'ریویوز' : 'Reviews'})',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontFamily: widget.fontFamily,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (widget.artisan.availability == 'available' &&
                        widget.artisan.id !=
                            FirebaseAuth.instance.currentUser?.uid)
                      _buildWorkRequestButton(
                          context, widget.isUrdu, widget.fontFamily),
                    if (widget.artisan.id ==
                        FirebaseAuth.instance.currentUser?.uid)
                      Icon(PhosphorIcons.caretRight(),
                          size: 16, color: Colors.grey),
                  ],
                ),
              ],
            ),
          ),
          // Status Badge for others
          if (!isMe)
            Positioned.directional(
              textDirection:
                  widget.isUrdu ? TextDirection.rtl : TextDirection.ltr,
              top: 0,
              end: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isAvailable ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.only(
                    topRight:
                        widget.isUrdu ? Radius.zero : const Radius.circular(16),
                    bottomLeft:
                        widget.isUrdu ? Radius.zero : const Radius.circular(16),
                    topLeft:
                        widget.isUrdu ? const Radius.circular(16) : Radius.zero,
                    bottomRight:
                        widget.isUrdu ? const Radius.circular(16) : Radius.zero,
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1), blurRadius: 4)
                  ],
                ),
                child: Text(
                  isAvailable
                      ? (widget.isUrdu ? 'دستیاب' : 'Available')
                      : (widget.isUrdu ? 'مصروف' : 'Busy'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWorkRequestButton(
      BuildContext context, bool isUrdu, String fontFamily) {
    final bool isPending = _requestStatus == 'pending';
    final bool isAccepted = _requestStatus == 'accepted';
    final bool isRejected = _requestStatus == 'rejected';

    Color btnColor = AppTheme.themeColor;
    String btnText = isUrdu ? 'کیا کام کریں گے؟' : 'Available?';
    IconData? icon;

    if (isPending) {
      btnColor = Colors.orange.shade700;
      btnText = isUrdu ? 'جواب کا انتظار' : 'Waiting...';
      icon = PhosphorIcons.clock();
    } else if (isAccepted) {
      btnColor = Colors.green.shade700;
      btnText = isUrdu ? 'منظور شدہ' : 'Accepted';
      icon = PhosphorIcons.checkCircle();
    } else if (isRejected) {
      btnColor = Colors.red.shade700;
      btnText = isUrdu ? 'دوبارہ پوچھیں' : 'Ask Again';
      icon = PhosphorIcons.arrowClockwise();
    }

    return InkWell(
      onTap: (_isSending || isPending || isAccepted)
          ? null
          : () => _sendRequest(context, isUrdu),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: btnColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: (_isSending || isPending || isAccepted)
              ? null
              : [
                  BoxShadow(
                      color: btnColor.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isSending)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            else ...[
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 14),
                const SizedBox(width: 4),
              ],
              Text(
                btnText,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: fontFamily,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _sendRequest(BuildContext context, bool isUrdu) async {
    setState(() => _isSending = true);

    final nService = Provider.of<NotificationService>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;

    try {
      await nService.sendArtisanWorkRequest(
        artisanUid: widget.artisan.id,
        customerName: user?.displayName ?? (isUrdu ? 'ایک گاہک' : 'A Customer'),
      );

      if (mounted) {
        setState(() {
          _isSending = false;
          _requestStatus = 'pending';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isUrdu
                ? 'درخواست کامیابی سے بھیج دی گئی!'
                : 'Request sent successfully!'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isUrdu
                ? 'درخواست بھیجنے میں غلطی ہوئی'
                : 'Failed to send request'),
            backgroundColor: AppTheme.expenseColor,
          ),
        );
      }
    }
  }
}
