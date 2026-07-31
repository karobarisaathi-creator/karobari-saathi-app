import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/auto_sync_service.dart';
import 'package:account_app/core/services/notification_service.dart';
import 'package:account_app/core/models/transaction_model.dart';
import 'package:account_app/core/models/transaction_item_model.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/models/inventory_item_model.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/image_grid_viewer.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';

class AddTransactionScreen extends StatefulWidget {
  final Account? account;
  final Transaction? transactionToEdit;
  final String? initialDescription;
  final double? initialAmount;

  const AddTransactionScreen({
    this.account,
    this.transactionToEdit,
    this.initialDescription,
    this.initialAmount,
  });

  @override
  _AddTransactionScreenState createState() => _AddTransactionScreenState();
}

class _ItemEntry {
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController quantityController = TextEditingController(text: '');
  final TextEditingController subQuantityController = TextEditingController(text: ''); // For KG or Pieces
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

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _referenceNumberController = TextEditingController();
  final TextEditingController _dateInputController = TextEditingController();
  List<_ItemEntry> _itemEntries = [];
  String _transactionType = 'income';
  String? _selectedAccountId;
  String? _selectedProfessionId;
  DateTime _selectedDate = DateTime.now();
  List<Account> _accounts = [];
  List<Profession> _professions = [];
  List<InventoryItem> _inventoryItems = [];
  List<String> _allItemNames = [];
  bool _isLoading = false;

  List<String> _billImagePaths = [];
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();

