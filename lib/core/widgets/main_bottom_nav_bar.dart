import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/notification_service.dart';
import 'package:account_app/core/theme/app_theme.dart';

class MainBottomNavBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  const MainBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  State<MainBottomNavBar> createState() => _MainBottomNavBarState();
}

class _MainBottomNavBarState extends State<MainBottomNavBar> {
  bool _isOffline = true;
  bool _hasConnectivityState = false;
  bool _showConnectivityStatus = false;
  int _connectivityRevision = 0;
  Timer? _statusDismissTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (results) {
        _connectivityRevision++;
        _updateConnectivity(results);
      },
      onError: (Object error, StackTrace stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'bottom navigation connectivity',
            context:
                ErrorDescription('while listening for connectivity changes'),
          ),
        );
      },
    );
    _loadInitialConnectivity();
  }

  Future<void> _loadInitialConnectivity() async {
    final revision = _connectivityRevision;
    try {
      final results = await Connectivity().checkConnectivity();
      if (!mounted || revision != _connectivityRevision) return;
      _updateConnectivity(results);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'bottom navigation connectivity',
          context: ErrorDescription('while checking the initial connectivity'),
        ),
      );
    }
  }

  void _updateConnectivity(List<ConnectivityResult> results) {
    final isOffline = results.contains(ConnectivityResult.none);
    if (!mounted) return;

    if (!_hasConnectivityState) {
      setState(() {
        _isOffline = isOffline;
        _hasConnectivityState = true;
      });
      return;
    }

    if (_isOffline == isOffline) return;

    setState(() {
      _isOffline = isOffline;
      _showConnectivityStatus = true;
    });
    _statusDismissTimer?.cancel();
    _statusDismissTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showConnectivityStatus = false);
      }
    });
  }

  @override
  void dispose() {
    _statusDismissTimer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final statusColor =
        _isOffline ? AppTheme.expenseColor : AppTheme.incomeColor;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: AppTheme.darkColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(15),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: _showConnectivityStatus
                ? Container(
                    width: double.infinity,
                    height: 25,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(15),
                      ),
                    ),
                    child: UrduAwareText(
                      isUrdu
                          ? (_isOffline
                              ? 'کاروباری ساتھی آف لائن'
                              : 'کاروباری ساتھی آن لائن')
                          : (_isOffline
                              ? 'Karobari Saathi Offline'
                              : 'Karobari Saathi Online'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        fontFamily: fontFamily,
                        height: 1,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          SizedBox(
            height: 60,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ═══ Shopkeeper Dashboard (Tab 0) ═══
                Expanded(
                  flex: 2,
                  child: _buildNavItem(
                    index: 0,
                    icon: PhosphorIcons.shoppingBag(),
                    activeIcon:
                        PhosphorIcons.shoppingBag(PhosphorIconsStyle.fill),
                  ),
                ),

                // ═══ Parties / Accounts (Tab 1) ═══
                Expanded(
                  flex: 2,
                  child: _buildNavItem(
                    index: 1,
                    icon: PhosphorIcons.users(),
                    activeIcon: PhosphorIcons.users(PhosphorIconsStyle.fill),
                  ),
                ),

                // ═══ Quick Bill (Center Pill) (Tab 2) ═══
                Expanded(
                  flex: 5,
                  child: _buildQuickBillPill(isUrdu, fontFamily),
                ),

                // ═══ Professions / Projects (Tab 3) ═══
                Expanded(
                  flex: 2,
                  child: _buildNavItem(
                    index: 3,
                    icon: PhosphorIcons.briefcase(),
                    activeIcon:
                        PhosphorIcons.briefcase(PhosphorIconsStyle.fill),
                  ),
                ),

                // ═══ Notifications (Tab 4) ═══
                Expanded(
                  flex: 2,
                  child: _buildNotificationItem(index: 4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
  }) {
    final isActive = widget.selectedIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onItemTapped(index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 66,
          alignment: Alignment.center,
          child: Icon(
            isActive ? activeIcon : icon,
            size: 22,
            color:
                isActive ? Colors.white : Colors.white.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickBillPill(bool isUrdu, String? fontFamily) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onItemTapped(2),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 66,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.verifiedGold,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.verifiedGold.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  PhosphorIcons.lightning(),
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: UrduAwareText(
                    isUrdu ? 'فوری بل' : 'Bill',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontFamily: fontFamily,
                      letterSpacing: 0.2,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationItem({int index = 4}) {
    final isActive = widget.selectedIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onItemTapped(index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 66,
          alignment: Alignment.center,
          child: Consumer<NotificationService>(
            builder: (context, notifService, child) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    isActive
                        ? PhosphorIcons.bell(PhosphorIconsStyle.fill)
                        : PhosphorIcons.bell(),
                    size: 22,
                    color: isActive
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.55),
                  ),
                  if (notifService.unreadCount > 0)
                    Positioned(
                      top: -4,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        constraints: const BoxConstraints(minWidth: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.expenseColor,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppTheme.darkColor,
                            width: 1.5,
                          ),
                        ),
                        child: UrduAwareText(
                          notifService.unreadCount > 99
                              ? '99+'
                              : '${notifService.unreadCount}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
