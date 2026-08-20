import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/models/job_post_model.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import '../post_job_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:account_app/core/services/job_algorithm_service.dart';
import 'package:account_app/core/services/artisan_service.dart';
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
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Stack(
        children: [
          InkWell(
            onTap: widget.onBidTap,
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ============================================
                // 1. ہیڈر (Profile on RIGHT, Options/Tag on LEFT - RTL Support)
                // ============================================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), 
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // پروفائل انفو (Right side in RTL)
                      Flexible(
                        child: ProfileInfoWidget(
                          name: widget.job.customerName,
                          phone: '', 
                          profileImage: widget.job.customerPhotoUrl,
                          customSize: 42,
                          borderRadius: 6,
                          bottom: Row(
                            mainAxisSize: MainAxisSize.min,
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
                      
                      // مینو اور آپشنز (Left side in RTL)
                      if (widget.job.customerId == widget.currentUserId)
                        _buildOptionsMenu(),
                    ],
                  ),
                ),

                const Divider(height: 1, thickness: 0.5),

                // ============================================
                // 2. مواد (Description & Images)
                // ============================================
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // متن (4 لائنیں)
                      Text(
                        widget.job.description,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[800],
                          height: 1.6,
                          fontFamily: widget.fontFamily,
                        ),
                      ),
                      
                      if (widget.job.description.length > 150)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            widget.isUrdu ? 'مزید پڑھیں...' : 'Read More...',
                            style: TextStyle(
                              color: AppTheme.themeColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: widget.fontFamily,
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 16),
                      
                      // تصاویر
                      _buildImageGallery(),

                      const SizedBox(height: 12),

                      // شعبے (Tags) - ہمیشہ نظر آئیں گے
                      _buildCategoryTags(),

                      if (widget.job.clarifications.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildClarificationsSection(),
                      ],
                    ],
                  ),
                ),

                const Divider(height: 1, thickness: 0.5),

                // ============================================
                // 3. فوٹر (Labels: Location)
                // ============================================
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // لوکیشن لیبل
                      Expanded(
                        child: _buildFooterLabel(
                          icon: PhosphorIcons.mapPin(),
                          text: widget.job.location,
                          color: Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // بجٹ (اگر ہے)
                      if (widget.job.estimatedBudget != null)
                        Text(
                          'Rs. ${widget.job.estimatedBudget!.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLabel({required IconData icon, required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
                fontFamily: widget.fontFamily,
              ),
            ),
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

  Widget _buildCategoryTags() {
    if (widget.job.categories.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: widget.job.categories.map((catId) {
        final prof = ArtisanService.getProfessions().firstWhere(
          (p) => p['id'] == catId, 
          orElse: () => {'name': catId, 'id': catId}
        );
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.themeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.themeColor.withValues(alpha: 0.2), width: 0.5),
          ),
          child: Text(
            widget.isUrdu ? prof['name'] : prof['id'],
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.themeColor,
              fontFamily: widget.fontFamily,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildImageGallery() {
    final List<String> displayImages = widget.job.images.isNotEmpty 
        ? widget.job.images 
        : [
            'https://picsum.photos/500/300?random=1', // Landscape
            'https://picsum.photos/300/500?random=2', // Portrait
            'https://picsum.photos/500/300?random=3', // Landscape
            'https://picsum.photos/300/500?random=4', // Portrait
          ];

    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: displayImages.length,
        itemBuilder: (context, index) {
          final imageUrl = displayImages[index];
          
          return _SmartImageFrame(
            imageUrl: imageUrl,
            tag: "job_img_${widget.job.id}_$index",
            onTap: () => _openFullScreenGallery(context, displayImages, index),
            isDetail: false,
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
                    color: Colors.black.withValues(alpha: 0.5),
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

  Widget _buildClarificationsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.info(), size: 16, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                widget.isUrdu ? 'گاہک کی طرف سے وضاحت' : 'Clarifications from Customer',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                  fontFamily: widget.fontFamily,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...widget.job.clarifications.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.bold)),
                Expanded(
                  child: Text(
                    c,
                    style: TextStyle(fontSize: 13, color: Colors.blue[900], fontFamily: widget.fontFamily),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildOptionsMenu() {
    return PopupMenuButton<String>(
      icon: Icon(PhosphorIcons.dotsThreeVertical(), color: Colors.grey[600], size: 18), // Smaller size
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(), // Tight constraints for smaller look
      onSelected: (value) async {
        if (value == 'edit') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostJobScreen(jobToEdit: widget.job),
            ),
          );
        } else if (value == 'clarify') {
          _showAddClarificationDialog();
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
          value: 'clarify',
          child: Row(
            children: [
              Icon(PhosphorIcons.info(), color: Colors.orange, size: 18),
              const SizedBox(width: 10),
              Text(widget.isUrdu ? 'مزید تفصیل دیں' : 'Add Detail', style: TextStyle(fontFamily: widget.fontFamily)),
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

  void _showAddClarificationDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(widget.isUrdu ? 'مزید تفصیل (سب کے لیے)' : 'Add Detail (For All)', style: TextStyle(fontFamily: widget.fontFamily, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 4,
          style: TextStyle(fontFamily: widget.fontFamily),
          decoration: InputDecoration(
            hintText: widget.isUrdu ? 'یہاں کام کی مزید وضاحت لکھیں...' : 'Enter more details here...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.isUrdu ? 'کینسل' : 'Cancel')),
          AppButton(
            text: widget.isUrdu ? 'پوسٹ کریں' : 'Post',
            size: AppButtonSize.small,
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              
              final updatedClarifications = List<String>.from(widget.job.clarifications)..add(text);
              await JobService().updateJobClarifications(widget.job.id, updatedClarifications);
              
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class _SmartImageFrame extends StatefulWidget {
  final String imageUrl;
  final String tag;
  final VoidCallback onTap;
  final bool isDetail;

  const _SmartImageFrame({
    required this.imageUrl,
    required this.tag,
    required this.onTap,
    required this.isDetail,
  });

  @override
  State<_SmartImageFrame> createState() => _SmartImageFrameState();
}

class _SmartImageFrameState extends State<_SmartImageFrame> {
  double? _aspectRatio;

  @override
  void initState() {
    super.initState();
    _calculateImageSize();
  }

  void _calculateImageSize() {
    final Image image = Image.network(widget.imageUrl);
    image.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        if (mounted) {
          setState(() {
            _aspectRatio = info.image.width / info.image.height;
          });
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ڈیفالٹ سائز (جب تک لوڈ نہ ہو)
    double width = widget.isDetail ? 180 : 100;
    
    if (_aspectRatio != null) {
      if (_aspectRatio! > 1.1) {
        // Landscape
        width = widget.isDetail ? 260 : 150;
      } else {
        // Portrait
        width = widget.isDetail ? 110 : 70;
      }
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Hero(
        tag: widget.tag,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: width,
          margin: EdgeInsets.only(right: widget.isDetail ? 12 : 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.isDetail ? 16 : 12),
            border: Border.all(color: Colors.grey[200]!),
            image: DecorationImage(
              image: CachedNetworkImageProvider(widget.imageUrl),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}
