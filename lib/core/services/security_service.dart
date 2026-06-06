import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';

class SecurityService with ChangeNotifier {
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isLockEnabled = false;
  bool _isBiometricEnabled = false;

  SecurityService() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _isLockEnabled = prefs.getBool('app_lock_enabled') ?? false;
    _isBiometricEnabled = prefs.getBool('app_biometric_enabled') ?? false;
    notifyListeners();
  }

  bool get isLockEnabled => _isLockEnabled;
  bool get isBioEnabled => _isBiometricEnabled;
  final String _encryptionKey = 'a_very_secret_key_that_is_32_lon';

  // Encrypt data
  String encryptData(String data) {
    final key = encrypt.Key.fromUtf8(_encryptionKey);
    final iv = encrypt.IV.fromLength(16); 
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(data, iv: iv);
    return '${base64.encode(iv.bytes)}:${encrypted.base64}';
  }

  // Decrypt data
  String decryptData(String encryptedData) {
    try {
      final parts = encryptedData.split(':');
      if (parts.length != 2) throw Exception('Invalid encrypted data format');
      final iv = encrypt.IV.fromBase64(parts[0]);
      final encryptedValue = parts[1];

      final key = encrypt.Key.fromUtf8(_encryptionKey);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final decrypted = encrypter.decrypt64(encryptedValue, iv: iv);
      return decrypted;
    } catch (e) {
      throw Exception('Decryption failed: $e');
    }
  }

  // Store sensitive data securely
  Future<void> storeSensitiveData(String key, String value) async {
    final encryptedValue = encryptData(value);
    await _secureStorage.write(key: key, value: encryptedValue);
    notifyListeners();
  }

  // Retrieve sensitive data
  Future<String?> getSensitiveData(String key) async {
    final encryptedValue = await _secureStorage.read(key: key);
    if (encryptedValue != null) {
      return decryptData(encryptedValue);
    }
    return null;
  }

  // Delete sensitive data
  Future<void> deleteSensitiveData(String key) async {
    await _secureStorage.delete(key: key);
    notifyListeners();
  }

  // Hash password/PIN
  String hashData(String data) {
    final bytes = utf8.encode(data + _encryptionKey); // Salting the hash
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Validate PIN
  Future<bool> validatePin(String enteredPin) async {
    final storedPinHash = await _secureStorage.read(key: 'app_pin_hash');
    if (storedPinHash == null) return false;

    final enteredPinHash = hashData(enteredPin);
    return storedPinHash == enteredPinHash;
  }

  // Set new PIN
  Future<void> setNewPin(String newPin) async {
    final pinHash = hashData(newPin);
    await _secureStorage.write(key: 'app_pin_hash', value: pinHash);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_lock_enabled', true);
    notifyListeners();
  }

  // Check if app lock is enabled
  Future<bool> isAppLockEnabled() async {
    return _isLockEnabled;
  }

  // Enable/disable app lock
  Future<void> setAppLockEnabled(bool enabled) async {
    _isLockEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_lock_enabled', enabled);
    notifyListeners();
  }

  // --- Biometric Authentication ---

  // Check if biometrics are available
  Future<bool> isBiometricsAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      print("Biometric Check Error: $e");
      return false;
    }
  }

  // Check if biometric is enabled by user
  Future<bool> isBiometricEnabled() async {
    return _isBiometricEnabled;
  }

  // Enable/Disable biometric
  Future<void> setBiometricEnabled(bool enabled) async {
    _isBiometricEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_biometric_enabled', enabled);
    notifyListeners();
  }

  // Authenticate with biometrics
  Future<bool> authenticateWithBiometrics() async {
    try {
      // Adjusted parameters to be compatible with various versions
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access the app',
      );
      return didAuthenticate;
    } catch (e) {
      print("Biometric Auth Error: $e");
      // Fallback attempt for older APIs if needed, though 'authenticate' is standard.
      return false;
    }
  }

  // Generate secure random token
  String generateSecureToken() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }

  // Validate session token
  Future<bool> validateSessionToken(String token) async {
    final storedToken = await getSensitiveData('session_token');
    return storedToken == token;
  }

  // Create new session
  Future<String> createNewSession() async {
    final token = generateSecureToken();
    await storeSensitiveData('session_token', token);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_created', DateTime.now().toIso8601String());

    notifyListeners();
    return token;
  }

  // Clear session
  Future<void> clearSession() async {
    await deleteSensitiveData('session_token');

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_created');
    notifyListeners();
  }

  // Encrypt database
  Future<void> encryptDatabase() async {
    // Implementation for database encryption
  }

  // Data sanitization
  String sanitizeInput(String input) {
    return input.replaceAll(RegExp(r'''[<>"'\\]'''), '');
  }

  // Validate email format
  bool isValidEmail(String email) {
    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return regex.hasMatch(email);
  }

  // Validate phone format
  bool isValidPhone(String phone) {
    final regex = RegExp(r'^\+?[0-9]{10,13}$');
    return regex.hasMatch(phone);
  }

  // Security audit log
  Future<void> logSecurityEvent(String event) async {
    final prefs = await SharedPreferences.getInstance();
    final logs = prefs.getStringList('security_logs') ?? [];

    logs.add('${DateTime.now().toIso8601String()}: $event');

    if (logs.length > 100) {
      logs.removeAt(0);
    }

    await prefs.setStringList('security_logs', logs);
  }

  // Get security logs
  Future<List<String>> getSecurityLogs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('security_logs') ?? [];
  }

  // Check if device is secure
  Future<bool> isDeviceSecure() async {
    return true; // Placeholder
  }

  // Secure data wipe
  Future<void> secureWipe() async {
    await _secureStorage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await logSecurityEvent('SECURE_WIPE: All data wiped');
    notifyListeners();
  }
}
