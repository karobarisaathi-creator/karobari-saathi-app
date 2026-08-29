import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/models/artisan_work_order_model.dart';
import 'package:account_app/core/models/artisan_profile_model.dart';
import 'package:account_app/core/models/transaction_item_model.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:account_app/core/services/artisan_work_order_service.dart';
import 'package:account_app/core/widgets/artisan_rating_stars.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WorkOrderListItem extends StatefulWidget {
  final ArtisanWorkOrder order;
  final bool isArtisanMode;
  final bool isUrdu;
  final String fontFamily;
  final VoidCallback? onChatTap;

  const WorkOrderListItem({
    super.key,
    required this.order,
    required this.isArtisanMode,
    required this.isUrdu,
    required this.fontFamily,
    this.onChatTap,
  });

  @override
  State<WorkOrderListItem> createState() => _WorkOrderListItemState();
}

class _WorkOrderListItemState extends State<WorkOrderListItem> {
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _laborController = TextEditingController();
  bool _isSyncing = false;
  bool _isExpanded = false; // کارڈ کے کھلنے یا بند ہونے کی حالت
  late Stream<DocumentSnapshot> _orderStream;

  @override
  void initState() {
    super.initState();
    _orderStream = FirebaseFirestore.instance
        .collection('artisans')
        .doc(widget.order.artisanId)
        .collection('work_orders')
        .doc(widget.order.id)
        .snapshots();
  }

  @override
  void dispose() {
    _descController.dispose();
    _rateController.dispose();
    _laborController.dispose();
    super.dispose();
  }

