import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/models/job_post_model.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:account_app/core/services/database/job_service.dart';
import 'package:account_app/core/services/job_algorithm_service.dart';
import 'package:account_app/core/widgets/app_button.dart';
import '../post_job_screen.dart';

class JobPostCard extends StatefulWidget {
  final JobPost job;
  final bool isUrdu;
  final String fontFamily;
  final VoidCallback onTap;
  final String currentUserId;

  const JobPostCard({
    super.key,
    required this.job,
    required this.isUrdu,
    required this.fontFamily,
    required this.onTap,
    required this.currentUserId,
  });

  @override
  State<JobPostCard> createState() => _JobPostCardState();
}

class _JobPostCardState extends State<JobPostCard> {
  @override
  Widget build(BuildContext context) {
    final bool isOwner = widget.job.customerId == widget.currentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ============================================
                  // 1. عنوان (Title)
                  // ============================================
                  if (widget.job.title.isNotEmpty)
                    Text(
                      widget.job.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        fontFamily: widget.fontFamily,
                      ),
                    ),

                  const SizedBox(height: 2),

                  // تاریخ
                  Text(
                    Formatters.formatDate(widget.job.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ============================================
                  // 2. مواد (Description)
                  // ============================================
                  if (widget.job.description.isNotEmpty)
                    Text(
                      widget.job.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                        height: 1.5,
                        fontFamily: widget.fontFamily,
                      ),
                    ),

                  const SizedBox(height: 12),

                  // ============================================
                  // 3. ٹائمنگز اور کیٹیگریز
                  // ============================================
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (widget.job.timeIn != null &&
                          widget.job.timeIn!.isNotEmpty &&
                          widget.job.timeOut != null &&
                          widget.job.timeOut!.isNotEmpty)
                        _buildInfoChip(
                          icon: PhosphorIcons.clock(),
                          text: '${widget.job.timeIn} - ${widget.job.timeOut}',
                          color: Colors.orange.shade800,
                        ),
                      ...widget.job.categories.map((catId) {
                        final prof = ArtisanService.getProfessions().firstWhere(
                            (p) => p['id'] == catId,
                            orElse: () => {'name': catId, 'id': catId});
                        return _buildInfoChip(
                          icon: PhosphorIcons.tag(),
                          text: widget.isUrdu ? prof['name'] : prof['id'],
                          color: Colors.black.withOpacity(0.6),
                          bgColor: const Color(0xFFE8EAF0),
                        );
                      }),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ============================================
                  // 4. فوٹر (Location & Budget)
                  // ============================================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // لوکیشن
                      if (widget.job.location.isNotEmpty)
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(PhosphorIcons.mapPin(),
                                  size: 14, color: Colors.black),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  widget.job.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                    fontFamily: widget.fontFamily,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // بجٹ اور مدت
                      if (widget.job.estimatedBudget != null ||
                          widget.job.estimatedDays != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.job.estimatedBudget != null)
                              Text(
                                'Rs. ${widget.job.estimatedBudget!.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.green.shade800,
                                  fontSize: 13,
                                ),
                              ),
                            if (widget.job.estimatedBudget != null &&
                                widget.job.estimatedDays != null)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Text('|',
                                    style: TextStyle(
                                        color: Colors.grey.shade300,
                                        fontSize: 12)),
                              ),
                            if (widget.job.estimatedDays != null)
                              Text(
                                '${widget.job.estimatedDays} ${widget.isUrdu ? 'دن' : 'Days'}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                  fontFamily: widget.fontFamily,
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ٹاپ لفٹ کونے میں مینو
          if (isOwner)
            Positioned(
              top: 8,
              left: 8,
              child: _buildOptionsMenu(),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String text,
    required Color color,
    Color? bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor ?? color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
              fontFamily: widget.fontFamily,
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildOptionsMenu() {
    return PopupMenuButton<String>(
      tooltip: '', // Disable tooltip to fix Ticker error
      icon: Icon(PhosphorIcons.dotsThreeVertical(),
          color: Colors.grey[600], size: 18),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
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
              Text(widget.isUrdu ? 'ترمیم کریں' : 'Edit',
                  style: TextStyle(fontFamily: widget.fontFamily)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(PhosphorIcons.trash(), color: Colors.red, size: 18),
              const SizedBox(width: 10),
              Text(widget.isUrdu ? 'ڈیلیٹ کریں' : 'Delete',
                  style: TextStyle(fontFamily: widget.fontFamily)),
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
        content: Text(widget.isUrdu
            ? 'کیا آپ واقعی اس کام کو حذف کرنا چاہتے ہیں؟'
            : 'Are you sure you want to delete this job?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(widget.isUrdu ? 'نہیں' : 'No')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await JobService().deleteJob(widget.job.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        widget.isUrdu ? 'کام حذف کر دیا گیا' : 'Job deleted')));
              }
            },
            child: Text(widget.isUrdu ? 'ہاں' : 'Yes',
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
