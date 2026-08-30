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
          
          return _buildCardContent(context, o, items, laborFee, total);
        }

        return _buildCardContent(context, widget.order, items, laborFee, total);
      },
    );
  }

  Widget _buildCardContent(BuildContext context, ArtisanWorkOrder currentOrder, List<TransactionItem> items, double laborFee, double total) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, currentOrder),

            if (_isExpanded) ...[
              if (items.isNotEmpty)
                _buildItemsList(items, laborFee)
              else
                _buildEmptyState(),

              _buildInputBar(items, laborFee),
              _buildActions(context, currentOrder),
              _buildTotalStrip(total),
            ] else ...[
              _buildCollapsedFooter(total),
            ],
          ],
        ),
      ),
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

  Widget _buildHeader(BuildContext context, ArtisanWorkOrder order) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: widget.isArtisanMode
                ? ProfileInfoWidget(
                    name: order.customerName,
                    phone: '',
                    customSize: 42,
                    borderRadius: 6,
                    address: order.title ?? order.workDescription,
                    isAddressBold: true,
                    addressColor: AppTheme.themeColor,
                  )
                : FutureBuilder<ArtisanProfile?>(
                    future: ArtisanService().getProfile(order.artisanId),
                    builder: (context, snapshot) {
                      final profile = snapshot.data;
                      final String displayName = (order.artisanName != null &&
                              order.artisanName!.isNotEmpty)
                          ? order.artisanName!
                          : (profile?.name ??
                              (widget.isUrdu ? 'کاریگر' : 'Artisan'));

                      return ProfileInfoWidget(
                        name: displayName,
                        phone: '',
                        profileImage: profile?.profileImage,
                        category: widget.isUrdu
                            ? profile?.professionUrdu
                            : profile?.profession,
                        isVerticalCategory: true,
                        customSize: 42,
                        borderRadius: 6,
                        address: order.title ?? order.workDescription,
                        isAddressBold: true,
                        addressColor: AppTheme.themeColor,
                      );
                    },
                  ),
          ),
          if (_isSyncing) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          
          if (widget.isArtisanMode && order.status != 'completed' && order.status != 'rated')
            GestureDetector(
              onTap: () => _handleComplete(order),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.green.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      widget.isUrdu ? 'مکمل' : 'Done',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: widget.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          IconButton(
            onPressed: widget.onChatTap,
            icon: Icon(PhosphorIcons.chatCircleText(PhosphorIconsStyle.fill), color: AppTheme.themeColor),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(List<TransactionItem> items, double labor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[50], 
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[200], indent: 12, endIndent: 12),
        itemBuilder: (context, idx) {
          final item = items[idx];
          final content = Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.description, 
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFamily: widget.fontFamily)
                  )
                ),
                Text(
                  Formatters.formatCurrency(item.total), 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.darkColor)
                ),
              ],
            ),
          );

          if (!widget.isArtisanMode) return content;

          // کاریگر کے لیے سویپ ٹو ڈیلیٹ
          return Dismissible(
            key: Key('item_${idx}_${item.description}'),
            direction: DismissDirection.endToStart,
            confirmDismiss: (direction) async {
               return await _showItemDeleteConfirmation(context, item.description);
            },
            onDismissed: (direction) {
              final newList = List<TransactionItem>.from(items)..removeAt(idx);
              _updateOnCloud(newList, labor);
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              color: Colors.red,
              child: const Icon(Icons.delete, color: Colors.white, size: 20),
            ),
            child: content,
          );
        },
      ),
    );
  }

  Future<bool?> _showItemDeleteConfirmation(BuildContext context, String itemName) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          widget.isUrdu ? 'آئٹم حذف کریں؟' : 'Delete Item?',
          style: TextStyle(fontFamily: widget.fontFamily, fontWeight: FontWeight.bold),
        ),
        content: Text(
          widget.isUrdu 
            ? 'کیا آپ واقعی "$itemName" کو لسٹ سے ہٹانا چاہتے ہیں؟' 
            : 'Are you sure you want to remove "$itemName" from the list?',
          style: TextStyle(fontFamily: widget.fontFamily),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(widget.isUrdu ? 'کینسل' : 'Cancel', style: TextStyle(fontFamily: widget.fontFamily)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text(widget.isUrdu ? 'حذف کریں' : 'Delete', style: TextStyle(fontFamily: widget.fontFamily)),
          ),
        ],
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
          Text(widget.isUrdu ? 'مزدوری فیس:' : 'Labor:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: widget.fontFamily)),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _descController,
                style: TextStyle(fontSize: 14, fontFamily: widget.fontFamily, color: AppTheme.darkColor),
                decoration: InputDecoration(
                  hintText: widget.isUrdu ? 'آئٹم نام' : 'Item Name',
                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey[500], fontFamily: widget.fontFamily),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  fillColor: Colors.transparent,
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            Container(width: 1, height: 20, color: Colors.grey[400]!.withOpacity(0.5), margin: const EdgeInsets.symmetric(horizontal: 8)),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _rateController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.darkColor),
                decoration: InputDecoration(
                  hintText: widget.isUrdu ? 'رقم' : 'Price',
                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey[500], fontFamily: widget.fontFamily),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  fillColor: Colors.transparent,
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                if (_descController.text.isEmpty || _rateController.text.isEmpty) return;
                final rate = double.tryParse(_rateController.text) ?? 0.0;
                final newList = List<TransactionItem>.from(items)
                  ..add(TransactionItem(
                      description: _descController.text.trim(),
                      quantity: 1,
                      rate: rate,
                      total: rate));
                _descController.clear();
                _rateController.clear();
                _updateOnCloud(newList, labor);
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppTheme.themeColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalStrip(double total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppTheme.darkColor,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(widget.isUrdu ? 'کل رقم (میزان):' : 'Total Bill:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: widget.fontFamily)),
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
            style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic, fontFamily: widget.fontFamily)),
      ),
    );
  }

  Widget _buildActions(BuildContext context, ArtisanWorkOrder order) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
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
                maxLength: 150,
                decoration: InputDecoration(
                  hintText: widget.isUrdu ? 'کاریگر کے کام کے بارے میں لکھیں...' : 'Write about artisan\'s work...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.all(12),
                  counterText: "",
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
