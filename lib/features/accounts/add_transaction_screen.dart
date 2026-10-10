import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/notification_service.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/models/transaction_item_model.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/models/stock_item_model.dart';
import 'package:account_app/core/config/professions_config.dart';
import 'package:account_app/core/services/stock_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/image_selector_field.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/constants/quick_bill_constants.dart';
import 'package:account_app/core/utils/bill_numbering.dart';

class AddTransactionScreen extends StatefulWidget {
  final Account? account;
  final Transaction? transactionToEdit;
  final String? initialDescription;
  final double? initialAmount;
  final Profession? forcedProfession;

  const AddTransactionScreen({
    this.account,
    this.transactionToEdit,
    this.initialDescription,
    this.initialAmount,
    this.forcedProfession,
  });

  @override
  _AddTransactionScreenState createState() => _AddTransactionScreenState();
}

class _ItemEntry {
  final String id =
      DateTime.now().microsecondsSinceEpoch.toString(); // منفرد آئی ڈی
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController quantityController =
      TextEditingController(text: '');
  final TextEditingController subQuantityController =
      TextEditingController(text: ''); // For KG or Pieces
  final TextEditingController rateController = TextEditingController();
  final TextEditingController totalController = TextEditingController();
  final FocusNode descriptionFocusNode = FocusNode();
  String? unit = 'Pieces';
  String? stockItemId;
  double? stockSuggestedRate;
  bool rateWasManuallyEdited = false;
  bool applyingSuggestedRate = false;

  void dispose() {
    descriptionController.dispose();
    quantityController.dispose();
    subQuantityController.dispose();
    rateController.dispose();
    totalController.dispose();
    descriptionFocusNode.dispose();
  }
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  static const Map<String, String> _itemUnitLabels = {
    'Pieces': 'عدد',
    'Kg': 'کلو',
    'Gram': 'گرام',
    'Liter': 'لیٹر',
    'Meter': 'میٹر',
    'Sqft': 'مربع فٹ',
    'Dozen': 'درجن',
    'Box': 'ڈبہ',
    'Bag': 'بوری',
    'Maund': 'من',
    'Bottle': 'بوتل',
    'Packet': 'پیکٹ',
    'Tola': 'تولہ',
    'Other': 'دیگر',
  };

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _referenceNumberController =
      TextEditingController();
  final TextEditingController _dateInputController = TextEditingController();
  final List<_ItemEntry> _itemEntries = [];
  String? _selectedAccountId;
  String? _selectedProfessionId;
  String? _selectedCategory;
  String? _professionSyncType; // 'income' or 'expense'
  DateTime _selectedDate = DateTime.now();
  List<Account> _accounts = [];
  List<Profession> _professions = [];
  List<String> _allItemNames = [];
  final Map<String, StockItem> _stockItemsByName = {};
  late StockService _stockService;
  bool _isLoading = false;
  bool _isProfessionCentric = false;
  bool _didLoadNextBillNumber = false;

  List<File> _billImages = [];

