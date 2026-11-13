// lib/features/accounts/widgets/party_tools_grid_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/pdf_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/account_balance_utils.dart';
import 'package:account_app/core/utils/party_ledger_metrics.dart';
import 'package:account_app/features/accounts/widgets/party_trust_metrics.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/features/accounts/add_party_screen.dart';
import 'package:account_app/features/accounts/bulk_party_transaction_screen.dart';
import 'package:account_app/features/accounts/widgets/party_trust_popup.dart';

class PartyToolsGridWidget extends StatelessWidget {
  final Account party;
  final bool isUrdu;
  final String? fontFamily;
  final VoidCallback onRefresh;

  const PartyToolsGridWidget({
    super.key,
    required this.party,
    required this.isUrdu,
    this.fontFamily,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    final currentParty = db.getAccount(party.id) ?? party;
    final allTx = db.getTransactions(party.id);
    final trustMetrics = PartyTrustMetrics.calculate(
      party: currentParty,
      transactions: allTx,
      isUrdu: isUrdu,
    );

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.backgroundColor),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkColor.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.gridFour(),
                  size: 14, color: AppTheme.themeColor),
              const SizedBox(width: 6),
              UrduAwareText(
                isUrdu ? 'پارٹی ٹولز اور مینو' : 'Party Tools & Menu',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.darkColor,
                  fontFamily: fontFamily,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 0.85,
            children: [
              _buildToolItem(
                icon: PhosphorIcons.listBullets(),
                label: isUrdu ? 'پیج انٹری' : 'Bulk Entry',
                iconColor: AppTheme.themeColor,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BulkPartyTransactionScreen(party: party),
                    ),
                  ).then((_) => onRefresh());
                },
              ),
              _buildToolItem(
                icon: PhosphorIcons.filePdf(),
                label: isUrdu ? 'PDF رپورٹ' : 'PDF Report',
                iconColor: AppTheme.incomeColor,
                onTap: () async {
                  final pdfService =
                      Provider.of<PdfService>(context, listen: false);
                  final txs = db.getTransactions(party.id);
                  await pdfService.generateAccountStatement(
                    account: party,
                    transactions: txs,
                    isUrdu: isUrdu,
                  );
                },
              ),
              _buildToolItem(
                icon: PhosphorIcons.shieldCheck(),
                label: isUrdu ? 'بھروسہ پوائنٹ' : 'Trust Point',
                iconColor: trustMetrics.badgeColor,
                onTap: () => PartyTrustPopup.show(
                  context: context,
                  trustScore: trustMetrics.hasTransactionHistory
                      ? trustMetrics.overallScore
                      : null,
                  isUrdu: isUrdu,
                  fontFamily: fontFamily,
                ),
              ),
              _buildToolItem(
                icon: PhosphorIcons.pencilLine(),
                label: isUrdu ? 'ایڈٹ' : 'Edit',
                iconColor: AppTheme.darkColor,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddPartyScreen(partyToEdit: party),
                    ),
                  );
                  onRefresh();
                },
              ),
              _buildToolItem(
                icon: PhosphorIcons.trash(),
                label: isUrdu ? 'ڈیلیٹ' : 'Delete',
                iconColor: AppTheme.expenseColor,
                onTap: () => _confirmDelete(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolItem({
    required IconData icon,
    required String label,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.backgroundColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.darkColor.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(height: 4),
              UrduAwareText(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkColor,
                  fontFamily: fontFamily,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // Delete confirmation — ویسا ہی
  // ═════════════════════════════════════════════════════════════
  Future<void> _confirmDelete(BuildContext context) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final transactions = db.getTransactions(party.id);
    final hasData = transactions.isNotEmpty ||
        party.initialBalance.abs() > 0.01 ||
        party.balance.abs() > 0.01;

    final nameController = TextEditingController();
    bool canDelete = !hasData;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: UrduAwareText(
            isUrdu ? 'پارٹی کو مستقل ختم کریں؟' : 'Permanently Delete Party?',
            style: TextStyle(
                fontFamily: fontFamily,
                fontWeight: FontWeight.bold,
                color: AppTheme.expenseColor),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UrduAwareText(
                isUrdu
                    ? 'وارننگ: اس پارٹی کا ${transactions.length} لین دین اور بیلنس موجود ہے۔ ختم کرنے سے تمام ڈیٹا ہمیشہ کے لیے مٹ جائے گا۔'
                    : 'Warning: This party has ${transactions.length} transactions and balance. Deletion is irreversible.',
                style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 13,
                    color: Colors.red.shade700),
              ),
              if (hasData) ...[
                const SizedBox(height: 14),
                UrduAwareText(
                  isUrdu
                      ? 'تصدیق کے لیے پارٹی کا نام "${party.name}" درج کریں:'
                      : 'Type party name "${party.name}" to confirm:',
                  style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: party.name,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (val) {
                    setState(() {
                      canDelete = val.trim() == party.name.trim();
                    });
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: UrduAwareText(
                isUrdu ? 'منسوخ' : 'Cancel',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontFamily: fontFamily),
              ),
            ),
            TextButton(
              onPressed: canDelete ? () => Navigator.pop(context, true) : null,
              child: UrduAwareText(
                isUrdu ? 'ختم کریں' : 'Delete',
                style: TextStyle(
                  color: canDelete ? AppTheme.expenseColor : Colors.grey,
                  fontFamily: fontFamily,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm == true && context.mounted) {
      await Provider.of<DatabaseService>(context, listen: false)
          .deleteAccount(party.id);
      if (context.mounted) Navigator.pop(context);
    }
  }
}
