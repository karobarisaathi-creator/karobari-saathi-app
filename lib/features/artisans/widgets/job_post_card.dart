import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/models/job_post_model.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';

import '../job_bids_screen.dart';
import 'package:account_app/core/services/job_algorithm_service.dart';

class JobPostCard extends StatelessWidget {
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
        border: Border.all(color: Colors.grey[300]!, width: 1.2), // Darker and slightly thicker border
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Profile Info Widget
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: ProfileInfoWidget(
              name: job.customerName,
              phone: isUrdu ? 'صارف کی پوسٹ' : 'Customer Post',
              profileImage: job.customerPhotoUrl,
              customSize: 40,
              borderRadius: 10,
              bottom: Row(
                children: [
                  Text(
                    Formatters.formatDate(job.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[500],
                      fontFamily: '',
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
                  job.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkColor,
                    fontFamily: fontFamily,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  job.description,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16, // Increased from 15 to 16
                    color: Colors.grey[800], // Slightly darker for better legibility
                    height: 1.5,
                    fontFamily: fontFamily,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Info Row (Location, Deadline & Budget)
                Row(
                  children: [
                    _buildInfoItem(PhosphorIcons.mapPin(), job.location),
                    const SizedBox(width: 12),
                    _buildInfoItem(
                      PhosphorIcons.calendarCheck(), 
                      isUrdu 
                        ? 'آخری تاریخ: ${Formatters.formatDate(job.deadline)}' 
                        : 'Deadline: ${Formatters.formatDate(job.deadline)}'
                    ),
                    const Spacer(),
                    if (job.estimatedBudget != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(PhosphorIcons.money(), size: 14, color: Colors.green),
                            const SizedBox(width: 4),
                            Text(
                              'Rs. ${job.estimatedBudget!.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Footer: Bid Buttons Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                // Bids Count Button (Outline Style)
                Expanded(
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(PhosphorIcons.handPointing(), size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          '${job.bidCount} ${isUrdu ? 'بولیاں' : 'Bids'}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Action Button Logic
                Expanded(
                  child: job.status != 'open'
                      ? Container(
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isUrdu ? 'کام جاری ہے' : 'Work in Progress',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              fontFamily: fontFamily,
                              color: Colors.grey[600],
                            ),
                          ),
                        )
                      : OutlinedButton(
                          onPressed: job.customerId == currentUserId
                              ? () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => JobBidsScreen(job: job),
                                    ),
                                  )
                              : onBidTap,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: job.customerId == currentUserId
                                  ? Colors.blue
                                  : AppTheme.themeColor,
                            ),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            minimumSize: const Size(0, 38),
                            padding: EdgeInsets.zero,
                          ),
                          child: Text(
                            job.customerId == currentUserId
                                ? (isUrdu ? 'بولیاں دیکھیں' : 'View Bids')
                                : (isUrdu ? 'بولی لگائیں' : 'Place Bid'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              fontFamily: fontFamily,
                              color: job.customerId == currentUserId
                                  ? Colors.blue
                                  : AppTheme.themeColor,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrgencyBadge() {
    final urgency = JobAlgorithmService().getUrgencyLabel(job.deadline, isUrdu);
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

  Widget _buildInfoItem(IconData icon, String text, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color ?? Colors.grey[600]),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color ?? Colors.grey[700],
          ),
        ),
      ],
    );
  }
}
