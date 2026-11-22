import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/constants/quick_bill_constants.dart';
import 'package:account_app/core/widgets/party_card.dart';
import 'package:account_app/core/widgets/search_sort_bar.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/features/accounts/add_party_screen.dart';
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
            Formatters.phoneMatchesSearch(a.phone, _query))
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppTheme.darkColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: UrduAwareText(
                      isUrdu ? 'گاہک منتخب کریں' : 'Select customer',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
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
                          // Add New Party List Button (above Search Bar)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.themeColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.themeColor.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 2),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.themeColor,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  PhosphorIcons.userPlus(PhosphorIconsStyle.bold),
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              title: UrduAwareText(
                                isUrdu
                                    ? 'نیا پارٹی / اکاؤنٹ شامل کریں'
                                    : 'Add New Party / Account',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.darkColor,
                                ),
                              ),
                              trailing: Icon(
                                isUrdu
                                    ? Icons.chevron_left_rounded
                                    : Icons.chevron_right_rounded,
                                color: AppTheme.themeColor,
                              ),
                              onTap: () async {
                                Navigator.pop(context);
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AddPartyScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                          SearchSortBar(
                            controller: _searchController,
                            padding: EdgeInsets.zero,
                            hintText: isUrdu
                                ? 'نام یا فون نمبر سے تلاش کریں'
                                : 'Search by name or phone',
                            onSearchChanged: (v) => setState(() => _query = v),
                          ),
                          const SizedBox(height: 8),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
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