    if (widget.transactionToEdit != null) {
      final t = widget.transactionToEdit!;
      _transactionType = t.type;
      _amountController.text = t.amount.toStringAsFixed(0);
      _selectedDate = t.date;
      _selectedAccountId = t.accountId;
      _selectedProfessionId = t.professionId;
      _referenceNumberController.text = t.referenceNumber ?? '';
      if (t.billImage != null && t.billImage!.isNotEmpty) {
        _billImagePaths = t.billImage!.split(',');
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

    _loadData();
    if (widget.account != null && _selectedAccountId == null) {
      _selectedAccountId = widget.account!.id;
    }
  }

  void _setupDateListener() {
    _dateInputController.addListener(() {
      String text = _dateInputController.text;

      // Auto-insert slash after DD
      if (text.length == 2 && !text.contains('/')) {
        _dateInputController.text = '$text/';
        _dateInputController.selection = TextSelection.fromPosition(TextPosition(offset: _dateInputController.text.length));
      }
      // Auto-insert slash after MM
      else if (text.length == 5 && text.split('/').length == 2) {
        _dateInputController.text = '$text/';
        _dateInputController.selection = TextSelection.fromPosition(TextPosition(offset: _dateInputController.text.length));
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
      double quantity = double.tryParse(entry.quantityController.text) ?? 0;
      double subQuantity = double.tryParse(entry.subQuantityController.text) ?? 0;
      double rate = double.tryParse(entry.rateController.text) ?? 0;

      // Handle dual-unit logic
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

    void lookupItemInfo() {
      final text = entry.descriptionController.text.trim().toLowerCase();
      if (text.isEmpty) {
        if (entry.unit != null) setState(() => entry.unit = null);
        return;
      }

      final invItem = _inventoryItems.firstWhere(
        (item) => item.name.trim().toLowerCase() == text,
        orElse: () => InventoryItem(id: '', name: '', unit: '', defaultRate: 0, createdAt: DateTime.now(), updatedAt: DateTime.now())
      );

      if (invItem.id.isNotEmpty) {
        if (entry.unit != invItem.unit) {
          setState(() {
            entry.unit = invItem.unit;
            if (entry.rateController.text.isEmpty && invItem.defaultRate > 0) {
              entry.rateController.text = invItem.defaultRate.toStringAsFixed(0);
            }
          });
        }
      }
    }

    entry.quantityController.addListener(calculate);
    entry.subQuantityController.addListener(calculate);
    entry.rateController.addListener(calculate);
    entry.descriptionController.addListener(() {
      lookupItemInfo();
      setState(() {});
    });
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
    final databaseService = Provider.of<DatabaseService>(context, listen: false);
    _accounts = await databaseService.getAccounts();
    _professions = await databaseService.getProfessions();
    _inventoryItems = databaseService.getInventoryItems();

    // Collect unique item names from inventory and past transactions
    Set<String> names = {};
    for (var item in _inventoryItems) {
      names.add(item.name);
    }
    final allTxs = databaseService.getAllTransactions();
    for (var tx in allTxs) {
      if (tx.items.isNotEmpty) {
        for (var item in tx.items) {
          if (item.description.isNotEmpty) names.add(item.description);
        }
      } else if (tx.description.isNotEmpty && tx.description != 'دیگر' && tx.description != 'Other') {
        names.add(tx.description);
      }
    }
    _allItemNames = names.toList();

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';
    final fontWeight = isUrdu ? FontWeight.bold : FontWeight.normal;
    final isAccountPreSelected = widget.account != null;
    final isEditing = widget.transactionToEdit != null;

    return Scaffold(
      backgroundColor: AppTheme.lightColor,
      appBar: CustomAppBar(
        title: isEditing ? (isUrdu ? 'لین دین میں ترمیم' : 'Edit Transaction') : (isUrdu ? 'نیا لین دین' : 'New Transaction'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.themeColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Bill Number & Date Row
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
                        child: _buildEditableDateSelector(isUrdu, fontFamily, fontWeight),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Items List
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _itemEntries.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _buildItemRow(index, isUrdu, fontFamily, fontWeight),
                  ),
                  const SizedBox(height: 20),

                  // Grand Total
                  _buildTextField(
                    controller: _amountController,
                    label: isUrdu ? 'کل رقم' : 'Grand Total',
                    isNumber: true,
                    icon: PhosphorIcons.wallet(),
                    fontFamily: fontFamily,
                    fontWeight: FontWeight.bold,
                  ),
                  const SizedBox(height: 16),

                  // Image Grid
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7F9),
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        if (_billImagePaths.isNotEmpty)
                          ImageGridViewer(imagePaths: _billImagePaths, onRemove: (index) => setState(() => _billImagePaths.removeAt(index))),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _addBillImage,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.themeColor.withOpacity(0.1)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(PhosphorIcons.camera(), color: AppTheme.themeColor, size: 22),
                                const SizedBox(width: 8),
                                Text(isUrdu ? 'تصویر شامل کریں' : 'Add Image', style: TextStyle(color: AppTheme.themeColor, fontFamily: fontFamily, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Dual Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _saveTransaction('income'),
                          icon: Icon(PhosphorIcons.arrowDownLeft(PhosphorIconsStyle.bold), color: Colors.white),
                          label: Text(isUrdu ? 'رقم لی / جمع' : 'Received', style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold, fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.incomeColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _saveTransaction('expense'),
                          icon: Icon(PhosphorIcons.arrowUpRight(PhosphorIconsStyle.bold), color: Colors.white),
                          label: Text(isUrdu ? 'رقم دی / بنام' : 'Paid', style: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold, fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.expenseColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildItemRow(int index, bool isUrdu, String fontFamily, FontWeight fontWeight) {
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
                  focusNode: entry.descriptionFocusNode,
                  textEditingController: entry.descriptionController,
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                    return _allItemNames.where((String option) {
                      return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  onSelected: (String selection) {
                    entry.descriptionController.text = selection;
                    // Try to find if it's an inventory item to auto-fill rate
                    final invItem = _inventoryItems.firstWhere(
                      (item) => item.name.trim().toLowerCase() == selection.trim().toLowerCase(),
                      orElse: () => InventoryItem(id: '', name: '', unit: '', defaultRate: 0, createdAt: DateTime.now(), updatedAt: DateTime.now())
                    );
                    if (invItem.id.isNotEmpty && invItem.defaultRate > 0) {
                      setState(() {
                        entry.rateController.text = invItem.defaultRate.toStringAsFixed(0);
                        entry.unit = invItem.unit;
                      });
                    } else {
                      // Search in past transactions for the rate
                      final databaseService = Provider.of<DatabaseService>(context, listen: false);
                      final allTxs = databaseService.getAllTransactions();
                      for (var tx in allTxs.reversed) {
                        bool found = false;
                        if (tx.items.isNotEmpty) {
                          for (var it in tx.items) {
                            if (it.description.trim().toLowerCase() == selection.trim().toLowerCase()) {
                              setState(() {
                                entry.rateController.text = it.rate.toStringAsFixed(0);
                                entry.unit = it.unit;
                              });
                              found = true;
                              break;
                            }
                          }
                        } else if (tx.description.trim().toLowerCase() == selection.trim().toLowerCase()) {
                          setState(() {
                            entry.rateController.text = tx.rate.toStringAsFixed(0);
                          });
                          found = true;
                        }
                        if (found) break;
                      }
                    }
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      maxLines: 1,
                      keyboardType: TextInputType.multiline,
                      textAlign: RegExp(r'[\u0600-\u06FF]').hasMatch(controller.text) ? TextAlign.right : TextAlign.left,
                      style: TextStyle(color: AppTheme.darkColor, fontFamily: fontFamily, fontWeight: fontWeight, fontSize: 16),
                      cursorColor: AppTheme.themeColor,
                      decoration: InputDecoration(
                        labelText: isUrdu ? 'تفصیل' : 'Description',
                        labelStyle: TextStyle(fontFamily: fontFamily, color: Colors.grey.shade600, fontWeight: fontWeight, fontSize: 13),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: Colors.grey.shade400)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: Colors.grey.shade400)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: AppTheme.themeColor, width: 1)),
                        prefixIcon: Icon(PhosphorIcons.note(), color: AppTheme.themeColor, size: 20),
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
                                title: Text(option, style: TextStyle(fontFamily: fontFamily, fontSize: 14)),
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
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                onPressed: _addNewItem,
                icon: Icon(PhosphorIcons.plusCircle(PhosphorIconsStyle.fill), color: AppTheme.themeColor, size: 28),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              Expanded(flex: 3, child: _buildSmallTextField(controller: entry.rateController, label: isUrdu ? 'ریٹ' : 'Rate', fontFamily: fontFamily, fontWeight: FontWeight.bold, isNumber: true)),
              const SizedBox(width: 8),
              Expanded(flex: 3, child: _buildSmallTextField(controller: entry.totalController, label: isUrdu ? 'کل' : 'Total', fontFamily: fontFamily, fontWeight: FontWeight.bold, isNumber: true, readOnly: true)),
              if (_itemEntries.length > 1) 
                IconButton(
                  icon: Icon(PhosphorIcons.minusCircle(PhosphorIconsStyle.fill), color: AppTheme.expenseColor), 
                  onPressed: () => _removeItem(index)
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallTextField({required TextEditingController controller, required String label, required String fontFamily, required FontWeight fontWeight, bool isNumber = false, bool readOnly = false, String? suffixText}) {
    final isUrdu = isUrduHelper(context);
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(
        color: AppTheme.darkColor, 
        fontFamily: isNumber ? '' : fontFamily, 
        fontSize: isNumber ? 16 : 14,
        fontWeight: fontWeight
      ),
      readOnly: readOnly,
      cursorColor: AppTheme.themeColor,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontFamily: isUrdu ? 'NooriNastaleeq' : '', color: Colors.grey.shade600, fontSize: 14, fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        suffixText: suffixText,
        suffixStyle: const TextStyle(fontSize: 10, color: Colors.grey),
        fillColor: Colors.white,
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: Colors.grey.shade400)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: Colors.grey.shade400)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: AppTheme.themeColor, width: 1)),
      ),
    );
  }

  bool isUrduHelper(BuildContext context) {
    return Provider.of<LanguageService>(context, listen: false).isUrdu;
  }

  Widget _buildTextField({required TextEditingController controller, required String label, bool isNumber = false, IconData? icon, required String fontFamily, required FontWeight fontWeight}) {
    final isUrdu = isUrduHelper(context);
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(
        color: AppTheme.darkColor, 
        fontFamily: isNumber ? '' : fontFamily, 
        fontSize: isNumber ? 18 : 16,
        fontWeight: fontWeight
      ),
      cursorColor: AppTheme.themeColor,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontFamily: isUrdu ? 'NooriNastaleeq' : '', color: Colors.grey.shade600, fontSize: 13, fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        fillColor: const Color(0xFFF5F7F9),
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: Colors.grey.shade400)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: Colors.grey.shade400)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: AppTheme.themeColor, width: 1)),
        prefixIcon: icon != null ? Icon(icon, color: AppTheme.themeColor, size: 20) : null,
      ),
    );
  }

