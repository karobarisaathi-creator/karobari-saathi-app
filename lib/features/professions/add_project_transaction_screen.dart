import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'package:account_app/core/models/transaction_item_model.dart' as model;
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/image_selector_field.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'categories_management_screen.dart';

class AddProjectTransactionScreen extends StatefulWidget {
  final Profession profession;
  final model.Transaction? transactionToEdit;

  const AddProjectTransactionScreen({
    super.key,
    required this.profession,
    this.transactionToEdit,
  });

  @override
  State<AddProjectTransactionScreen> createState() =>
      _AddProjectTransactionScreenState();
}

class _ItemEntry {
  final String id = DateTime.now().microsecondsSinceEpoch.toString();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController quantityController =
      TextEditingController(text: '');
  final TextEditingController subQuantityController =
      TextEditingController(text: '');
  final TextEditingController rateController = TextEditingController();
  final TextEditingController totalController = TextEditingController();
  final FocusNode descriptionFocusNode = FocusNode();
  String? unit;

  void dispose() {
    descriptionController.dispose();
    quantityController.dispose();
    subQuantityController.dispose();
    rateController.dispose();
    totalController.dispose();
    descriptionFocusNode.dispose();
  }
}

class _AddProjectTransactionScreenState
    extends State<AddProjectTransactionScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _referenceNumberController =
      TextEditingController();
  final TextEditingController _dateInputController = TextEditingController();
  final List<_ItemEntry> _itemEntries = [];
  String? _selectedCategory;
  String? _selectedType; // ہمیشہ آمدن یا خرچ کو ٹریک کریں
  DateTime _selectedDate = DateTime.now();
  List<String> _allItemNames = [];
  bool _isLoading = false;

  List<File> _billImages = [];

  @override
  void initState() {
    super.initState();

    if (widget.transactionToEdit != null) {
      final t = widget.transactionToEdit!;
      _amountController.text = t.amount.toStringAsFixed(0);
      _selectedDate = t.date;

      // نوٹ: زمرہ سے قسم (آمدنی/خرچ) کا تعین کریں
      if (t.category.startsWith('INC:')) {
        _selectedType = 'income';
        _selectedCategory = t.category.substring(4);
      } else if (t.category.startsWith('EXP:')) {
        _selectedType = 'expense';
        _selectedCategory = t.category.substring(4);
      } else if (t.category == 'income') {
        _selectedType = 'income';
        _selectedCategory = null;
      } else if (t.category == 'expense') {
        _selectedType = 'expense';
        _selectedCategory = null;
      } else if (t.category != 'دیگر') {
        _selectedCategory = t.category;
        _selectedType = null; // صارف کو دوبارہ منتخب کرنا ہوگا
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
          entry.unit = item.unit;
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
    }

    _dateInputController.text = DateFormat('dd/MM/yy').format(_selectedDate);
    _setupDateListener();
    _loadItemNames();
  }

  void _setupDateListener() {
    _dateInputController.addListener(() {
      String text = _dateInputController.text;
      if (text.length == 2 && !text.contains('/')) {
        _dateInputController.text = '$text/';
        _dateInputController.selection = TextSelection.fromPosition(
            TextPosition(offset: _dateInputController.text.length));
      } else if (text.length == 5 && text.split('/').length == 2) {
        _dateInputController.text = '$text/';
        _dateInputController.selection = TextSelection.fromPosition(
            TextPosition(offset: _dateInputController.text.length));
      }
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
        } catch (_) {}
      }
    });
  }

  void _addNewItem() {
    final entry = _ItemEntry();
    setState(() => _itemEntries.add(entry));
    _setupEntryListeners(entry);
  }

  void _removeItem(int index) {
    if (_itemEntries.length > 1) {
      final entry = _itemEntries[index];
      entry.dispose();
      setState(() => _itemEntries.removeAt(index));
      _calculateGrandTotal();
    }
  }

  void _setupEntryListeners(_ItemEntry entry) {
    void calculate() {
      double quantity = double.tryParse(entry.quantityController.text) ?? 0;
      double subQuantity =
          double.tryParse(entry.subQuantityController.text) ?? 0;
      double rate = double.tryParse(entry.rateController.text) ?? 0;
      double finalQuantity = quantity;
      if (entry.unit == 'من' || entry.unit == 'maund') {
        finalQuantity = quantity + (subQuantity / 40);
      } else if (entry.unit == 'درجن' || entry.unit == 'doz') {
        finalQuantity = quantity + (subQuantity / 12);
      }
      final total = finalQuantity * rate;
      if (entry.totalController.text != total.toStringAsFixed(0)) {
        entry.totalController.text = total.toStringAsFixed(0);
      }
      _calculateGrandTotal();
    }

    entry.quantityController.addListener(calculate);
    entry.subQuantityController.addListener(calculate);
    entry.rateController.addListener(calculate);
    entry.descriptionController.addListener(() => setState(() {}));
  }

  void _calculateGrandTotal() {
    double grandTotal = 0;
    for (var entry in _itemEntries) {
      grandTotal += double.tryParse(entry.totalController.text) ?? 0;
    }
    if (_amountController.text != grandTotal.toStringAsFixed(0)) {
      setState(() => _amountController.text = grandTotal.toStringAsFixed(0));
    }
  }

  void _loadItemNames() {
    final databaseService =
        Provider.of<DatabaseService>(context, listen: false);
    Set<String> names = {};
    for (var tx in databaseService.getAllTransactions()) {
      if (tx.items.isNotEmpty) {
        for (var it in tx.items) {
          if (it.description.isNotEmpty) {
            names.add(it.description);
          }
        }
      } else if (tx.description.isNotEmpty && tx.description != 'دیگر') {
        names.add(tx.description);
      }
    }
    setState(() => _allItemNames = names.toList());
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
            ? (isUrdu ? 'ترمیم' : 'Edit')
            : (isUrdu ? 'نیا لین دین' : 'New Transaction'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.themeColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // 1. Basic Info
                  _buildSectionCard(
                    children: [
                      _buildSectionHeader(
                          isUrdu ? 'بنیادی معلومات' : 'Basic Information',
                          fontFamily,
                          isUrdu,
                          topPadding: 0),
                      const SizedBox(height: 8),
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
                                  isUrdu, fontFamily, fontWeight)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildCategorySelector(isUrdu, fontFamily, fontWeight),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. Items & Total
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

                  // 3. Attachments
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

                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          text: isUrdu ? 'آمدن' : 'Income',
                          icon: PhosphorIcons.arrowUpRight(
                              PhosphorIconsStyle.bold),
                          color: AppTheme.incomeColor,
                          size: AppButtonSize.large,
                          onPressed: () => _saveTransaction('income'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton(
                          text: isUrdu ? 'خرچ' : 'Expense',
                          icon: PhosphorIcons.arrowDownLeft(
                              PhosphorIconsStyle.bold),
                          color: AppTheme.expenseColor,
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

  Widget _buildCategorySelector(
      bool isUrdu, String fontFamily, FontWeight fontWeight) {
    // ہمیشہ ماسٹر ریکارڈ سے زمرے حاصل کریں تاکہ وہی لسٹ ملے جو مینجمنٹ اسکرین پر ہے
    final db = Provider.of<DatabaseService>(context, listen: false);
    final masterId = widget.profession.parentId ?? widget.profession.id;
    final masterProf = db.getProfession(masterId);

    List<String> cats = (masterProf?.categories ?? widget.profession.categories)
        .map((c) {
          if (c.contains(':')) return c.split(':')[1];
          return c;
        })
        .toSet()
        .toList();

    // اگر لسٹ خالی ہو تو وہی ڈیفالٹ لسٹ دکھائیں جو مینجمنٹ اسکرین پر ہے
    if (cats.isEmpty) {
      cats = getAppDefaultCategories(isUrdu);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(isUrdu ? 'زمرہ منتخب کریں' : 'Select Category',
            style: TextStyle(
                fontSize: 13,
                fontWeight: fontWeight,
                fontFamily: fontFamily,
                color: Colors.grey.shade600)),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cats.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = cats[index];
              final isSelected = _selectedCategory == cat;
              return InkWell(
                onTap: () => setState(() => _selectedCategory = cat),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.themeColor : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: isSelected
                            ? AppTheme.themeColor
                            : Colors.grey.shade300),
                  ),
                  alignment: Alignment.center,
                  child: Text(cat,
                      style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Colors.white : AppTheme.darkColor,
                          fontFamily: fontFamily,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildItemRow(
      int index, bool isUrdu, String fontFamily, FontWeight fontWeight) {
    final entry = _itemEntries[index];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFF5F7F9),
          borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 5,
                child: RawAutocomplete<String>(
                  focusNode: entry.descriptionFocusNode,
                  textEditingController: entry.descriptionController,
                  optionsBuilder: (textValue) => textValue.text.isEmpty
                      ? const Iterable<String>.empty()
                      : _allItemNames.where((opt) => opt
                          .toLowerCase()
                          .contains(textValue.text.toLowerCase())),
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
                  fieldViewBuilder: (context, controller, focusNode, _) =>
                      TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    style: TextStyle(
                        color: AppTheme.darkColor,
                        fontFamily: fontFamily,
                        fontWeight: fontWeight,
                        fontSize: 16),
                    decoration: _inputDecoration(
                        isUrdu ? 'تفصیل' : 'Description',
                        PhosphorIcons.note(),
                        fontFamily),
                  ),
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
                      isNumber: true)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                  onPressed: _addNewItem,
                  icon: Icon(PhosphorIcons.plusCircle(PhosphorIconsStyle.fill),
                      color: AppTheme.themeColor, size: 28),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints()),
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

  InputDecoration _inputDecoration(
      String label, IconData icon, String fontFamily) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
          fontFamily: fontFamily, color: Colors.grey.shade600, fontSize: 13),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      fillColor: Colors.white,
      filled: true,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.themeColor, width: 1.5)),
      prefixIcon: Icon(icon, color: AppTheme.themeColor, size: 20),
    );
  }

  Widget _buildSmallTextField(
      {required TextEditingController controller,
      required String label,
      required String fontFamily,
      required FontWeight fontWeight,
      bool isNumber = false,
      bool readOnly = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      readOnly: readOnly,
      style: TextStyle(
          color: readOnly ? Colors.grey : AppTheme.darkColor,
          fontFamily: isNumber ? '' : fontFamily,
          fontSize: 16,
          fontWeight: fontWeight),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            fontFamily: fontFamily, color: Colors.grey.shade600, fontSize: 14),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        fillColor: Colors.white,
        filled: true,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppTheme.themeColor, width: 1.5)),
      ),
    );
  }

  Widget _buildTextField(
      {required TextEditingController controller,
      required String label,
      bool isNumber = false,
      IconData? icon,
      required String fontFamily,
      required FontWeight fontWeight}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(
          color: AppTheme.darkColor,
          fontFamily: isNumber ? '' : fontFamily,
          fontSize: 16,
          fontWeight: fontWeight),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            fontFamily: fontFamily, color: Colors.grey.shade600, fontSize: 13),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        fillColor: Colors.white,
        filled: true,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
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
        fontWeight: FontWeight.bold);
  }

  Widget _buildSectionCard(
      {required List<Widget> children, EdgeInsets? padding}) {
    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.themeColor.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ]),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildSectionHeader(String title, String fontFamily, bool isUrdu,
      {double topPadding = 24}) {
    return Padding(
        padding: EdgeInsets.only(top: topPadding, bottom: 8),
        child: Text(title,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.themeColor,
                fontFamily: fontFamily)));
  }

  Future<void> _saveTransaction(String type) async {
    double grandTotal = double.tryParse(_amountController.text) ?? 0;
    if (grandTotal <= 0) return;

    setState(() => _isLoading = true);
    try {
      final db = Provider.of<DatabaseService>(context, listen: false);

      // یقینی بنائیں کہ نوع سیٹ ہے
      _selectedType = type;

      List<model.TransactionItem> items = [];
      String mainDesc = "";
      for (var entry in _itemEntries) {
        final desc = entry.descriptionController.text;
        final total = double.tryParse(entry.totalController.text) ?? 0;
        if (total > 0 || desc.isNotEmpty) {
          items.add(model.TransactionItem(
            description: desc,
            quantity: double.tryParse(entry.quantityController.text) ?? 1,
            rate: double.tryParse(entry.rateController.text) ?? total,
            total: total,
            unit: entry.unit,
          ));
          if (desc.isNotEmpty)
            mainDesc += (mainDesc.isEmpty ? "" : ", ") + desc;
        }
      }

      final transaction = model.Transaction(
        id: widget.transactionToEdit?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        accountId: 'default_account',
        amount: grandTotal,
        pendingAmount: grandTotal,
        type: type,
        category:
            '${type == 'income' ? 'INC:' : 'EXP:'}${_selectedCategory ?? 'دیگر'}',
        description: mainDesc.isEmpty ? 'دیگر' : mainDesc,
        date: _selectedDate,
        createdAt: widget.transactionToEdit?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        billImage: _billImages.isNotEmpty
            ? _billImages.map((f) => f.path).join(',')
            : null,
        referenceNumber: _referenceNumberController.text.trim(),
        items: items,
        professionId: widget.profession.id,
        professionName: widget.profession.name,
      );

      if (widget.transactionToEdit != null) {
        await db.updateTransaction(transaction);
      } else {
        await db.addTransaction(transaction);
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceNumberController.dispose();
    _dateInputController.dispose();
    for (var entry in _itemEntries) {
      entry.dispose();
    }
    super.dispose();
  }
}
