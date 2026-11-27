import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:account_app/core/services/account_deletion_service.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/services/database/profile_service.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/features/dashboard/app_shell_screen.dart';
import 'package:account_app/features/settings/master_profile_screen.dart';

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
  String? _pendingPhoneNumber;
  int? _resendToken;
  Timer? _resendTimer;
  int _resendSecondsRemaining = 0;
  bool _loginCompleted = false;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _showTermsDialog(bool isUrdu, String fontFamily) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.slateColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child:
                Icon(PhosphorIcons.shieldCheck(), color: AppTheme.verifiedGold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: UrduAwareText(
              isUrdu ? 'شرائط و ضوابط' : 'Terms & Conditions',
              style: TextStyle(
                fontFamily: fontFamily,
                color: AppTheme.darkColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ]),
        content: SingleChildScrollView(
          child: UrduAwareText.rich(
            TextSpan(
              style: TextStyle(
                fontFamily: fontFamily,
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
              children: [
                TextSpan(
                  text: isUrdu
                      ? 'اس ایپ کو استعمال کرکے، آپ درج ذیل شرائط سے اتفاق کرتے ہیں:\n\n'
                      : 'By using this app, you agree to the following terms:\n\n',
                ),
                _buildTermPoint(
                    isUrdu ? 'ڈیٹا کی ذمہ داری: ' : 'Data Responsibility: ',
                    isUrdu
                        ? 'آپ اپنے درج کردہ تمام ڈیٹا (آمدنی، اخراجات، لین دین) کی درستگی اور قانونی حیثیت کے مکمل طور پر خود ذمہ دار ہیں۔'
                        : 'You are solely responsible for the accuracy and legality of all data you enter (income, expenses, transactions).',
                    isUrdu,
                    fontFamily),
                _buildTermPoint(
                    isUrdu ? 'قانونی مشورہ نہیں: ' : 'Not Legal Advice: ',
                    isUrdu
                        ? 'یہ ایپ صرف حساب کتاب اور ریکارڈ رکھنے کے لیے ہے۔ اس میں فراہم کردہ کوئی بھی معلومات، رپورٹس یا تجزیہ قانونی، مالی یا ٹیکس سے متعلق مشورہ نہیں ہے۔'
                        : 'This app is for accounting and record-keeping purposes only. No information, reports, or analysis provided constitutes legal, financial, or tax advice.',
                    isUrdu,
                    fontFamily),
                _buildTermPoint(
                    isUrdu ? 'ڈیٹا کا نقصان: ' : 'Data Loss: ',
                    isUrdu
                        ? 'ہم آپ کے ڈیٹا کی حفاظت کی کوشش کرتے ہیں، لیکن ہم ڈیٹا کے کسی بھی قسم کے نقصان (حذف ہونے، کرپشن) کے ذمہ دار نہیں ہوں گے۔ اپنے ریکارڈ کا باقاعدگی سے بیک اپ بنانا آپ کی ذمہ داری ہے۔'
                        : 'We strive to protect your data, but we are not liable for any data loss (deletion, corruption). It is your responsibility to maintain regular backups of your records.',
                    isUrdu,
                    fontFamily),
                _buildTermPoint(
                    isUrdu ? 'استعمال کی حدود: ' : 'Limitation of Use: ',
                    isUrdu
                        ? 'اس ایپ کو کسی بھی غیر قانونی سرگرمی کے لیے استعمال نہیں کیا جا سکتا۔ ایپ کے غلط استعمال کی صورت میں آپ کے اکاؤنٹ کو بغیر اطلاع کے معطل کیا جا سکتا ہے۔'
                        : 'This app may not be used for any illegal activities. Your account may be suspended without notice for misuse of the app.',
                    isUrdu,
                    fontFamily),
                TextSpan(
                  text: isUrdu
                      ? '\nایپ کا استعمال جاری رکھ کر آپ ان تمام شرائط کو قبول کرتے ہیں۔'
                      : '\nBy continuing to use the app, you accept all these terms.',
                  style: TextStyle(
                    color: AppTheme.darkColor,
                    fontFamily: fontFamily,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          AppButton(
            text: isUrdu ? 'قبول ہے' : 'Accept',
            onPressed: () => Navigator.of(context).pop(),
            color: AppTheme.verifiedGold,
            size: AppButtonSize.small,
          ),
        ],
      ),
    );
  }

  InlineSpan _buildTermPoint(
      String title, String description, bool isUrdu, String fontFamily) {
    return TextSpan(
      children: [
        TextSpan(
          text: '\n• $title',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.darkColor,
            fontFamily: fontFamily,
          ),
        ),
        TextSpan(
          text: description,
          style: TextStyle(fontFamily: fontFamily),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.slateColor, AppTheme.verifiedGold],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),
                  // Top Logo & Header
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/icons/zalooq.png',
                        width: 90,
                        height: 90,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  UrduAwareText(
                    isUrdu ? 'کاروباری ساتھی' : 'Karobari Saathi',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: fontFamily,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: UrduAwareText(
                      isUrdu ? 'پرو ڈیجیٹل کھاتہ' : 'PRO LEDGER',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.95),
                        fontFamily: fontFamily,
                        letterSpacing: isUrdu ? 0 : 3.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Full Width White Card (No Radius)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.zero,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UrduAwareText(
                            isUrdu ? 'خوش آمدید' : 'Welcome',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkColor,
                              fontFamily: fontFamily,
                            ),
                          ),
                          const SizedBox(height: 4),
                          UrduAwareText(
                            isUrdu
                                ? 'اپنے اکاؤنٹ تک رسائی کے لیے لاگ ان کریں'
                                : 'Sign in to access your account',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.darkColor.withValues(alpha: 0.65),
                              fontFamily: fontFamily,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Phone Field
                          TextFormField(
                            controller: _phoneController,
                            enabled: _verificationId.isEmpty && !_isLoading,
                            keyboardType: TextInputType.phone,
                            autofillHints: const [
                              AutofillHints.telephoneNumber
                            ],
                            style: const TextStyle(
                              fontSize: 17,
                              color: AppTheme.darkColor,
                              fontWeight: FontWeight.bold,
                              fontFamily: '',
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: isUrdu ? 'فون نمبر' : 'Phone Number',
                              labelStyle: TextStyle(
                                color:
                                    AppTheme.darkColor.withValues(alpha: 0.7),
                                fontFamily: fontFamily,
                              ),
                              hintText: '03001234567',
                              hintStyle: TextStyle(
                                color:
                                    AppTheme.darkColor.withValues(alpha: 0.3),
                                fontFamily: '',
                              ),
                              prefixIcon: Icon(
                                PhosphorIcons.phoneCall(),
                                color: AppTheme.slateColor,
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: AppTheme.verifiedGold, width: 2),
                              ),
                              errorStyle: TextStyle(fontFamily: fontFamily),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 16),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return isUrdu
                                    ? 'نمبر درج کریں'
                                    : 'Enter number';
                              }
                              if (!Formatters.isValidPhoneNumber(value)) {
                                return isUrdu
                                    ? 'درست فون نمبر لکھیں'
                                    : 'Enter a valid phone number';
                              }
                              return null;
                            },
                          ),

                          // OTP Field (Animated)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeInOut,
                            height: _verificationId.isNotEmpty ? 75 : 0,
                            margin: EdgeInsets.only(
                                top: _verificationId.isNotEmpty ? 14 : 0),
                            child: _verificationId.isNotEmpty
                                ? Column(
                                    children: [
                                      TextFormField(
                                        controller: _otpController,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                          LengthLimitingTextInputFormatter(6),
                                        ],
                                        autofillHints: const [
                                          AutofillHints.oneTimeCode
                                        ],
                                        textAlign: TextAlign.center,
                                        onChanged: (value) {
                                          if (value.length == 6) {
                                            _handleLogin();
                                          }
                                        },
                                        style: const TextStyle(
                                          fontSize: 20,
                                          letterSpacing: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.darkColor,
                                          fontFamily: '',
                                        ),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          hintText: '------',
                                          hintStyle: TextStyle(
                                            letterSpacing: 10,
                                            color: AppTheme.darkColor
                                                .withValues(alpha: 0.3),
                                            fontFamily: '',
                                          ),
                                          prefixIcon: Icon(
                                            PhosphorIcons.key(),
                                            color: AppTheme.verifiedGold,
                                          ),
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                                color: Colors.grey.shade300),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                                color: AppTheme.verifiedGold,
                                                width: 2),
                                          ),
                                          errorStyle:
                                              TextStyle(fontFamily: fontFamily),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 12),
                                        ),
                                      ),
                                    ],
                                  )
                                : const SizedBox(),
                          ),

                          Visibility(
                            visible: _verificationId.isNotEmpty,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed:
                                      _isLoading || _resendSecondsRemaining > 0
                                          ? null
                                          : _resendVerificationCode,
                                  child: UrduAwareText(
                                    isUrdu
                                        ? 'کوڈ دوبارہ بھیجیں ($_resendSecondsRemaining)'
                                        : 'Resend code ($_resendSecondsRemaining)',
                                    style: TextStyle(
                                      color: AppTheme.verifiedGold,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: fontFamily,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () {
                                          setState(() {
                                            _verificationId = '';
                                            _pendingPhoneNumber = null;
                                            _resendToken = null;
                                            _loginCompleted = false;
                                            _resendTimer?.cancel();
                                            _resendSecondsRemaining = 0;
                                            _otpController.clear();
                                          });
                                        },
                                  child: UrduAwareText(
                                    isUrdu
                                        ? 'نمبر تبدیل کریں'
                                        : 'Change number',
                                    style: TextStyle(
                                      color: AppTheme.verifiedGold,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: fontFamily,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: _verificationId.isEmpty ? 20 : 0,
                          ),

                          // Action AppButton
                          AppButton(
                            text: _verificationId.isEmpty
                                ? (isUrdu ? 'کوڈ بھیجیں' : 'Send Code')
                                : (isUrdu
                                    ? 'تصدیق اور لاگ ان'
                                    : 'Verify & Login'),
                            onPressed: _handleLogin,
                            icon: _verificationId.isEmpty
                                ? PhosphorIcons.arrowRight()
                                : PhosphorIcons.checkCircle(),
                            isLoading: _isLoading,
                            loadingTexts: isUrdu
                                ? [
                                    'کوڈ بھیجا جا رہا ہے...',
                                    'برائے مہربانی انتظار کریں...',
                                  ]
                                : [
                                    'Sending OTP...',
                                    'Please wait...',
                                  ],
                            isFullWidth: true,
                            size: AppButtonSize.large,
                            color: AppTheme.verifiedGold,
                          ),

                          const SizedBox(height: 18),

                          Center(
                            child: UrduAwareText.rich(
                              TextSpan(
                                style: TextStyle(
                                  color: AppTheme.darkColor
                                      .withValues(alpha: 0.55),
                                  fontSize: 11.5,
                                  fontFamily: fontFamily,
                                ),
                                children: [
                                  TextSpan(
                                    text: isUrdu
                                        ? 'جاری رکھنے پر آپ '
                                        : 'By continuing, you agree to our ',
                                  ),
                                  TextSpan(
                                    text: isUrdu
                                        ? 'شرائط و ضوابط'
                                        : 'Terms & Conditions',
                                    style: const TextStyle(
                                      color: AppTheme.slateColor,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () =>
                                          _showTermsDialog(isUrdu, fontFamily),
                                  ),
                                  TextSpan(
                                      text: isUrdu ? ' سے متفق ہیں۔' : '.'),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_isLoading || _loginCompleted) return;
    if (!_formKey.currentState!.validate()) return;

    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    if (_verificationId.isEmpty) {
      final phoneNumber = Formatters.toE164(_phoneController.text);
      if (phoneNumber.isEmpty) return;
      _pendingPhoneNumber = phoneNumber;
      await _sendVerificationCode(phoneNumber);
      return;
    }

    final smsCode = _otpController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(smsCode)) {
      AppToast.warning(
        context,
        isUrdu ? 'چھ ہندسوں کا کوڈ درج کریں' : 'Enter the 6-digit code',
      );
      return;
    }

    setState(() => _isLoading = true);
    var authenticated = false;
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: smsCode,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      authenticated = true;
      _loginCompleted = true;
      await _handleSuccessfulLogin(
        _pendingPhoneNumber ?? Formatters.toE164(_phoneController.text),
      );
    } catch (error) {
      await _handleLoginFailure(error, isUrdu, signOut: authenticated);
    }
  }

  Future<void> _resendVerificationCode() async {
    final phoneNumber = _pendingPhoneNumber;
    if (phoneNumber == null || _isLoading) return;
    await _sendVerificationCode(
      phoneNumber,
      forceResendingToken: _resendToken,
    );
  }

  Future<void> _sendVerificationCode(
    String phoneNumber, {
    int? forceResendingToken,
  }) async {
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        forceResendingToken: forceResendingToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          if (_loginCompleted || !mounted) return;
          _loginCompleted = true;
          var authenticated = false;
          try {
            if (credential.smsCode != null) {
              _otpController.text = credential.smsCode!;
            }
            await FirebaseAuth.instance.signInWithCredential(credential);
            authenticated = true;
            await _handleSuccessfulLogin(phoneNumber);
          } catch (error) {
            await _handleLoginFailure(error, isUrdu, signOut: authenticated);
          }
        },
        verificationFailed: (FirebaseAuthException error) {
          _loginCompleted = false;
          if (!mounted) return;
          setState(() => _isLoading = false);
          AppToast.error(context, _authErrorMessage(error, isUrdu));
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted || _loginCompleted) return;
          setState(() {
            _isLoading = false;
            _verificationId = verificationId;
            _resendToken = resendToken;
            _otpController.clear();
          });
          _startResendCountdown();
          AppToast.info(
            context,
            isUrdu ? 'او ٹی پی کوڈ بھیج دیا گیا ہے' : 'OTP code sent',
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted && !_loginCompleted) {
            setState(() => _verificationId = verificationId);
          }
        },
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppToast.error(context, _authErrorMessage(error, isUrdu));
    }
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsRemaining = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendSecondsRemaining <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendSecondsRemaining = 0);
        return;
      }
      setState(() => _resendSecondsRemaining--);
    });
  }

  Future<void> _handleLoginFailure(
    Object error,
    bool isUrdu, {
    required bool signOut,
  }) async {
    _loginCompleted = false;
    if (signOut) {
      try {
        await Provider.of<DatabaseService>(context, listen: false)
            .prepareForLogout();
      } catch (cleanupError, stackTrace) {
        debugPrint(
            'Failed to clear local data after login error: $cleanupError');
        debugPrintStack(stackTrace: stackTrace);
      }
      ProfileService.clearCache();
      await FirebaseAuth.instance.signOut();
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
    AppToast.error(context, _authErrorMessage(error, isUrdu));
  }

  String _authErrorMessage(Object error, bool isUrdu) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-verification-code':
          return isUrdu ? 'او ٹی پی کوڈ غلط ہے' : 'The OTP code is incorrect';
        case 'session-expired':
          return isUrdu
              ? 'کوڈ کی مدت ختم ہو گئی، نیا کوڈ لیں'
              : 'The code expired. Request a new one';
        case 'too-many-requests':
          return isUrdu
              ? 'بہت زیادہ کوششیں ہوئیں، کچھ دیر بعد دوبارہ کوشش کریں'
              : 'Too many attempts. Try again later';
        case 'network-request-failed':
          return isUrdu
              ? 'انٹرنیٹ کنکشن چیک کرکے دوبارہ کوشش کریں'
              : 'Check your internet connection and try again';
        case 'invalid-phone-number':
          return isUrdu ? 'درج کردہ فون نمبر غلط ہے' : 'Invalid phone number';
      }
    }
    if (error is FirebaseException &&
        (error.code == 'unavailable' ||
            error.code == 'deadline-exceeded' ||
            error.code == 'network-request-failed')) {
      return isUrdu
          ? 'انٹرنیٹ کنکشن چیک کرکے دوبارہ کوشش کریں'
          : 'Check your internet connection and try again';
    }
    debugPrint('Authentication flow failed: $error');
    return isUrdu
        ? 'لاگ ان مکمل نہیں ہو سکا، دوبارہ کوشش کریں'
        : 'Could not complete sign-in. Please try again';
  }

  Future<void> _handleSuccessfulLogin(String phoneNumber) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Authentication completed without a current user');
    }

    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(user.uid);
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    final userSnapshot = await userRef.get();
    if (!mounted) return;
    var userData = userSnapshot.data() ?? <String, dynamic>{};

    if (userData['isDeactivated'] == true) {
      final deadlineValue = userData['restoreDeadline'];
      final restoreDeadline =
          deadlineValue is Timestamp ? deadlineValue.toDate() : null;
      final hasRestoreDeadline = restoreDeadline != null;
      final deadlineText = restoreDeadline == null
          ? ''
          : MaterialLocalizations.of(context)
              .formatMediumDate(restoreDeadline.toLocal());
      final shouldRestore = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            isUrdu ? 'اکاؤنٹ حذف کرنے کی درخواست' : 'Account deletion pending',
          ),
          content: Text(
            hasRestoreDeadline
                ? (isUrdu
                    ? 'آپ کے اکاؤنٹ کو حذف کرنے کی درخواست موصول ہو چکی ہے۔ 30 دن کی مدت باقی ہو تو اسے بحال کریں۔ آخری تاریخ: $deadlineText'
                    : 'Your account is scheduled for deletion. You can restore it if the 30-day window is still open. Deadline: $deadlineText')
                : (isUrdu
                    ? 'اکاؤنٹ بحال کرنے کی مدت ختم ہو چکی ہے۔'
                    : 'The account recovery period has ended.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(isUrdu ? 'سائن آؤٹ' : 'Sign out'),
            ),
            if (hasRestoreDeadline)
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(isUrdu ? 'اکاؤنٹ بحال کریں' : 'Restore account'),
              ),
          ],
        ),
      );
      if (!mounted) return;
      if (shouldRestore == true) {
        try {
          await AccountDeletionService.restoreDeletion();
          final refreshedUser = await userRef.get();
          userData = refreshedUser.data() ?? <String, dynamic>{};
          if (userData['isDeactivated'] == true) {
            throw StateError('The account is still marked for deletion.');
          }
        } catch (error, stackTrace) {
          debugPrint('Account restoration failed: $error');
          debugPrintStack(stackTrace: stackTrace);
          await _signOutPendingDeletionUser();
          if (mounted) {
            setState(() => _isLoading = false);
            AppToast.error(
              context,
              isUrdu
                  ? 'اکاؤنٹ بحال نہیں ہو سکا۔ انٹرنیٹ چیک کریں اور تصدیق کریں کہ 30 دن کی مدت ختم نہیں ہوئی۔'
                  : 'Could not restore the account. Check your connection and confirm the 30-day window has not ended.',
            );
          }
          return;
        }
      } else {
        await _signOutPendingDeletionUser();
        if (mounted) {
          setState(() => _isLoading = false);
          AppToast.warning(
            context,
            isUrdu
                ? 'اکاؤنٹ ابھی حذف کرنے کے لیے مقرر ہے'
                : 'The account is still scheduled for deletion',
          );
        }
        return;
      }
    }

    final storedName =
        userData['displayName'] ?? userData['name'] ?? user.displayName;
    final isNewUser = !userSnapshot.exists ||
        storedName == null ||
        storedName.toString().trim().isEmpty;
    final profileUpdates = <String, dynamic>{
      'phoneNumber': user.phoneNumber ?? phoneNumber,
      'uid': user.uid,
      'lastLogin': FieldValue.serverTimestamp(),
    };
    await userRef.set(profileUpdates, SetOptions(merge: true));
    await firestore.collection('public_profiles').doc(user.uid).set(
          ProfileService.publicProfileData(
            uid: user.uid,
            userData: {
              ...userData,
              ...profileUpdates,
              'displayName': userData['displayName'] ??
                  userData['name'] ??
                  user.displayName,
            },
            verifiedPhoneNumber: user.phoneNumber,
          ),
        );

    await _restoreUserData();
    if (!mounted) return;
    AppToast.success(
      context,
      isUrdu ? 'لاگ ان کامیاب ہو گیا' : 'Signed in successfully',
    );

    if (isNewUser) {
      _navigateToProfileSetup();
    } else {
      _navigateToDashboard();
    }
  }

  Future<void> _signOutPendingDeletionUser() async {
    try {
      await Provider.of<DatabaseService>(context, listen: false)
          .prepareForLogout();
    } catch (error, stackTrace) {
      debugPrint('Failed to clear local data for deactivated user: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    ProfileService.clearCache();
    await FirebaseAuth.instance.signOut();
    _loginCompleted = false;
  }

  void _navigateToProfileSetup() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const MasterProfileScreen()),
      (route) => false,
    );
  }

  Future<void> _restoreUserData() async {
    if (!mounted) return;
    final databaseService =
        Provider.of<DatabaseService>(context, listen: false);

    if (!databaseService.isInitialized) {
      await databaseService.init();
    }

    await databaseService.clearLocalData();

    await databaseService.fetchFromFirebase();
  }

  void _navigateToDashboard() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => AppShellScreen(key: AppShellScreen.navigationKey),
      ),
      (route) => false,
    );
  }
}
