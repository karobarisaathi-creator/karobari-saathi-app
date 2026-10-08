import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/constants/quick_bill_constants.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart' as app_widgets;
import 'package:account_app/core/widgets/party_card.dart';
import 'package:account_app/core/widgets/search_sort_bar.dart';

/// Opens the party selector and returns the chosen account, or null on close.
Future<Account?> showCustomerPickerSheet(BuildContext context) {
  return showModalBottomSheet<Account>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const CustomerPickerSheet(),
  );
}

class CustomerPickerSheet extends StatefulWidget {
  const CustomerPickerSheet({super.key});

  @override
  State<CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<CustomerPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final databaseService = Provider.of<DatabaseService>(context, listen: false);

    final parties = databaseService
        .getAccounts()
        .where((a) => a.id != QuickBillConstants.cashCustomerAccountId)
        .where((a) =>
            _query.isEmpty ||
            a.name.toLowerCase().contains(_query.toLowerCase()) ||
            a.phone.contains(_query))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final contentHeight = MediaQuery.of(context).size.height * 0.78;

    return Container(
      constraints: BoxConstraints(maxHeight: contentHeight),
      decoration: const BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            app_widgets.CustomAppBar(
              title: isUrdu ? 'گاہک منتخب کریں' : 'Select customer',
              showBackButton: false,
              backgroundColor: AppTheme.darkColor,
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              actions: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  tooltip: isUrdu ? 'بند کریں' : 'Close',
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SearchSortBar(
                    hintText: isUrdu ? 'نام یا فون نمبر سے تلاش کریں' : 'Search by name or phone',
                    onSearchChanged: (v) => setState(() => _query = v),
                    isAscending: true,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isUrdu ? 'حالیہ پارٹیاں' : 'Recent parties',
                    style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: parties.length,
                itemBuilder: (context, index) {
                  final account = parties[index];

                  return PartyCard(
                    party: account,
                    onView: () => Navigator.pop(context, account),
                    onMessage: () {},
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
