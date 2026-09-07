import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/notification_service.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/services/artisan_work_order_service.dart';
import 'package:account_app/core/models/artisan_work_order_model.dart';
import 'package:account_app/core/models/job_post_model.dart';
import 'package:account_app/core/services/database/job_service.dart';
import 'package:account_app/features/artisans/widgets/work_order_list_item.dart';
import 'package:account_app/features/artisans/widgets/job_post_card.dart';
import 'package:account_app/features/artisans/job_detail_screen.dart';
import 'package:account_app/features/dashboard/main_navigation_screen.dart';
import 'package:account_app/core/services/logging_service.dart';
import 'dart:async';

class CustomerOrdersScreen extends StatefulWidget {
  const CustomerOrdersScreen({super.key});

  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> {
  final _logger = LoggingService();
  final ArtisanWorkOrderService _workOrderService = ArtisanWorkOrderService();
  final JobService _jobService = JobService();

  Stream<List<ArtisanWorkOrder>>? _ordersStream;
  StreamSubscription<List<ArtisanWorkOrder>>? _ordersSubscription;
  StreamSubscription<List<JobPost>>? _postsSubscription;
  List<ArtisanWorkOrder> _orders = [];
  List<JobPost> _myPosts = [];

  bool _isLoading = true;
  String? _error;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _initializeStream();
    _initializePostsStream();
  }

  void _initializePostsStream() {
    if (_userId == null || _userId!.isEmpty) return;

    _postsSubscription = _jobService.getCustomerJobs(_userId!).listen(
      (posts) {
        if (mounted) setState(() => _myPosts = posts);
      },
      onError: (error, stackTrace) =>
          _logger.error('Customer posts stream error', error, stackTrace),
    );
  }

  void _initializeStream() {
    if (_userId == null || _userId!.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'User not logged in';
      });
      return;
    }

    _ordersStream = _workOrderService.streamCustomerWorkOrders(_userId!);
    _ordersSubscription = _ordersStream?.listen(
      _onOrdersReceived,
      onError: _onError,
    );
  }

  void _onOrdersReceived(List<ArtisanWorkOrder> orders) {
    if (!mounted) return;

    // Remove duplicates and sort by latest activity
    final Map<String, ArtisanWorkOrder> uniqueOrders = {};
    for (var order in orders) {
      uniqueOrders[order.id] = order;
    }

    final sortedOrders = uniqueOrders.values.toList();
    sortedOrders.sort((a, b) {
      final aTime = a.updatedAt ?? a.createdAt;
      final bTime = b.updatedAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });

    setState(() {
      _orders = sortedOrders;
      _isLoading = false;
      _error = null;
    });
  }

  void _onOrderUpdated() {
    // This can be used to trigger UI updates if needed,
    // but the stream already handles real-time changes.
  }

  List<ArtisanWorkOrder> _ordersForPost(JobPost post) {
    final postOrderId = 'job_neg_${post.id}';
    return _orders.where((order) => order.id == postOrderId).toList();
  }

  void _onError(dynamic error) {
    _logger.error("Customer orders stream error", error);
    if (mounted) {
      setState(() {
        _isLoading = false;
        _error = error.toString();
      });
    }
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _postsSubscription?.cancel();
    super.dispose();
  }

  void _navigateToChat(ArtisanWorkOrder order) {
    final notificationService = Provider.of<NotificationService>(
      context,
      listen: false,
    );
    notificationService.setNotificationsTabIndex(1);
    notificationService.setTargetExpandOrderId(order.id);
    MainNavigationScreen.switchTab(4);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: isUrdu ? 'میرے کام کا ریکارڈ' : 'My Job History',
      ),
      body: _buildBody(isUrdu, fontFamily),
    );
  }

  Widget _buildBody(bool isUrdu, String fontFamily) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState(isUrdu, fontFamily);
    }

    if (_orders.isEmpty && _myPosts.isEmpty) {
      return _buildEmptyState(isUrdu, fontFamily);
    }

    return RefreshIndicator(
      onRefresh: _refreshOrders,
      color: AppTheme.themeColor,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (_myPosts.isNotEmpty) ...[
            ..._myPosts.map(
              (post) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    JobPostCard(
                      job: post,
                      isUrdu: isUrdu,
                      fontFamily: fontFamily,
                      currentUserId: _userId!,
                      embedded: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => JobDetailScreen(
                              job: post,
                            ),
                          ),
                        );
                      },
                    ),
                    if (_ordersForPost(post).isNotEmpty)
                      Divider(
                        height: 1,
                        indent: 12,
                        endIndent: 12,
                        color: Colors.grey.withValues(alpha: 0.25),
                      ),
                    ..._ordersForPost(post).map(
                      (order) => Padding(
                        padding: const EdgeInsets.only(left: 12, bottom: 16),
                        child: WorkOrderListItem(
                          order: order,
                          isArtisanMode: false,
                          isUrdu: isUrdu,
                          fontFamily: fontFamily,
                          embedded: true,
                          onChatTap: () => _navigateToChat(order),
                          onOrderUpdated: _onOrderUpdated,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_orders.any((order) =>
              !_myPosts.any((post) => order.id == 'job_neg_${post.id}'))) ...[
            _buildSectionTitle(
              isUrdu ? 'دیگر رابطے اور کام' : 'Other Contacts and Work',
              fontFamily,
            ),
            ..._orders
                .where((order) =>
                    !_myPosts.any((post) => order.id == 'job_neg_${post.id}'))
                .map(
                  (order) => Column(
                    children: [
                      WorkOrderListItem(
                        order: order,
                        isArtisanMode: false,
                        isUrdu: isUrdu,
                        fontFamily: fontFamily,
                        showTitleForCustomer: true,
                        onChatTap: () => _navigateToChat(order),
                        onOrderUpdated: _onOrderUpdated,
                      ),
                      Divider(
                        height: 1,
                        color: Colors.grey.withValues(alpha: 0.2),
                      ),
                    ],
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String fontFamily) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: AppTheme.darkColor,
          fontFamily: fontFamily,
        ),
      ),
    );
  }

  Future<void> _refreshOrders() async {
    // Stream automatically updates, this is just for pull-to-refresh
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LanguageService>(context, listen: false).isUrdu
                ? 'تازہ ترین معلومات'
                : 'Updated',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Widget _buildEmptyState(bool isUrdu, String fontFamily) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIcons.clipboardText(),
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            isUrdu ? 'کوئی ریکارڈ نہیں ملا' : 'No records found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontFamily: fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isUrdu
                ? 'آپ نے ابھی تک کسی کاریگر کو ہائر نہیں کیا'
                : 'You haven\'t hired any artisan yet',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
              fontFamily: fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isUrdu, String fontFamily) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIcons.warningCircle(),
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            isUrdu ? 'ڈیٹا لوڈ کرنے میں ناکامی' : 'Failed to load data',
            style: TextStyle(
              fontSize: 18,
              color: Colors.red,
              fontFamily: fontFamily,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              setState(() => _isLoading = true);
              _initializeStream();
            },
            icon: const Icon(Icons.refresh),
            label: Text(
              isUrdu ? 'دوبارہ کوشش کریں' : 'Retry',
              style: TextStyle(fontFamily: fontFamily),
            ),
          ),
        ],
      ),
    );
  }
}
