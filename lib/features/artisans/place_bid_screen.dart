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
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/widgets/app_button.dart';

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
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadExistingBid();
  }

  Future<void> _loadExistingBid() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final bid = await JobService().getArtisanBid(widget.job.id, user.uid);
      if (bid != null && mounted) {
        setState(() {
          _amountController.text = bid.amount.toStringAsFixed(0);
          _daysController.text = bid.estimatedDays.toString();
          _messageController.text = bid.message;
          _isEditing = true;
        });
      }
    } catch (e) {
      debugPrint("Error loading existing bid: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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

              Text(isUrdu ? 'اپنی بولی کی رقم درج کریں' : 'Enter your bid amount', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: fontFamily, color: AppTheme.darkColor)),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _amountController, 
                label: isUrdu ? 'رقم درج کریں' : 'Amount', 
                icon: PhosphorIcons.wallet(),
                isNumber: true,
                isUrdu: isUrdu,
                fontFamily: fontFamily,
              ),

              const SizedBox(height: 16),
              Text(isUrdu ? 'کتنے دن لگیں گے؟' : 'Days to complete', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: fontFamily, color: AppTheme.darkColor)),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _daysController, 
                label: isUrdu ? 'دنوں کی تعداد' : 'Number of days', 
                icon: PhosphorIcons.clock(),
                isNumber: true,
                isUrdu: isUrdu,
                fontFamily: fontFamily,
              ),

              const SizedBox(height: 16),
              Text(isUrdu ? 'گاہک کو ایک پیغام' : 'Message to customer', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: fontFamily, color: AppTheme.darkColor)),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _messageController, 
                label: isUrdu ? 'تفصیل لکھیں' : 'Enter message', 
                icon: PhosphorIcons.chatText(),
                maxLines: 3,
                isUrdu: isUrdu,
                fontFamily: fontFamily,
              ),

              const SizedBox(height: 32),
              AppButton(
                text: isUrdu 
                    ? (_isEditing ? 'بولی اپ ڈیٹ کریں' : 'بولی جمع کریں') 
                    : (_isEditing ? 'Update Bid' : 'Submit Bid'),
                onPressed: _submitBid,
                isLoading: _isLoading,
                isFullWidth: true,
                size: AppButtonSize.large,
                color: AppTheme.darkColor,
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
          if (widget.job.estimatedBudget != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIcons.money(), size: 18, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    isUrdu 
                      ? 'گاہک کا تخمینی بجٹ: Rs. ${widget.job.estimatedBudget!.toStringAsFixed(0)}'
                      : 'Customer Est. Budget: Rs. ${widget.job.estimatedBudget!.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                      fontFamily: fontFamily,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller, 
    required String label, 
    required IconData icon,
    bool isNumber = false, 
    int maxLines = 1,
    required bool isUrdu,
    required String fontFamily,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(
        color: AppTheme.darkColor, 
        fontFamily: isNumber ? '' : fontFamily, 
        fontSize: isNumber ? 18 : 16,
      ),
      cursorColor: AppTheme.themeColor,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: isUrdu ? 'NooriNastaleeq' : '', 
          color: Colors.grey.shade600, 
          fontSize: 13, 
          fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        fillColor: const Color(0xFFF5F7F9),
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: Colors.grey.shade400)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: Colors.grey.shade400)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: AppTheme.themeColor, width: 1)),
        prefixIcon: Icon(icon, color: AppTheme.themeColor, size: 20),
      ),
      validator: (val) => val == null || val.isEmpty ? (isUrdu ? 'ضروری ہے' : 'Required') : null,
    );
  }

  Future<void> _submitBid() async {
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
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
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(isUrdu 
                ? (_isEditing ? '✅ بولی اپ ڈیٹ کر دی گئی ہے!' : '✅ بولی جمع کر دی گئی ہے!') 
                : (_isEditing ? '✅ Bid Updated!' : '✅ Bid Submitted!')), 
            backgroundColor: Colors.green
          )
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.contains('PERMISSION_DENIED')) {
          errorMsg = isUrdu ? 'اجازت نہیں ہے: براہ کرم انٹرنیٹ چیک کریں یا دوبارہ لاگ ان کریں۔' : 'Permission Denied: Please check connection or re-login.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