  @override
  void initState() {
    super.initState();
    _stockService = Provider.of<StockService>(context, listen: false);
    _stockService.addListener(_loadData);

    if (widget.transactionToEdit != null) {
      final t = widget.transactionToEdit!;
      _amountController.text = t.amount.toStringAsFixed(0);
      _selectedDate = t.date;
      _selectedAccountId = t.accountId;
      _selectedProfessionId = t.professionId;
      _isProfessionCentric = t.accountId == 'default_account';

      if (t.professionId != null) {
        _professionSyncType =
            (t.category.startsWith('INC:') || t.category == 'income')
                ? 'income'
                : 'expense';
        _selectedCategory =
            t.category.contains(':') ? t.category.split(':')[1] : t.category;
      }

      _referenceNumberController.text = t.referenceNumber ?? '';
      if (t.billImage != null && t.billImage!.isNotEmpty) {
        _billImages = t.billImage!.split(',').map((p) => File(p)).toList();
      }

      if (t.items.isNotEmpty) {
        for (var item in t.items) {
          final entry = _ItemEntry();
          entry.descriptionController.text = item.description;
          entry.quantityController.text = item.quantity.toString();
          entry.rateController.text = item.rate.toStringAsFixed(0);
          entry.totalController.text = item.total.toStringAsFixed(0);
          entry.unit = item.unit ?? 'Pieces';
          entry.stockItemId = item.stockItemId;
          entry.rateWasManuallyEdited = item.stockItemId != null;
          _itemEntries.add(entry);
          _setupEntryListeners(entry);
        }
      } else {
        final entry = _ItemEntry();
        entry.descriptionController.text = t.description;
        entry.quantityController.text = t.quantity.toString();
        entry.rateController.text = t.amount.toStringAsFixed(0);
        entry.totalController.text = t.amount.toStringAsFixed(0);
        _itemEntries.add(entry);
        _setupEntryListeners(entry);
      }
    } else {
      _addNewItem();
      if (widget.initialDescription != null || widget.initialAmount != null) {
        final entry = _itemEntries.first;
        if (widget.initialDescription != null) {
          entry.descriptionController.text = widget.initialDescription!;
        }
        if (widget.initialAmount != null) {
          entry.rateController.text = widget.initialAmount!.toStringAsFixed(0);
          entry.quantityController.text = '1';
          entry.totalController.text = widget.initialAmount!.toStringAsFixed(0);
          _amountController.text = widget.initialAmount!.toStringAsFixed(0);
        }
      }
    }

    _dateInputController.text = DateFormat('dd/MM/yy').format(_selectedDate);
    _setupDateListener();

    Provider.of<StockService>(context, listen: false).addListener(_loadData);
    _loadData();
    if (widget.account != null && _selectedAccountId == null) {
      _selectedAccountId = widget.account!.id;
      _isProfessionCentric = false;
    }

    if (widget.forcedProfession != null) {
      _selectedProfessionId = widget.forcedProfession!.id;
      _isProfessionCentric = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadNextBillNumber || widget.transactionToEdit != null) return;
    _didLoadNextBillNumber = true;
    final nextNumber = BillNumbering.loadNextNumber(
      Provider.of<DatabaseService>(context, listen: false),
    );
    if (nextNumber != null) {
      _referenceNumberController.text = nextNumber;
    }
  }

  void _setupDateListener() {
    _dateInputController.addListener(() {
      String text = _dateInputController.text;

      // Auto-insert slash after DD
      if (text.length == 2 && !text.contains('/')) {
        _dateInputController.text = '$text/';
        _dateInputController.selection = TextSelection.fromPosition(
            TextPosition(offset: _dateInputController.text.length));
      }
      // Auto-insert slash after MM
      else if (text.length == 5 && text.split('/').length == 2) {
        _dateInputController.text = '$text/';
        _dateInputController.selection = TextSelection.fromPosition(
            TextPosition(offset: _dateInputController.text.length));
      }

      // Update selectedDate when format is valid DD/MM/YY
      if (text.length == 8) {
        try {
          List<String> parts = text.split('/');
          int day = int.parse(parts[0]);
          int month = int.parse(parts[1]);
          int yearPart = int.parse(parts[2]);

          int fullYear = yearPart < 50 ? 2000 + yearPart : 1900 + yearPart;

          DateTime newDate = DateTime(fullYear, month, day);

          if (newDate.day == day && newDate.month == month) {
            _selectedDate = newDate;
          }
        } catch (e) {
          debugPrint("Date parsing error: $e");
        }
      }
    });
  }

  void _addNewItem() {
    final entry = _ItemEntry();
    setState(() {
      _itemEntries.add(entry);
    });
    _setupEntryListeners(entry);
  }

  void _removeItem(int index) {
    if (_itemEntries.length > 1) {
      final entry = _itemEntries[index];
      entry.dispose();
      setState(() {
        _itemEntries.removeAt(index);
      });
      _calculateGrandTotal();
    }
  }

  void _setupEntryListeners(_ItemEntry entry) {
    void calculate() {
      final finalQuantity = _effectiveEntryQuantity(entry);
      double rate = double.tryParse(entry.rateController.text) ?? 0;

      final total = finalQuantity * rate;
      if (entry.totalController.text != total.toStringAsFixed(0)) {
        entry.totalController.text = total.toStringAsFixed(0);
      }
      _calculateGrandTotal();
    }

    entry.quantityController.addListener(calculate);
    entry.subQuantityController.addListener(calculate);
    entry.rateController.addListener(() {
      if (!entry.applyingSuggestedRate) entry.rateWasManuallyEdited = true;
      calculate();
    });
    entry.descriptionController.addListener(() {
      final previousStockItemId = entry.stockItemId;
      final stockItem = _stockItemsByName[
          entry.descriptionController.text.trim().toLowerCase()];
      if (stockItem?.id != previousStockItemId) {
        entry.stockItemId = stockItem?.id;
        if (stockItem != null) {
          entry.unit = stockItem.unit;
          if (widget.transactionToEdit != null) {
            entry.rateWasManuallyEdited = true;
          }
        } else if (previousStockItemId != null) {
          entry.unit = null;
          entry.rateWasManuallyEdited = false;
          entry.stockSuggestedRate = null;
        }
      }
      setState(() {});
    });
  }

