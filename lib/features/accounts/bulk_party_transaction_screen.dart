import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/models/account_model.dart';
import 'package:account_app/core/models/transaction_model.dart' as model;
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/app_button.dart';

class BulkPartyTransactionScreen extends StatefulWidget {
  final Account? party;

  const BulkPartyTransactionScreen({Key? key, this.party}) : super(key: key);

  @override
  _BulkPartyTransactionScreenState createState() => _BulkPartyTransactionScreenState();
}

class _TransactionRow {
  DateTime selectedDate = DateTime.now();
  TextEditingController descriptionController = TextEditingController();
  TextEditingController amountController = TextEditingController();
  TextEditingController dateInputController = TextEditingController();
  String type = 'income'; // 'income' = جمع, 'expense' = بنام

  void dispose() {
    descriptionController.dispose();
    amountController.dispose();
    dateInputController.dispose();
  }
}

class _BulkPartyTransactionScreenState extends State<BulkPartyTransactionScreen> {
  List<_TransactionRow> _rows = [];
  String? _selectedPartyId;
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _addNewRow();

    if (widget.party != null) {
      _selectedPartyId = widget.party!.id;
    }
  }

  void _addNewRow() {
    final row = _TransactionRow();

    // Auto-add listener for the last row
    row.amountController.addListener(() {
      if (_rows.indexOf(row) == _rows.length - 1 && row.amountController.text.isNotEmpty) {
        _addNewRow();
      }
    });

    // Smart Date Input Listener (DD/MM/YY)
    row.dateInputController.addListener(() {
      String text = row.dateInputController.text;

      // Auto-insert slash after DD
      if (text.length == 2 && !text.contains('/')) {
        row.dateInputController.text = '$text/';
        row.dateInputController.selection = TextSelection.fromPosition(TextPosition(offset: row.dateInputController.text.length));
      }
      // Auto-insert slash after MM
      else if (text.length == 5 && text.split('/').length == 2) {
        row.dateInputController.text = '$text/';
        row.dateInputController.selection = TextSelection.fromPosition(TextPosition(offset: row.dateInputController.text.length));
      }

      // Update selectedDate when format is valid DD/MM/YY
      if (text.length == 8) {
        try {
          List<String> parts = text.split('/');
          int day = int.parse(parts[0]);
          int month = int.parse(parts[1]);
          int yearPart = int.parse(parts[2]);
          
          // Fix: Handle 2000+ year correctly
          int fullYear = yearPart < 50 ? 2000 + yearPart : 1900 + yearPart;
          
          DateTime newDate = DateTime(fullYear, month, day);
          
          // Only update if it's a valid date
          if (newDate.day == day && newDate.month == month) {
            row.selectedDate = newDate;
          }
        } catch (e) {
          debugPrint("Date parsing error: $e");
        }
      }
    });

    if (_rows.isNotEmpty) {
      row.selectedDate = _rows.last.selectedDate;
    } else {
      row.selectedDate = DateTime.now();
    }
    row.dateInputController.text = DateFormat('dd/MM/yy').format(row.selectedDate);

    setState(() {
      _rows.add(row);
    });
  }

  void _removeRow(int index) {
    if (_rows.length > 1) {
      final row = _rows[index];
      row.dispose();
      setState(() {
        _rows.removeAt(index);
      });
    }
  }

  Future<void> _selectDateForRow(int index) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _rows[index].selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        DateTime oldDate = _rows[index].selectedDate;
        for (int i = index; i < _rows.length; i++) {
          if (_rows[i].selectedDate.year == oldDate.year && _rows[i].selectedDate.month == oldDate.month && _rows[i].selectedDate.day == oldDate.day) {
             _rows[i].selectedDate = picked;
             _rows[i].dateInputController.text = DateFormat('dd/MM/yy').format(picked);
          }
        }
      });
    }
  }

  Future<void> _saveAllTransactions() async {
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;

    if (_selectedPartyId == null) {
      _showSnackbar(isUrdu ? 'پارٹی منتخب کریں' : 'Select a party', true);
      return;
    }

    List<Map<String, dynamic>> validTransactions = [];
    for (int i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      final amount = double.tryParse(row.amountController.text);
      String description = row.descriptionController.text.trim();

      if (description.isEmpty) {
        description = isUrdu ? "دیگر" : "Other";
      }

      if (amount == null || amount <= 0) {
        continue; // Skip invalid or empty amount rows
      }

      validTransactions.add({
        'amount': amount,
        'description': description,
        'type': row.type,
        'date': row.selectedDate,
      });
    }

    if (validTransactions.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final db = Provider.of<DatabaseService>(context, listen: false);

      for (var tx in validTransactions) {
        final transaction = model.Transaction(
          id: DateTime.now().millisecondsSinceEpoch.toString() + tx['description'].hashCode.toString() + tx['amount'].toString() + tx['date'].millisecondsSinceEpoch.toString(),
          accountId: _selectedPartyId!,
          amount: tx['amount'],
          type: tx['type'],
          category: tx['type'] == 'income' ? 'جمع' : 'بنام',
          description: tx['description'] == (isUrdu ? "دیگر" : "Other") ? (isUrdu ? "دیگر" : "Other") : tx['description'],
          date: tx['date'],
          professionId: null,
          pendingAmount: tx['amount'],
          isPending: false,
          quantity: 1,
          rate: tx['amount'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await db.addTransaction(transaction);
      }

      _showSnackbar(
          isUrdu ? '${validTransactions.length} ٹرانزیکشنز محفوظ ہو گئیں' : '${validTransactions.length} transactions saved',
          false
      );

      for (var row in _rows) {
        row.dispose();
      }
      _rows.clear();
      _addNewRow();

    } catch (e) {
      _showSnackbar('Error: $e', true);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showSnackbar(String message, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.expenseColor : AppTheme.incomeColor,
      ),
    );
  }

  @override
  void dispose() {
    for (var row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isUrdu = languageService.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppTheme.lightColor,
      appBar: CustomAppBar(
        centerTitle: true,
        backgroundColor: AppTheme.darkColor,
        foregroundColor: Colors.white,
        title: Text(
          '${isUrdu ? 'بیچ انٹری:' : 'Bulk Entry:'} ${widget.party?.name ?? ''}',
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: isUrdu ? 20 : 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.themeColor))
          : Column(
        children: [
          // Header
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              width: 600,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: AppTheme.themeColor.withOpacity(0.1),
              child: Row(
                children: [
                  SizedBox(width: 250, child: Text(isUrdu ? 'تفصیل و تاریخ' : 'Description & Date',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: fontFamily, color: Colors.black))),
                  const SizedBox(width: 40), // Arrow space
                  SizedBox(width: 100, child: Text(isUrdu ? 'رقم' : 'Amount',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: fontFamily, color: Colors.black))),
                  SizedBox(width: 120, child: Text(isUrdu ? 'قسم' : 'Type',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: fontFamily, color: Colors.black))),
                  const SizedBox(width: 40),
                ],
              ),
            ),
          ),

          // Rows List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _rows.length,
              itemBuilder: (context, index) {
                final row = _rows[index];
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    width: 600,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: const BoxDecoration(color: Colors.white),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end, // Aligns everything with the last line of description
                      children: [
                        // Description & Smart Date
                        SizedBox(
                          width: 250,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: row.descriptionController,
                                  maxLines: null,
                                  style: TextStyle(fontSize: 15, fontFamily: fontFamily, color: Colors.black),
                                  decoration: InputDecoration(
                                    hintText: isUrdu ? 'دیگر' : 'Other',
                                    hintStyle: TextStyle(fontFamily: fontFamily, color: Colors.black54),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                                    border: const UnderlineInputBorder(),
                                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 0.8)),
                                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.themeColor)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 75,
                                child: TextFormField(
                                  controller: row.dateInputController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 14, color: AppTheme.themeColor, fontWeight: FontWeight.normal),
                                  textAlign: TextAlign.center,
                                  decoration: const InputDecoration(
                                    hintText: '00/00/00',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                                    border: UnderlineInputBorder(),
                                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 0.8)),
                                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.themeColor)),
                                  ),
                                  onTap: () {
                                    row.dateInputController.selection = TextSelection(baseOffset: 0, extentOffset: row.dateInputController.text.length);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 5),

                        // Amount Field
                        SizedBox(
                          width: 100,
                          child: TextFormField(
                            controller: row.amountController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: row.type == 'income' ? AppTheme.incomeColor : AppTheme.expenseColor,
                            ),
                            decoration: const InputDecoration(
                              hintText: '0',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                              border: UnderlineInputBorder(),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 0.8)),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.themeColor)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),

                        // Interactive Toggle Arrow (Now on the right side of amount)
                        SizedBox(
                          width: 35,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  row.type = row.type == 'income' ? 'expense' : 'income';
                                });
                              },
                              child: Icon(
                                row.type == 'income' ? PhosphorIcons.arrowDownLeft(PhosphorIconsStyle.bold) : PhosphorIcons.arrowUpRight(PhosphorIconsStyle.bold),
                                color: row.type == 'income' ? AppTheme.incomeColor : AppTheme.expenseColor,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),

                        // Type Toggle
                        SizedBox(
                          width: 120,
                          child: Row(
                            children: [
                              _buildTypeButton(row, 'income', isUrdu ? 'جمع' : 'In', AppTheme.incomeColor),
                              const SizedBox(width: 6),
                              _buildTypeButton(row, 'expense', isUrdu ? 'بنام' : 'Out', AppTheme.expenseColor),
                            ],
                          ),
                        ),

                        // Delete Button
                        SizedBox(
                          width: 40,
                          child: _rows.length > 1
                              ? IconButton(
                                  icon: Icon(PhosphorIcons.trash(), size: 18, color: AppTheme.expenseColor),
                                  onPressed: () => _removeRow(index),
                                  padding: EdgeInsets.zero,
                                )
                              : const SizedBox(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Save Button
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            color: Colors.white,
            child: AppButton(
              text: isUrdu ? 'تمام ٹرانزیکشنز محفوظ کریں' : 'Save All Transactions',
              onPressed: _saveAllTransactions,
              icon: PhosphorIcons.checkCircle(),
              isLoading: _isSaving,
              isFullWidth: true,
              size: AppButtonSize.large,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeButton(_TransactionRow row, String type, String label, Color selectedColor) {
    bool isSelected = row.type == type;
    final isUrdu = Provider.of<LanguageService>(context, listen: false).isUrdu;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => row.type = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? selectedColor : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontFamily: isUrdu ? 'NooriNastaleeq' : '',
              color: isSelected ? Colors.white : Colors.black,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
