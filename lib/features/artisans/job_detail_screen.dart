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
import 'package:account_app/core/models/job_bid_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'post_job_screen.dart';
import 'widgets/job_bid_card.dart';
import 'widgets/work_negotiation_popup.dart';

class JobDetailScreen extends StatefulWidget {
  final JobPost job;
  const JobDetailScreen({super.key, required this.job});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _bidAmountController = TextEditingController();
  final TextEditingController _bidMessageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isBidPanelOpen = false;
  bool _isSubmittingBid = false;
  bool _canBid = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _loadBidPermission();
  }

  Future<void> _loadBidPermission() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final profile = await ArtisanService().getProfile(userId);
    if (!mounted) return;
    setState(() => _canBid = profile != null && profile.isActive);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _bidAmountController.dispose();
    _bidMessageController.dispose();
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
                              Text(
                                freshJob.detailedScope ?? freshJob.description,
                                style: TextStyle(
                                  fontSize: 17,
                                  height: 1.7,
                                  color: Colors.black,
                                  fontFamily: fontFamily,
                                ),
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
                                Text(
                                  freshJob.exclusions!,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.red.shade900,
                                    height: 1.6,
                                    fontFamily: fontFamily,
                                  ),
                                ),
                              ],

                              const SizedBox(height: 24),
                              const Divider(height: 1),
                              const SizedBox(height: 24),

                              // 5. Category & Location Row (Moved below divider)
                              _buildCategoryAndLocationRow(
                                  isUrdu, fontFamily, freshJob),
                              const SizedBox(height: 24),

                              // 6. Job Terms (Deadline, Timings, Duration, Budget)
                              _buildJobTerms(isUrdu, fontFamily, freshJob),

                              const SizedBox(height: 24),

                              // 7. Additional Info Icons (Complex, Height, etc.)
                              _buildAdditionalInfoRow(
                                  isUrdu, fontFamily, freshJob),

                              const SizedBox(height: 32),

                              // 8. Images Gallery
                              _buildImageGallery(context, freshJob),

                              const SizedBox(height: 40),

                              // 9. Bids Section
                              _buildBidsSection(isUrdu, fontFamily,
                                  currentUserId, isOwner, freshJob),

                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bid Input Panel
                if (_isBidPanelOpen)
                  _buildBidInputPanel(isUrdu, fontFamily, freshJob),

                // Bottom Action Bar
                if (!_isBidPanelOpen && !isOwner && _canBid)
                  _buildBottomActionBar(context, isUrdu, fontFamily, freshJob),
              ],
            );
          }),
    );
  }

  Widget _buildJobTerms(bool isUrdu, String fontFamily, JobPost job) {
    return Column(
      children: [
        _buildTermItem(
          icon: PhosphorIcons.calendar(),
          label: isUrdu ? 'آخری تاریخ' : 'Deadline',
          value: Formatters.formatDate(job.deadline),
          fontFamily: fontFamily,
        ),
        if (job.timeIn != null && job.timeIn!.isNotEmpty)
          _buildTermItem(
            icon: PhosphorIcons.clock(),
            label: isUrdu ? 'ڈیوٹی ٹائمنگ' : 'Duty Timings',
            value: '${job.timeIn} - ${job.timeOut}',
            fontFamily: fontFamily,
          ),
        if (job.estimatedBudget != null)
          _buildTermItem(
            icon: PhosphorIcons.money(),
            label: isUrdu ? 'بجٹ / تنخواہ' : 'Budget / Salary',
            value: 'Rs. ${job.estimatedBudget!.toStringAsFixed(0)}',
            fontFamily: fontFamily,
            valueColor: Colors.green.shade700,
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

  Widget _buildBidsSection(bool isUrdu, String fontFamily, String currentUserId,
      bool isOwner, JobPost job) {
    return StreamBuilder<List<JobBid>>(
      stream: JobService().getJobBids(job.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final allBids = snapshot.data!;
        final visibleBids = isOwner
            ? allBids
            : allBids.where((b) => b.artisanId == currentUserId).toList();

        if (visibleBids.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(PhosphorIcons.gavel(),
                    size: 20, color: AppTheme.themeColor),
                const SizedBox(width: 8),
                Text(
                  isUrdu ? 'موصولہ بولیاں (ریٹس)' : 'Received Bids (Rates)',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: fontFamily,
                      color: AppTheme.darkColor),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppTheme.themeColor,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(visibleBids.length.toString(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleBids.length,
              itemBuilder: (context, index) {
                return JobBidCard(
                  bid: visibleBids[index],
                  isOwner: isOwner,
                  isJobOpen: job.status == 'open',
                  isUrdu: isUrdu,
                  fontFamily: fontFamily,
                  onAccept: () => _showBargainingDialog(
                      visibleBids[index], isUrdu, fontFamily, job),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildBidInputPanel(bool isUrdu, String fontFamily, JobPost job) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -10)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _isBidPanelOpen = false),
                icon: Icon(PhosphorIcons.caretDown(),
                    color: Colors.grey[600]),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isUrdu ? 'اپنی بولی (ریٹ) درج کریں' : 'Enter Your Bid (Rate)',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: fontFamily,
                      color: AppTheme.darkColor),
                ),
              ),
              AppButton(
                text: isUrdu ? 'جمع کریں' : 'Submit',
                size: AppButtonSize.small,
                isLoading: _isSubmittingBid,
                onPressed: () => _submitBidLocally(job),
              ),
            ],
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _bidAmountController,
            keyboardType: TextInputType.number,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: isUrdu
                  ? 'رقم درج کریں (مثال: 5000)'
                  : 'Enter Amount (e.g. 5000)',
              hintStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: Colors.grey[400],
                  fontFamily: fontFamily),
              prefixText: 'Rs. ',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[200]!)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[200]!)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.themeColor)),
              filled: true,
              fillColor: const Color(0xFFF5F7F9),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10),
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _bidMessageController,
            maxLines: 3,
            style: TextStyle(fontSize: 15, fontFamily: fontFamily),
            decoration: InputDecoration(
              hintText: isUrdu
                  ? 'اپنا پیغام یا مختصر تفصیل لکھیں...'
                  : 'Enter your message or short details...',
              hintStyle: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[400],
                  fontFamily: fontFamily),
              filled: true,
              fillColor: const Color(0xFFF5F7F9),
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.themeColor)),
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> _submitBidLocally(JobPost job) async {
    final amountText = _bidAmountController.text.trim();
    final messageText = _bidMessageController.text.trim();

    if (amountText.isEmpty && messageText.isEmpty) return;

    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    setState(() => _isSubmittingBid = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final artisan = await ArtisanService().getProfile(user.uid);

      final bid = JobBid(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        jobId: job.id,
        artisanId: user.uid,
        artisanName: user.displayName ?? 'Artisan',
        artisanPhone: user.phoneNumber ?? '',
        artisanPhotoUrl: user.photoURL,
        amount:
            double.tryParse(amountText) ?? 0.0,
        message: messageText,
        estimatedDays: job.estimatedDays ?? 1,
        createdAt: DateTime.now(),
        artisanRating: artisan?.rating ?? 0.0,
        artisanExperience: artisan?.experience ?? 0,
        proposedScope: job.detailedScope,
      );

      await JobService().placeBid(bid);

      if (mounted) {
        setState(() {
          _isSubmittingBid = false;
          _isBidPanelOpen = false;
          _bidAmountController.clear();
          _bidMessageController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isUrdu
                ? (amountText.isNotEmpty
                    ? 'آپ کی بولی جمع کر دی گئی ہے'
                    : 'آپ کا کمنٹ جمع کر دیا گیا ہے')
                : (amountText.isNotEmpty
                    ? 'Your bid has been submitted'
                    : 'Your comment has been submitted'))));
      }
    } catch (e) {
      if (mounted) setState(() => _isSubmittingBid = false);
      debugPrint("Error submitting bid: $e");
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
                  ? (isUrdu ? 'ریٹ دیں' : 'Give Rate')
                  : (isUrdu ? 'کام جاری ہے' : 'In Progress'),
              color: isOpen ? AppTheme.darkColor : Colors.grey,
              size: AppButtonSize.large,
              isFullWidth: true,
              onPressed:
                  isOpen ? () => setState(() => _isBidPanelOpen = true) : null,
            ),
          ),
        ],
      ),
    );
  }

  void _showBargainingDialog(
      JobBid bid, bool isUrdu, String fontFamily, JobPost job) {
    showDialog(
      context: context,
      builder: (context) => WorkNegotiationPopup(job: job, bid: bid),
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

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                  size: 16, color: Colors.red[400]),
              const SizedBox(width: 8),
              Text(
                job.location,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                  fontFamily: fontFamily,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdditionalInfoRow(bool isUrdu, String fontFamily, JobPost job) {
    final List<Map<String, dynamic>> items = [];

    if (job.isComplex == true) {
      items.add({
        'icon': PhosphorIcons.wrench(),
        'label': isUrdu ? 'مشکل کام' : 'Complex Job',
      });
    }

    if (job.requiresHeightWork == true) {
      items.add({
        'icon': PhosphorIcons.stairs(),
        'label': isUrdu ? 'اونچائی پر کام' : 'Height Work',
      });
    }

    if (job.requiresSpecialTools == true) {
      items.add({
        'icon': PhosphorIcons.toolbox(),
        'label': isUrdu ? 'خصوصی آلات' : 'Special Tools',
      });
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppTheme.themeColor.withValues(alpha: 0.8),
                width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item['icon'],
                  size: 14, color: AppTheme.darkColor),
              const SizedBox(width: 6),
              Text(
                item['label'],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkColor,
                  fontFamily: fontFamily,
                ),
              ),
            ],
          ),
        );
      }).toList(),
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
