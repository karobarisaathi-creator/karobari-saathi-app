import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/constants/quick_bill_constants.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/party_card.dart';
import 'package:account_app/core/widgets/search_sort_bar.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// گاہک منتخب کرنے کی شیٹ — نقد گاہک یا موجودہ پارٹیوں میں سے کوئی ایک۔
/// نتیجہ: منتخب Account، یا null اگر نقد گاہک چنا گیا ہو۔
class CustomerPickResult {
  final Account? account;
  final bool isCashCustomer;
  CustomerPickResult({this.account, this.isCashCustomer = false});
}

Future<CustomerPickResult?> showCustomerPickerSheet(BuildContext context) {
  return showModalBottomSheet<CustomerPickResult>(
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
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final databaseService =
        Provider.of<DatabaseService>(context, listen: false);

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
        color: Color(0xFFEEF2F5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomAppBar(
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
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SearchSortBar(
                            controller: _searchController,
                            hintText: isUrdu
                                ? 'نام یا فون نمبر سے تلاش کریں'
                                : 'Search by name or phone',
                            onSearchChanged: (v) => setState(() => _query = v),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: UrduAwareText(
                              isUrdu ? 'حالیہ پارٹیاں' : 'Recent parties',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (parties.isNotEmpty)
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        itemCount: parties.length,
                        itemBuilder: (context, index) {
                          final account = parties[index];
                          return PartyCard(
                            party: account,
                            onView: () => Navigator.pop(
                              context,
                              CustomerPickResult(account: account),
                            ),
                            onMessage: () => Navigator.pop(
                              context,
                              CustomerPickResult(account: account),
                            ),
                          );
                        },
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                        child: UrduAwareText(
                          isUrdu ? 'کوئی پارٹی نہیں ملی' : 'No parties found',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
