import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:account_app/core/services/database/job_service.dart';
import 'package:account_app/core/models/job_post_model.dart';
import 'package:account_app/core/models/job_bid_model.dart';

class PlaceBidScreen extends StatefulWidget {
  final JobPost job;
  const PlaceBidScreen({super.key, required this.job});

  @override
  State<PlaceBidScreen> createState() => _PlaceBidScreenState();
}

class _PlaceBidScreenState extends State<PlaceBidScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _daysController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _messageController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Scaffold(
      appBar: CustomAppBar(
        title: isUrdu ? 'بولی لگائیں' : 'Place a Bid',
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildJobPreview(isUrdu, fontFamily),
              const SizedBox(height: 24),

              Text(isUrdu ? 'اپنی بولی کی رقم درج کریں' : 'Enter your bid amount', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: fontFamily)),
              const SizedBox(height: 8),
              _buildTextField(_amountController, 'Rs.', isNumber: true),

              const SizedBox(height: 16),
              Text(isUrdu ? 'کتنے دن لگیں گے؟' : 'Days to complete', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: fontFamily)),
              const SizedBox(height: 8),
              _buildTextField(_daysController, 'Days', isNumber: true),

              const SizedBox(height: 16),
              Text(isUrdu ? 'گاہک کو ایک پیغام' : 'Message to customer', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: fontFamily)),
              const SizedBox(height: 8),
              _buildTextField(_messageController, 'Message', maxLines: 3),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _submitBid,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.darkColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text(isUrdu ? 'بولی جمع کریں' : 'Submit Bid', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJobPreview(bool isUrdu, String fontFamily) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.job.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: fontFamily)),
          const SizedBox(height: 4),
          Text(widget.job.description, style: TextStyle(fontSize: 14, color: Colors.grey[700], fontFamily: fontFamily)),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isNumber = false, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(hintText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
    );
  }

  Future<void> _submitBid() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final artisan = await ArtisanService().getProfile(user.uid);
      
      final bid = JobBid(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        jobId: widget.job.id,
        artisanId: user.uid,
        artisanName: user.displayName ?? 'Artisan',
        artisanPhone: user.phoneNumber ?? '',
        amount: double.parse(_amountController.text),
        message: _messageController.text.trim(),
        estimatedDays: int.parse(_daysController.text),
        createdAt: DateTime.now(),
        artisanRating: artisan?.rating ?? 0.0,
        artisanExperience: artisan?.experience ?? 0,
      );

      await JobService().placeBid(bid);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Bid Submitted!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
