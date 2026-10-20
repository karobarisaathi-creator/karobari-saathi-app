// lib/features/accounts/widgets/party_tools_grid_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:ui' as ui;
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/pdf_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/account_balance_utils.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/features/accounts/add_party_screen.dart';
import 'package:account_app/features/accounts/bulk_party_transaction_screen.dart';

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
              Icon(PhosphorIcons.gridFour(), size: 14, color: AppTheme.themeColor),
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
                  final pdfService = Provider.of<PdfService>(context, listen: false);
                  final db = Provider.of<DatabaseService>(context, listen: false);
                  final txs = db
                      .getAllTransactions()
                      .where((t) => t.accountId == party.id)
                      .toList();
                  await pdfService.generateAccountStatement(
                    account: party,
                    transactions: txs,
                    isUrdu: isUrdu,
                  );
                },
              ),
              _buildToolItem(
                icon: PhosphorIcons.star(PhosphorIconsStyle.fill),
                label: isUrdu ? 'ذاتی جائزہ' : 'Review',
                iconColor: AppTheme.verifiedGold,
                onTap: () => _showPersonalReviewDialog(context),
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

  void _showPersonalReviewDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PersonalReviewCard(
                party: party,
                isUrdu: isUrdu,
                fontFamily: fontFamily,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: AppTheme.backgroundColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: UrduAwareText(
                    isUrdu ? 'بند کریں' : 'Close',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      color: AppTheme.darkColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: UrduAwareText(
          isUrdu ? 'پارٹی ختم کریں؟' : 'Delete Party?',
          style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
        ),
        content: UrduAwareText(
          isUrdu
              ? 'کیا آپ واقعی اس پارٹی کو ختم کرنا چاہتے ہیں؟ تمام ریکارڈ مٹ جائے گا۔'
              : 'Are you sure you want to delete this party? All records will be lost.',
          style: TextStyle(fontFamily: fontFamily),
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
            onPressed: () => Navigator.pop(context, true),
            child: UrduAwareText(
              isUrdu ? 'ختم کریں' : 'Delete',
              style: TextStyle(
                  color: AppTheme.expenseColor, fontFamily: fontFamily),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await Provider.of<DatabaseService>(context, listen: false)
          .deleteAccount(party.id);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

class _PersonalReviewCard extends StatelessWidget {
  final Account party;
  final bool isUrdu;
  final String? fontFamily;

  const _PersonalReviewCard({
    required this.party,
    required this.isUrdu,
    this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final allTx = db
        .getAllTransactions()
        .where((t) => t.accountId == party.id && t.partnershipId == null)
        .toList();

    double totalIn = 0, totalOut = 0;
    int totalDeals = allTx.length;
    DateTime? firstDeal;

    for (var tx in allTx) {
      if (tx.isQuickBill) {
        final subtotal = tx.subtotal > 0 ? tx.subtotal : tx.amount;
        final billTotal =
            (subtotal - tx.discountAmount).clamp(0, double.infinity).toDouble();
        if (tx.type == 'income') {
          totalIn += billTotal;
        } else {
          totalOut += billTotal;
        }
      } else if (tx.type == 'income') {
        totalIn += tx.amount;
      } else {
        totalOut += tx.amount;
      }
      if (firstDeal == null || tx.date.isBefore(firstDeal)) {
        firstDeal = tx.date;
      }
    }

    final totalVolume = totalIn + totalOut;
    final openingBalance = party.balanceType.toLowerCase() == 'payable'
        ? -party.initialBalance
        : party.initialBalance;
    final currentBalance = AccountBalanceUtils.ledgerBalance(
      allTx,
      initialBalance: openingBalance,
    );

    double score = 0;
    final days = DateTime.now().difference(firstDeal ?? DateTime.now()).inDays;
    if (days > 180) {
      score += 1.0;
    } else if (days > 30) {
      score += 0.5;
    }
    if (totalDeals > 25) {
      score += 1.0;
    } else if (totalDeals > 10) {
      score += 0.5;
    }
    if (totalVolume > 100000) {
      score += 1.0;
    } else if (totalVolume > 20000) {
      score += 0.5;
    }
    if (totalVolume > 0) {
      final ratio = 1 - (currentBalance.abs() / totalVolume);
      if (ratio > 0.9) {
        score += 1.0;
      } else if (ratio > 0.7) {
        score += 0.5;
      }
    }
    final trustScore = score.clamp(1.0, 5.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            UrduAwareText(
              isUrdu ? 'ذاتی جائزہ' : 'Personal Review',
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkColor,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.expenseColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock, size: 11, color: AppTheme.expenseColor),
                  const SizedBox(width: 4),
                  UrduAwareText(
                    isUrdu ? 'صرف آپ' : 'Only you',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.expenseColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _stars(trustScore, 18),
            const SizedBox(width: 8),
            UrduAwareText(
              isUrdu ? 'آخری 12 مہینے' : 'Last 12 months',
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 11.5,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _reviewRow(
          isUrdu ? 'ادائیگی کی رفتار' : 'Payment speed',
          isUrdu ? 'اوسط 12 دن دیر' : 'Avg 12 days late',
          3,
        ),
        _reviewRow(
          isUrdu ? 'بقایا رقم' : 'Outstanding',
          isUrdu ? '16% باقی' : '16% remaining',
          2,
        ),
        _reviewRow(
          isUrdu ? 'باقاعدگی' : 'Regularity',
          isUrdu ? 'ہر 8.8 دن' : 'Every 8.8 days',
          4,
        ),
        const SizedBox(height: 10),
        UrduAwareText(
          isUrdu
              ? 'یہ آپ کے اپنے حساب پر اندازہ ہے۔ پارٹی کو نہیں دکھتا۔'
              : 'Your private estimate. Not visible to the party.',
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: 10.5,
            color: Colors.grey.shade400,
          ),
        ),
      ],
    );
  }

  Widget _reviewRow(String title, String sub, int stars) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UrduAwareText(
                  title,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 13,
                    color: AppTheme.darkColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                UrduAwareText(
                  sub,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _stars(stars.toDouble(), 14),
        ],
      ),
    );
  }

  Widget _stars(double score, double size) {
    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          return Icon(
            i < score ? Icons.star_rounded : Icons.star_outline_rounded,
            color: const Color(0xFF2563EB),
            size: size,
          );
        }),
      ),
    );
  }
}