  Widget _buildDropdownField({required dynamic value, required String label, required List<DropdownMenuItem<Object>> items, required Function(Object?) onChanged, IconData? icon, required String fontFamily, required FontWeight fontWeight}) {
    final isUrdu = isUrduHelper(context);
    return DropdownButtonFormField(
      value: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontFamily: isUrdu ? 'NooriNastaleeq' : '', color: Colors.grey.shade600, fontWeight: isUrdu ? FontWeight.bold : FontWeight.normal, fontSize: 13),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        fillColor: const Color(0xFFF5F7F9),
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: Colors.grey.shade400)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: BorderSide(color: Colors.grey.shade400)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0), borderSide: const BorderSide(color: AppTheme.themeColor, width: 1)),
        prefixIcon: icon != null ? Icon(icon, color: AppTheme.themeColor) : null,
      ),
    );
  }

  Widget _buildEditableDateSelector(bool isUrdu, String fontFamily, FontWeight fontWeight) {
    return _buildTextField(
      controller: _dateInputController,
      label: isUrdu ? 'تاریخ' : 'Date',
      icon: PhosphorIcons.calendar(),
      fontFamily: '',
      fontWeight: FontWeight.bold,
    );
  }

  Future<void> _addBillImage() async {
    final List<XFile> images = await _imagePicker.pickMultiImage(maxWidth: 1024, maxHeight: 1024, imageQuality: 80);
    if (images.isNotEmpty) setState(() => _billImagePaths.addAll(images.map((e) => e.path)));
  }

  Future<void> _saveTransaction(String type) async {
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    if (_selectedAccountId == null) {
      _showSnackBar(isUrdu ? 'اکاؤنٹ منتخب کریں' : 'Please select account', true);
      return;
    }
    double grandTotal = double.tryParse(_amountController.text) ?? 0;
    if (grandTotal <= 0) {
      _showSnackBar(isUrdu ? 'رقم درج کریں' : 'Please enter amount', true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final databaseService = Provider.of<DatabaseService>(context, listen: false);
      final syncService = Provider.of<AutoSyncService>(context, listen: false);
      final notificationService = Provider.of<NotificationService>(context, listen: false);

      List<TransactionItem> items = [];
      String mainDescription = "";
      for (var entry in _itemEntries) {
        final desc = entry.descriptionController.text;
        final total = double.tryParse(entry.totalController.text) ?? 0;
        if (total > 0 || desc.isNotEmpty) {
          items.add(TransactionItem(
            description: desc, 
            quantity: double.tryParse(entry.quantityController.text) ?? 1, 
            rate: double.tryParse(entry.rateController.text) ?? total, 
            total: total,
            unit: entry.unit,
          ));
          if (desc.isNotEmpty) mainDescription += (mainDescription.isEmpty ? "" : ", ") + desc;
        }
      }

      final transaction = Transaction(
        id: widget.transactionToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        accountId: _selectedAccountId!,
        amount: grandTotal,
        pendingAmount: grandTotal, // مینول ٹرانزیکشن کے لیے بیلنس اپ ڈیٹ کرنے کے لیے یہ ضروری ہے
        type: type,
        category: 'دیگر',
        description: mainDescription.isEmpty ? 'دیگر' : mainDescription,
        date: _selectedDate,
        quantity: 1,
        rate: grandTotal,
        createdAt: widget.transactionToEdit?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        billImage: _billImagePaths.isNotEmpty ? _billImagePaths.join(',') : null,
        referenceNumber: _referenceNumberController.text.trim(),
        items: items,
      );

      if (widget.transactionToEdit != null) {
        await databaseService.updateTransaction(transaction);
      } else {
        await databaseService.addTransaction(transaction);
        
        // Auto-save new items to inventory for analysis ONLY for 'expense' (Paid/Banaam) transactions
        if (type == 'expense') {
          for (var item in items) {
            final exists = _inventoryItems.any((inv) => inv.name.toLowerCase() == item.description.toLowerCase());
            if (!exists && item.description.isNotEmpty && item.description != 'دیگر' && item.description != 'Other') {
              final newItem = InventoryItem(
                id: DateTime.now().millisecondsSinceEpoch.toString() + item.description.hashCode.toString(),
                name: item.description,
                unit: item.unit ?? 'واحد',
                defaultRate: item.rate,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              await databaseService.addInventoryItem(newItem);
            }
          }
        }

        syncService.syncNewTransaction(transaction).catchError((e) => print(e));
        final account = _accounts.firstWhere((a) => a.id == _selectedAccountId);
        if (account.phone.isNotEmpty) {
          notificationService.notifyPartyByPhone(
            partyPhoneNumber: account.phone, 
            amount: grandTotal, 
            transactionType: type,
            description: transaction.description,
            items: transaction.items?.map((e) => e.toMap()).toList(),
          ).catchError((e) => print(e));
        }
      }
      _showSnackBar(isUrdu ? 'محفوظ ہوگیا' : 'Saved successfully', false);
      Navigator.pop(context);
    } catch (e) {
      _showSnackBar('Error: $e', true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context, bool isUrdu) async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateInputController.text = DateFormat('dd/MM/yy').format(picked);
      });
    }
  }

  void _showInventoryPicker(int index) {
    final languageService = Provider.of<LanguageService>(context, listen: false);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              isUrdu ? 'آئٹم منتخب کریں' : 'Select Item',
              style: TextStyle(fontFamily: fontFamily, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _inventoryItems.length,
              itemBuilder: (context, i) {
                final item = _inventoryItems[i];
                return ListTile(
                  title: Text(item.name, style: TextStyle(fontFamily: fontFamily)),
                  subtitle: Text('Rs ${item.defaultRate} / ${item.unit}', style: TextStyle(fontFamily: fontFamily)),
                  onTap: () {
                    setState(() {
                      final entry = _itemEntries[index];
                      entry.descriptionController.text = item.name;
                      entry.rateController.text = item.defaultRate.toString();
                      entry.unit = item.unit;
                      // Auto-calculate will trigger from listeners
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: isError ? AppTheme.expenseColor : AppTheme.incomeColor));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceNumberController.dispose();
    _dateInputController.dispose();
    for (var entry in _itemEntries) entry.dispose();
    super.dispose();
  }
}
