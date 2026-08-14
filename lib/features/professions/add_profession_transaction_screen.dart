import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/models/profession_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as transaction_model;
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/app_button.dart';

class AddProfessionTransactionScreen extends StatefulWidget {
  final Profession profession;
  final List<String> incomeCategories;
  final List<String> expenseCategories;
  final transaction_model.Transaction? transactionToEdit;

  const AddProfessionTransactionScreen({
    Key? key,
    required this.profession,
    required this.incomeCategories,
    required this.expenseCategories,
    this.transactionToEdit,
  }) : super(key: key);

  @override
  _AddProfessionTransactionScreenState createState() => _AddProfessionTransactionScreenState();
}

class _AddProfessionTransactionScreenState extends State<AddProfessionTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  
  final TextEditingController _productionAmountController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  String? _selectedUnit;

  String _transactionType = 'income';
  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  final List<Map<String, String>> _units = [
    {'en': 'kg', 'ur': 'کلو'},
    {'en': 'gram', 'ur': 'گرام'},
    {'en': 'ton', 'ur': 'ٹن'},
    {'en': 'man', 'ur': 'من'},
    {'en': 'litre', 'ur': 'لیٹر'},
    {'en': 'dozen', 'ur': 'درجن'},
    {'en': 'piece', 'ur': 'عدد'},
  ];

  @override
  void initState() {
    super.initState();
    
    _selectedUnit = widget.profession.productionUnit.isNotEmpty ? widget.profession.productionUnit : 'kg';
    
    // Ensure _selectedUnit is a valid 'en' value even if it was saved differently
    bool unitExists = _units.any((u) => u['en'] == _selectedUnit);
    if (!unitExists) _selectedUnit = 'kg';

    if (widget.transactionToEdit != null) {
      _selectedDate = widget.transactionToEdit!.date;
    } else {
      _selectedDate = DateTime.now();
    }
    _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate);

    if (widget.transactionToEdit != null) {
      final t = widget.transactionToEdit!;
      _transactionType = t.type;
      _amountController.text = t.amount.toStringAsFixed(0);
      _descriptionController.text = t.description;
      
      if (t.quantity > 1 || (t.rate > 0 && t.rate != t.amount)) {
        _productionAmountController.text = t.quantity.toString();
        _rateController.text = t.rate.toStringAsFixed(2);
      }

      List<String> currentCats = t.type == 'income' ? widget.incomeCategories : widget.expenseCategories;
      if (currentCats.contains(t.category)) {
        _selectedCategory = t.category;
      } else {
        _selectedCategory = null;
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    _productionAmountController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  void _calculateTotalFromRate() {
    double qty = double.tryParse(_productionAmountController.text) ?? 0;
    double rate = double.tryParse(_rateController.text) ?? 0;
    if (qty > 0 && rate > 0) {
      double total = qty * rate;
      setState(() {
        _amountController.text = total.toStringAsFixed(0);
      });
    }
  }

  Future<void> _pickDate() async {
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : 'NotoSans';

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: isUrdu ? const Locale('ur') : const Locale('en'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.darkColor,
              onPrimary: Colors.white,
              onSurface: AppTheme.darkColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : 'NotoSans';
    final isIncome = _transactionType == 'income';
    final isEditing = widget.transactionToEdit != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: isEditing
            ? (isUrdu ? 'لین دین میں ترمیم' : 'Edit Transaction')
            : (isUrdu ? 'نیا لین دین' : 'New Transaction'),
        actions: [
          if (isEditing)
            IconButton(
              icon: Icon(PhosphorIcons.trash(), color: Colors.white),
              onPressed: _deleteTransaction,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.themeColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Field
                    _buildLabel(isUrdu ? 'تاریخ' : 'Date', fontFamily),
                    TextFormField(
                      controller: _dateController,
                      readOnly: true,
                      style: const TextStyle(fontFamily: '', color: AppTheme.darkColor),
                      onTap: _pickDate,
                      decoration: _inputDecoration(
                        hint: '',
                        icon: PhosphorIcons.calendarBlank(),
                        fontFamily: fontFamily,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Amount Field
                    _buildLabel(isUrdu ? 'رقم' : 'Amount', fontFamily),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.darkColor, fontFamily: ''),
                      decoration: _inputDecoration(
                        hint: '0.00',
                        icon: PhosphorIcons.money(),
                        fontFamily: fontFamily,
                      ),
                      validator: (value) => value == null || value.isEmpty ? (isUrdu ? 'رقم درج کریں' : 'Enter Amount') : null,
                    ),
                    const SizedBox(height: 16),

                    // Production Yield / Rate Calculation (Optional)
                    _buildLabel(isUrdu ? 'پیداوار اور ریٹ (اختیاری)' : 'Production & Rate (Optional)', fontFamily),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _productionAmountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: AppTheme.darkColor, fontSize: 14, fontFamily: ''),
                            decoration: _inputDecoration(
                              hint: isUrdu ? 'مقدار' : 'Qty', 
                              fontFamily: fontFamily,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                            ),
                            onChanged: (val) => _calculateTotalFromRate(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: _selectedUnit,
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            decoration: _inputDecoration(
                              hint: '', 
                              fontFamily: fontFamily,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                            ),
                            style: TextStyle(color: AppTheme.darkColor, fontFamily: isUrdu ? 'NooriNastaleeq' : '', fontSize: 13),
                            items: _units.map((unit) => DropdownMenuItem(
                              value: unit['en'],
                              child: Text(
                                isUrdu ? unit['ur']! : unit['en']!, 
                                style: TextStyle(fontSize: 16, fontFamily: isUrdu ? 'NooriNastaleeq' : '')
                              ),
                            )).toList(),
                            onChanged: (value) => setState(() => _selectedUnit = value),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _rateController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: AppTheme.darkColor, fontSize: 14, fontFamily: ''),
                            decoration: _inputDecoration(
                              hint: isUrdu ? 'ریٹ' : 'Rate', 
                              fontFamily: fontFamily,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                            ),
                            onChanged: (val) => _calculateTotalFromRate(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Category Dropdown
                    _buildLabel(isUrdu ? 'زمرہ منتخب کریں' : 'Select Category', fontFamily),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      dropdownColor: Colors.white,
                      style: TextStyle(fontFamily: fontFamily, color: AppTheme.darkColor),
                      decoration: _inputDecoration(
                        hint: isUrdu ? 'زمرہ' : 'Category',
                        icon: PhosphorIcons.tag(),
                        fontFamily: fontFamily,
                      ),
                      items: [...widget.incomeCategories, ...widget.expenseCategories].toSet().toList()
                          .map((category) => DropdownMenuItem(
                            value: category,
                            child: Text(category, style: TextStyle(fontFamily: fontFamily)),
                          )).toList(),
                      onChanged: (value) => setState(() => _selectedCategory = value),
                      validator: (value) => value == null ? (isUrdu ? 'زمرہ منتخب کریں' : 'Select Category') : null,
                    ),
                    const SizedBox(height: 16),

                    // Description Field
                    _buildLabel(isUrdu ? 'تفصیل (اختیاری)' : 'Description (Optional)', fontFamily),
                    TextFormField(
                      controller: _descriptionController,
                      style: TextStyle(fontFamily: fontFamily, color: AppTheme.darkColor),
                      maxLines: 2,
                      decoration: _inputDecoration(
                        hint: isUrdu ? 'کچھ لکھیں...' : 'Write something...',
                        icon: PhosphorIcons.notePencil(),
                        fontFamily: fontFamily,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Dual Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            text: isUrdu ? 'آمدنی' : 'Income',
                            onPressed: () => _saveTransaction('income'),
                            icon: PhosphorIcons.arrowDownLeft(PhosphorIconsStyle.bold),
                            color: AppTheme.incomeColor,
                            size: AppButtonSize.large,
                            isFullWidth: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppButton(
                            text: isUrdu ? 'خرچ' : 'Expense',
                            onPressed: () => _saveTransaction('expense'),
                            icon: PhosphorIcons.arrowUpRight(PhosphorIconsStyle.bold),
                            color: AppTheme.expenseColor,
                            size: AppButtonSize.large,
                            isFullWidth: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _typeButton({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
    required String fontFamily,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontWeight: FontWeight.bold,
            fontFamily: fontFamily,
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, String fontFamily) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
      child: Text(
        text,
        style: TextStyle(
          color: AppTheme.darkColor,
          fontWeight: FontWeight.w600,
          fontSize: 14,
          fontFamily: fontFamily,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, IconData? icon, String? fontFamily, EdgeInsetsGeometry? contentPadding}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontFamily: fontFamily, color: AppTheme.textSecondary, fontSize: 14),
      prefixIcon: icon != null ? Icon(icon, size: 20, color: AppTheme.themeColor) : null,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.themeColor, width: 1.5),
      ),
      contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Future<void> _saveTransaction(String type) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    final databaseService = Provider.of<DatabaseService>(context, listen: false);
    
    try {
      final double amount = double.parse(_amountController.text);
      final double qtyDouble = double.tryParse(_productionAmountController.text) ?? 1.0;
      final int qty = qtyDouble.round();
      final double rate = double.tryParse(_rateController.text) ?? amount;
      
      final transactionId = widget.transactionToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
      final createdAt = widget.transactionToEdit?.createdAt ?? DateTime.now();
      final updatedAt = DateTime.now();

      final now = DateTime.now();
      final DateTime finalDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        now.hour,
        now.minute,
        now.second,
      );

      final transaction = transaction_model.Transaction(
        id: transactionId,
        amount: amount,
        type: type,
        category: _selectedCategory!,
        description: _descriptionController.text,
        date: finalDate,
        accountId: 'default_account',
        professionId: widget.profession.id,
        pendingAmount: amount,
        isPending: false,
        quantity: qty,
        rate: rate,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      if (type == 'income' && _productionAmountController.text.isNotEmpty) {
        double addedYield = double.tryParse(_productionAmountController.text) ?? 0.0;
        if (addedYield > 0) {
          final updatedProfession = widget.profession.copyWith(
            totalProduction: widget.profession.totalProduction + addedYield,
            productionUnit: _selectedUnit,
            updatedAt: DateTime.now(),
          );
          await databaseService.updateProfession(updatedProfession);
        }
      }

      if (widget.transactionToEdit != null) {
        await databaseService.updateTransaction(transaction);
      } else {
        await databaseService.addTransaction(transaction);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.transactionToEdit != null
                ? (isUrdu ? 'ترمیم محفوظ ہو گئی' : 'Transaction updated')
                : (isUrdu ? 'ٹرانزیکشن محفوظ ہوگئی' : 'Transaction Saved'),
            style: TextStyle(fontFamily: isUrdu ? 'NooriNastaleeq' : 'NotoSans'),
          ),
          backgroundColor: AppTheme.darkColor,
        ),
      );
      
      Navigator.pop(context);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteTransaction() async {
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : 'NotoSans';

    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isUrdu ? 'حذف کریں؟' : 'Delete?', style: TextStyle(fontFamily: fontFamily, color: AppTheme.darkColor)),
        content: Text(isUrdu ? 'کیا آپ واقعی حذف کرنا چاہتے ہیں؟' : 'Are you sure you want to delete?', style: TextStyle(fontFamily: fontFamily)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isUrdu ? 'منسوخ' : 'Cancel', style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isUrdu ? 'حذف' : 'Delete', style: const TextStyle(color: AppTheme.expenseColor)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final databaseService = Provider.of<DatabaseService>(context, listen: false);
        await databaseService.deleteTransaction(widget.transactionToEdit!.id);
        Navigator.pop(context); 
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }
}
