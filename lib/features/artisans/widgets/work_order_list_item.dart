import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/models/artisan_work_order_model.dart';
import 'package:account_app/core/models/artisan_profile_model.dart';
import 'package:account_app/core/models/transaction_item_model.dart';
import 'package:account_app/core/services/artisan_service.dart';
import 'package:account_app/core/services/artisan_work_order_service.dart';
import 'package:account_app/core/services/logging_service.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/services/database_service.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WorkOrderListItem extends StatefulWidget {
  final ArtisanWorkOrder order;
  final bool isArtisanMode;
  final bool isUrdu;
  final String fontFamily;
  final VoidCallback? onChatTap;
  final VoidCallback? onOrderUpdated;

  const WorkOrderListItem({
    super.key,
    required this.order,
    required this.isArtisanMode,
    required this.isUrdu,
    required this.fontFamily,
    this.onChatTap,
    this.onOrderUpdated,
  });

  @override
  State<WorkOrderListItem> createState() => _WorkOrderListItemState();
}

class _WorkOrderListItemState extends State<WorkOrderListItem> {
  final _logger = LoggingService();
  final ArtisanWorkOrderService _workOrderService = ArtisanWorkOrderService();
  final ArtisanService _artisanService = ArtisanService();
  
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  
  bool _isSyncing = false;
  bool _isExpanded = false;
  Stream<DocumentSnapshot>? _orderStream;

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
    super.dispose();
  }

  Future<void> _updateOnCloud(List<TransactionItem> items, double labor) async {
    setState(() => _isSyncing = true);
    try {
      final total = items.fold(0.0, (sum, i) => sum + i.total) + labor;
      final db = Provider.of<DatabaseService>(context, listen: false);
      await db.updateArtisanWorkOrderItems(
        artisanId: widget.order.artisanId,
        orderId: widget.order.id,
        items: items,
        laborFee: labor,
        total: total,
      );
    } catch (e, stack) {
      _logger.error("Update items error", e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isUrdu ? 'اپ ڈیٹ میں ناکامی' : 'Update failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _orderStream,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final order = ArtisanWorkOrder.fromMap(data);
          return _buildCardContent(
            context,
            order,
            order.items ?? [],
            order.laborFee,
            order.amount ?? 0.0,
          );
        }
        return _buildCardContent(
          context,
          widget.order,
          widget.order.items ?? [],
          widget.order.laborFee,
          widget.order.amount ?? 0.0,
        );
      },
    );
  }

  Widget _buildCardContent(
    BuildContext context,
    ArtisanWorkOrder currentOrder,
    List<TransactionItem> items,
    double laborFee,
    double total,
  ) {
    final bool isDone = currentOrder.status == 'completed' || currentOrder.status == 'rated';

    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, currentOrder),
            if (_isExpanded) ...[
              if (items.isNotEmpty)
                _buildItemsList(items, laborFee, isDone)
              else
                _buildEmptyState(),
              if (!isDone) _buildInputBar(items, laborFee),
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
            style: const TextStyle(
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
                : _buildArtisanHeader(order),
          ),
          if (_isSyncing)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          if (widget.isArtisanMode &&
              order.status != 'completed' &&
              order.status != 'rated' &&
              order.status != 'negotiating')
            GestureDetector(
              onTap: () => _handleComplete(order),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
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
          if (order.status == 'completed' && !widget.isArtisanMode && !order.isRated)
            GestureDetector(
              onTap: () => _showRatingDialog(context, order),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: AppTheme.darkColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.darkColor.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_outline, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      widget.isUrdu ? 'ریٹنگ دیں' : 'Rate',
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
          if (order.isRated)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.darkColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.darkColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: AppTheme.darkColor, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    order.rating?.toStringAsFixed(1) ?? '5.0',
                    style: const TextStyle(
                      color: AppTheme.darkColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            onPressed: widget.onChatTap,
            icon: Icon(
              PhosphorIcons.chatCircleText(PhosphorIconsStyle.fill),
              color: AppTheme.themeColor,
            ),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
          ),
        ],
      ),
    );
  }

  Widget _buildArtisanHeader(ArtisanWorkOrder order) {
    return FutureBuilder<ArtisanProfile?>(
      future: _artisanService.getProfile(order.artisanId),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final displayName = (order.artisanName != null && order.artisanName!.isNotEmpty)
            ? order.artisanName!
            : (profile?.name ?? (widget.isUrdu ? 'کاریگر' : 'Artisan'));

        return ProfileInfoWidget(
          name: displayName,
          phone: '',
          profileImage: profile?.profileImage,
          category: widget.isUrdu ? profile?.professionUrdu : profile?.profession,
          isVerticalCategory: true,
          customSize: 42,
          borderRadius: 6,
          address: order.title ?? order.workDescription,
          isAddressBold: true,
          addressColor: AppTheme.themeColor,
        );
      },
    );
  }

  Widget _buildItemsList(List<TransactionItem> items, double labor, bool isDone) {
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
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Colors.grey[200],
          indent: 12,
          endIndent: 12,
        ),
        itemBuilder: (context, idx) {
          final item = items[idx];
          final content = Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.description,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      fontFamily: widget.fontFamily,
                    ),
                  ),
                ),
                Text(
                  Formatters.formatCurrency(item.total),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.darkColor,
                  ),
                ),
              ],
            ),
          );

          if (!widget.isArtisanMode || isDone) return content;

          return Dismissible(
            key: ValueKey('item_${idx}_${item.description}'),
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

  Future<bool?> _showItemDeleteConfirmation(
    BuildContext context,
    String itemName,
  ) async {
    return await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          widget.isUrdu ? 'آئٹم حذف کریں؟' : 'Delete Item?',
          style: TextStyle(
            fontFamily: widget.fontFamily,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          widget.isUrdu
              ? 'کیا آپ واقعی "$itemName" کو لسٹ سے ہٹانا چاہتے ہیں؟'
              : 'Are you sure you want to remove "$itemName" from the list?',
          style: TextStyle(fontFamily: widget.fontFamily),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              widget.isUrdu ? 'کینسل' : 'Cancel',
              style: TextStyle(fontFamily: widget.fontFamily),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              widget.isUrdu ? 'حذف کریں' : 'Delete',
              style: TextStyle(fontFamily: widget.fontFamily),
            ),
          ),
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
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: widget.fontFamily,
                  color: AppTheme.darkColor,
                ),
                decoration: InputDecoration(
                  hintText: widget.isUrdu ? 'آئٹم نام' : 'Item Name',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontFamily: widget.fontFamily,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            Container(
              width: 1,
              height: 20,
              color: Colors.grey[400]!.withValues(alpha: 0.5),
              margin: const EdgeInsets.symmetric(horizontal: 8),
            ),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _rateController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkColor,
                ),
                decoration: InputDecoration(
                  hintText: widget.isUrdu ? 'رقم' : 'Price',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontFamily: widget.fontFamily,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _addItem(items, labor),
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

  void _addItem(List<TransactionItem> items, double labor) {
    if (_descController.text.isEmpty || _rateController.text.isEmpty) return;
    
    final rate = double.tryParse(_rateController.text) ?? 0.0;
    final newItem = TransactionItem(
      description: _descController.text.trim(),
      quantity: 1,
      rate: rate,
      total: rate,
    );
    
    final newList = List<TransactionItem>.from(items)..add(newItem);
    _descController.clear();
    _rateController.clear();
    _updateOnCloud(newList, labor);
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
          Text(
            widget.isUrdu ? 'کل رقم (میزان):' : 'Total Bill:',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              fontFamily: widget.fontFamily,
            ),
          ),
          Text(
            Formatters.formatCurrency(total),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Text(
          widget.isUrdu ? "ابھی تک کوئی سامان ایڈ نہیں کیا گیا" : "No items added yet",
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontStyle: FontStyle.italic,
            fontFamily: widget.fontFamily,
          ),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, ArtisanWorkOrder order) {
    return const SizedBox.shrink();
  }

  Future<void> _handleComplete(ArtisanWorkOrder order) async {
    // اگر بل زیرو ہے تو پہلے وارننگ دکھائیں
    if ((order.amount ?? 0) <= 0) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(widget.isUrdu ? 'بل خالی ہے' : 'Empty Bill'),
          content: Text(
            widget.isUrdu 
              ? 'آپ نے ابھی تک بل میں کوئی آئٹم شامل نہیں کیا ہے۔ کیا آپ واقعی بغیر بل کے کام مکمل کرنا چاہتے ہیں؟' 
              : 'You haven\'t added any items to the bill. Are you sure you want to complete without a bill?',
            style: TextStyle(fontFamily: widget.fontFamily),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(widget.isUrdu ? 'نہیں' : 'No'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(widget.isUrdu ? 'ہاں' : 'Yes'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    try {
      setState(() => _isSyncing = true);
      
      final db = Provider.of<DatabaseService>(context, listen: false);
      await db.updateArtisanWorkStatus(
        order.artisanId,
        order.id,
        'completed',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isUrdu ? 'کام مکمل ہو گیا!' : 'Work marked as completed!',
            ),
          ),
        );
      }
    } catch (e, stack) {
      _logger.error("Complete work error", e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isUrdu ? 'ناکامی' : 'Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _handleStartWork(ArtisanWorkOrder order) async {
    try {
      setState(() => _isSyncing = true);
      
      final db = Provider.of<DatabaseService>(context, listen: false);
      // Status transition: negotiating -> confirmed
      await db.updateArtisanWorkStatus(
        order.artisanId,
        order.id,
        'confirmed',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isUrdu ? 'کام شروع کر دیا گیا ہے!' : 'Work started and added to your list!',
            ),
            backgroundColor: AppTheme.themeColor,
          ),
        );
      }
    } catch (e, stack) {
      _logger.error("Start work error", e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isUrdu ? 'ناکامی' : 'Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showRatingDialog(BuildContext context, ArtisanWorkOrder order) {
    double selectedRating = 5.0;
    final reviewController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Text(
                  widget.isUrdu ? 'کاریگر کو ریویو دیں' : 'Rate Artisan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    fontFamily: widget.fontFamily,
                    color: AppTheme.darkColor,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                
                // Stars
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final bool isSelected = index < selectedRating;
                      return IconButton(
                        icon: Icon(
                          isSelected ? Icons.star : Icons.star_border,
                          color: AppTheme.darkColor,
                          size: 32,
                        ),
                        onPressed: () {
                          setDialogState(() => selectedRating = index + 1.0);
                        },
                      );
                    }),
                  ),
                ),
                const Divider(height: 1),
                
                // Review Text
                TextField(
                  controller: reviewController,
                  maxLines: 4,
                  minLines: 2,
                  style: TextStyle(fontFamily: widget.fontFamily, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: widget.isUrdu 
                        ? 'اپنا تجربہ لکھیں...' 
                        : 'Share your experience...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    contentPadding: const EdgeInsets.all(20),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
                // Actions
                const Divider(height: 1),
                IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: const RoundedRectangleBorder(),
                          ),
                          child: Text(
                            widget.isUrdu ? 'کینسل' : 'Cancel',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.bold,
                              fontFamily: widget.fontFamily,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        color: Colors.grey[200],
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: isSubmitting ? null : () async {
                            setDialogState(() => isSubmitting = true);
                            try {
                              await _artisanService.addReview(
                                artisanId: order.artisanId,
                                workOrderId: order.id,
                                rating: selectedRating,
                                comment: reviewController.text.trim(),
                              );
                              if (dialogContext.mounted) Navigator.pop(dialogContext);
                              widget.onOrderUpdated?.call();
                              if (mounted) {
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      widget.isUrdu
                                          ? 'شکریہ! آپ کا ریویو سبمٹ ہو گیا'
                                          : 'Thank you for your feedback!',
                                    ),
                                    backgroundColor: AppTheme.darkColor,
                                  ),
                                );
                              }
                            } catch (e, stack) {
                              _logger.error("Submit review error", e, stack);
                              if (mounted) {
                                setDialogState(() => isSubmitting = false);
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AppTheme.darkColor,
                            foregroundColor: Colors.white,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(0),
                              ),
                            ),
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  widget.isUrdu ? 'سبمٹ' : 'Submit',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontFamily: widget.fontFamily,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
