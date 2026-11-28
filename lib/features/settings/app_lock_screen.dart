// lib/features/settings/app_lock_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/security_service.dart';
import 'package:account_app/core/theme/app_theme.dart';

class AppLockScreen extends StatefulWidget {
  final bool isSettingUp;
  final bool isChangingPin;
  final bool isVerifyingOnly;
  final VoidCallback? onUnlock;

  const AppLockScreen({
    super.key,
    this.isSettingUp = false,
    this.isChangingPin = false,
    this.isVerifyingOnly = false,
    this.onUnlock,
  });

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  String _enteredPin = '';
  String? _newPinCache;
  bool _isVerifyingOldPin = false;
  bool _isLoading = true;
  bool _isError = false;
  bool _isBiometricAvailable = false;
  bool _isAuthenticatingBiometrics = false;
  String? _errorTextOverride;

  @override
  void initState() {
    super.initState();
    _isVerifyingOldPin = widget.isChangingPin;
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    if (mounted) {
      setState(() => _isLoading = false);
    }
    if (!widget.isSettingUp && !_isVerifyingOldPin && !widget.isVerifyingOnly) {
      _checkBiometrics();
    }
  }

  Future<void> _checkBiometrics() async {
    final securityService =
        Provider.of<SecurityService>(context, listen: false);
    final isAvailable = await securityService.isBiometricsAvailable();
    final isEnabled = await securityService.isBiometricEnabled();

    if (mounted) {
      setState(() {
        _isBiometricAvailable = isAvailable && isEnabled;
      });

      if (_isBiometricAvailable) {
        await _authenticateWithBiometrics();
      }
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    if (_isAuthenticatingBiometrics) return;
    setState(() => _isAuthenticatingBiometrics = true);
    final securityService =
        Provider.of<SecurityService>(context, listen: false);
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    try {
      final isAuthenticated = await securityService.authenticateWithBiometrics(
        localizedReason: isUrdu
            ? 'ایپ کھولنے کے لیے اپنی شناخت کی تصدیق کریں'
            : 'Authenticate to unlock Karobari Saathi',
      );

      if (isAuthenticated && mounted) {
        widget.onUnlock?.call();
      }
    } finally {
      if (mounted) setState(() => _isAuthenticatingBiometrics = false);
    }
  }

  void _onNumberTap(String digit) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += digit;
        _isError = false;
        _errorTextOverride = null;
      });

      if (_enteredPin.length == 4) {
        _validatePin(_enteredPin);
      }
    }
  }

  void _onBackspaceTap() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _isError = false;
        _errorTextOverride = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.slateColor, // Slate Top
              AppTheme.darkColor,  // Dark Slate Center
              Color(0xFF0F172A),   // Deep Slate Bottom
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppTheme.verifiedGold),
                  ),
                )
              : Column(
                  children: [
                    if ((widget.isSettingUp ||
                            widget.isChangingPin ||
                            widget.isVerifyingOnly) &&
                        _newPinCache == null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close_rounded,
                                  color: Colors.white70),
                            ),
                          ],
                        ),
                      )
                    else
                      const SizedBox(height: 24),

                    // Header Icon & Title
                    Expanded(
                      flex: 2,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.verifiedGold.withValues(alpha: 0.35),
                                  AppTheme.verifiedGold.withValues(alpha: 0.1),
                                ],
                              ),
                              border: Border.all(
                                color: AppTheme.verifiedGold,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.verifiedGold
                                      .withValues(alpha: 0.3),
                                  blurRadius: 24,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.lock_rounded,
                              color: AppTheme.verifiedGold,
                              size: 38,
                            ),
                          ),
                          const SizedBox(height: 18),
                          UrduAwareText(
                            isUrdu ? 'کاروباری ساتھی' : 'Karobari Sathi',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              fontFamily: fontFamily,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          UrduAwareText(
                            _getStatusText(isUrdu),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.verifiedGold,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          UrduAwareText(
                            isUrdu
                                ? 'اپنا 4 ہندسوں کا پن کوڈ درج کریں'
                                : 'Enter your 4-digit security PIN',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 13,
                              fontFamily: fontFamily,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // PIN Dots Indicator (Gold & Slate Styled)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(4, (index) {
                              final isFilled = index < _enteredPin.length;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isFilled
                                      ? (_isError
                                          ? AppTheme.redColor
                                          : AppTheme.verifiedGold)
                                      : AppTheme.slateColor
                                          .withValues(alpha: 0.4),
                                  border: Border.all(
                                    color: isFilled
                                        ? (_isError
                                            ? AppTheme.redColor
                                            : AppTheme.verifiedGold)
                                        : Colors.white.withValues(alpha: 0.3),
                                    width: 1.5,
                                  ),
                                  boxShadow: isFilled
                                      ? [
                                          BoxShadow(
                                            color: (_isError
                                                    ? AppTheme.redColor
                                                    : AppTheme.verifiedGold)
                                                .withValues(alpha: 0.6),
                                            blurRadius: 10,
                                            spreadRadius: 2,
                                          )
                                        ]
                                      : [],
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 16),

                          // Error text
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: _isError
                                ? UrduAwareText(
                                    _getErrorText(isUrdu),
                                    key: const ValueKey('pin-error'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppTheme.redColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: fontFamily,
                                    ),
                                  )
                                : const SizedBox(
                                    key: ValueKey('pin-hint'),
                                    height: 18,
                                  ),
                          ),
                        ],
                      ),
                    ),

                    // Custom On-Screen Keypad (Slate background with Gold accents)
                    Container(
                      padding: const EdgeInsets.fromLTRB(32, 20, 32, 28),
                      decoration: BoxDecoration(
                        color: AppTheme.darkColor.withValues(alpha: 0.95),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(36),
                        ),
                        border: Border.all(
                          color: AppTheme.verifiedGold.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildKeypadRow(['1', '2', '3']),
                          const SizedBox(height: 16),
                          _buildKeypadRow(['4', '5', '6']),
                          const SizedBox(height: 16),
                          _buildKeypadRow(['7', '8', '9']),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _isBiometricAvailable &&
                                      !widget.isSettingUp &&
                                      !_isVerifyingOldPin &&
                                      !widget.isVerifyingOnly
                                  ? _buildKeypadActionKey(
                                      icon: Icons.fingerprint_rounded,
                                      onTap: _authenticateWithBiometrics,
                                    )
                                  : const SizedBox(width: 72, height: 72),
                              _buildKeypadButton('0'),
                              _buildKeypadActionKey(
                                icon: Icons.backspace_rounded,
                                onTap: _onBackspaceTap,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((digit) => _buildKeypadButton(digit)).toList(),
    );
  }

  Widget _buildKeypadButton(String digit) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onNumberTap(digit),
        borderRadius: BorderRadius.circular(36),
        splashColor: AppTheme.verifiedGold.withValues(alpha: 0.3),
        highlightColor: AppTheme.verifiedGold.withValues(alpha: 0.15),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.slateColor.withValues(alpha: 0.25),
            border: Border.all(
              color: AppTheme.verifiedGold.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              digit,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadActionKey({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(36),
        splashColor: AppTheme.verifiedGold.withValues(alpha: 0.3),
        highlightColor: AppTheme.verifiedGold.withValues(alpha: 0.15),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.slateColor.withValues(alpha: 0.2),
            border: Border.all(
              color: AppTheme.verifiedGold.withValues(alpha: 0.3),
              width: 1.2,
            ),
          ),
          child: Center(
            child: Icon(
              icon,
              color: AppTheme.verifiedGold,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }

  String _getStatusText(bool isUrdu) {
    if (_isVerifyingOldPin) {
      return isUrdu ? 'پرانا پن کوڈ درج کریں' : 'Enter old PIN code';
    }
    if (widget.isSettingUp || (widget.isChangingPin && !_isVerifyingOldPin)) {
      if (_newPinCache == null) {
        return isUrdu
            ? 'نیا 4 ہندسوں کا کوڈ درج کریں'
            : 'Enter new 4-digit PIN';
      } else {
        return isUrdu ? 'تصدیق کے لیے دوبارہ درج کریں' : 'Re-enter to confirm';
      }
    }
    if (widget.isVerifyingOnly) {
      return isUrdu ? 'تصدیق کے لیے پن کوڈ درج کریں' : 'Enter PIN to verify';
    }
    return isUrdu ? 'اپنا پن کوڈ درج کریں' : 'Enter your PIN code';
  }

  String _getErrorText(bool isUrdu) {
    if (_errorTextOverride != null) return _errorTextOverride!;
    if (_isVerifyingOldPin) {
      return isUrdu ? 'پرانا پن کوڈ درست نہیں ہے' : 'Old PIN is incorrect';
    }
    if (widget.isSettingUp || widget.isChangingPin) {
      return isUrdu ? 'پن کوڈ میچ نہیں ہوا' : 'PINs do not match';
    }
    return isUrdu ? 'غلط پن کوڈ' : 'Wrong PIN Code';
  }

  Future<void> _showPinFailure({
    required SecurityService securityService,
    required bool isUrdu,
    required String fallbackMessage,
  }) async {
    final retryDelay = await securityService.pinRetryDelay();
    final remainingSeconds = retryDelay.inSeconds +
        (retryDelay.inMilliseconds.remainder(1000) > 0 ? 1 : 0);
    if (!mounted) return;

    setState(() {
      _isError = true;
      _errorTextOverride = retryDelay > Duration.zero
          ? (isUrdu
              ? 'بہت زیادہ کوششیں ہو گئیں۔ $remainingSeconds سیکنڈ بعد دوبارہ کوشش کریں۔'
              : 'Too many attempts. Try again in $remainingSeconds seconds.')
          : fallbackMessage;
      _enteredPin = '';
    });
  }

  Future<void> _validatePin(String enteredPin) async {
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    final securityService =
        Provider.of<SecurityService>(context, listen: false);
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    final cleanPin = enteredPin.trim();

    try {
      if (_isVerifyingOldPin) {
        final isValid = await securityService.validatePin(cleanPin);
        if (isValid) {
          setState(() {
            _isVerifyingOldPin = false;
            _enteredPin = '';
            _isError = false;
            _errorTextOverride = null;
          });
        } else {
          await _showPinFailure(
            securityService: securityService,
            isUrdu: isUrdu,
            fallbackMessage:
                isUrdu ? 'پرانا پن کوڈ درست نہیں ہے' : 'Old PIN is incorrect',
          );
        }
        return;
      }

      if (widget.isSettingUp || widget.isChangingPin) {
        if (_newPinCache == null) {
          setState(() {
            _newPinCache = cleanPin;
            _enteredPin = '';
          });
        } else {
          if (cleanPin == _newPinCache) {
            await securityService.setNewPin(cleanPin);
            if (mounted) {
              Navigator.pop(context, true);
            }
          } else {
            setState(() {
              _isError = true;
              _errorTextOverride = null;
              _enteredPin = '';
              _newPinCache = null;
            });
          }
        }
      } else {
        final isValid = await securityService.validatePin(cleanPin);
        if (isValid) {
          if (widget.isVerifyingOnly) {
            if (mounted) {
              Navigator.pop(context, true);
            }
            return;
          }
          widget.onUnlock?.call();
        } else {
          await _showPinFailure(
            securityService: securityService,
            isUrdu: isUrdu,
            fallbackMessage: isUrdu ? 'غلط پن کوڈ' : 'Wrong PIN Code',
          );
        }
      }
    } catch (error, stackTrace) {
      debugPrint('PIN verification failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _isError = true;
        _errorTextOverride = isUrdu
            ? 'پن کی تصدیق نہیں ہو سکی۔ دوبارہ کوشش کریں۔'
            : 'Could not verify PIN. Please try again.';
        _enteredPin = '';
      });
    }
  }
}
