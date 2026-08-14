import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'artisan_home_screen.dart';
import 'post_job_screen.dart';
import 'customer_orders_screen.dart';

class CustomerDashboardScreen extends StatelessWidget {
  const CustomerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: CustomAppBar(
        title: isUrdu ? 'گاہک ڈیش بورڈ' : 'Customer Dashboard',
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isUrdu ? 'آپ کا کام کیسے کرنا چاہیں گے؟' : 'How would you like to proceed?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: fontFamily,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isUrdu 
                  ? 'اپنی ضرورت کے مطابق کوئی ایک طریقہ منتخب کریں' 
                  : 'Choose one based on your need',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontFamily: fontFamily,
              ),
            ),
            const SizedBox(height: 24),

            _buildOptionCard(
              context: context,
              icon: PhosphorIcons.magnifyingGlass(),
              title: isUrdu ? 'کاریگر تلاش کریں' : 'Find Artisan',
              description: isUrdu 
                  ? 'فوری کام کے لیے براہ راست کاریگر تلاش کریں' 
                  : 'Find an artisan directly for quick work',
              color: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ArtisanHomeScreen()),
                );
              },
              isUrdu: isUrdu,
              fontFamily: fontFamily,
            ),

            const SizedBox(height: 16),

            _buildOptionCard(
              context: context,
              icon: PhosphorIcons.megaphone(),
              title: isUrdu ? 'کام پوسٹ کریں' : 'Post a Job',
              description: isUrdu 
                  ? 'بہترین قیمت کے لیے کام پوسٹ کریں اور بولیاں حاصل کریں' 
                  : 'Post a job and get bids for the best price',
              color: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PostJobScreen()),
                );
              },
              isUrdu: isUrdu,
              fontFamily: fontFamily,
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CustomerOrdersScreen()),
                  );
                },
                icon: Icon(PhosphorIcons.clockCounterClockwise()),
                label: Text(
                  isUrdu ? 'میرا تاریخچہ' : 'My History',
                  style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: AppTheme.themeColor.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
    required bool isUrdu,
    required String fontFamily,
  }) {
    return Card(
      elevation: 4,
      shadowColor: color.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: fontFamily,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontFamily: fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(PhosphorIcons.caretRight(), color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
