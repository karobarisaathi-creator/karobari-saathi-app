import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/models/job_post_model.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';

import '../job_bids_screen.dart';
import '../post_job_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:account_app/core/services/job_algorithm_service.dart';
import 'package:account_app/core/services/database/job_service.dart';
import 'package:account_app/core/widgets/app_button.dart';

class JobPostCard extends StatefulWidget {
  final JobPost job;
  final bool isUrdu;
  final String fontFamily;
  final VoidCallback onBidTap;
  final String currentUserId;

  const JobPostCard({
    super.key,
    required this.job,
    required this.isUrdu,
    required this.fontFamily,
    required this.onBidTap,
    required this.currentUserId,
  });

  @override
  State<JobPostCard> createState() => _JobPostCardState();
}

class _JobPostCardState extends State<JobPostCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey[300]!, width: 1.2),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: ProfileInfoWidget(
                  name: widget.job.customerName,
                  phone: widget.isUrdu ? 'صارف کی پوسٹ' : 'Customer Post',
                  profileImage: widget.job.customerPhotoUrl,
                  customSize: 40,
                  borderRadius: 10,
                  bottom: Row(
                    children: [
                      Text(
                        Formatters.formatDate(widget.job.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildUrgencyBadge(),
                    ],
                  ),
                ),
              ),

              const Divider(height: 1, thickness: 0.5),

              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.job.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkColor,
                        fontFamily: widget.fontFamily,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => setState(() => _isExpanded = !_isExpanded),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.job.description,
                            maxLines: _isExpanded ? null : 5,
                            overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[800],
                              height: 1.5,
                              fontFamily: widget.fontFamily,
                            ),
                          ),
                          if (widget.job.description.length > 100)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _isExpanded 
                                    ? (widget.isUrdu ? 'کم دکھائیں' : 'Show Less')
                                    : (widget.isUrdu ? 'مزید دکھائیں' : 'Show More...'),
                                style: TextStyle(
                                  color: AppTheme.themeColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: widget.fontFamily,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    _buildImageGallery(),
                    
                    const SizedBox(height: 12),
                    
                    // Info Row
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _buildInfoItem(context, PhosphorIcons.mapPin(), widget.job.location),
                        _buildInfoItem(
                          context,
                          PhosphorIcons.calendarCheck(), 
                          widget.isUrdu 
                            ? 'تاریخ: ${Formatters.formatDate(widget.job.deadline)}' 
                            : 'Date: ${Formatters.formatDate(widget.job.deadline)}'
                        ),
                        if (widget.job.estimatedBudget != null)
                          _buildBudgetBadge(),
                      ],
                    ),
                  ],
                ),
              ),

              // Footer
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.darkColor.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(PhosphorIcons.handPointing(), size: 16, color: AppTheme.darkColor),
                            const SizedBox(width: 8),
                            Text(
                              '${widget.job.bidCount} ${widget.isUrdu ? 'بولیاں' : 'Bids'}',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.darkColor,
                                fontWeight: FontWeight.bold,
                                fontFamily: widget.fontFamily,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: widget.job.status != 'open'
                          ? Container(
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                widget.isUrdu ? 'کام جاری ہے' : 'Work in Progress',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: widget.fontFamily,
                                  color: Colors.grey[600],
                                ),
                              ),
                            )
                          : StreamBuilder<bool>(
                              stream: JobService().hasArtisanBid(widget.job.id, widget.currentUserId),
                              builder: (context, snapshot) {
                                final hasBid = snapshot.data ?? false;
                                final buttonColor = widget.job.customerId == widget.currentUserId
                                    ? Colors.blue
                                    : (hasBid ? Colors.green : AppTheme.themeColor);
                                    
                                final buttonText = widget.job.customerId == widget.currentUserId
                                    ? (widget.isUrdu ? 'بولیاں دیکھیں' : 'View Bids')
                                    : (hasBid 
                                        ? (widget.isUrdu ? 'بولی ایڈٹ کریں' : 'Edit Bid')
                                        : (widget.isUrdu ? 'بولی لگائیں' : 'Place Bid'));

                                return AppButton(
                                  text: buttonText,
                                  variant: AppButtonVariant.outlined,
                                  color: buttonColor,
                                  onPressed: widget.job.customerId == widget.currentUserId
                                      ? () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => JobBidsScreen(job: widget.job),
                                            ),
                                          )
                                      : widget.onBidTap,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          if (widget.job.customerId == widget.currentUserId)
            Positioned(
              left: 4,
              top: 8,
              child: _buildOptionsMenu(),
            ),
        ],
      ),
    );
  }

  Widget _buildUrgencyBadge() {
    final urgency = JobAlgorithmService().getUrgencyLabel(widget.job.deadline, widget.isUrdu);
    if (urgency.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Text(
        urgency,
        style: const TextStyle(
          color: Colors.red,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBudgetBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIcons.money(), size: 14, color: Colors.green),
          const SizedBox(width: 4),
          Text(
            widget.isUrdu 
                ? 'تخمینی بجٹ: Rs. ${widget.job.estimatedBudget!.toStringAsFixed(0)}'
                : 'Est. Budget: Rs. ${widget.job.estimatedBudget!.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.green,
              fontFamily: widget.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(BuildContext context, IconData icon, String text, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color ?? Colors.grey[600]),
        const SizedBox(width: 6),
        Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.45),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color ?? Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageGallery() {
    final List<String> displayImages = widget.job.images.isNotEmpty 
        ? widget.job.images 
        : [
            'https://picsum.photos/400/300?random=1',
            'https://picsum.photos/400/300?random=2',
            'https://picsum.photos/400/300?random=3',
          ];

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: displayImages.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _openFullScreenGallery(context, displayImages, index),
            child: Hero(
              tag: "job_img_${widget.job.id}_$index",
              child: Container(
                width: 140,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                  image: DecorationImage(
                    image: CachedNetworkImageProvider(displayImages[index]),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openFullScreenGallery(BuildContext context, List<String> images, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
          ),
          body: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              PhotoViewGallery.builder(
                itemCount: images.length,
                builder: (context, index) {
                  return PhotoViewGalleryPageOptions(
                    imageProvider: CachedNetworkImageProvider(images[index]),
                    initialScale: PhotoViewComputedScale.contained,
                    minScale: PhotoViewComputedScale.contained * 0.8,
                    maxScale: PhotoViewComputedScale.covered * 2,
                    heroAttributes: PhotoViewHeroAttributes(tag: "job_img_${widget.job.id}_$index"),
                  );
                },
                scrollPhysics: const BouncingScrollPhysics(),
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                pageController: PageController(initialPage: initialIndex),
              ),
              Positioned(
                bottom: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${initialIndex + 1} / ${images.length}",
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionsMenu() {
    return PopupMenuButton<String>(
      icon: Icon(PhosphorIcons.dotsThreeVertical(), color: Colors.grey[600]),
      padding: EdgeInsets.zero,
      onSelected: (value) async {
        if (value == 'edit') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostJobScreen(jobToEdit: widget.job),
            ),
          );
        } else if (value == 'delete') {
          _showDeleteConfirmation();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(PhosphorIcons.pencilLine(), color: Colors.blue, size: 18),
              const SizedBox(width: 10),
              Text(widget.isUrdu ? 'ترمیم کریں' : 'Edit', style: TextStyle(fontFamily: widget.fontFamily)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(PhosphorIcons.trash(), color: Colors.red, size: 18),
              const SizedBox(width: 10),
              Text(widget.isUrdu ? 'ڈیلیٹ کریں' : 'Delete', style: TextStyle(fontFamily: widget.fontFamily)),
            ],
          ),
        ),
      ],
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.isUrdu ? 'حذف کریں؟' : 'Delete?'),
        content: Text(widget.isUrdu ? 'کیا آپ واقعی اس کام کو حذف کرنا چاہتے ہیں؟' : 'Are you sure you want to delete this job?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.isUrdu ? 'نہیں' : 'No')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await JobService().deleteJob(widget.job.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(widget.isUrdu ? 'کام حذف کر دیا گیا' : 'Job deleted'))
                );
              }
            },
            child: Text(widget.isUrdu ? 'ہاں' : 'Yes', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
