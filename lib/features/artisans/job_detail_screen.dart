import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/models/job_post_model.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:account_app/core/services/database/job_service.dart';
import 'package:account_app/core/models/artisan_work_order_model.dart';
import 'package:account_app/core/services/artisan_work_order_service.dart';
import 'package:account_app/core/services/database/job_negotiation_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:account_app/core/widgets/location_map_widget.dart';
import 'package:account_app/core/services/notification_service.dart';
import 'package:account_app/features/dashboard/main_navigation_screen.dart';
import 'post_job_screen.dart';

class JobDetailScreen extends StatefulWidget {
  final JobPost job;
  const JobDetailScreen({super.key, required this.job});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isStartingNegotiation = false;
  bool _canContact = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _loadContactPermission();
  }

  Future<void> _loadContactPermission() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final profile = await ArtisanService().getProfile(userId);
    if (!mounted) return;
    setState(() => _canContact = profile != null && profile.isActive);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isOwner = widget.job.customerId == currentUserId;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: isUrdu ? 'کام کی مکمل تفصیل' : 'Job Details',
        actions: isOwner ? [_buildOptionsMenu(isUrdu, fontFamily)] : null,
      ),
      body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('jobs')
              .doc(widget.job.id)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());

            final jobData = snapshot.data!.data() as Map<String, dynamic>?;
            if (jobData == null)
              return const Center(child: Text('Job not found'));

            final freshJob = JobPost.fromMap(jobData);

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Customer Info Header
                              _buildCustomerHeader(
                                  isUrdu, fontFamily, freshJob),
                              const SizedBox(height: 16),

                              // 2. Title
                              if (freshJob.title.isNotEmpty) ...[
                                Text(
                                  freshJob.title,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                    fontFamily: fontFamily,
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // 3. Detailed Description
                              const SizedBox(height: 12),
                              _buildBulletPoints(
                                freshJob.detailedScope ?? freshJob.description,
                                isUrdu,
                                fontFamily,
                                Colors.black,
                              ),

                              // 4. Exclusions (If present)
                              if (freshJob.exclusions != null &&
                                  freshJob.exclusions!.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                Text(
                                  isUrdu
                                      ? 'اس کام میں شامل نہیں ہے:'
                                      : 'Not Included:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                    fontFamily: fontFamily,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildBulletPoints(
                                  freshJob.exclusions!,
                                  isUrdu,
                                  fontFamily,
                                  Colors.red.shade900,
                                ),
                              ],

                              const SizedBox(height: 24),
                              const Divider(height: 1),
                              const SizedBox(height: 24),

                              // 🔥 Location Map (Moved above profession tags)
                              LocationMapWidget(
                                latitude: freshJob.latitude,
                                longitude: freshJob.longitude,
                                address: freshJob.location,
                                isUrdu: isUrdu,
                              ),
                              const SizedBox(height: 24),

                              // 5. Category & Location Row (Moved below divider)
                              _buildCategoryAndLocationRow(
                                  isUrdu, fontFamily, freshJob),
                              const SizedBox(height: 24),

                              // 6. Job Terms (Timings, Duration, Budget)
                              _buildJobTerms(isUrdu, fontFamily, freshJob),

                              const SizedBox(height: 32),

                              // 8. Images Gallery
                              _buildImageGallery(context, freshJob),

                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Action Bar
                if (!isOwner && _canContact)
                  _buildBottomActionBar(context, isUrdu, fontFamily, freshJob),
              ],
            );
          }),
    );
  }

  Widget _buildJobTerms(bool isUrdu, String fontFamily, JobPost job) {
    String budgetLabel = isUrdu ? 'بجٹ / رقم' : 'Budget / Price';
    if (job.budgetUnit == 'monthly') budgetLabel = isUrdu ? 'ماہانہ تنخواہ' : 'Monthly Salary';
    if (job.budgetUnit == 'hourly') budgetLabel = isUrdu ? 'فی گھنٹہ اجرت' : 'Hourly Rate';
    if (job.budgetUnit == 'contract') budgetLabel = isUrdu ? 'ٹھیکہ / ماوضع' : 'Contract Price';

    String durationValue = "";
    if (job.estimatedDays != null) {
      String unit = isUrdu ? 'دن' : 'Days';
      if (job.durationUnit == 'hours') unit = isUrdu ? 'گھنٹے' : 'Hours';
      if (job.durationUnit == 'weeks') unit = isUrdu ? 'ہفتے' : 'Weeks';
      if (job.durationUnit == 'months') unit = isUrdu ? 'مہینے' : 'Months';
      durationValue = '${job.estimatedDays} $unit';
    }

    return Column(
      children: [
        if (job.timeIn != null && job.timeIn!.isNotEmpty)
          _buildTermItem(
            icon: PhosphorIcons.clock(),
            label: isUrdu ? 'ڈیوٹی ٹائمنگ' : 'Duty Timings',
            value: '${job.timeIn} - ${job.timeOut}',
            fontFamily: fontFamily,
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (job.estimatedBudget != null)
              Expanded(
                child: _buildTermItem(
                  icon: PhosphorIcons.money(),
                  label: budgetLabel,
                  value: 'Rs. ${job.estimatedBudget!.toStringAsFixed(0)}',
                  fontFamily: fontFamily,
                  valueColor: Colors.green.shade700,
                ),
              ),
            if (durationValue.isNotEmpty)
              Expanded(
                child: _buildTermItem(
                  icon: PhosphorIcons.calendarDots(),
                  label: isUrdu ? 'متوقع مدت' : 'Estimated Duration',
                  value: durationValue,
                  fontFamily: fontFamily,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTermItem({
    required IconData icon,
    required String label,
    required String value,
    required String fontFamily,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.themeColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: AppTheme.themeColor),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontFamily: fontFamily,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? Colors.black,
                  fontFamily: fontFamily,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _startNegotiation(bool isUrdu, JobPost job) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final artisanId = user.uid;
    final customerId = job.customerId;

    setState(() => _isStartingNegotiation = true);

    try {
      final orderId = 'job_neg_${job.id}';
      final existingOrder = await FirebaseFirestore.instance
          .collection('artisans')
          .doc(artisanId)
          .collection('work_orders')
          .doc(orderId)
          .get();
      ArtisanWorkOrder order;
      if (existingOrder.exists && existingOrder.data() != null) {
        order = ArtisanWorkOrder.fromMap(existingOrder.data()!);
      } else {
        order = ArtisanWorkOrder(
          id: orderId,
          artisanId: artisanId,
          artisanName: user.displayName ?? (isUrdu ? 'کاریگر' : 'Artisan'),
          customerId: customerId,
          customerName: job.customerName,
          customerPhone: '',
          title: job.title, // کام کا عنوان یہاں سیو کریں
          workDescription: job.description, // مکمل تفصیل یہاں
          status: 'negotiating',
          amount: job.estimatedBudget,
          createdAt: DateTime.now(),
          artisanAgreed: true,
        );

        await ArtisanWorkOrderService().addWorkOrder(order);

        // Send initial message
        final negService = JobNegotiationService();
        await negService.sendNegotiationMessage(
          jobId: order.id,
          artisanId: artisanId,
          message: isUrdu
              ? 'السلام علیکم! میں آپ کے کام "${job.title}" میں دلچسپی رکھتا ہوں۔ کیا ہم اس بارے میں بات کر سکتے ہیں؟'
              : 'Salam! I am interested in your job "${job.title}". Can we discuss this?',
          isDirect: true,
        );
      }

      if (mounted) {
        // 1. Set the target tab and expansion
        final notificationService = Provider.of<NotificationService>(context, listen: false);
        notificationService.setNotificationsTabIndex(1);
        notificationService.setTargetExpandOrderId(order.id);
        
        // 2. Change tab and THEN pop
        MainNavigationScreen.switchTab(4);
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Error starting negotiation: $e");
    } finally {
      if (mounted) setState(() => _isStartingNegotiation = false);
    }
  }

  Widget _buildOptionsMenu(bool isUrdu, String fontFamily) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      onSelected: (value) async {
        if (value == 'edit') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostJobScreen(jobToEdit: widget.job),
            ),
          );
        } else if (value == 'clarify') {
          _showAddClarificationDialog(isUrdu, fontFamily);
        } else if (value == 'delete') {
          _showDeleteConfirmation(isUrdu, fontFamily);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(PhosphorIcons.pencilLine(), color: Colors.blue, size: 18),
              const SizedBox(width: 10),
              Text(isUrdu ? 'ترمیم کریں' : 'Edit',
                  style: TextStyle(fontFamily: fontFamily)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'clarify',
          child: Row(
            children: [
              Icon(PhosphorIcons.info(), color: Colors.orange, size: 18),
              const SizedBox(width: 10),
              Text(isUrdu ? 'مزید تفصیل دیں' : 'Add Detail',
                  style: TextStyle(fontFamily: fontFamily)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(PhosphorIcons.trash(), color: Colors.red, size: 18),
              const SizedBox(width: 10),
              Text(isUrdu ? 'ڈیلیٹ کریں' : 'Delete',
                  style: TextStyle(fontFamily: fontFamily, color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  void _showDeleteConfirmation(bool isUrdu, String fontFamily) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isUrdu ? 'حذف کریں؟' : 'Delete?'),
        content: Text(isUrdu
            ? 'کیا آپ واقعی اس کام کو حذف کرنا چاہتے ہیں؟'
            : 'Are you sure you want to delete this job?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isUrdu ? 'نہیں' : 'No')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await JobService().deleteJob(widget.job.id);
              if (mounted && context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content:
                        Text(isUrdu ? 'کام حذف کر دیا گیا' : 'Job deleted')));
              }
            },
            child: Text(isUrdu ? 'ہاں' : 'Yes',
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddClarificationDialog(bool isUrdu, String fontFamily) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isUrdu ? 'مزید تفصیل (سب کے لیے)' : 'Add Detail (For All)',
            style:
                TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 4,
          style: TextStyle(fontFamily: fontFamily),
          decoration: InputDecoration(
            hintText: isUrdu
                ? 'یہاں کام کی مزید وضاحت لکھیں...'
                : 'Enter more details here...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isUrdu ? 'کینسل' : 'Cancel')),
          AppButton(
            text: isUrdu ? 'پوسٹ کریں' : 'Post',
            size: AppButtonSize.small,
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;

              await JobService().appendJobDetail(widget.job.id, text);

              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(
      BuildContext context, bool isUrdu, String fontFamily, JobPost job) {
    final bool isOpen = job.status == 'open';

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5))
        ],
      ),
      child: Row(
        children: [
          if (job.estimatedBudget != null) ...[
            Expanded(
              flex: 1,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isUrdu ? 'تخمینی بجٹ' : 'Est. Budget',
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  Text('Rs. ${job.estimatedBudget!.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green)),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: AppButton(
              text: isOpen
                  ? (isUrdu ? 'رابطہ کریں' : 'Contact Owner')
                  : (isUrdu ? 'کام جاری ہے' : 'In Progress'),
              color: isOpen ? AppTheme.themeColor : Colors.grey,
              size: AppButtonSize.large,
              isLoading: _isStartingNegotiation,
              isFullWidth: true,
              onPressed: isOpen ? () => _startNegotiation(isUrdu, job) : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGallery(BuildContext context, JobPost job) {
    if (job.images.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Provider.of<LanguageService>(context).isUrdu ? 'تصاویر:' : 'Images:',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: job.images.length,
            itemBuilder: (context, index) {
              return _SmartImageFrame(
                imageUrl: job.images[index],
                tag: "job_img_${job.id}_$index",
                onTap: () => _openFullScreenGallery(context, job.images, index),
                isDetail: true,
              );
            },
          ),
        ),
      ],
    );
  }

  void _openFullScreenGallery(
      BuildContext context, List<String> images, int initialIndex) {
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
                    heroAttributes: PhotoViewHeroAttributes(
                        tag: "job_img_${widget.job.id}_$index"),
                  );
                },
                scrollPhysics: const BouncingScrollPhysics(),
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                pageController: PageController(initialPage: initialIndex),
              ),
              Positioned(
                bottom: 20,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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

  Widget _buildBulletPoints(
      String text, bool isUrdu, String fontFamily, Color color) {
    final List<String> lines =
        text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        // نکتہ ہٹائیں اگر پہلے سے موجود ہے تاکہ ہم اپنی مرضی کی سپیس دے سکیں
        final cleanLine = line.replaceAll(RegExp(r'^•\s*'), '').trim();
        if (cleanLine.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (lines.length > 1) ...[
                Text(
                  "•",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color == Colors.black ? AppTheme.themeColor : color,
                  ),
                ),
                const SizedBox(width: 14), // نکتہ اور تحریر کے درمیان سپیس
              ],
              Expanded(
                child: Text(
                  cleanLine,
                  style: TextStyle(
                    fontSize: 17,
                    height: 1.5,
                    color: color,
                    fontFamily: fontFamily,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCustomerHeader(bool isUrdu, String fontFamily, JobPost job) {
    return StreamBuilder<bool>(
      stream: ArtisanService().isFavorite(job.customerId),
      builder: (context, favSnapshot) {
        final isFav = favSnapshot.data ?? false;
        return ProfileInfoWidget(
          name: job.customerName,
          phone: '',
          profileImage: job.customerPhotoUrl,
          customSize: 42,
          borderRadius: 6,
          isFavorite: isFav,
          bottom: Text(
            Formatters.formatDate(job.createdAt),
            style: TextStyle(
                fontSize: 12, color: Colors.grey[600], fontFamily: fontFamily),
          ),
        );
      },
    );
  }

  Widget _buildCategoryAndLocationRow(
      bool isUrdu, String fontFamily, JobPost job) {
    final professions = ArtisanService.getProfessions();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...job.categories.map((catId) {
          final prof = professions.firstWhere(
            (p) => p['id'] == catId,
            orElse: () => {'name': catId, 'icon': PhosphorIcons.briefcase()},
          );
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.themeColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: AppTheme.themeColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(prof['icon'], size: 16, color: AppTheme.themeColor),
                const SizedBox(width: 8),
                Text(
                  isUrdu ? prof['name'] : prof['id'],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.themeColor,
                    fontFamily: fontFamily,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
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
    double width = widget.isDetail ? 180 : 100;

    if (_aspectRatio != null) {
      if (_aspectRatio! > 1.1) {
        width = widget.isDetail ? 260 : 150;
      } else {
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
