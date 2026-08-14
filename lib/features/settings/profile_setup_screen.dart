import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/theme/app_theme.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  _ProfileSetupScreenState createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final fontWeight = isUrdu ? FontWeight.bold : FontWeight.normal;

    return Scaffold(
      appBar: CustomAppBar(
        title: isUrdu ? 'پروفائل مکمل کریں' : 'Complete Profile',
        showBackButton: false,
        leading: Icon(PhosphorIcons.userCirclePlus(), color: Colors.white),
        backgroundColor: AppTheme.darkColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Phone Number Display (Read-only)
              Card(
                child: ListTile(
                  leading: Icon(PhosphorIcons.phone(), color: AppTheme.themeColor),
                  title: Text(
                    isUrdu ? 'فون نمبر' : 'Phone Number',
                    style: TextStyle(fontFamily: fontFamily, fontWeight: fontWeight),
                  ),
                  subtitle: Text(
                    (FirebaseAuth.instance.currentUser?.phoneNumber ?? '')
                        .replaceAll('+92', '0'),
                    style: const TextStyle(fontFamily: '', fontWeight: FontWeight.bold),
                  ),
                  trailing: Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), color: Colors.green),
                ),
              ),

              SizedBox(height: 20),

              // Name Input
              TextFormField(
                controller: _nameController,
                style: TextStyle(
                  color: AppTheme.darkColor, 
                  fontFamily: fontFamily, 
                  fontSize: 16,
                  fontWeight: fontWeight
                ),
                decoration: InputDecoration(
                  labelText: isUrdu ? 'اپنا نام درج کریں' : 'Enter your name',
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0), 
                    borderSide: BorderSide(color: Colors.grey.shade400)
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0), 
                    borderSide: BorderSide(color: Colors.grey.shade400)
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0), 
                    borderSide: const BorderSide(color: AppTheme.themeColor, width: 1)
                  ),
                  prefixIcon: Icon(PhosphorIcons.user(), color: AppTheme.themeColor, size: 20),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return isUrdu ? 'نام درج کریں' : 'Please enter your name';
                  }
                  return null;
                },
              ),

              SizedBox(height: 30),

              // Complete Profile Button
              ElevatedButton(
                onPressed: _isLoading ? null : _completeProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.themeColor,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(
                        isUrdu ? 'پروفائل مکمل کریں' : 'Complete Profile',
                        style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _completeProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Update Firebase Auth Profile
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updateDisplayName(_nameController.text);
        // Force refresh user to get updated profile locally
        await user.reload(); 
      }

      // Navigate to dashboard
      Navigator.pushReplacementNamed(context, '/dashboard');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
