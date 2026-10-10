import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/constants/quick_bill_constants.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
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
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () => Navigator.pop(
                              context,
                              CustomerPickResult(isCashCustomer: true),
                            ),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.darkColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    PhosphorIcons.coins(),
                                    color: Colors.white70,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isUrdu ? 'نقد گاہک' : 'Cash customer',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          isUrdu
                                              ? 'کوئی کھاتہ نہیں بنے گا، صرف سیل ریکارڈ ہوگا'
                                              : 'No party account, just a sale record',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    PhosphorIcons.caretLeft(),
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _searchController,
                            onChanged: (v) => setState(() => _query = v),
                            decoration: InputDecoration(
                              hintText: isUrdu
                                  ? 'نام یا فون نمبر سے تلاش کریں'
                                  : 'Search by name or phone',
                              prefixIcon: Icon(
                                PhosphorIcons.magnifyingGlass(),
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isUrdu ? 'حالیہ پارٹیاں' : 'Recent parties',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (parties.isNotEmpty)
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        itemCount: parties.length,
                        itemBuilder: (context, index) {
                          final account = parties[index];
                          final isSelected = false;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              onTap: () => Navigator.pop(
                                context,
                                CustomerPickResult(account: account),
                              ),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.themeColor.withOpacity(0.08)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.themeColor
                                        : Colors.black12,
                                    width: isSelected ? 1.2 : 0.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor:
                                          AppTheme.themeColor.withOpacity(0.12),
                                      child: Text(
                                        account.name.isNotEmpty
                                            ? account.name[0]
                                            : '?',
                                        style: const TextStyle(
                                          color: AppTheme.darkColor,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            account.name,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            account.phone.isNotEmpty
                                                ? account.phone
                                                : (isUrdu
                                                    ? 'فون نمبر نہیں ہے'
                                                    : 'No phone number'),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.black54,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            account.balance == 0
                                                ? (isUrdu
                                                    ? 'بقایا: 0'
                                                    : 'Balance: 0')
                                                : '${isUrdu ? "بقایا" : "Balance"}: ${account.balance.abs().toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      PhosphorIcons.caretLeft(),
                                      size: 16,
                                      color: Colors.black45,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                        child: Text(
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
