import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/database_service.dart';
import '../../core/services/language_service.dart';
import '../../core/models/work_log_model.dart';
import '../../core/models/account_model.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/search_sort_bar.dart';
import 'person_diary_screen.dart';

class SmartDiaryScreen extends StatefulWidget {
  const SmartDiaryScreen({super.key});

  @override
  State<SmartDiaryScreen> createState() => _SmartDiaryScreenState();
}

class _SmartDiaryScreenState extends State<SmartDiaryScreen> {
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return DateFormat('hh:mm a').format(date);
    }
    if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE').format(date);
    }
    return DateFormat('dd/MM/yy').format(date);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final dbService = Provider.of<DatabaseService>(context);
    
    final allAccounts = dbService.getAccounts().where((a) => a.isActive).toList();
    final allLogs = dbService.getWorkLogs();
    
    final Map<String, WorkLog?> latestLogs = {};
    for (var acc in allAccounts) {
      try {
        latestLogs[acc.id] = allLogs.firstWhere((l) => l.accountId == acc.id);
      } catch (_) {
        latestLogs[acc.id] = null;
      }
    }

    final filteredAccounts = allAccounts.where((a) => 
      a.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
      a.phone.contains(_searchQuery)
    ).toList();

    filteredAccounts.sort((a, b) {
      final logA = latestLogs[a.id];
      final logB = latestLogs[b.id];
      if (logA == null && logB == null) return a.name.compareTo(b.name);
      if (logA == null) return 1;
      if (logB == null) return -1;
      return logB.date.compareTo(logA.date);
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: isUrdu ? 'میرا روزنامچہ' : 'Work Diary',
        showBackButton: false,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SearchSortBar(
              controller: _searchController,
              hintText: isUrdu ? 'بندہ تلاش کریں...' : 'Search person...',
              onSearchChanged: (v) => setState(() => _searchQuery = v),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          Expanded(
            child: allAccounts.isEmpty 
                ? _buildEmptyState(isUrdu, fontFamily)
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 20),
                    itemCount: filteredAccounts.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 70, endIndent: 16, color: Color(0xFFF1F1F1)),
                    itemBuilder: (context, index) {
                      final account = filteredAccounts[index];
                      final latestLog = latestLogs[account.id];
                      return _buildIndexCard(account, latestLog, isUrdu, fontFamily);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndexCard(Account account, WorkLog? latestLog, bool isUrdu, String fontFamily) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PersonDiaryScreen(
              accountId: account.id,
              accountName: account.name,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppTheme.themeColor.withValues(alpha: 0.1),
              child: Text(
                account.name[0].toUpperCase(),
                style: const TextStyle(color: AppTheme.themeColor, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        account.name,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: fontFamily),
                      ),
                      if (latestLog != null)
                        Text(
                          _formatDate(latestLog.date),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (latestLog != null)
                    Text(
                      latestLog.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontFamily: fontFamily),
                    )
                  else
                    Text(
                      isUrdu ? 'کوئی ریکارڈ نہیں' : 'No entries yet',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontFamily: fontFamily),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isUrdu, String fontFamily) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.notebook(), size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 24),
          Text(
            isUrdu ? 'روزنامچہ خالی ہے' : 'Diary is empty',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey, fontFamily: fontFamily),
          ),
        ],
      ),
    );
  }
}
