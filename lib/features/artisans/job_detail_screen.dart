// lib/features/artisans/job_detail_screen.dart
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
import 'package:account_app/core/widgets/location_map_widget.dart';
import 'package:account_app/core/services/notification_service.dart';
import 'package:account_app/features/dashboard/main_navigation_screen.dart';
import 'package:account_app/features/artisans/controllers/job_detail_controller.dart';
import 'post_job_screen.dart';

class JobDetailScreen extends StatefulWidget {
  final JobPost job;
  const JobDetailScreen({super.key, required this.job});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  late final JobDetailController _controller;

  @override
  void initState() {
    super.initState();
    _controller = JobDetailController(initialJob: widget.job);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Consumer<JobDetailController>(
        builder: (context, controller, _) {
          return _buildScreen(context, controller);
        },
      ),
    );
  }

  Widget _buildScreen(BuildContext context, JobDetailController controller) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final job = controller.currentJob ?? widget.job;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: isUrdu ? 'کام کی مکمل تفصیل' : 'Job Details',
        actions: controller.isOwner
            ? [_buildOptionsMenu(controller, isUrdu, fontFamily)]
            : null,
      ),
      body: Column(
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
                        // کسٹمر ہیڈر
                        _buildCustomerHeader(controller, isUrdu, fontFamily, job),
                        const SizedBox(height: 16),

                        // عنوان
                        if (job.title.isNotEmpty) ...[
                          Text(
                            job.title,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                              fontFamily: fontFamily,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // تفصیل
                        const SizedBox(height: 12),
                        _buildBulletPoints(
                          job.detailedScope ?? job.description,
                          isUrdu,
                          fontFamily,
                          Colors.black,
                        ),

                        // مستثنیات
                        if (job.exclusions != null &&
                            job.exclusions!.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(
                            isUrdu ? 'اس کام میں شامل نہیں ہے:' : 'Not Included:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                              fontFamily: fontFamily,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildBulletPoints(
                            job.exclusions!,
                            isUrdu,
                            fontFamily,
                            Colors.red.shade900,
                          ),
                        ],

                        const SizedBox(height: 24),
                        const Divider(height: 1),
                        const SizedBox(height: 24),

                        // لوکیشن میپ
                        LocationMapWidget(
                          latitude: job.latitude,
                          longitude: job.longitude,
                          address: job.location,
                          isUrdu: isUrdu,
                        ),
                        const SizedBox(height: 24),

                        // کیٹیگری اور لوکیشن
                        _buildCategoryAndLocationRow(isUrdu, fontFamily, job),
                        const SizedBox(height: 24),

                        // کام کی شرائط
                        _buildJobTerms(isUrdu, fontFamily, job),

                        // کمپنی کا نام (اگر موجود ہو - اب رقم کے نیچے)
                        if (job.companyName != null && job.companyName!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildCompanySection(job.companyName!, isUrdu, fontFamily),
                        ],

                        // ویب سائٹ لنک (اگر موجود ہو)
                        if (job.website != null && job.website!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildWebsiteSection(job.website!, isUrdu, fontFamily),
                        ],

                        if (job.images.isNotEmpty)
                          const SizedBox(height: 32),

                        // تصاویر گیلری
                        _buildImageGallery(context, job),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // نیچے ایکشن بار
          if (!controller.isOwner && controller.canContact)
            _buildBottomActionBar(controller, isUrdu, fontFamily, job),
        ],
      ),
    );
  }

  Widget _buildCustomerHeader(
    JobDetailController controller,
    bool isUrdu,
    String fontFamily,
    JobPost job,
  ) {
    return ProfileInfoWidget(
      name: job.customerName,
      phone: '',
      profileImage: job.customerPhotoUrl,
      customSize: 42,
      borderRadius: 6,
      isFavorite: controller.isFavorite,
      bottom: Text(
        Formatters.formatDate(job.createdAt),
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
          fontFamily: fontFamily,
        ),
      ),
    );
  }

  Widget _buildJobTerms(bool isUrdu, String fontFamily, JobPost job) {
    String budgetLabel = isUrdu ? 'رقم / اجرت' : 'Budget / Rate';
    
    switch (job.budgetUnit) {
      case 'monthly': budgetLabel = isUrdu ? 'ماہانہ تنخواہ' : 'Monthly Salary'; break;
      case 'hourly': budgetLabel = isUrdu ? 'فی گھنٹہ اجرت' : 'Hourly Rate'; break;
      case 'daily': budgetLabel = isUrdu ? 'فی دیہاڑی' : 'Daily Rate'; break;
      case 'contract': budgetLabel = isUrdu ? 'ٹھیکہ / پروجیکٹ' : 'Contract Price'; break;
      case 'per_item': budgetLabel = isUrdu ? 'فی آئٹم ریٹ' : 'Per Item Rate'; break;
      case 'sqft': budgetLabel = isUrdu ? 'فی مربع فٹ' : 'Per Sqft Rate'; break;
      case 'visit': budgetLabel = isUrdu ? 'فی وزٹ فیس' : 'Per Visit Fee'; break;
      case 'km': budgetLabel = isUrdu ? 'فی کلومیٹر کرایہ' : 'Per KM Rate'; break;
      case 'kg': budgetLabel = isUrdu ? 'فی کلو ریٹ' : 'Per KG Rate'; break;
      case 'total': budgetLabel = isUrdu ? 'کل رقم / بجٹ' : 'Total Budget'; break;
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
        if (job.estimatedBudget != null)
          _buildTermItem(
            icon: PhosphorIcons.money(),
            label: budgetLabel,
            value: 'Rs. ${job.estimatedBudget!.toStringAsFixed(0)}${_getBudgetUnitValue(job, isUrdu)}',
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
              color: AppTheme.themeColor.withValues(alpha: 0.1),
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

  Future<void> _startNegotiation(JobDetailController controller) async {
    final success = await controller.startNegotiation();

    if (!mounted || !success) return;

    // نوٹیفکیشن ٹیب پر جائیں
    final notificationService = Provider.of<NotificationService>(
      context,
      listen: false,
    );
    notificationService.setNotificationsTabIndex(1);
    notificationService.setTargetExpandOrderId('job_neg_${widget.job.id}');

    // ٹیب تبدیل کریں اور پھر پاپ کریں
    MainNavigationScreen.switchTab(4);
    Navigator.pop(context);
  }

  Widget _buildOptionsMenu(
    JobDetailController controller,
    bool isUrdu,
    String fontFamily,
  ) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      onSelected: (value) async {
        if (value == 'edit') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostJobScreen(
                jobToEdit: controller.currentJob,
              ),
            ),
          );
        } else if (value == 'delete') {
          _showDeleteConfirmation(controller, isUrdu, fontFamily);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(PhosphorIcons.pencilLine(), color: Colors.blue, size: 18),
              const SizedBox(width: 10),
              Text(
                isUrdu ? 'ترمیم کریں' : 'Edit',
                style: TextStyle(fontFamily: fontFamily),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(PhosphorIcons.trash(), color: Colors.red, size: 18),
              const SizedBox(width: 10),
              Text(
                isUrdu ? 'ڈیلیٹ کریں' : 'Delete',
                style: TextStyle(
                  fontFamily: fontFamily,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showDeleteConfirmation(
    JobDetailController controller,
    bool isUrdu,
    String fontFamily,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isUrdu ? 'حذف کریں؟' : 'Delete?'),
        content: Text(
          isUrdu
              ? 'کیا آپ واقعی اس کام کو حذف کرنا چاہتے ہیں؟'
              : 'Are you sure you want to delete this job?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isUrdu ? 'نہیں' : 'No'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await controller.deleteJob();
              if (mounted && context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isUrdu ? 'کام حذف کر دیا گیا' : 'Job deleted',
                    ),
                  ),
                );
              }
            },
            child: Text(
              isUrdu ? 'ہاں' : 'Yes',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddClarificationDialog(
    JobDetailController controller,
    bool isUrdu,
    String fontFamily,
  ) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          isUrdu ? 'مزید تفصیل (سب کے لیے)' : 'Add Detail (For All)',
          style: TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: textController,
          maxLines: 4,
          style: TextStyle(fontFamily: fontFamily),
          decoration: InputDecoration(
            hintText: isUrdu
                ? 'یہاں کام کی مزید وضاحت لکھیں...'
                : 'Enter more details here...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isUrdu ? 'کینسل' : 'Cancel'),
          ),
          AppButton(
            text: isUrdu ? 'پوسٹ کریں' : 'Post',
            size: AppButtonSize.small,
            onPressed: () async {
              await controller.addClarification(textController.text);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWebsiteSection(String website, bool isUrdu, String fontFamily) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(PhosphorIcons.globe(), color: Colors.blue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUrdu ? 'ویب سائٹ' : 'Website',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontFamily: fontFamily,
                  ),
                ),
                Text(
                  website,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanySection(String companyName, bool isUrdu, String fontFamily) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(PhosphorIcons.buildings(), color: Colors.blue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUrdu ? 'کمپنی / ادارہ' : 'Company Name',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontFamily: fontFamily,
                  ),
                ),
                Text(
                  companyName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                    fontFamily: fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getBudgetUnitValue(JobPost job, bool isUrdu) {
    final unit = job.budgetUnit;
    if (unit == null || unit == 'total') return "";

    switch (unit) {
      case 'hourly': return isUrdu ? " / فی گھنٹہ" : " / Hr";
      case 'daily': return isUrdu ? " / فی دیہاڑی" : " / Day";
      case 'monthly': return isUrdu ? " / فی مہینہ" : " / Mo";
      case 'contract': return isUrdu ? " / ٹھیکہ" : " / Contract";
      case 'per_item': return isUrdu ? " / فی آئٹم" : " / Item";
      case 'sqft': return isUrdu ? " / فی فٹ" : " / Sqft";
      case 'visit': return isUrdu ? " / فی وزٹ" : " / Visit";
      case 'km': return isUrdu ? " / فی کلومیٹر" : " / KM";
      case 'kg': return isUrdu ? " / فی کلو" : " / KG";
      default: return "";
    }
  }

  Widget _buildBottomActionBar(
    JobDetailController controller,
    bool isUrdu,
    String fontFamily,
    JobPost job,
  ) {
    final bool isOpen = job.status == 'open';

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
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
                  Text(
                    isUrdu ? 'تخمینی بجٹ' : 'Est. Budget',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  Text(
                    'Rs. ${job.estimatedBudget!.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: AppButton(
              text: isOpen
                  ? (isUrdu ? 'کام حاصل کریں' : 'Apply for Job')
                  : (isUrdu ? 'کام جاری ہے' : 'In Progress'),
              color: isOpen ? AppTheme.themeColor : Colors.grey,
              size: AppButtonSize.large,
              isLoading: controller.status == JobDetailStatus.negotiating,
              isFullWidth: true,
              onPressed: isOpen
                  ? () => _startNegotiation(controller)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGallery(BuildContext context, JobPost job) {
    if (job.images.isEmpty) return const SizedBox.shrink();

    final isUrdu = Provider.of<LanguageService>(context).isUrdu;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isUrdu ? 'تصاویر:' : 'Images:',
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
                onTap: () => _openFullScreenGallery(
                  context,
                  job.images,
                  index,
                ),
                isDetail: true,
              );
            },
          ),
        ),
      ],
    );
  }

  void _openFullScreenGallery(
    BuildContext context,
    List<String> images,
    int initialIndex,
  ) {
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
                      tag: "job_img_${widget.job.id}_$index",
                    ),
                  );
                },
                scrollPhysics: const BouncingScrollPhysics(),
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                pageController: PageController(initialPage: initialIndex),
              ),
              Positioned(
                bottom: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${initialIndex + 1} / ${images.length}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
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
    String text,
    bool isUrdu,
    String fontFamily,
    Color color,
  ) {
    final List<String> lines = text
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        // نشان اور تحریر کو الگ کرنے کی کوشش کریں
        final match = RegExp(r'^(•|★|✓|\d+\.)\s*(.*)$').firstMatch(line);
        
        if (match != null) {
          final symbol = match.group(1)!;
          final content = match.group(2)!;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22, // جگہ تھوڑی بڑھا دی
                  child: Text(
                    symbol,
                    style: TextStyle(
                      fontSize: symbol.contains('.') ? 16 : 22,
                      fontWeight: FontWeight.bold,
                      color: color == Colors.black ? AppTheme.themeColor : color,
                    ),
                  ),
                ),
                const SizedBox(width: 6), // فاصلہ مناسب کر دیا
                Expanded(
                  child: Text(
                    content,
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
        }

        // اگر کوئی نشان نہ ملے تو عام ٹیکسٹ کی طرح دکھائیں
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            line,
            style: TextStyle(
              fontSize: 17,
              height: 1.5,
              color: color,
              fontFamily: fontFamily,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCategoryAndLocationRow(
    bool isUrdu,
    String fontFamily,
    JobPost job,
  ) {
    final professions = ArtisanService.getProfessions();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...job.categories.map((catId) {
          final prof = professions.firstWhere(
            (p) => p['id'] == catId,
            orElse: () => {
              'name': catId,
              'icon': PhosphorIcons.briefcase(),
            },
          );
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFE8EAF0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  prof['icon'],
                  size: 14,
                  color: Colors.black.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                Text(
                  isUrdu ? prof['name'] : prof['id'],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black.withValues(alpha: 0.7),
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

// _SmartImageFrame کلاس کو بہتر بنایا گیا
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
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;

  @override
  void initState() {
    super.initState();
    _calculateImageSize();
  }

  void _calculateImageSize() {
    final Image image = Image.network(widget.imageUrl);
    _imageStream = image.image.resolve(const ImageConfiguration());
    
    _imageStreamListener = ImageStreamListener(
      (ImageInfo info, bool _) {
        if (mounted) {
          setState(() {
            _aspectRatio = info.image.width / info.image.height;
          });
        }
      },
      onError: (error, stackTrace) {
        // غلطی کی صورت میں ڈیفالٹ اسپیکٹ ریشو
        if (mounted) {
          setState(() {
            _aspectRatio = 1.0;
          });
        }
      },
    );
    
    _imageStream!.addListener(_imageStreamListener!);
  }

  @override
  void dispose() {
    // میموری لیک سے بچنے کے لیے لسٹنر کو ہٹائیں
    if (_imageStream != null && _imageStreamListener != null) {
      _imageStream!.removeListener(_imageStreamListener!);
    }
    super.dispose();
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
