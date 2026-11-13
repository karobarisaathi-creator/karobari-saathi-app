import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/services/security_service.dart';
import 'package:account_app/features/settings/app_lock_screen.dart';

class AppLockGate extends StatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  late final SecurityService _securityService;
  StreamSubscription<User?>? _authSubscription;
  String? _lastUserId;
  bool? _lastLockEnabled;
  bool _hasHandledSecurityInitialization = false;
  bool _isUnlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _securityService = context.read<SecurityService>();
    _lastLockEnabled = _securityService.isLockEnabled;
    _hasHandledSecurityInitialization = _securityService.isInitialized;
    _lastUserId = FirebaseAuth.instance.currentUser?.uid;
    _securityService.addListener(_handleSecurityChanged);
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen(_handleAuthChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _securityService.removeListener(_handleSecurityChanged);
    _authSubscription?.cancel();
    super.dispose();
  }

  void _handleSecurityChanged() {
    if (!_securityService.isInitialized) return;
    final isFirstInitialization = !_hasHandledSecurityInitialization;
    _hasHandledSecurityInitialization = true;
    final lockEnabled = _securityService.isLockEnabled;
    if (_lastLockEnabled == lockEnabled) return;
    _lastLockEnabled = lockEnabled;

    if (!mounted) return;
    setState(() {
      if (lockEnabled) _isUnlocked = !isFirstInitialization;
    });
  }

  void _handleAuthChanged(User? user) {
    final userId = user?.uid;
    if (_lastUserId == userId) return;
    _lastUserId = userId;
    if (mounted) setState(() => _isUnlocked = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused &&
        FirebaseAuth.instance.currentUser != null &&
        _securityService.isLockEnabled &&
        _isUnlocked) {
      setState(() => _isUnlocked = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SecurityService>(
      builder: (context, securityService, _) {
        final isSignedIn = FirebaseAuth.instance.currentUser != null;
        final isWaitingForSecurity =
            isSignedIn && !securityService.isInitialized;
        final isLocked = isSignedIn &&
            securityService.isInitialized &&
            securityService.isLockEnabled &&
            !_isUnlocked;
        final shouldBlockApp = isWaitingForSecurity || isLocked;

        return Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              ignoring: shouldBlockApp,
              child: ExcludeSemantics(
                excluding: shouldBlockApp,
                child: widget.child,
              ),
            ),
            if (isWaitingForSecurity)
              const Positioned.fill(child: _SecurityLoadingScreen()),
            if (isLocked)
              Positioned.fill(
                child: AppLockScreen(
                  onUnlock: () {
                    if (mounted) setState(() => _isUnlocked = true);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SecurityLoadingScreen extends StatelessWidget {
  const _SecurityLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF0B1628),
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF78B7FF)),
        ),
      ),
    );
  }
}
