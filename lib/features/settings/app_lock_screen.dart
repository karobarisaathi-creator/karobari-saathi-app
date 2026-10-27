// lib/features/settings/app_lock_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/security_service.dart';

class AppLockScreen extends StatefulWidget {
  final bool isSettingUp;
  final bool isChangingPin;
  final bool isVerifyingOnly; // ⭐ نیا
  final VoidCallback? onUnlock;

  const AppLockScreen({
    super.key,
    this.isSettingUp = false,
    this.isChangingPin = false,
    this.isVerifyingOnly = false, // ⭐ نیا
    this.onUnlock,
  });

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String? _newPinCache;
  bool _isVerifyingOldPin = false;
  bool _isLoading = true;
  bool _isError = false;
  bool _isBiometricAvailable = false;

  final Color _greyColor = const Color(0xFF607D8B);

  @override
  void initState() {
    super.initState();
    _isVerifyingOldPin = widget.isChangingPin;
    _loadInitialState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometricsAndFocus();
    });
  }

  Future<void> _loadInitialState() async {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkBiometricsAndFocus() async {
    // ⭐ verifyOnly کے لیے صرف keyboard — biometrics نہیں
    if (widget.isSettingUp || _isVerifyingOldPin || widget.isVerifyingOnly) {
      _showKeyboard();
      return;
    }

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
      } else {
        _showKeyboard();
      }
    }
  }

  void _showKeyboard() {
    if (mounted && !_isLoading) {
      _focusNode.requestFocus();
      SystemChannels.textInput.invokeMethod('TextInput.show');
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    final securityService =
        Provider.of<SecurityService>(context, listen: false);
    FocusScope.of(context).unfocus();

    final isAuthenticated = await securityService.authenticateWithBiometrics();

    if (isAuthenticated && mounted) {
      widget.onUnlock?.call();
    } else {
      _showKeyboard();
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1628),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned(
            top: -110,
            right: -85,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1D6ED6).withValues(alpha: 0.16),
              ),
            ),
          ),
          SafeArea(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(_greyColor),
                    ),
                  )
                : Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        child: SizedBox(
                          width: 1,
                          height: 1,
                          child: TextField(
                            controller: _pinController,
                            focusNode: _focusNode,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            showCursor: false,
                            enableSuggestions: false,
                            autocorrect: false,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              counterText: '',
                            ),
                            style: const TextStyle(color: Colors.transparent),
                            onChanged: (value) {
                              setState(() => _isError = false);
                              if (value.length == 4) _validatePin(value);
                            },
                          ),
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _showKeyboard,
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 28,
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 440),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.12),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.lock_rounded,
                                      color: Color(0xFF78B7FF),
                                      size: 34,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  UrduAwareText(
                                    isUrdu
                                        ? 'کاروباری ساتھی'
                                        : 'Karobari Sathi',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: fontFamily,
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.fromLTRB(
                                      24,
                                      30,
                                      24,
                                      24,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF14243A)
                                          .withValues(alpha: 0.94),
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.08),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.22),
                                          blurRadius: 32,
                                          offset: const Offset(0, 18),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        UrduAwareText(
                                          _getStatusText(isUrdu),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 19,
                                            height: 1.6,
                                            fontWeight: FontWeight.w700,
                                            fontFamily: fontFamily,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        UrduAwareText(
                                          isUrdu
                                              ? 'اپنا 4 ہندسوں کا پن درج کریں'
                                              : 'Enter your 4-digit PIN',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.58),
                                            fontSize: 13,
                                            fontFamily: fontFamily,
                                          ),
                                        ),
                                        const SizedBox(height: 26),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: List.generate(4, (index) {
                                            final isFilled = index <
                                                _pinController.text.length;
                                            return AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 180,
                                              ),
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 9,
                                              ),
                                              width: 54,
                                              height: 58,
                                              decoration: BoxDecoration(
                                                color: isFilled
                                                    ? const Color(0xFF1D6ED6)
                                                        .withValues(alpha: 0.2)
                                                    : Colors.white.withValues(
                                                        alpha: 0.04,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(17),
                                                border: Border.all(
                                                  color: _isError
                                                      ? Colors.redAccent
                                                      : isFilled
                                                          ? const Color(
                                                              0xFF78B7FF)
                                                          : Colors.white
                                                              .withValues(
                                                              alpha: 0.13,
                                                            ),
                                                  width: 1.4,
                                                ),
                                              ),
                                              child: Center(
                                                child: AnimatedContainer(
                                                  duration: const Duration(
                                                    milliseconds: 180,
                                                  ),
                                                  width: isFilled ? 12 : 8,
                                                  height: isFilled ? 12 : 8,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: isFilled
                                                        ? (_isError
                                                            ? Colors.redAccent
                                                            : const Color(
                                                                0xFF78B7FF,
                                                              ))
                                                        : Colors.white
                                                            .withValues(
                                                            alpha: 0.24,
                                                          ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),
                                        ),
                                        const SizedBox(height: 18),
                                        AnimatedSwitcher(
                                          duration:
                                              const Duration(milliseconds: 180),
                                          child: _isError
                                              ? UrduAwareText(
                                                  _getErrorText(isUrdu),
                                                  key: const ValueKey(
                                                      'pin-error'),
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color:
                                                        const Color(0xFFFF7B7B),
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
                                        if (_isBiometricAvailable &&
                                            !widget.isSettingUp &&
                                            !_isVerifyingOldPin &&
                                            !widget.isVerifyingOnly) ...[
                                          const SizedBox(height: 16),
                                          TextButton.icon(
                                            onPressed:
                                                _authenticateWithBiometrics,
                                            icon: const Icon(
                                              Icons.fingerprint_rounded,
                                              size: 22,
                                            ),
                                            label: UrduAwareText(
                                              isUrdu
                                                  ? 'فنگر پرنٹ سے تصدیق'
                                                  : 'Use fingerprint',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontFamily: fontFamily,
                                              ),
                                            ),
                                            style: TextButton.styleFrom(
                                              foregroundColor:
                                                  const Color(0xFF9ACBFF),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if ((widget.isSettingUp ||
                                          widget.isChangingPin ||
                                          widget.isVerifyingOnly) &&
                                      _newPinCache == null) ...[
                                    const SizedBox(height: 18),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: UrduAwareText(
                                        isUrdu ? 'واپس جائیں' : 'Cancel',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: fontFamily,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
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
    // ⭐ verifyOnly کے لیے واضح متن
    if (widget.isVerifyingOnly) {
      return isUrdu ? 'تصدیق کے لیے پن کوڈ درج کریں' : 'Enter PIN to verify';
    }
    return isUrdu ? 'اپنا پن کوڈ درج کریں' : 'Enter your PIN code';
  }

  String _getErrorText(bool isUrdu) {
    if (_isVerifyingOldPin) {
      return isUrdu ? 'پرانا پن کوڈ درست نہیں ہے' : 'Old PIN is incorrect';
    }
    if (widget.isSettingUp || widget.isChangingPin) {
      return isUrdu ? 'پن کوڈ میچ نہیں ہوا' : 'PINs do not match';
    }
    return isUrdu ? 'غلط پن کوڈ' : 'Wrong PIN Code';
  }

  Future<void> _validatePin(String enteredPin) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    final securityService =
        Provider.of<SecurityService>(context, listen: false);
    final cleanPin = enteredPin.trim();

    if (_isVerifyingOldPin) {
      final isValid = await securityService.validatePin(cleanPin);
      if (isValid) {
        setState(() {
          _isVerifyingOldPin = false;
          _pinController.clear();
          _isError = false;
        });
        _showKeyboard();
      } else {
        setState(() {
          _isError = true;
          _pinController.clear();
        });
        _showKeyboard();
      }
      return;
    }

    if (widget.isSettingUp || widget.isChangingPin) {
      if (_newPinCache == null) {
        setState(() {
          _newPinCache = cleanPin;
          _pinController.clear();
        });
        _showKeyboard();
      } else {
        if (cleanPin == _newPinCache) {
          await securityService.setNewPin(cleanPin);
          if (mounted) {
            Navigator.pop(context, true);
          }
        } else {
          setState(() {
            _isError = true;
            _pinController.clear();
            _newPinCache = null;
          });
          _showKeyboard();
        }
      }
    } else {
      // ⭐ normal unlock یا verifyOnly — دونوں کے لیے validatePin
      final isValid = await securityService.validatePin(cleanPin);
      if (isValid) {
        // ⭐ اگر صرف verify کرنا ہے تو true واپس کریں
        if (widget.isVerifyingOnly) {
          if (mounted) {
            Navigator.pop(context, true);
          }
          return;
        }
        widget.onUnlock?.call();
      } else {
        setState(() {
          _isError = true;
          _pinController.clear();
        });
        _showKeyboard();
      }
    }
  }
}
