import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/features/dashboard/dashboard_screen.dart';
import 'package:account_app/features/dashboard/main_navigation_screen.dart';
import 'settings_screen.dart';
import 'profile_setup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String _verificationId = '';

  // Defined Colors
  final Color _lightColor = AppTheme.lightColor;
  final Color _themeColor = AppTheme.themeColor;
  final Color _darkColor = AppTheme.darkColor;
  final Color _goldColor = const Color(0xFFDAAD51);

  void _showTermsDialog(bool isUrdu, String fontFamily) {
    final fontWeight = FontWeight.normal;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(PhosphorIcons.shield(), color: _themeColor),
            SizedBox(width: 10),
            Text(
              isUrdu ? 'شرائط و ضوابط' : 'Terms & Conditions',
              style: TextStyle(fontFamily: fontFamily, color: _darkColor, fontWeight: isUrdu ? fontWeight : FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text.rich(
            TextSpan(
              style: TextStyle(fontFamily: fontFamily, color: Colors.grey.shade700, fontSize: 14, fontWeight: fontWeight),
              children: [
                TextSpan(
                  text: isUrdu 
                      ? 'اس ایپ کو استعمال کرکے، آپ درج ذیل شرائط سے اتفاق کرتے ہیں:\n\n' 
                      : 'By using this app, you agree to the following terms:\n\n',
                ),
                _buildTermPoint(isUrdu ? 'ڈیٹا کی ذمہ داری: ' : 'Data Responsibility: ', isUrdu ? 'آپ اپنے درج کردہ تمام ڈیٹا (آمدنی، اخراجات، لین دین) کی درستگی اور قانونی حیثیت کے مکمل طور پر خود ذمہ دار ہیں۔' : 'You are solely responsible for the accuracy and legality of all data you enter (income, expenses, transactions).', isUrdu, fontFamily),
                _buildTermPoint(isUrdu ? 'قانونی مشورہ نہیں: ' : 'Not Legal Advice: ', isUrdu ? 'یہ ایپ صرف حساب کتاب اور ریکارڈ رکھنے کے لیے ہے۔ اس میں فراہم کردہ کوئی بھی معلومات، رپورٹس یا تجزیہ قانونی، مالی یا ٹیکس سے متعلق مشورہ نہیں ہے۔' : 'This app is for accounting and record-keeping purposes only. No information, reports, or analysis provided constitutes legal, financial, or tax advice.', isUrdu, fontFamily),
                _buildTermPoint(isUrdu ? 'ڈیٹا کا نقصان: ' : 'Data Loss: ', isUrdu ? 'ہم آپ کے ڈیٹا کی حفاظت کی کوشش کرتے ہیں، لیکن ہم ڈیٹا کے کسی بھی قسم کے نقصان (حذف ہونے، کرپشن) کے ذمہ دار نہیں ہوں گے۔ اپنے ریکارڈ کا باقاعدگی سے بیک اپ بنانا آپ کی ذمہ داری ہے۔' : 'We strive to protect your data, but we are not liable for any data loss (deletion, corruption). It is your responsibility to maintain regular backups of your records.', isUrdu, fontFamily),
                _buildTermPoint(isUrdu ? 'استعمال کی حدود: ' : 'Limitation of Use: ', isUrdu ? 'اس ایپ کو کسی بھی غیر قانونی سرگرمی کے لیے استعمال نہیں کیا جا سکتا۔ ایپ کے غلط استعمال کی صورت میں آپ کے اکاؤنٹ کو بغیر اطلاع کے معطل کیا جا سکتا ہے۔' : 'This app may not be used for any illegal activities. Your account may be suspended without notice for misuse of the app.', isUrdu, fontFamily),
                TextSpan(
                  text: isUrdu 
                      ? '\nایپ کا استعمال جاری رکھ کر آپ ان تمام شرائط کو قبول کرتے ہیں۔' 
                      : '\nBy continuing to use the app, you accept all these terms.',
                  style: TextStyle(color: _darkColor, fontFamily: fontFamily, fontWeight: isUrdu ? fontWeight : FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(isUrdu ? 'قبول ہے' : 'Accept', style: TextStyle(fontFamily: fontFamily, color: _themeColor, fontWeight: isUrdu ? fontWeight : FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  InlineSpan _buildTermPoint(String title, String description, bool isUrdu, String fontFamily) {
    final fontWeight = FontWeight.normal;
    return TextSpan(
      children: [
        TextSpan(text: '\n• $title', style: TextStyle(fontWeight: fontWeight, color: _darkColor, fontFamily: fontFamily)),
        TextSpan(text: description, style: TextStyle(fontFamily: fontFamily, fontWeight: fontWeight)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final fontWeight = FontWeight.normal;

    // Calculate available height to enable scrolling when keyboard is open
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final availableHeight = size.height - padding.top - padding.bottom;

    return Scaffold(
      backgroundColor: _themeColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: SizedBox(
            height: availableHeight,
            child: Column(
              children: [
                // Header Section with Logo
                Expanded(
                  flex: 4,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo with Glow Effect
                        Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _themeColor,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/icons/zalooq.png',
                              width: 100,
                              height: 100,
                              //fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          'Karobari Saathi',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: '',
                            letterSpacing: 1.0,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.3),
                                offset: Offset(0, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'PRO LEDGER',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: _darkColor,
                            fontFamily: '',
                            letterSpacing: 4.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Form Section
                Expanded(
                  flex: 5,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _lightColor,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(40),
                        topRight: Radius.circular(40),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: Offset(0, -5),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(32, 40, 32, 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isUrdu ? 'خوش آمدید' : 'Welcome',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: fontWeight,
                                color: _darkColor,
                                fontFamily: fontFamily,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              isUrdu ? 'اپنے اکاؤنٹ تک رسائی حاصل کریں' : 'Sign in to access your account',
                              style: TextStyle(
                                fontSize: 14,
                                color: _darkColor.withOpacity(0.6),
                                fontFamily: fontFamily,
                                fontWeight: fontWeight,
                              ),
                            ),
                            SizedBox(height: 32),

                            // Phone Field
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              autofillHints: const [AutofillHints.telephoneNumber],
                              style: TextStyle(fontSize: 18, color: _darkColor, fontWeight: FontWeight.bold, fontFamily: ''),
                              decoration: InputDecoration(
                                labelText: isUrdu ? 'فون نمبر' : 'Phone Number',
                                labelStyle: TextStyle(color: _darkColor.withOpacity(0.6), fontFamily: fontFamily, fontWeight: fontWeight),
                                hintText: '03001234567',
                                hintStyle: TextStyle(color: _darkColor.withOpacity(0.3), fontFamily: ''),
                                prefixIcon: Icon(PhosphorIcons.phone(), color: _themeColor),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: _themeColor, width: 2),
                                ),
                                errorStyle: TextStyle(fontFamily: fontFamily, fontWeight: fontWeight),
                                contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) return isUrdu ? 'نمبر درج کریں' : 'Enter number';
                                // Normalize and validate for Pakistan numbers (10 digits after prefix)
                                String cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
                                if (cleaned.startsWith('0')) cleaned = cleaned.substring(1);
                                if (cleaned.length != 10) {
                                  return isUrdu ? 'درست نمبر لکھیں (10 ہندسے)' : 'Enter valid 10-digit number';
                                }
                                return null;
                              },
                            ),

                            // OTP Field (Animated)
                            AnimatedContainer(
                              duration: Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                              height: _verificationId.isNotEmpty ? 80 : 0,
                              margin: EdgeInsets.only(top: _verificationId.isNotEmpty ? 20 : 0),
                              child: _verificationId.isNotEmpty
                                  ? TextFormField(
                                      controller: _otpController,
                                      keyboardType: TextInputType.number,
                                      autofillHints: const [AutofillHints.oneTimeCode],
                                      textAlign: TextAlign.center,
                                      onChanged: (value) {
                                        if (value.length == 6) {
                                          _handleLogin();
                                        }
                                      },
                                      style: TextStyle(fontSize: 22, letterSpacing: 12, fontWeight: FontWeight.bold, color: _darkColor, fontFamily: ''),
                                      decoration: InputDecoration(
                                        hintText: '------',
                                        hintStyle: TextStyle(letterSpacing: 12, color: _darkColor.withOpacity(0.3), fontFamily: ''),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide.none,
                                        ),
                                        errorStyle: TextStyle(fontFamily: fontFamily, fontWeight: fontWeight),
                                        contentPadding: EdgeInsets.symmetric(vertical: 16),
                                      ),
                                    )
                                  : SizedBox(),
                            ),

                            SizedBox(height: 32),

                            // Action Button
                            AppButton(
                              text: _verificationId.isEmpty
                                  ? (isUrdu ? 'کوڈ بھیجیں' : 'Send Code')
                                  : (isUrdu ? 'تصدیق کریں' : 'Verify & Login'),
                              onPressed: _handleLogin,
                              icon: _verificationId.isEmpty ? PhosphorIcons.arrowRight() : null,
                              isLoading: _isLoading,
                              isFullWidth: true,
                              size: AppButtonSize.large,
                              color: _themeColor,
                            ),
                            
                            SizedBox(height: 24),

                            Center(
                              child: Text.rich(
                                TextSpan(
                                  style: TextStyle(color: _darkColor.withOpacity(0.5), fontSize: 12, fontFamily: fontFamily, fontWeight: fontWeight),
                                  children: [
                                    TextSpan(text: isUrdu ? 'جاری رکھنے پر آپ ' : 'By continuing, you agree to our '),
                                    TextSpan(
                                      text: isUrdu ? 'شرائط و ضوابط' : 'Terms & Conditions',
                                      style: TextStyle(color: _themeColor, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                                      recognizer: TapGestureRecognizer()..onTap = () => _showTermsDialog(isUrdu, fontFamily),
                                    ),
                                    TextSpan(text: isUrdu ? ' سے متفق ہیں' : ''),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Ensure country code is present for backend, but user only types local number
    String input = _phoneController.text.trim();
    String cleaned = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.startsWith('0')) cleaned = cleaned.substring(1);
    
    String phoneNumber = '+92$cleaned';

    try {
      if (_verificationId.isEmpty) {
        // Send OTP
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: phoneNumber,
          verificationCompleted: (PhoneAuthCredential credential) async {
            // Android only: auto-retrieval or instant verification
            try {
              if (credential.smsCode != null) {
                _otpController.text = credential.smsCode!;
              }

              await FirebaseAuth.instance.signInWithCredential(credential);
              if (!mounted) return;
              await _handleSuccessfulLogin(phoneNumber);
            } catch (e) {
              print('Auto verification error: $e');
            }
          },
          verificationFailed: (FirebaseAuthException e) {
            if (!mounted) return;
            setState(() => _isLoading = false);
            String errorMessage = e.message ?? 'Verification failed';
            if (e.code == 'invalid-phone-number') {
              errorMessage = 'The phone number is invalid.';
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
            );
          },
          codeSent: (String verificationId, int? resendToken) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _verificationId = verificationId;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('OTP code sent'),
                backgroundColor: _darkColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            if (mounted) {
              setState(() => _verificationId = verificationId);
            }
          },
        );
      } else {
        // Verify OTP
        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId,
          smsCode: _otpController.text,
        );

        await FirebaseAuth.instance.signInWithCredential(credential);
        if (!mounted) return;
        await _handleSuccessfulLogin(phoneNumber);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleSuccessfulLogin(String phoneNumber) async {
    bool isNewUser = false;
    // Save user info to Firestore
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // فائر بیس سے چیک کرنا کہ کیا صارف کا نام پہلے سے موجود ہے
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final userData = userDoc.data();
        
        // اگر ڈاکیومنٹ موجود نہیں یا نام خالی ہے، تو یہ نیا صارف ہے
        if (!userDoc.exists || userData == null || userData['name'] == null || userData['name'].toString().trim().isEmpty) {
          isNewUser = true;
        }

        // فون نمبر اور آخری لاگ ان اپڈیٹ کریں، لیکن نام کو نہیں چھیڑیں گے
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'phoneNumber': phoneNumber,
          'uid': user.uid,
          'lastLogin': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Firestore login error: $e');
    }

    await _restoreUserData();
    if (!mounted) return;

    if (mounted) {
      if (isNewUser) {
        _navigateToProfileSetup();
      } else {
        _navigateToDashboard();
      }
    }
  }

  void _navigateToProfileSetup() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const ProfileSetupScreen()),
      (route) => false,
    );
  }

  Future<void> _restoreUserData() async {
    if (!mounted) return;
    final databaseService = Provider.of<DatabaseService>(context, listen: false);
    
    if (!databaseService.isInitialized) {
      await databaseService.init();
    }

    // Clear local data before fetching new data
    await databaseService.clearLocalData();

    try {
      await databaseService.fetchFromFirebase();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data restored successfully'),
          backgroundColor: _darkColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to restore data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToDashboard() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
      (route) => false,
    );
  }
}
