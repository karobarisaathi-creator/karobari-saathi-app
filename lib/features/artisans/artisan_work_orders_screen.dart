// lib/features/artisans/screens/artisan_work_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/services/language_service.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/services/artisan_work_order_service.dart';
import 'package:account_app/core/models/artisan_work_order_model.dart';

class ArtisanWorkOrdersScreen extends StatefulWidget {
  final String artisanId;

  const ArtisanWorkOrdersScreen({super.key, required this.artisanId});

  @override
  State<ArtisanWorkOrdersScreen> createState() =>
      _ArtisanWorkOrdersScreenState();
}

class _ArtisanWorkOrdersScreenState extends State<ArtisanWorkOrdersScreen> {
  final ArtisanWorkOrderService _service = ArtisanWorkOrderService();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController =
      TextEditingController();
  final TextEditingController _workDescriptionController =
      TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _workDescriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = Provider.of<LanguageService>(context).isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        title: isUrdu ? 'میرے کام' : 'My Work Orders',
      ),
      body: StreamBuilder<List<ArtisanWorkOrder>>(
        stream: _service.getArtisanWorkOrders(widget.artisanId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState(isUrdu, fontFamily);
          }

          final orders = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return _buildOrderCard(order, isUrdu, fontFamily);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddWorkDialog(isUrdu, fontFamily),
        backgroundColor: AppTheme.themeColor,
        child: Icon(PhosphorIcons.plus(), color: Colors.white),
      ),
    );
  }

  Widget _buildOrderCard(
      ArtisanWorkOrder order, bool isUrdu, String fontFamily) {
    final statusColors = {
      'pending': Colors.orange,
      'in_progress': Colors.blue,
      'completed': Colors.green,
      'rated': AppTheme.goldColor,
    };

    final statusLabels = {
      'pending': isUrdu ? 'زیرِ غور' : 'Pending',
      'in_progress': isUrdu ? 'جاری' : 'In Progress',
      'completed': isUrdu ? 'مکمل' : 'Completed',
      'rated': isUrdu ? 'ریٹنگ دی گئی' : 'Rated',
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    order.customerName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: fontFamily,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColors[order.status]?.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColors[order.status]!),
                  ),
                  child: Text(
                    statusLabels[order.status] ?? order.status,
                    style: TextStyle(
                      fontSize: 11,
                      color: statusColors[order.status],
                      fontWeight: FontWeight.bold,
                      fontFamily: fontFamily,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              order.workDescription,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontFamily: fontFamily,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(PhosphorIcons.calendar(), size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd/MM/yyyy').format(order.createdAt),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (order.amount != null) ...[
                  const SizedBox(width: 12),
                  Icon(PhosphorIcons.money(), size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Rs ${order.amount!.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
                const Spacer(),
                if (order.status == 'pending')
                  _buildStatusButton(
                    order,
                    'in_progress',
                    isUrdu ? 'شروع کریں' : 'Start',
                    Colors.blue,
                    fontFamily,
                  ),
                if (order.status == 'in_progress')
                  _buildStatusButton(
                    order,
                    'completed',
                    isUrdu ? 'مکمل' : 'Complete',
                    Colors.green,
                    fontFamily,
                  ),
                if (order.status == 'completed' && !order.isRated)
                  _buildStatusButton(
                    order,
                    'rated',
                    isUrdu ? 'ریٹنگ' : 'Rate',
                    AppTheme.goldColor,
                    fontFamily,
                  ),
                if (order.isRated)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.goldColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.goldColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star,
                          color: AppTheme.goldColor,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${order.rating}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.goldColor,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton(
    ArtisanWorkOrder order,
    String status,
    String label,
    Color color,
    String fontFamily,
  ) {
    return ElevatedButton(
      onPressed: () async {
        await _service.updateStatus(widget.artisanId, order.id, status);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontFamily: fontFamily,
        ),
      ),
    );
  }

  void _showAddWorkDialog(bool isUrdu, String fontFamily) {
    final _dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          isUrdu ? 'نیا کام شامل کریں' : 'Add New Work',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: fontFamily,
          ),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: _dialogFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogTextField(
                  controller: _customerNameController,
                  label: isUrdu ? 'گاہک کا نام' : 'Customer Name',
                  icon: PhosphorIcons.user(),
                  fontFamily: fontFamily,
                  isUrdu: isUrdu,
                ),
                const SizedBox(height: 12),
                _buildDialogTextField(
                  controller: _customerPhoneController,
                  label: isUrdu ? 'گاہک کا فون' : 'Customer Phone',
                  icon: PhosphorIcons.phone(),
                  fontFamily: fontFamily,
                  isUrdu: isUrdu,
                  isPhone: true,
                ),
                const SizedBox(height: 12),
                _buildDialogTextField(
                  controller: _workDescriptionController,
                  label: isUrdu ? 'کام کی تفصیل' : 'Work Description',
                  icon: PhosphorIcons.note(),
                  fontFamily: fontFamily,
                  isUrdu: isUrdu,
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                _buildDialogTextField(
                  controller: _amountController,
                  label: isUrdu ? 'رقم (اختیاری)' : 'Amount (Optional)',
                  icon: PhosphorIcons.money(),
                  fontFamily: fontFamily,
                  isUrdu: isUrdu,
                  isNumber: true,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _clearControllers();
              Navigator.pop(context);
            },
            child: Text(
              isUrdu ? 'منسوخ' : 'Cancel',
              style: TextStyle(fontFamily: fontFamily),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!_dialogFormKey.currentState!.validate()) return;

              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;

              final order = ArtisanWorkOrder(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                artisanId: widget.artisanId,
                customerId: user.uid,
                customerName: _customerNameController.text.trim(),
                customerPhone: _customerPhoneController.text.trim(),
                workDescription: _workDescriptionController.text.trim(),
                amount: double.tryParse(_amountController.text),
                createdAt: DateTime.now(),
              );

              await _service.addWorkOrder(order);
              _clearControllers();
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.themeColor,
            ),
            child: Text(
              isUrdu ? 'شامل کریں' : 'Add',
              style: TextStyle(
                color: Colors.white,
                fontFamily: fontFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String fontFamily,
    required bool isUrdu,
    bool isNumber = false,
    bool isPhone = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber
          ? TextInputType.number
          : (isPhone ? TextInputType.phone : TextInputType.text),
      style: TextStyle(fontFamily: fontFamily, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: AppTheme.themeColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return isUrdu ? 'یہ فیلڈ ضروری ہے' : 'This field is required';
        }
        return null;
      },
    );
  }

  void _clearControllers() {
    _customerNameController.clear();
    _customerPhoneController.clear();
    _workDescriptionController.clear();
    _amountController.clear();
  }

  Widget _buildEmptyState(bool isUrdu, String fontFamily) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.package(), size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            isUrdu ? 'کوئی کام نہیں ملا' : 'No work orders',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontFamily: fontFamily,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isUrdu ? 'پہلا کام شامل کریں' : 'Add your first work',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
              fontFamily: fontFamily,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddWorkDialog(isUrdu, fontFamily),
            icon: Icon(PhosphorIcons.plus()),
            label: Text(
              isUrdu ? 'نیا کام' : 'New Work',
              style: TextStyle(fontFamily: fontFamily),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.themeColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
