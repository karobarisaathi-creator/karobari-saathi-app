import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:account_app/core/services/verification_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';

class AdminVerificationScreen extends StatefulWidget {
  const AdminVerificationScreen({super.key});

  @override
  State<AdminVerificationScreen> createState() =>
      _AdminVerificationScreenState();
}

class _AdminVerificationScreenState extends State<AdminVerificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _broadcastTitleController =
      TextEditingController();
  final TextEditingController _broadcastMessageController =
      TextEditingController();
  bool _isBroadcastSending = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkAdminAccess();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _noteController.dispose();
    _searchController.dispose();
    _broadcastTitleController.dispose();
    _broadcastMessageController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final canAccess = VerificationService.canAccessAdminPanel(
      userData: snapshot.data(),
      uid: user.uid,
      email: user.email,
      phone: user.phoneNumber,
    );

    if (!canAccess && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            backgroundColor: AppTheme.expenseColor,
            content: const Text('آپ کو ایڈمن پینل تک رسائی کا اجازت نہیں ہے')),
      );
      Navigator.pop(context);
    }
  }

  void _showImageDialog(String url, String title) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(title, style: const TextStyle(color: Colors.white)),
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(PhosphorIcons.x(), color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (context, url) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => Icon(
                    PhosphorIcons.imageBroken(),
                    color: Colors.white,
                    size: 40),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _process(String uid, bool approve) async {
    String? note;
    if (!approve) {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('مسترد کرنے کی وجہ'),
          content: TextField(
            controller: _noteController,
            decoration: const InputDecoration(
                hintText: 'وجہ لکھیں (صارف کو نظر آئے گی)'),
            maxLines: 3,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('منسوخ',
                    style: TextStyle(color: AppTheme.textSecondary))),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, _noteController.text),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.expenseColor),
              child: const Text('مسترد کریں'),
            ),
          ],
        ),
      );
      if (result == null) return;
      note = result;
    }

    try {
      await Provider.of<VerificationService>(context, listen: false)
          .processRequest(
        uid: uid,
        approve: approve,
        adminNote: note,
      );
      _noteController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor:
                  approve ? AppTheme.incomeColor : AppTheme.expenseColor,
              content: Text(approve
                  ? 'درخواست منظور کر دی گئی'
                  : 'درخواست مسترد کر دی گئی')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: AppTheme.expenseColor,
            content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: CustomAppBar(
        title: 'ایڈمن کنٹرول پینل',
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppTheme.verifiedGold,
          indicatorWeight: 3,
          tabs: [
            Tab(text: 'درخواستیں', icon: Icon(PhosphorIcons.clipboardText())),
            Tab(text: 'پیغام', icon: Icon(PhosphorIcons.megaphone())),
            Tab(text: 'صارفین', icon: Icon(PhosphorIcons.users())),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVerificationsTab(),
          _buildBroadcastTab(),
          _buildUsersTab(),
        ],
      ),
    );
  }

  Widget _buildBroadcastTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('تمام صارفین کو نوٹیفیکیشن بھیجیں',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          TextField(
            controller: _broadcastTitleController,
            decoration: InputDecoration(
              labelText: 'عنوان (Title)',
              prefixIcon:
                  Icon(PhosphorIcons.textT(), color: AppTheme.themeColor),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _broadcastMessageController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'پیغام (Message)',
              prefixIcon: Padding(
                padding: const EdgeInsets.only(bottom: 60),
                child:
                    Icon(PhosphorIcons.chatText(), color: AppTheme.themeColor),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: _isBroadcastSending
                  ? null
                  : () async {
                      if (_broadcastTitleController.text.isEmpty ||
                          _broadcastMessageController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                const Text('عنوان اور پیغام دونوں ضروری ہیں'),
                            backgroundColor: AppTheme.expenseColor,
                          ),
                        );
                        return;
                      }

                      setState(() => _isBroadcastSending = true);
                      try {
                        await Provider.of<VerificationService>(context,
                                listen: false)
                            .sendBroadcastNotification(
                          title: _broadcastTitleController.text,
                          message: _broadcastMessageController.text,
                        );
                        _broadcastTitleController.clear();
                        _broadcastMessageController.clear();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('تمام صارفین کو پیغام بھیج دیا گیا ہے'),
                              backgroundColor: AppTheme.incomeColor,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppTheme.expenseColor,
                              content: Text('خرابی: $e'),
                            ),
                          );
                        }
                      } finally {
                        if (mounted)
                          setState(() => _isBroadcastSending = false);
                      }
                    },
              icon: _isBroadcastSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Icon(
                      PhosphorIcons.paperPlaneRight(PhosphorIconsStyle.fill)),
              label: const Text('براڈکاسٹ بھیجیں'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.themeColor,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationsTab() {
    final vService = Provider.of<VerificationService>(context);
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: vService.getPendingRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(
              PhosphorIcons.checkCircle(), 'کوئی نئی درخواست موجود نہیں ہے');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) =>
              _buildRequestCard(snapshot.data![index]),
        );
      },
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> req) {
    final date = (req['submittedAt'] as dynamic)?.toDate() ?? DateTime.now();
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey[200]!)),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
                backgroundColor: AppTheme.verifiedGold.withOpacity(0.1),
                child:
                    Icon(PhosphorIcons.user(), color: AppTheme.verifiedGold)),
            title: Text(req['name'] ?? 'نامعلوم',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(req['phone'] ?? ''),
            trailing: Text(DateFormat('dd MMM, hh:mm a').format(date),
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInfoRow('کاروبار:', req['businessName'] ?? ''),
                _buildInfoRow('قسم:', req['businessType'] ?? ''),
                const SizedBox(height: 12),
                if (req['isArtisanRequest'] == true) ...[
                  Row(
                    children: [
                      _buildImageThumb(req['cnicFront'], 'CNIC Front'),
                      const SizedBox(width: 12),
                      _buildImageThumb(req['cnicBack'], 'CNIC Back'),
                    ],
                  ),
                  if (req['shopImageUrl'] != null) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      _buildImageThumb(req['shopImageUrl'], 'Workplace')
                    ]),
                  ],
                ] else
                  Row(
                    children: [
                      _buildImageThumb(req['shopImageUrl'], 'دکان'),
                      const SizedBox(width: 12),
                      _buildImageThumb(req['cnicFront'], 'شناختی کارڈ'),
                    ],
                  ),
              ],
            ),
          ),
          _buildActionButtons(req['uid']),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    final vService = Provider.of<VerificationService>(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'فون نمبر سے تلاش کریں...',
              prefixIcon: Icon(PhosphorIcons.magnifyingGlass()),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (v) => setState(() {}),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: vService.getAllUsers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final users = snapshot.data
                      ?.where((u) =>
                          u['phoneNumber']?.contains(_searchController.text) ??
                          true)
                      .toList() ??
                  [];
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  final bool isVerified = user['isVerified'] == true;
                  final bool isBlocked = user['isDeactivated'] == true;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundImage: user['photoURL'] != null
                          ? NetworkImage(user['photoURL'])
                          : null,
                      child: user['photoURL'] == null
                          ? Icon(PhosphorIcons.user())
                          : null,
                    ),
                    title: Row(
                      children: [
                        Text(user['displayName'] ?? 'صارف',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        if (isVerified) const SizedBox(width: 4),
                        if (isVerified)
                          Icon(PhosphorIcons.sealCheck(PhosphorIconsStyle.fill),
                              size: 14, color: AppTheme.verifiedGold),
                      ],
                    ),
                    subtitle: Text(user['phoneNumber'] ?? '',
                        style: const TextStyle(fontSize: 12)),
                    trailing: Switch(
                      value: !isBlocked,
                      activeColor: AppTheme.incomeColor,
                      onChanged: (val) =>
                          vService.toggleUserStatus(user['uid'], !val),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showUserControl(String uid) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading:
                Icon(PhosphorIcons.prohibit(), color: AppTheme.expenseColor),
            title: const Text('صارف کو بلاک کریں'),
            onTap: () async {
              Navigator.pop(context);
              try {
                await Provider.of<VerificationService>(context, listen: false)
                    .toggleUserStatus(uid, true);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        backgroundColor: AppTheme.expenseColor,
                        content: const Text('صارف بلاک کر دیا گیا')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        backgroundColor: AppTheme.expenseColor,
                        content: Text('خرابی: $e')),
                  );
                }
              }
            },
          ),
          ListTile(
            leading: Icon(PhosphorIcons.sealCheck(PhosphorIconsStyle.fill),
                color: AppTheme.incomeColor),
            title: const Text('تصدیق منسوخ کریں'),
            onTap: () async {
              Navigator.pop(context);
              try {
                await Provider.of<VerificationService>(context, listen: false)
                    .revokeVerification(uid);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        backgroundColor: AppTheme.incomeColor,
                        content: const Text('تصدیق منسوخ کر دی گئی')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        backgroundColor: AppTheme.expenseColor,
                        content: Text('خرابی: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(children: [
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
      const SizedBox(width: 8),
      Text(value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    ]);
  }

  Widget _buildImageThumb(String? url, String label) {
    if (url == null) return const SizedBox.shrink();
    return Expanded(
      child: InkWell(
        onTap: () => _showImageDialog(url, label),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
              imageUrl: url,
              height: 80,
              fit: BoxFit.cover,
              placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2))),
        ),
      ),
    );
  }

  Widget _buildActionButtons(String uid) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey[50],
      child: Row(children: [
        Expanded(
            child: ElevatedButton.icon(
                onPressed: () => _process(uid, false),
                icon: Icon(PhosphorIcons.xCircle()),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.expenseColor,
                    side: BorderSide(color: AppTheme.expenseColor)),
                label: const Text('مسترد'))),
        const SizedBox(width: 12),
        Expanded(
            child: ElevatedButton.icon(
                onPressed: () => _process(uid, true),
                icon: Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.verifiedGold),
                label: const Text('منظور'))),
      ]),
    );
  }
}
