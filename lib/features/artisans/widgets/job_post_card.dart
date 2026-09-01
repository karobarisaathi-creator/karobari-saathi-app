import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/models/job_post_model.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:account_app/core/services/database/job_service.dart';
import 'package:account_app/core/services/logging_service.dart';
import 'package:account_app/core/widgets/app_button.dart';
import '../post_job_screen.dart';

class JobPostCard extends StatefulWidget {
  final JobPost job;
  final bool isUrdu;
  final String fontFamily;
  final VoidCallback onTap;
  final String currentUserId;
  final VoidCallback? onDeleted;

  const JobPostCard({
    super.key,
    required this.job,
    required this.isUrdu,
    required this.fontFamily,
    required this.onTap,
    required this.currentUserId,
    this.onDeleted,
  });

  @override
  State<JobPostCard> createState() => _JobPostCardState();
}

class _JobPostCardState extends State<JobPostCard> {
  @override
  Widget build(BuildContext context) {
    final bool isOwner = widget.job.customerId == widget.currentUserId;

    // تفصیل سے نشانات (Bullets) ختم کریں اور تازہ ترین ڈیٹا لیں
    String cleanDescription = widget.job.description.replaceAll(RegExp(r'(•|★|✓|\d+\.)\s*'), '').trim();
    if (cleanDescription.isEmpty && widget.job.description.isNotEmpty) {
      cleanDescription = widget.job.description;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // عنوان، کمپنی ٹیگ اور مینو (ٹاپ لائن)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // عنوان اور تاریخ (پہلے)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.job.title.isNotEmpty)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  widget.job.title,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                    fontFamily: widget.fontFamily,
                                  ),
                                ),
                              ),
                              if (widget.job.companyName != null && widget.job.companyName!.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(PhosphorIcons.buildings(), size: 11, color: Colors.blue),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.job.companyName!,
                                        style: TextStyle(
                                          fontSize: 11, // عنوان سے تھوڑا چھوٹا اور متوازن سائز
                                          fontWeight: FontWeight.w900,
                                          color: Colors.blue.shade900,
                                          fontFamily: widget.fontFamily,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        const SizedBox(height: 4),
                        Text(
                          Formatters.formatDate(widget.job.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // تفصیل
              if (cleanDescription.isNotEmpty)
                Text(
                  cleanDescription,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black,
                    height: 1.5,
                    fontFamily: widget.fontFamily,
                  ),
                ),
              const SizedBox(height: 12),

              // ٹائمنگز اور کیٹیگریز (ایک ہی لائن میں)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    if (widget.job.timeIn != null &&
                        widget.job.timeIn!.isNotEmpty &&
                        widget.job.timeOut != null &&
                        widget.job.timeOut!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildInfoChip(
                          icon: PhosphorIcons.clock(),
                          text: '${widget.job.timeIn} - ${widget.job.timeOut}',
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ...widget.job.categories.map((catId) {
                      final prof = ArtisanService.getProfessions().firstWhere(
                        (p) => p['id'] == catId,
                        orElse: () => <String, dynamic>{'name': catId, 'id': catId},
                      );
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildInfoChip(
                          icon: PhosphorIcons.tag(),
                          text: widget.isUrdu ? prof['name'] : prof['id'],
                          color: Colors.black.withValues(alpha: 0.6),
                          bgColor: const Color(0xFFE8EAF0),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // فوٹر
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.job.location.isNotEmpty)
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIcons.mapPin(),
                            size: 14,
                            color: Colors.black,
                          ),
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
                  if (widget.job.estimatedBudget != null)
                    Text(
                      'Rs. ${widget.job.estimatedBudget!.toStringAsFixed(0)}${_getBudgetUnitText()}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.green.shade800,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
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

  String _getBudgetUnitText() {
    final unit = widget.job.budgetUnit;
    if (unit == null || unit == 'total') return "";
    
    switch (unit) {
      case 'hourly': return widget.isUrdu ? " / فی گھنٹہ" : " / Hr";
      case 'daily': return widget.isUrdu ? " / فی دیہاڑی" : " / Day";
      case 'monthly': return widget.isUrdu ? " / فی مہینہ" : " / Mo";
      case 'contract': return widget.isUrdu ? " / ٹھیکہ" : " / Contract";
      case 'per_item': return widget.isUrdu ? " / فی آئٹم" : " / Item";
      case 'sqft': return widget.isUrdu ? " / فی فٹ" : " / Sqft";
      case 'visit': return widget.isUrdu ? " / فی وزٹ" : " / Visit";
      case 'km': return widget.isUrdu ? " / فی کلومیٹر" : " / KM";
      case 'kg': return widget.isUrdu ? " / فی کلو" : " / KG";
      default: return "";
    }
  }
}