  double _effectiveEntryQuantity(_ItemEntry entry) {
    final quantity = double.tryParse(entry.quantityController.text) ?? 0;
    final subQuantity = double.tryParse(entry.subQuantityController.text) ?? 0;
    if (entry.unit == 'من' || entry.unit == 'maund') {
      return quantity + (subQuantity / 40);
    }
    if (entry.unit == 'درجن' || entry.unit == 'doz') {
      return quantity + (subQuantity / 12);
    }
    return quantity;
  }

  void _setSuggestedStockRate(_ItemEntry entry, double rate) {
    if (rate <= 0) return;
    entry.stockSuggestedRate = rate;
    entry.rateWasManuallyEdited = false;
    entry.applyingSuggestedRate = true;
    entry.rateController.text = rate.toStringAsFixed(0);
    entry.applyingSuggestedRate = false;
  }

  void _calculateGrandTotal() {
    double grandTotal = 0;
    for (var entry in _itemEntries) {
      grandTotal += double.tryParse(entry.totalController.text) ?? 0;
    }
    if (_amountController.text != grandTotal.toStringAsFixed(0)) {
      setState(() {
        _amountController.text = grandTotal.toStringAsFixed(0);
      });
    }
  }

  Future<void> _loadData() async {
    final databaseService =
        Provider.of<DatabaseService>(context, listen: false);
    final stockService = _stockService;
    _accounts = databaseService.getAccounts().where((account) {
      return account.id != QuickBillConstants.cashCustomerAccountId ||
          account.id == _selectedAccountId;
    }).toList();
    final masterProfessions = databaseService.getMasterProfessions();
    _professions = masterProfessions.where((p) => p.isActive ?? true).toList();

    // Collect unique item names from past transactions
    Set<String> names = {};
    final allTxs = databaseService.getAllTransactions();
    for (var tx in allTxs) {
      if (tx.items.isNotEmpty) {
        for (var item in tx.items) {
          if (item.description.isNotEmpty) names.add(item.description);
        }
      } else if (tx.description.isNotEmpty &&
          tx.description != 'دیگر' &&
          tx.description != 'Other') {
        names.add(tx.description);
      }
    }

    _stockItemsByName.clear();
    for (final stockItem in stockService.items) {
      names.add(stockItem.name);
      _stockItemsByName[stockItem.name.trim().toLowerCase()] = stockItem;
      if (stockItem.nameUrdu.trim().isNotEmpty) {
        names.add(stockItem.nameUrdu);
        _stockItemsByName[stockItem.nameUrdu.trim().toLowerCase()] = stockItem;
      }
    }

    for (final entry in _itemEntries) {
      final stockItem = _stockItemsByName[
          entry.descriptionController.text.trim().toLowerCase()];
      if (stockItem != null) {
        entry.stockItemId = stockItem.id;
        entry.unit = stockItem.unit;
        if (widget.transactionToEdit != null) {
          entry.rateWasManuallyEdited = true;
        }
      }
    }

    if (mounted) {
      setState(() {
        _allItemNames = names.toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final fontWeight = isUrdu ? FontWeight.bold : FontWeight.normal;
    final isEditing = widget.transactionToEdit != null;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: isEditing
            ? (isUrdu ? 'لین دین میں ترمیم' : 'Edit Transaction')
            : (isUrdu ? 'نیا لین دین' : 'New Transaction'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.themeColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // 1. Basic Info Card
                  _buildSectionCard(
                    children: [
                      _buildSectionHeader(
                          isUrdu ? 'بنیادی معلومات' : 'Basic Information',
                          fontFamily,
                          isUrdu,
                          topPadding: 0),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _referenceNumberController,
                              label: isUrdu ? 'بل نمبر' : 'Bill Number',
                              isNumber: true,
                              icon: PhosphorIcons.hash(),
                              fontFamily: '',
                              fontWeight: fontWeight,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildEditableDateSelector(
                                isUrdu, fontFamily, fontWeight),
                          ),
                        ],
                      ),
                      if (widget.forcedProfession == null &&
                          _professions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildProfessionSelectionArea(
                            isUrdu, fontFamily, fontWeight),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. Items & Total Card
                  _buildSectionCard(
                    children: [
                      _buildSectionHeader(
                          isUrdu ? 'ایٹمز اور کل رقم' : 'Items & Total Amount',
                          fontFamily,
                          isUrdu,
                          topPadding: 0),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _itemEntries.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) => _buildItemRow(
                            index, isUrdu, fontFamily, fontWeight),
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _amountController,
                        label: isUrdu ? 'کل رقم' : 'Grand Total',
                        isNumber: true,
                        icon: PhosphorIcons.wallet(),
                        fontFamily: fontFamily,
                        fontWeight: FontWeight.bold,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3. Attachments Card
                  _buildSectionCard(
                    children: [
                      _buildSectionHeader(isUrdu ? 'منسلکات' : 'Attachments',
                          fontFamily, isUrdu,
                          topPadding: 0),
                      ImageSelectorField(
                        selectedFiles: _billImages,
                        onFilesChanged: (newList) =>
                            setState(() => _billImages = newList),
                        maxTotal: 1,
                        isVertical: true,
                        isFullWidth: true,
                        aspectRatio: 3,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Dual Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          text: isUrdu ? 'رقم لی / جمع' : 'Received',
                          icon: PhosphorIcons.arrowUpRight(
                              PhosphorIconsStyle.bold),
                          color: AppTheme.incomeColor,
                          variant: AppButtonVariant.primary,
                          size: AppButtonSize.large,
                          onPressed: () => _saveTransaction('income'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton(
                          text: isUrdu ? 'رقم دی / بنام' : 'Paid',
                          icon: PhosphorIcons.arrowDownLeft(
                              PhosphorIconsStyle.bold),
                          color: AppTheme.expenseColor,
                          variant: AppButtonVariant.primary,
                          size: AppButtonSize.large,
                          onPressed: () => _saveTransaction('expense'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildItemRow(
      int index, bool isUrdu, String fontFamily, FontWeight fontWeight) {
    final entry = _itemEntries[index];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 5,
                child: RawAutocomplete<String>(
                  key: ValueKey('item_autocomplete_${entry.id}'),
                  focusNode: entry.descriptionFocusNode,
                  textEditingController: entry.descriptionController,
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty)
                      return const Iterable<String>.empty();
                    final query = textEditingValue.text.toLowerCase();
                    return _allItemNames.where((String option) {
                      return option.toLowerCase().contains(query);
                    });
                  },
                  onSelected: (String selection) {
                    entry.descriptionController.text = selection;

                    final stockItem =
                        _stockItemsByName[selection.trim().toLowerCase()];
                    if (stockItem != null) {
                      setState(() {
                        entry.stockItemId = stockItem.id;
                        entry.unit = stockItem.unit;
                      });
                      final suggestedRate = stockItem.sellingPrice > 0
                          ? stockItem.sellingPrice
                          : stockItem.purchasePrice;
                      _setSuggestedStockRate(entry, suggestedRate);
                      return;
                    }
                    entry.stockItemId = null;

                    // Search in past transactions for the rate
                    final databaseService =
                        Provider.of<DatabaseService>(context, listen: false);
                    final allTxs = databaseService.getAllTransactions();
                    for (var tx in allTxs.reversed) {
                      bool found = false;
                      if (tx.items.isNotEmpty) {
                        for (var it in tx.items) {
                          if (it.description.trim().toLowerCase() ==
                              selection.trim().toLowerCase()) {
                            setState(() {
                              entry.rateController.text =
                                  it.rate.toStringAsFixed(0);
                              entry.unit = it.unit ?? 'Pieces';
                            });
                            found = true;
                            break;
                          }
                        }
                      } else if (tx.description.trim().toLowerCase() ==
                          selection.trim().toLowerCase()) {
                        setState(() {
                          entry.rateController.text =
                              tx.rate.toStringAsFixed(0);
                        });
                        found = true;
                      }
                      if (found) break;
                    }
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onFieldSubmitted) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      maxLines: 1,
                      keyboardType: TextInputType.multiline,
                      textAlign:
                          RegExp(r'[\u0600-\u06FF]').hasMatch(controller.text)
                              ? TextAlign.right
                              : TextAlign.left,
                      style: TextStyle(
                          color: AppTheme.darkColor,
                          fontFamily: fontFamily,
                          fontWeight: fontWeight,
                          fontSize: 16),
                      cursorColor: AppTheme.themeColor,
                      decoration: InputDecoration(
                        labelText: isUrdu ? 'تفصیل' : 'Description',
                        labelStyle: TextStyle(
                            fontFamily: fontFamily,
                            color: Colors.grey.shade600,
                            fontWeight: fontWeight,
                            fontSize: 13),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(color: Colors.grey[300]!)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(color: Colors.grey[300]!)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: const BorderSide(
                                color: AppTheme.themeColor, width: 1.5)),
                        prefixIcon: Icon(PhosphorIcons.note(),
                            color: AppTheme.themeColor, size: 20),
                      ),
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4.0,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.6,
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (BuildContext context, int index) {
                              final String option = options.elementAt(index);
                              return ListTile(
                                title: Text(option,
                                    style: TextStyle(
                                        fontFamily: fontFamily, fontSize: 14)),
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _buildSmallTextField(
                  controller: entry.quantityController,
                  label: entry.unit ?? (isUrdu ? 'تعداد' : 'Qty'),
                  fontFamily: fontFamily,
                  fontWeight: FontWeight.bold,
                  isNumber: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildUnitSelector(entry, isUrdu, fontFamily),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                onPressed: _addNewItem,
                icon: Icon(PhosphorIcons.plusCircle(PhosphorIconsStyle.fill),
                    color: AppTheme.themeColor, size: 28),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              Expanded(
                  flex: 3,
                  child: _buildSmallTextField(
                      controller: entry.rateController,
                      label: isUrdu ? 'ریٹ' : 'Rate',
                      fontFamily: fontFamily,
                      fontWeight: FontWeight.bold,
                      isNumber: true)),
              const SizedBox(width: 8),
              Expanded(
                  flex: 3,
                  child: _buildSmallTextField(
                      controller: entry.totalController,
                      label: isUrdu ? 'کل' : 'Total',
                      fontFamily: fontFamily,
                      fontWeight: FontWeight.bold,
                      isNumber: true,
                      readOnly: true)),
              if (_itemEntries.length > 1)
                IconButton(
                    icon: Icon(
                        PhosphorIcons.minusCircle(PhosphorIconsStyle.fill),
                        color: AppTheme.expenseColor),
                    onPressed: () => _removeItem(index)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnitSelector(
    _ItemEntry entry,
    bool isUrdu,
    String fontFamily,
  ) {
    final currentUnit = entry.unit ?? 'Pieces';
    final choices = entry.stockItemId == null
        ? _itemUnitLabels.keys.toList()
        : [currentUnit];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isUrdu ? 'اکائی منتخب کریں' : 'Unit',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 11,
            fontFamily: fontFamily,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: choices.map((unit) {
            final selected = unit == currentUnit;
            final label = isUrdu ? (_itemUnitLabels[unit] ?? unit) : unit;
            return ChoiceChip(
              label: Text(label),
              selected: selected,
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              labelStyle: TextStyle(
                color: selected ? AppTheme.darkColor : Colors.black87,
                fontFamily: fontFamily,
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: Colors.white,
              selectedColor: AppTheme.themeColor.withValues(alpha: 0.12),
              side: BorderSide(
                color: selected ? AppTheme.themeColor : Colors.black12,
              ),
              onSelected: (_) {
                if (entry.stockItemId != null || selected) return;
                setState(() => entry.unit = unit);
                entry.subQuantityController.clear();
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildProfessionSelectionArea(
      bool isUrdu, String fontFamily, FontWeight fontWeight) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isUrdu ? 'پیشہ منتخب کریں' : 'Select Profession',
              style: TextStyle(
                fontSize: 13,
                fontWeight: fontWeight,
                fontFamily: fontFamily,
                color: Colors.grey.shade600,
              ),
            ),
            if (_selectedProfessionId != null)
              GestureDetector(
                onTap: () => setState(() {
                  _selectedProfessionId = null;
                  _professionSyncType = null;
                }),
                child: Text(
                  isUrdu ? 'تبدیل کریں' : 'Change',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.themeColor,
                      fontWeight: FontWeight.bold,
                      fontFamily: fontFamily),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 88,
          child: _selectedProfessionId == null
              ? ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _professions.length + 1,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildProfessionCard(
                        null,
                        isUrdu ? 'کسی پیشے میں نہیں' : 'None',
                        PhosphorIcons.prohibit(),
                        _selectedProfessionId == null,
                        isUrdu,
                        fontFamily,
                        fontWeight,
                      );
                    }
                    final p = _professions[index - 1];
                    IconData displayIcon = _getProfessionIcon(p);
                    return _buildProfessionCard(p.id, p.name, displayIcon,
                        false, isUrdu, fontFamily, fontWeight);
                  },
                )
              : _buildSelectedProfessionView(isUrdu, fontFamily, fontWeight),
        ),
      ],
    );
  }

  Widget _buildSelectedProfessionView(
      bool isUrdu, String fontFamily, FontWeight fontWeight) {
    // Find the profession - it might be a Master ID or a Season ID
    final db = Provider.of<DatabaseService>(context, listen: false);
    Profession? selectedProf =
        _professions.where((p) => p.id == _selectedProfessionId).firstOrNull;

    // If not in the filtered list (e.g. it's a season), look it up globally
    selectedProf ??= db.getProfession(_selectedProfessionId!);

    if (selectedProf == null) {
      // Fallback if still not found
      return Text(isUrdu ? 'پیشہ دستیاب نہیں' : 'Profession not found');
    }

    return ListView(
      scrollDirection: Axis.horizontal,
      children: [
        // Always show "None" option
        _buildProfessionCard(
          null,
          isUrdu ? 'کسی پیشے میں نہیں' : 'None',
          PhosphorIcons.prohibit(),
          false,
          isUrdu,
          fontFamily,
          fontWeight,
        ),
        const SizedBox(width: 12),
        // Selected Profession
        _buildProfessionCard(
          _selectedProfessionId,
          selectedProf.name,
          _getProfessionIcon(selectedProf),
          true,
          isUrdu,
          fontFamily,
          fontWeight,
        ),
        const SizedBox(width: 12),
        Center(
            child:
                Container(width: 1.5, height: 40, color: Colors.grey.shade200)),
        const SizedBox(width: 12),
        _buildSyncTypeCard(
          label: isUrdu ? 'آمدن' : 'Income',
          type: 'income',
          icon: PhosphorIcons.trendUp(),
          color: AppTheme.incomeColor,
          isSelected: _professionSyncType == 'income',
          fontFamily: fontFamily,
        ),
        const SizedBox(width: 12),
        _buildSyncTypeCard(
          label: isUrdu ? 'خرچ' : 'Expense',
          type: 'expense',
          icon: PhosphorIcons.trendDown(),
          color: AppTheme.expenseColor,
          isSelected: _professionSyncType == 'expense',
          fontFamily: fontFamily,
        ),
      ],
    );
  }

  IconData _getProfessionIcon(Profession p) {
    IconData displayIcon = PhosphorIcons.briefcase();
    if (p.description != null && p.description!.startsWith('ICON:')) {
      try {
        final parts = p.description!.split('|');
        final iconKey = parts[0].substring(5);
        if (ProfessionsConfig.iconMap.containsKey(iconKey)) {
          displayIcon = ProfessionsConfig.iconMap[iconKey]!;
        }
      } catch (_) {}
    }
    return displayIcon;
  }

  Widget _buildSyncTypeCard({
    required String label,
    required String type,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required String fontFamily,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _professionSyncType = type;
          _selectedCategory = null; // Reset category
        });
      },
      child: SizedBox(
        width: 75,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? color : color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? color : color.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : color,
                size: 24,
              ),
            ),
            const SizedBox(height: 6),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontFamily: fontFamily,
                color: isSelected ? color : AppTheme.darkColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionCard(
    String? id,
    String name,
    IconData icon,
    bool isSelected,
    bool isUrdu,
    String fontFamily,
    FontWeight fontWeight,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_selectedProfessionId == id && id != null) {
            // Deselect if already selected
            _selectedProfessionId = null;
            _professionSyncType = null;
          } else {
            _selectedProfessionId = id;
            if (id == null) {
              _professionSyncType = null;
            }
          }
        });
      },
      child: SizedBox(
        width: 75,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.themeColor
                    : AppTheme.backgroundColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppTheme.themeColor : Colors.transparent,
                  width: 2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppTheme.themeColor.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AppTheme.themeColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontFamily: fontFamily,
                color: isSelected ? AppTheme.themeColor : AppTheme.darkColor,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
      {required List<Widget> children, EdgeInsets? padding}) {
    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.themeColor.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildSectionHeader(String title, String fontFamily, bool isUrdu,
      {double topPadding = 24}) {
    return Padding(
      padding: EdgeInsets.only(top: topPadding, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppTheme.themeColor,
          fontFamily: fontFamily,
        ),
      ),
    );
  }

  Widget _buildSmallTextField(
      {required TextEditingController controller,
      required String label,
      required String fontFamily,
      required FontWeight fontWeight,
      bool isNumber = false,
      bool readOnly = false,
      String? suffixText}) {
    final isUrdu = isUrduHelper(context);
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(
          color: readOnly ? Colors.grey : AppTheme.darkColor,
          fontFamily: isNumber ? '' : fontFamily,
          fontSize: isNumber ? 16 : 14,
          fontWeight: fontWeight),
      readOnly: readOnly,
      cursorColor: AppTheme.themeColor,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            fontFamily: isUrdu ? 'NooriNastaleeq' : '',
            color: Colors.grey.shade600,
            fontSize: 14,
            fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        suffixText: suffixText,
        suffixStyle: const TextStyle(fontSize: 10, color: Colors.grey),
        fillColor: Colors.white,
        filled: true,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide:
                const BorderSide(color: AppTheme.themeColor, width: 1.5)),
      ),
    );
  }

  bool isUrduHelper(BuildContext context) {
    return Provider.of<LanguageService>(context, listen: false).isUrdu;
  }

  Widget _buildTextField(
      {required TextEditingController controller,
      required String label,
      bool isNumber = false,
      IconData? icon,
      required String fontFamily,
      required FontWeight fontWeight}) {
    final isUrdu = isUrduHelper(context);
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(
          color: AppTheme.darkColor,
          fontFamily: isNumber ? '' : fontFamily,
          fontSize: 16,
          fontWeight: fontWeight),
      cursorColor: AppTheme.themeColor,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            fontFamily: isUrdu ? 'NooriNastaleeq' : '',
            color: Colors.grey.shade600,
            fontSize: 13,
            fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        fillColor: Colors.white,
        filled: true,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide:
                const BorderSide(color: AppTheme.themeColor, width: 1.5)),
        prefixIcon: icon != null
            ? Icon(icon, color: AppTheme.themeColor, size: 20)
            : null,
      ),
    );
  }

  Widget _buildEditableDateSelector(
      bool isUrdu, String fontFamily, FontWeight fontWeight) {
    return _buildTextField(
      controller: _dateInputController,
      label: isUrdu ? 'تاریخ' : 'Date',
      icon: PhosphorIcons.calendar(),
      fontFamily: '',
      fontWeight: FontWeight.bold,
    );
  }

  Future<void> _saveTransaction(String type) async {
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;

    final stockService = Provider.of<StockService>(context, listen: false);
    final requestedStockById = <String, double>{};
    for (final entry in _itemEntries) {
      final stockItemId = entry.stockItemId;
      if (stockItemId == null) continue;
      final stockItem = stockService.items.firstWhere(
        (item) => item.id == stockItemId,
        orElse: () => StockItem(
          id: '',
          name: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      if (stockItem.id.isEmpty) continue;

      final defaultRate =
          type == 'income' ? stockItem.sellingPrice : stockItem.purchasePrice;
      final currentRate = double.tryParse(entry.rateController.text) ?? 0;
      if (defaultRate > 0 &&
          (!entry.rateWasManuallyEdited ||
              currentRate == entry.stockSuggestedRate)) {
        _setSuggestedStockRate(entry, defaultRate);
      }

      if (type == 'income' && stockItem.trackStock) {
        requestedStockById.update(
          stockItemId,
          (quantity) => quantity + _effectiveEntryQuantity(entry),
          ifAbsent: () => _effectiveEntryQuantity(entry),
        );
      }
    }

    for (final requested in requestedStockById.entries) {
      final stockItem = stockService.items.firstWhere(
        (item) => item.id == requested.key,
      );
      final availableQuantity = stockService.availableStockForTransaction(
        stockItem.id,
        excludingTransactionId: widget.transactionToEdit?.id,
      );
      if (!StockService.canSellQuantity(
        availableStock: availableQuantity,
        quantity: requested.value,
        stopWhenOut: stockItem.stopWhenOut,
      )) {
        _showSnackBar(
          isUrdu
              ? '${stockItem.name} کا دستیاب اسٹاک ${availableQuantity.toStringAsFixed(1)} ہے'
              : 'Available ${stockItem.name} stock is ${availableQuantity.toStringAsFixed(1)}',
          true,
        );
        return;
      }
    }

    double grandTotal = double.tryParse(_amountController.text) ?? 0;
    if (grandTotal <= 0) {
      _showSnackBar(isUrdu ? 'رقم درج کریں' : 'Please enter amount', true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final databaseService =
          Provider.of<DatabaseService>(context, listen: false);
      final notificationService =
          Provider.of<NotificationService>(context, listen: false);

      List<TransactionItem> items = [];
      String mainDescription = "";
      for (var entry in _itemEntries) {
        final desc = entry.descriptionController.text;
        final total = double.tryParse(entry.totalController.text) ?? 0;
        if (total > 0 || desc.isNotEmpty) {
          items.add(TransactionItem(
            description: desc,
            quantity: _effectiveEntryQuantity(entry),
            rate: double.tryParse(entry.rateController.text) ?? total,
            total: total,
            unit: entry.unit,
            stockItemId: entry.stockItemId,
          ));
          if (desc.isNotEmpty)
            mainDescription += (mainDescription.isEmpty ? "" : ", ") + desc;
        }
      }

      String? profName;
      String? targetProfessionId = _selectedProfessionId;

      if (_selectedProfessionId != null) {
        try {
          // Look up profession globally as it could be a Season ID
          final db = Provider.of<DatabaseService>(context, listen: false);
          Profession? prof = db.getProfession(_selectedProfessionId!);

          if (prof != null) {
            profName = prof.name;

            // If it's a master profession, try to find an active season
            if (prof.parentId == null) {
              final seasons =
                  databaseService.getSeasons(_selectedProfessionId!);
              final activeSeason =
                  seasons.where((s) => s.isActive ?? true).firstOrNull;
              if (activeSeason != null) {
                targetProfessionId = activeSeason.id;
              }
            }
          }
        } catch (e) {
          debugPrint("Error setting profession data: $e");
        }
      }

      final transaction = Transaction(
        id: widget.transactionToEdit?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        accountId: _selectedAccountId ?? 'default_account',
        amount: grandTotal,
        pendingAmount: grandTotal,
        type: type,
        category: _professionSyncType ?? type,
        description: mainDescription.isEmpty ? 'دیگر' : mainDescription,
        date: _selectedDate,
        quantity: 1,
        rate: grandTotal,
        createdAt: widget.transactionToEdit?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        billImage: _billImages.isNotEmpty
            ? _billImages.map((f) => f.path).join(',')
            : null,
        referenceNumber: _referenceNumberController.text.trim(),
        items: items,
        professionId: targetProfessionId,
        professionName: profName,
      );

      if (widget.transactionToEdit != null) {
        await databaseService.updateTransaction(transaction);
      } else {
        await databaseService.addTransaction(transaction);
        final referenceNumber = transaction.referenceNumber?.trim() ?? '';
        if (referenceNumber.isNotEmpty) {
          await BillNumbering.saveNextNumber(databaseService, referenceNumber);
        }

        // Safely find account
        final accountIndex =
            _accounts.indexWhere((a) => a.id == _selectedAccountId);
        if (accountIndex != -1) {
          final account = _accounts[accountIndex];
          if (account.phone.isNotEmpty) {
            notificationService
                .notifyPartyByPhone(
                  partyPhoneNumber: account.phone,
                  amount: grandTotal,
                  transactionType: type,
                  category: transaction.category,
                  paymentMethod: transaction.paymentMethod,
                  description: transaction.description,
                  items: transaction.items.map((e) => e.toMap()).toList(),
                  receivedAmount: transaction.receivedAmount,
                  pendingAmount: transaction.pendingAmount,
                  transactionId: transaction.id,
                  transactionDate: transaction.date,
                  referenceNumber: transaction.referenceNumber,
                  subtotal: transaction.subtotal,
                  discountAmount: transaction.discountAmount,
                  discountPercent: transaction.discountPercent,
                  discountReason: transaction.discountReason,
                )
                .catchError((e) => debugPrint(e.toString()));
          }
        }
      }

      if (!mounted) return;

      // Close the screen first to avoid UI lag/spinner sticking
      Navigator.pop(context);
      _showSnackBar(isUrdu ? 'محفوظ ہوگیا' : 'Saved successfully', false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error: $e', true);
      }
    }
    // Removed finally to prevent setState on a popped screen
  }

  void _showSnackBar(String message, bool isError) {
    if (isError) {
      AppToast.error(context, message);
    } else {
      AppToast.success(context, message);
    }
  }

  @override
  void dispose() {
    _stockService.removeListener(_loadData);
    _amountController.dispose();
    _referenceNumberController.dispose();
    _dateInputController.dispose();
    for (var entry in _itemEntries) {
      entry.dispose();
    }
    super.dispose();
  }
}
