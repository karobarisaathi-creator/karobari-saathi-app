import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/features/accounts/transaction_receipt_screen.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';

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

    final bool isIncome = transaction.type == 'income';
    final Color color = isIncome ? AppTheme.incomeColor : AppTheme.expenseColor;
    final Color bgColor = isIncome ? Colors.green.shade50 : Colors.red.shade50;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isIncome ? PhosphorIcons.arrowDownLeft() : PhosphorIcons.arrowUpRight(),
            color: color,
            size: 20,
          ),
        ),
        title: Text(
          transaction.description,
          style: TextStyle(
            fontFamily: fontFamily,
            fontWeight: fontWeight,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${transaction.date.day}/${transaction.date.month}/${transaction.date.year}',
              style: const TextStyle(fontFamily: '', fontWeight: FontWeight.bold),
            ),
            if (transaction.professionName != null)
              Text(
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
          children: [
            Text(
              'Rs. ${transaction.amount.toStringAsFixed(0)}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                fontFamily: '',
              ),
            ),
          ],
        ),
        onTap: () {
          // اگر باہر سے کوئی خاص فنکشن دیا گیا ہے تو وہ چلے، ورنہ رسید کھلے
          if (onTap != null) {
            onTap!();
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TransactionReceiptScreen(transaction: transaction),
              ),
            );
          }
        },
      ),
    );
  }
}
