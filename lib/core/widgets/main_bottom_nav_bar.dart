import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/services/language_service.dart';
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
  static const int _destinationCount = 5;
  static const int _pageCount = 25;
  static const int _middlePage = 10;
  static const int _recenterThreshold = 4;

  bool _isOffline = true;
  bool _hasConnectivityState = false;
  bool _showConnectivityStatus = false;
  int _connectivityRevision = 0;
  late int _centeredPage;
  late final PageController _pageController;
  Timer? _statusDismissTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _centeredPage = _middlePage +
        widget.selectedIndex.clamp(0, _destinationCount - 1).toInt();
    _pageController = PageController(
      initialPage: _centeredPage,
      viewportFraction: 1 / _destinationCount,
    );
    _initConnectivityListener();
  }

  @override
  void didUpdateWidget(covariant MainBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex &&
        _pageController.hasClients) {
      final currentPage =
          (_pageController.page ?? _centeredPage.toDouble()).round();
      final currentIndex = currentPage % _destinationCount;
      final selectedIndex =
          widget.selectedIndex.clamp(0, _destinationCount - 1).toInt();
      var pageDelta = (selectedIndex - currentIndex + _destinationCount) %
          _destinationCount;
      if (pageDelta > _destinationCount ~/ 2) {
        pageDelta -= _destinationCount;
      }
      final targetPage =
          (currentPage + pageDelta).clamp(0, _pageCount - 1).toInt();
      _pageController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
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

  void _handlePageChanged(int page) {
    var centeredPage = page;
    if (page <= _middlePage - _recenterThreshold) {
      centeredPage += _destinationCount;
    } else if (page >= _middlePage + _recenterThreshold) {
      centeredPage -= _destinationCount;
    }

    if (centeredPage != page && _pageController.hasClients) {
      _pageController.jumpToPage(centeredPage);
    }
    if (mounted && _centeredPage != centeredPage) {
      setState(() => _centeredPage = centeredPage);
    }
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
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final statusColor = _isOffline ? AppTheme.redColor : AppTheme.greenColor;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
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
            child: PageView.builder(
              controller: _pageController,
              itemCount: _pageCount,
              clipBehavior: Clip.none,
              onPageChanged: _handlePageChanged,
              itemBuilder: (context, page) {
                final index = page % _destinationCount;
                return _buildNavItem(
                  index: index,
                  isUrdu: isUrdu,
                  fontFamily: fontFamily,
                  isSelected: index == widget.selectedIndex,
                  isCentered: page == _centeredPage,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required bool isUrdu,
    required String? fontFamily,
    required bool isSelected,
    required bool isCentered,
  }) {
    final label = _navLabel(index, isUrdu);
    final iconColor = isCentered
        ? Colors.white
        : isSelected
            ? AppTheme.themeColor
            : AppTheme.textSecondary.withValues(alpha: 0.7);

    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onItemTapped(index),
          borderRadius: BorderRadius.circular(999),
          child: Center(
            child: isCentered
                ? Container(
                    width: 108,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.verifiedGold,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildNavIcon(index, iconColor),
                        const SizedBox(width: 6),
                        Flexible(
                          child: UrduAwareText(
                            label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              fontFamily: fontFamily,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )
                : _buildNavIcon(index, iconColor),
          ),
        ),
      ),
    );
  }

  Widget _buildNavIcon(int index, Color color) {
    final icon = switch (index) {
      0 => PhosphorIcons.circle(),
      1 => PhosphorIcons.users(),
      2 => PhosphorIcons.receipt(),
      3 => PhosphorIcons.briefcase(),
      _ => PhosphorIcons.clipboardText(),
    };
    return Icon(icon, size: 22, color: color);
  }

  String _navLabel(int index, bool isUrdu) {
    return switch (index) {
      0 => isUrdu ? 'ہوم' : 'Home',
      1 => isUrdu ? 'پارٹیز' : 'Parties',
      2 => isUrdu ? 'فوری بل' : 'Bills',
      3 => isUrdu ? 'پیشے' : 'Professions',
      _ => isUrdu ? 'ٹھیکے' : 'Contracts',
    };
  }
}
