import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/models/artisan_work_order_model.dart';
import 'package:account_app/core/models/artisan_profile_model.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/image_selector_field.dart';
import 'package:account_app/core/services/artisan_work_order_service.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:intl/intl.dart';
import 'dart:io';

class UnifiedWorkOrderCard extends StatefulWidget {
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
  State<UnifiedWorkOrderCard> createState() => _UnifiedWorkOrderCardState();
}

class _UnifiedWorkOrderCardState extends State<UnifiedWorkOrderCard> {
  late bool _isFolded;
  bool _isUploading = false;
  List<File> _selectedFiles = [];
  List<String> _remoteImages = [];

  @override
  void initState() {
    super.initState();
    // کام مکمل یا ریٹڈ ہونے کی صورت میں کارڈ ڈیفالٹ میں فولڈ رہے گا
    _isFolded = widget.order.status == 'completed' || widget.order.status == 'rated';
    _remoteImages = List<String>.from(widget.order.workImages ?? []);
  }

  @override
  void didUpdateWidget(UnifiedWorkOrderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.order.workImages != oldWidget.order.workImages) {
      setState(() {
        _remoteImages = List<String>.from(widget.order.workImages ?? []);
      });
    }
  }

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
      'negotiating': widget.isUrdu ? 'ڈیل ہو رہی ہے' : 'Negotiating',
      'confirmed': widget.isUrdu ? 'منظور شدہ' : 'Confirmed',
      'in_progress': widget.isUrdu ? 'جاری ہے' : 'In Progress',
      'completed': widget.isUrdu ? 'مکمل' : 'Completed',
      'rated': widget.isUrdu 
          ? (widget.isArtisanMode ? 'فیڈ بیک موصول' : 'ریٹنگ دے دی گئی') 
          : (widget.isArtisanMode ? 'Feedback Received' : 'Rating Given'),
      'rejected': widget.isUrdu ? 'مسترد' : 'Rejected',
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
        onTap: () {
          if (_isFolded) {
            setState(() => _isFolded = false);
          } else if (widget.order.status == 'negotiating' || widget.order.status == 'quoted') {
            // Always allow opening negotiation popup when in these statuses
            if (widget.onTap != null) widget.onTap!();
          } else if (widget.onTap != null) {
            widget.onTap!();
          } else {
            // Toggle for all
            setState(() => _isFolded = !_isFolded);
          }
        },
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
                    child: widget.isArtisanMode
                        ? ProfileInfoWidget(
                            name: widget.order.customerName,
                            phone: widget.isUrdu ? 'گاہک / مالک' : 'Customer',
                            customSize: 42,
                            borderRadius: 6,
                          )
                        : FutureBuilder<ArtisanProfile?>(
                            future: ArtisanService().getProfile(widget.order.artisanId),
                            builder: (context, snapshot) {
                              final name = snapshot.data?.name ?? (widget.isUrdu ? 'کاریگر' : 'Artisan');
                              final profession = widget.isUrdu 
                                  ? (snapshot.data?.professionUrdu ?? '') 
                                  : (snapshot.data?.profession ?? '');
                              
                              return StreamBuilder<bool>(
                                stream: ArtisanService().isFavorite(widget.order.artisanId),
                                builder: (context, favSnapshot) {
                                  final isFav = favSnapshot.data ?? false;
                                  return ProfileInfoWidget(
                                    name: name,
                                    phone: '',
                                    category: profession,
                                    profileImage: snapshot.data?.profileImage,
                                    customSize: 42,
                                    borderRadius: 6,
                                    isFavorite: isFav,
                                    isVerticalCategory: true,
                                  );
                                },
                              );
                            },
                          ),
                  ),
                  const SizedBox(width: 8),
                  if (_isFolded && widget.order.amount != null && widget.order.amount! > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'Rs. ${widget.order.amount!.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ),
                  _buildStatusBadge(statusLabels[widget.order.status] ?? widget.order.status, statusColors[widget.order.status] ?? Colors.grey),
                  if (_isFolded) 
                    Icon(PhosphorIcons.caretDown(), size: 20, color: Colors.grey),
                ],
              ),
            ),

            if (!_isFolded) ...[
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
                            widget.isUrdu ? 'اسٹام پیپر' : 'STAMP PAPER',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: Colors.amber.shade900,
                              fontFamily: widget.fontFamily,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.isUrdu ? 'کام کی مکمل تفصیل' : 'FULL WORK DETAILS',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade800,
                              fontFamily: widget.fontFamily,
                            ),
                          ),
                          const Divider(thickness: 1.5, color: Colors.amber, indent: 40, endIndent: 40),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 250), // Limit height on card
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: _buildScopeWithExclusions(widget.order.lockedScope ?? widget.order.workDescription),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(thickness: 1, color: Colors.amber),
                    const SizedBox(height: 8),
                    
                    // Terms at bottom
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStampTextItem(
                          label: widget.isUrdu ? 'طے شدہ رقم' : 'Agreed Amount',
                          value: widget.order.amount != null && widget.order.amount! > 0 
                              ? 'Rs. ${widget.order.amount!.toStringAsFixed(0)}' 
                              : (widget.isUrdu ? 'طے ہونا باقی' : 'N/A'),
                          fontFamily: widget.fontFamily,
                        ),
                        _buildStampTextItem(
                          label: widget.isUrdu ? 'معاہدے کی تاریخ' : 'Agreement Date',
                          value: DateFormat('dd/MM/yyyy').format(widget.order.createdAt),
                          fontFamily: widget.fontFamily,
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
          fontFamily: widget.fontFamily,
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
            fontSize: 17,
            height: 1.7,
            color: Colors.brown.shade900,
            fontFamily: widget.fontFamily,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(thickness: 1, color: Color(0xFFFDE68A)),
        ),
        Text(
          widget.isUrdu ? 'اس کام میں شامل نہیں ہے:' : 'NOT INCLUDED:',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.red.shade700,
            fontFamily: widget.fontFamily,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          exclusionText,
          style: TextStyle(
            fontSize: 15,
            height: 1.6,
            color: Colors.red.shade900,
            fontFamily: widget.fontFamily,
          ),
        ),
      ],
    );
  }

  Widget _buildStampTextItem({required String label, required String value, required String fontFamily}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontFamily: fontFamily)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
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
          fontFamily: widget.fontFamily,
        ),
      ),
    );
  }

  Widget _buildActionArea(BuildContext context) {
    Widget? actionButton;

    if (widget.isArtisanMode) {
      // Artisan Actions
      if (widget.order.status == 'confirmed') {
        actionButton = _buildButton(
          text: widget.isUrdu ? 'کام شروع کریں' : 'Start Work',
          color: Colors.blue,
          icon: PhosphorIcons.play(),
        );
      } else if (widget.order.status == 'in_progress') {
        actionButton = _buildButton(
          text: widget.isUrdu ? 'مکمل کریں' : 'Complete',
          color: Colors.green,
          icon: PhosphorIcons.checkCircle(),
        );
      } else if (widget.order.status == 'negotiating' || widget.order.status == 'quoted') {
        actionButton = _buildButton(
          text: widget.isUrdu ? 'بات چیت / ریٹ طے کریں' : 'Negotiate / Set Rate',
          color: Colors.orange,
          icon: PhosphorIcons.chatCircleText(),
        );
      }
    } else {
      // Customer Actions
      if (widget.order.status == 'completed') {
        actionButton = _buildButton(
          text: widget.isUrdu ? 'ریٹنگ دیں' : 'Rate Now',
          color: AppTheme.verifiedGold,
          icon: PhosphorIcons.star(),
        );
      } else if (widget.order.status == 'negotiating' || widget.order.status == 'quoted') {
        actionButton = _buildButton(
          text: widget.isUrdu ? 'بات چیت کریں' : 'Discuss Work',
          color: Colors.orange,
          icon: PhosphorIcons.chatCircleText(),
        );
      }
    }

    final bool showImagePicker = widget.isArtisanMode && 
        (widget.order.status == 'confirmed' || widget.order.status == 'in_progress');

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          if (actionButton != null) ...[
             actionButton,
             const SizedBox(height: 12),
          ],
          
          if (showImagePicker) ...[
            ImageSelectorField(
              label: widget.isUrdu ? 'کام کی تصاویر (زیادہ سے زیادہ 5)' : 'Work Photos (Max 5)',
              selectedFiles: _selectedFiles,
              remoteUrls: _remoteImages,
              maxTotal: 5,
              onFilesChanged: (files) => setState(() => _selectedFiles = files),
              onRemoteRemoved: (index) {
                setState(() => _remoteImages.removeAt(index));
                _updateRemoteImages();
              },
            ),
            if (_selectedFiles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: AppButton(
                  text: widget.isUrdu ? 'تصاویر محفوظ کریں' : 'Save Photos',
                  onPressed: _uploadNewPhotos,
                  isLoading: _isUploading,
                  color: AppTheme.incomeColor,
                  icon: PhosphorIcons.floppyDisk(),
                  isFullWidth: true,
                ),
              ),
            const SizedBox(height: 12),
          ],

          if (widget.order.status == 'rated') 
            _buildRatingDisplay(),
        ],
      ),
    );
  }

  Future<void> _updateRemoteImages() async {
    await ArtisanWorkOrderService().updateWorkImages(
      widget.order.artisanId, 
      widget.order.id, 
      _remoteImages
    );
  }

  Future<void> _uploadNewPhotos() async {
    setState(() => _isUploading = true);
    try {
      final artisanService = ArtisanService();
      List<String> newUrls = List.from(_remoteImages);
      
      for (var file in _selectedFiles) {
        final url = await artisanService.uploadImage(widget.order.artisanId, file, 'work_order');
        if (url != null) newUrls.add(url);
      }

      await ArtisanWorkOrderService().updateWorkImages(
        widget.order.artisanId, 
        widget.order.id, 
        newUrls
      );

      if (mounted) {
        setState(() {
          _remoteImages = newUrls;
          _selectedFiles = [];
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.isUrdu ? 'تصاویر محفوظ کر لی گئیں' : 'Photos saved!')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Widget _buildButton({required String text, required Color color, required IconData icon}) {
    return AppButton(
      text: text,
      onPressed: widget.onAction,
      color: color,
      icon: icon,
      size: AppButtonSize.small,
      isFullWidth: true,
    );
  }

  Widget _buildRatingDisplay() {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.darkColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.darkColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(PhosphorIcons.star(PhosphorIconsStyle.fill), color: AppTheme.darkColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${widget.order.rating ?? 0.0}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkColor),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.isUrdu ? 'ریٹنگ دی گئی' : 'Rating Given',
                  style: TextStyle(fontSize: 12, color: AppTheme.darkColor, fontFamily: widget.fontFamily),
                ),
              ],
            ),
            if (widget.order.review != null && widget.order.review!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                widget.order.review!,
                style: TextStyle(
                  fontSize: 16, // Increased from 13
                  color: AppTheme.darkColor.withOpacity(0.9), // Slightly darker for better readability
                  fontFamily: widget.fontFamily,
                  fontWeight: FontWeight.w500, // Medium weight for visibility
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
