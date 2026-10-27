// lib/features/order/order_preview_screen.dart

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/models/shop_model.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/widgets/app_button.dart';
import 'package:account_app/core/widgets/app_toast.dart';
import 'package:account_app/core/widgets/custom_app_bar.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'package:account_app/features/order/services/shop_order_service.dart';

class OrderPreviewScreen extends StatefulWidget {
  final Shop shop;
  final List<ShopItem> selectedItems;
  final bool isUrdu;

  const OrderPreviewScreen({
    super.key,
    required this.shop,
    required this.selectedItems,
    required this.isUrdu,
  });

  @override
  State<OrderPreviewScreen> createState() => _OrderPreviewScreenState();
}

class _OrderPreviewScreenState extends State<OrderPreviewScreen> {
  bool _isPlacingOrder = false;
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUrdu = widget.isUrdu;
    final fontFamily = isUrdu ? 'NooriNastaleeq' : null;
    final totalCount =
        widget.selectedItems.fold<double>(0, (sum, i) => sum + i.quantity);
    final subtotal = widget.selectedItems.fold<double>(
      0,
      (sum, item) => sum + item.total,
    );
    final deliveryFee =
        ShopOrderService.parseConfiguredAmount(widget.shop.deliveryFee);
    final minimumOrder =
        ShopOrderService.parseConfiguredAmount(widget.shop.minOrder);
    final minimumOrderNotMet = minimumOrder > 0 && subtotal < minimumOrder;
    final total = subtotal + deliveryFee;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: isUrdu ? 'آرڈر کا جائزہ' : 'Order Preview',
        showBackButton: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ═══ Shop Card ═══
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.themeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(PhosphorIcons.storefront(),
                              color: AppTheme.themeColor, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              UrduAwareText(
                                widget.shop.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.darkColor,
                                  fontFamily: fontFamily,
                                ),
                              ),
                              const SizedBox(height: 2),
                              UrduAwareText(
                                widget.shop.area,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                  fontFamily: fontFamily,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: UrduAwareText(
                            widget.shop.deliveryTime,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.incomeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ═══ Combined Items & Bill Summary Card ═══
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        UrduAwareText(
                          isUrdu
                              ? 'منتخب کردہ اشیاء (${totalCount.toInt()})'
                              : 'Selected Items (${totalCount.toInt()})',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textSecondary,
                            fontFamily: fontFamily,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Items ListView
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: widget.selectedItems.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 14),
                          itemBuilder: (context, index) {
                            final item = widget.selectedItems[index];
                            return Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      UrduAwareText(
                                        item.name,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.darkColor,
                                          fontFamily: fontFamily,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Directionality(
                                        textDirection: TextDirection.ltr,
                                        child: UrduAwareText(
                                          '${item.quantity.toInt()} ${item.unit} × ${Formatters.formatAmountWithCurrency(item.rate)}',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textSecondary,
                                            fontFamily: fontFamily,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                UrduAwareText(
                                  Formatters.formatAmountWithCurrency(
                                      item.total),
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.themeColor,
                                    fontFamily: fontFamily,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                        const Divider(height: 24, thickness: 1.5),

                        // Bill Summary inside the same card
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            UrduAwareText(
                              isUrdu ? 'اشیاء کی کل قیمت' : 'Subtotal',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppTheme.textSecondary,
                                  fontFamily: fontFamily),
                            ),
                            UrduAwareText(
                              Formatters.formatAmountWithCurrency(subtotal),
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: fontFamily),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            UrduAwareText(
                              isUrdu ? 'ڈیلیوری چارجز' : 'Delivery Fee',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppTheme.textSecondary,
                                  fontFamily: fontFamily),
                            ),
                            UrduAwareText(
                              deliveryFee == 0
                                  ? (isUrdu ? 'مفت' : 'Free')
                                  : Formatters.formatAmountWithCurrency(
                                      deliveryFee,
                                    ),
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.incomeColor,
                                  fontFamily: fontFamily),
                            ),
                          ],
                        ),
                        if (minimumOrder > 0) ...[
                          const SizedBox(height: 6),
                          UrduAwareText(
                            minimumOrderNotMet
                                ? (isUrdu
                                    ? 'کم از کم آرڈر ${Formatters.formatAmountWithCurrency(minimumOrder)} ہے'
                                    : 'Minimum order is ${Formatters.formatAmountWithCurrency(minimumOrder)}')
                                : (isUrdu
                                    ? 'کم از کم آرڈر: ${Formatters.formatAmountWithCurrency(minimumOrder)}'
                                    : 'Minimum order: ${Formatters.formatAmountWithCurrency(minimumOrder)}'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: minimumOrderNotMet
                                  ? AppTheme.expenseColor
                                  : AppTheme.textSecondary,
                              fontFamily: fontFamily,
                            ),
                          ),
                        ],
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            UrduAwareText(
                              isUrdu ? 'کل قابلِ ادائیگی' : 'Total Amount',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.darkColor,
                                  fontFamily: fontFamily),
                            ),
                            UrduAwareText(
                              Formatters.formatAmountWithCurrency(total),
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.themeColor,
                                  fontFamily: fontFamily),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ═══ Order Note (Moved to the very bottom) ═══
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: UrduAwareText(
                      isUrdu
                          ? 'آرڈر نوٹ یا ہدایت (اختیاری)'
                          : 'Order Note / Instructions (Optional)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textSecondary,
                        fontFamily: fontFamily,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: TextField(
                      controller: _noteController,
                      maxLines: 2,
                      maxLength: 500,
                      decoration: InputDecoration(
                        hintText: isUrdu
                            ? 'کوئی خاص ہدایت یا پیغام درج کریں...'
                            : 'Enter any special instructions...',
                        hintStyle:
                            TextStyle(fontSize: 12, fontFamily: fontFamily),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ═══ Bottom Confirm Button Bar ═══
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: AppButton(
                text: isUrdu ? 'آرڈر کنفرم کریں' : 'Confirm & Place Order',
                icon: PhosphorIcons.checkCircle(),
                size: AppButtonSize.large,
                isLoading: _isPlacingOrder,
                loadingTextIntervalMs: 2200,
                loadingTexts: isUrdu
                    ? [
                        'پروسیسنگ ہو رہی ہے...',
                        'آرڈر بھیجا جا رہا ہے...',
                        'تقریباً ہو گیا...'
                      ]
                    : ['Processing...', 'Sending Order...', 'Almost Done...'],
                onPressed: _isPlacingOrder || minimumOrderNotMet
                    ? null
                    : () async {
                        setState(() => _isPlacingOrder = true);
                        try {
                          final service = ShopOrderService();
                          await service.placeOrder(
                            shop: widget.shop,
                            items: widget.selectedItems,
                            note: _noteController.text,
                          );
                          if (!context.mounted) return;
                          setState(() => _isPlacingOrder = false);
                          AppToast.success(
                            context,
                            isUrdu
                                ? 'آرڈر کامیابی سے بھیج دیا گیا!'
                                : 'Order placed successfully!',
                          );
                          Navigator.pop(context, true);
                        } catch (e) {
                          if (!context.mounted) return;
                          setState(() => _isPlacingOrder = false);
                          AppToast.error(
                            context,
                            isUrdu ? 'خرابی: $e' : 'Error: $e',
                          );
                        }
                      },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