  Future<void> _updateOnCloud(List<TransactionItem> items, double labor) async {
    setState(() => _isSyncing = true);
    try {
      final total = items.fold(0.0, (sum, i) => sum + i.total) + labor;
      await FirebaseFirestore.instance
          .collection('artisans')
          .doc(widget.order.artisanId)
          .collection('work_orders')
          .doc(widget.order.id)
          .update({
        'items': items.map((e) => e.toMap()).toList(),
        'laborFee': labor,
        'amount': total,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Sync Error: $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _orderStream,
      builder: (context, snapshot) {
        List<TransactionItem> items = [];
        double laborFee = 0.0;
        double total = 0.0;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final o = ArtisanWorkOrder.fromMap(data);
          items = o.items ?? [];
          laborFee = o.laborFee;
          total = o.amount ?? 0.0;
        }

        return GestureDetector(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isExpanded ? AppTheme.themeColor.withOpacity(0.3) : Colors.transparent,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header: Profile and Chat (ہمیشہ نظر آئے گا)
                _buildHeader(context),

                // اگر کارڈ کھلا ہوا ہے تو باقی تفصیلات دکھائیں
                if (_isExpanded) ...[
                  // 2. Items List
                  if (items.isNotEmpty)
                    _buildItemsList(items, laborFee)
                  else
                    _buildEmptyState(),

                  // 3. Labor Fee Row
                  _buildLaborRow(items, laborFee),

                  // 4. Quick Input (Only Artisan)
                  _buildInputBar(items, laborFee),

                  // 5. Action Buttons (Complete & Review)
                  if (snapshot.hasData && snapshot.data!.exists)
                    _buildActions(context, ArtisanWorkOrder.fromMap(snapshot.data!.data() as Map<String, dynamic>)),

                  // 6. Total Strip
                  _buildTotalStrip(total),
                ] else ...[
                  // اگر کارڈ بند ہے تو صرف ایک چھوٹا سا ٹوٹل دکھا دیتے ہیں تاکہ اندازہ ہو
                  _buildCollapsedFooter(total),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCollapsedFooter(double total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.isUrdu ? 'کل بل:' : 'Total:',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontFamily: widget.fontFamily,
            ),
          ),
          Text(
            Formatters.formatCurrency(total),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.themeColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: widget.isArtisanMode
                ? ProfileInfoWidget(name: widget.order.customerName, phone: '', customSize: 32)
                : FutureBuilder<ArtisanProfile?>(
                    future: ArtisanService().getProfile(widget.order.artisanId),
                    builder: (context, snapshot) {
                      final profile = snapshot.data;
                      final String displayName = (widget.order.artisanName != null && widget.order.artisanName!.isNotEmpty)
                          ? widget.order.artisanName!
                          : (profile?.name ?? (widget.isUrdu ? 'کاریگر' : 'Artisan'));
                      
                      return ProfileInfoWidget(
                        name: displayName,
                        phone: '',
                        category: widget.isUrdu ? profile?.professionUrdu : profile?.profession,
                        isVerticalCategory: true,
                        customSize: 32,
                      );
                    },
                  ),
          ),
          if (_isSyncing) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          IconButton(
            onPressed: widget.onChatTap,
            icon: Icon(PhosphorIcons.chatCircleText(PhosphorIconsStyle.fill), color: AppTheme.themeColor),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(List<TransactionItem> items, double labor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text(item.description, style: const TextStyle(fontSize: 13))),
                Text(Formatters.formatCurrency(item.total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                if (widget.isArtisanMode)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
                    onPressed: () {
                      final newList = List<TransactionItem>.from(items)..removeAt(idx);
                      _updateOnCloud(newList, labor);
                    },
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLaborRow(List<TransactionItem> items, double labor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Icon(PhosphorIcons.userGear(), size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          Text(widget.isUrdu ? 'مزدوری فیس:' : 'Labor:', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const Spacer(),
          if (widget.isArtisanMode)
            SizedBox(
              width: 80,
              child: TextField(
                keyboardType: TextInputType.number,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13),
                decoration: const InputDecoration(hintText: '0', isDense: true, border: InputBorder.none),
                onSubmitted: (val) => _updateOnCloud(items, double.tryParse(val) ?? 0.0),
              ),
            )
          else
            Text(Formatters.formatCurrency(labor), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildInputBar(List<TransactionItem> items, double labor) {
    if (!widget.isArtisanMode) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey[100]!))),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _descController,
              decoration: InputDecoration(
                hintText: widget.isUrdu ? 'آئٹم نام' : 'Item',
                hintStyle: const TextStyle(fontSize: 12),
                border: InputBorder.none,
              ),
            ),
          ),
          Container(width: 1, height: 20, color: Colors.grey[200]),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _rateController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: widget.isUrdu ? 'رقم' : 'Price',
                hintStyle: const TextStyle(fontSize: 12),
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.add_circle, color: AppTheme.themeColor, size: 28),
            onPressed: () {
              if (_descController.text.isEmpty || _rateController.text.isEmpty) return;
              final rate = double.tryParse(_rateController.text) ?? 0.0;
              final newList = List<TransactionItem>.from(items)..add(TransactionItem(description: _descController.text.trim(), quantity: 1, rate: rate, total: rate));
              _descController.clear();
              _rateController.clear();
              _updateOnCloud(newList, labor);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTotalStrip(double total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppTheme.darkColor,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(widget.isUrdu ? 'کل رقم (میزان):' : 'Total Bill:', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          Text(Formatters.formatCurrency(total), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Text(widget.isUrdu ? "ابھی تک کوئی سامان ایڈ نہیں کیا گیا" : "No items added yet",
            style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
      ),
    );
  }

  Widget _buildActions(BuildContext context, ArtisanWorkOrder order) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // کاریگر کے لیے کام مکمل کرنے کا بٹن
          if (widget.isArtisanMode && order.status != 'completed' && order.status != 'rated')
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _handleComplete(order),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: Text(
                  widget.isUrdu ? 'کام مکمل کریں' : 'Complete Work',
                  style: TextStyle(fontFamily: widget.fontFamily, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

          // گاہک کے لیے کاریگر کو ریویو دینے کا بٹن
          if (!widget.isArtisanMode && order.status == 'completed' && !order.isRated)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showRatingDialog(context, order),
                icon: const Icon(Icons.star_outline, size: 18),
                label: Text(
                  widget.isUrdu ? 'کاریگر کو ریویو دیں' : 'Rate Artisan',
                  style: TextStyle(fontFamily: widget.fontFamily, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          
          if (order.isRated)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      widget.isUrdu ? 'ریویو دیا جا چکا ہے' : 'Review Submitted',
                      style: TextStyle(
                        color: Colors.orange[800],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        fontFamily: widget.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleComplete(ArtisanWorkOrder order) async {
    try {
      setState(() => _isSyncing = true);
      final service = ArtisanWorkOrderService();
      
      await service.updateStatus(order.artisanId, order.id, 'completed');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.isUrdu ? 'کام مکمل ہو گیا!' : 'Work marked as completed!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showRatingDialog(BuildContext context, ArtisanWorkOrder order) {
    double selectedRating = 5.0;
    final reviewController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            widget.isUrdu ? 'کاریگر کو ریویو دیں' : 'Rate Artisan',
            style: TextStyle(fontFamily: widget.fontFamily),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                order.artisanName ?? (widget.isUrdu ? 'کاریگر' : 'Artisan'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < selectedRating ? Icons.star : Icons.star_border,
                      color: Colors.orange,
                      size: 32,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        selectedRating = index + 1.0;
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: reviewController,
                maxLines: 3,
                maxLength: 150, // تقریباً تین لائنوں کے لیے کریکٹر لمٹ
                decoration: InputDecoration(
                  hintText: widget.isUrdu ? 'کاریگر کے کام کے بارے میں لکھیں...' : 'Write about artisan\'s work...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.all(12),
                  counterText: "", // لمٹ دکھانے کی ضرورت نہیں، بس خودکار رک جائے گا
                ),
                style: TextStyle(fontFamily: widget.fontFamily),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(widget.isUrdu ? 'کینسل' : 'Cancel', style: TextStyle(fontFamily: widget.fontFamily)),
            ),
            ElevatedButton(
              onPressed: () async {
                final artisanService = ArtisanService();
                await artisanService.addReview(
                  artisanId: order.artisanId,
                  workOrderId: order.id,
                  rating: selectedRating,
                  comment: reviewController.text.trim(),
                );
                
                if (context.mounted) Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(widget.isUrdu ? 'شکریہ! آپ کا ریویو سبمٹ ہو گیا' : 'Thank you! Your review submitted')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.themeColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(widget.isUrdu ? 'سبمٹ' : 'Submit', style: TextStyle(fontFamily: widget.fontFamily)),
            ),
          ],
        ),
      ),
    );
  }
}
