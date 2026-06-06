import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for SystemChannels
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/security_service.dart';

class AppLockScreen extends StatefulWidget {
  final bool isSettingUp;
  final bool isChangingPin;
  final VoidCallback? onUnlock;

  const AppLockScreen({
    super.key, 
    this.isSettingUp = false, 
    this.isChangingPin = false,
    this.onUnlock
  });

  @override
  _AppLockScreenState createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String? _newPinCache; // Temporary storage for the first PIN entry during setup
  bool _isVerifyingOldPin = false;
  bool _isLoading = true;
  bool _isError = false;
  bool _isBiometricAvailable = false;

  // Colors (Updated to match AppTheme)
  final Color _themeColor = const Color(0xFF123248); // AppTheme.darkColor
  final Color _greyColor = const Color(0xFF607D8B); // AppTheme.goldColor (Grey)

  @override
  void initState() {
    super.initState();
    _isVerifyingOldPin = widget.isChangingPin;
    _loadInitialState();
    
    // Check biometrics and handle keyboard logic
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
    if (widget.isSettingUp || _isVerifyingOldPin) {
        // If setting up or verifying old PIN for change, just focus keyboard
        _showKeyboard();
        return;
    }

    final securityService = Provider.of<SecurityService>(context, listen: false);
    final isAvailable = await securityService.isBiometricsAvailable();
    final isEnabled = await securityService.isBiometricEnabled();

    if (mounted) {
      setState(() {
        _isBiometricAvailable = isAvailable && isEnabled;
      });

      if (_isBiometricAvailable) {
        // Try biometric auth
        await _authenticateWithBiometrics();
      } else {
        // No biometric, show keyboard immediately
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
    final securityService = Provider.of<SecurityService>(context, listen: false);
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

    return Scaffold(
      backgroundColor: _themeColor,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque, 
        onTap: _showKeyboard,
        child: SafeArea(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_greyColor),
                  ),
                )
              : Stack(
                  children: [
                    Container(
                      width: 1,
                      height: 1,
                      child: TextField(
                        controller: _pinController,
                        focusNode: _focusNode,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        autofocus: false, 
                        showCursor: false,
                        enableSuggestions: false,
                        autocorrect: false,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                            border: InputBorder.none,
                            counterText: "",
                        ),
                        style: const TextStyle(color: Colors.transparent),
                        onChanged: (value) {
                          setState(() {
                            _isError = false;
                          });
                          if (value.length == 4) {
                            _validatePin(value);
                          }
                        },
                      ),
                    ),

                    Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/icons/zalooq.png',
                              width: 100,
                              height: 100,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.lock, size: 80, color: Colors.white24),
                            ),

                            const SizedBox(height: 40),

                            Text(
                              isUrdu ? 'کاروباری ساتھی' : 'Karobari Sathi',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                fontFamily: 'NooriNastaleeq',
                                letterSpacing: 1.0,
                              ),
                            ),

                            const SizedBox(height: 20),

                            Text(
                              _getStatusText(isUrdu),
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.7),
                                fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                                fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),

                            const SizedBox(height: 30),

                            GestureDetector(
                              onTap: _showKeyboard,
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                color: Colors.transparent,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(4, (index) {
                                    bool isFilled = index < _pinController.text.length;
                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      margin: const EdgeInsets.symmetric(horizontal: 10),
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isFilled
                                            ? (_isError ? Colors.redAccent : _greyColor)
                                            : Colors.white.withOpacity(0.2),
                                        border: isFilled
                                            ? null
                                            : Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            if (_isError)
                              Text(
                                _getErrorText(isUrdu),
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 16,
                                  fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                                  fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
                                ),
                              )
                            else
                              const SizedBox(height: 20),
                            
                            if (_isBiometricAvailable && !widget.isSettingUp && !_isVerifyingOldPin)
                              Padding(
                                padding: const EdgeInsets.only(top: 20.0),
                                child: IconButton(
                                  icon: Icon(Icons.fingerprint, size: 50, color: _greyColor),
                                  onPressed: _authenticateWithBiometrics,
                                ),
                              ),

                            const SizedBox(height: 80),
                            
                            if ((widget.isSettingUp || widget.isChangingPin) && _newPinCache == null)
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    isUrdu ? 'بعد میں' : 'Later',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                      fontFamily: isUrdu ? 'NooriNastaleeq' : '',
                                      fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
         return isUrdu ? 'نیا 4 ہندسوں کا کوڈ درج کریں' : 'Enter new 4-digit PIN';
       } else {
         return isUrdu ? 'تصدیق کے لیے دوبارہ درج کریں' : 'Re-enter to confirm';
       }
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

    final securityService = Provider.of<SecurityService>(context, listen: false);
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
      final isValid = await securityService.validatePin(cleanPin);
      if (isValid) {
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
