import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/services/database/job_service.dart';
import 'package:account_app/core/models/job_post_model.dart';
import 'package:account_app/core/models/job_bid_model.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/widgets/artisan_rating_stars.dart';
import 'package:account_app/core/services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class JobBidsScreen extends StatelessWidget {
  final JobPost job;
  const JobBidsScreen({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: CustomAppBar(
        title: isUrdu ? 'موصول شدہ بولیاں' : 'Received Bids',
      ),
      body: Column(
        children: [
          _buildJobSummary(isUrdu, fontFamily),
          Expanded(
            child: StreamBuilder<List<JobBid>>(
              stream: JobService().getJobBids(job.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final bids = snapshot.data ?? [];
                if (bids.isEmpty) return _buildEmptyState(isUrdu, fontFamily);

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: bids.length,
                  itemBuilder: (context, index) => _buildBidCard(context, bids[index], isUrdu, fontFamily),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobSummary(bool isUrdu, String fontFamily) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(job.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: fontFamily)),
          const SizedBox(height: 4),
          Text(
            '${isUrdu ? 'کل بولیاں' : 'Total Bids'}: ${job.bidCount}',
            style: TextStyle(color: AppTheme.themeColor, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildBidCard(BuildContext context, JobBid bid, bool isUrdu, String fontFamily) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bid.artisanName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: fontFamily)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text('${bid.artisanRating}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 8),
                          Text(
                            '${bid.artisanExperience} ${isUrdu ? 'سال کا تجربہ' : 'years exp.'}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  'Rs. ${bid.amount.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              bid.message,
              style: TextStyle(fontSize: 14, color: Colors.grey[700], fontFamily: fontFamily),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(PhosphorIcons.clock(), size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '${bid.estimatedDays} ${isUrdu ? 'دن' : 'days'}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => _showAcceptConfirmation(context, bid, isUrdu, fontFamily),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.themeColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(isUrdu ? 'قبول کریں' : 'Accept', style: const TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAcceptConfirmation(BuildContext context, JobBid bid, bool isUrdu, String fontFamily) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isUrdu ? 'تصدیق' : 'Confirmation', style: TextStyle(fontFamily: fontFamily)),
        content: Text(
          isUrdu 
            ? 'کیا آپ ${bid.artisanName} کی بولی قبول کرنا چاہتے ہیں؟' 
            : 'Do you want to accept the bid from ${bid.artisanName}?',
          style: TextStyle(fontFamily: fontFamily),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(isUrdu ? 'نہیں' : 'No')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              final nService = Provider.of<NotificationService>(context, listen: false);
              
              // 1. Get all bids for this job to notify them
              final bidsSnapshot = await FirebaseFirestore.instance
                  .collection('jobs')
                  .doc(job.id)
                  .collection('bids')
                  .get();

              // 2. Select the bid in DB
              await JobService().selectBid(job.id, bid.id);
              
              // 3. Send Notifications
              for (var doc in bidsSnapshot.docs) {
                final bidData = doc.data();
                final artisanId = bidData['artisanId'] as String;
                final isAccepted = doc.id == bid.id;

                await nService.sendBidStatusNotification(
                  artisanUid: artisanId,
                  jobTitle: job.title,
                  accepted: isAccepted,
                );
              }

              if (context.mounted) {
                Navigator.pop(context); // Go back to browse
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isUrdu ? 'بولی قبول کر لی گئی اور سب کو مطلع کر دیا گیا ہے!' : 'Bid Accepted and all bidders notified!'), backgroundColor: Colors.green),
                );
              }
            },
            child: Text(isUrdu ? 'جی ہاں' : 'Yes'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isUrdu, String fontFamily) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.handPointing(), size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(isUrdu ? 'ابھی تک کوئی بولی نہیں آئی' : 'No bids yet', style: TextStyle(fontSize: 18, color: Colors.grey, fontFamily: fontFamily)),
        ],
      ),
    );
  }
}
