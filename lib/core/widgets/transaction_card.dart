import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/utils/receipt_dialog_helper.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/utils/account_balance_utils.dart';

class TransactionCard extends StatelessWidget {
  final Transaction transaction;
  // ہم نے onTap کو اب آپشنل کر دیا ہے تاکہ اگر یہ نہ بھی ہو تو رسید کھلے
  final VoidCallback? onTap;

  const TransactionCard({
    super.key,
    required this.transaction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final fontWeight = isUrdu ? FontWeight.bold : FontWeight.normal;

    final columns = AccountBalanceUtils.transactionColumns(transaction);
    final bool debitLeads = columns.debit >= columns.credit;
    final Color color =
        debitLeads ? AppTheme.expenseColor : AppTheme.incomeColor;
    final Color bgColor =
        debitLeads ? Colors.red.shade50 : Colors.green.shade50;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        visualDensity: const VisualDensity(vertical: -2),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            debitLeads
                ? PhosphorIcons.arrowUpRight()
                : PhosphorIcons.arrowDownLeft(),
            color: color,
            size: 20,
          ),
        ),
        title: UrduAwareText(
          transaction.description,
          style: TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UrduAwareText(
              '${transaction.date.day}/${transaction.date.month}/${transaction.date.year}',
              style:
                  const TextStyle(fontFamily: '', fontWeight: FontWeight.bold),
            ),
            if (transaction.professionName != null)
              UrduAwareText(
                transaction.professionName!,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.themeColor,
                  fontFamily: fontFamily,
                  fontWeight: fontWeight,
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (columns.debit > 0)
              _buildSideAmount(
                isUrdu ? 'بنام' : 'Debit',
                columns.debit,
                AppTheme.expenseColor,
              ),
            if (columns.credit > 0)
              _buildSideAmount(
                isUrdu ? 'جمع' : 'Credit',
                columns.credit,
                AppTheme.incomeColor,
              ),
          ],
        ),
        onTap: () {
          if (onTap != null) {
            onTap!();
          } else {
            ReceiptDialogHelper.showReceiptDialog(
              context,
              transaction: transaction,
              isLocalTransaction: true,
            );
          }
        },
      ),
    );
  }

  Widget _buildSideAmount(String label, double amount, Color color) {
    return UrduAwareText(
      '$label: ${Formatters.formatAmountWithCurrency(amount)}',
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 13,
        fontFamily: '',
      ),
    );
  }
}
