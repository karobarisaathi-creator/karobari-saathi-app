import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:account_app/core/models/notification_model.dart';
import 'package:account_app/core/theme/app_theme.dart';
import 'package:account_app/core/utils/formatters.dart';
import 'package:account_app/core/widgets/profile_info_widget.dart';
import 'package:account_app/core/widgets/receipt_paper_wrapper.dart';
import 'package:account_app/core/widgets/urdu_aware_text.dart';
import 'home_activity_message.dart';

/// Activity Receipt Dialog Content — receipt style pop-up with jagged cut edges
class ActivityReceiptDialog extends StatelessWidget {
  final AppNotification notification;
  final bool isUrdu;
  final VoidCallback? onAddToLedger;

  const ActivityReceiptDialog({
    super.key,
    required this.notification,
    required this.isUrdu,
    this.onAddToLedger,
  });

  @override
  Widget build(BuildContext context) {
    final data = notification.data ?? const <String, dynamic>{};
    final senderName =
        data['senderName']?.toString() ?? (isUrdu ? 'صارف' : 'A user');
    final senderPhone = data['senderPhone']?.toString() ?? '';
    final formattedTime = DateFormat(
      isUrdu ? 'yyyy/MM/dd  hh:mm a' : 'dd MMM yyyy, hh:mm a',
    ).format(notification.timestamp);

    final activityMessage = HomeActivityMessage.fromNotification(
      notification,
      isUrdu: isUrdu,
    );

    final items = data['items'] is List ? data['items'] as List : const [];
    final description = data['description']?.toString().trim() ?? '';
    final refNo = data['referenceNumber']?.toString().trim() ?? '';
    final transactionType = data['transactionType']?.toString().trim() ?? '';
    final isAdded = data['isAdded'] == true;

    final amount = _number(data['amount']);
    final subtotal = _number(data['subtotal']);
    final discount = _number(data['discountAmount']);
    final received = _number(data['receivedAmount']);
    final pending = _number(data['pendingAmount']);

    const clipper = ReceiptClipper(toothWidth: 10, toothHeight: 7);

    return CustomPaint(
      painter: ReceiptShadowPainter(clipper: clipper),
      child: ClipPath(
        clipper: clipper,
        child: Container(
          color: const Color(0xFFFAF8F5), // Thermal paper background color
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Receipt Icon & Title Header
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.themeColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      PhosphorIcons.receipt(PhosphorIconsStyle.fill),
                      color: AppTheme.themeColor,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: UrduAwareText(
                    isUrdu ? 'سرگرمی رسید' : 'ACTIVITY RECEIPT',
                    style: const TextStyle(
                      color: AppTheme.darkColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                const DashedLineDivider(),
                const SizedBox(height: 12),

                // 2. Party / Sender Info using ProfileInfoWidget
                ProfileInfoWidget(
                  name: senderName,
                  phone: senderPhone,
                  profileImage: data['senderPhotoUrl']?.toString(),
                  customSize: 34,
                  borderRadius: 8,
                  verticalSpacing: 1.0,
                  suffix: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      UrduAwareText(
                        formattedTime,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 10,
                        ),
                      ),
                      if (refNo.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        UrduAwareText(
                          refNo,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // 3. Optional Description Box (if description present)
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const DashedLineDivider(),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: UrduAwareText(
                      description,
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],

                // 4. Items Table (if items exist)
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  UrduAwareText(
                    isUrdu ? 'تفصیل اشیاء:' : 'Items list:',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppTheme.darkColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        // Table Header Row
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: UrduAwareText(
                                  isUrdu ? 'آئٹم' : 'Item',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: UrduAwareText(
                                  isUrdu ? 'تعداد' : 'Qty',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: UrduAwareText(
                                  isUrdu ? 'کل رقم' : 'Total',
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        for (int i = 0; i < items.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: _buildReceiptItemRow(items[i]),
                          ),
                      ],
                    ),
                  ),
                ],

                // 5. Amount Financial Breakdown (if amounts exist)
                if (amount > 0 || pending > 0 || received > 0) ...[
                  const SizedBox(height: 12),
                  const DashedLineDivider(),
                  const SizedBox(height: 10),
                  _buildFinancialBreakdown(
                    amount: amount,
                    subtotal: subtotal,
                    discount: discount,
                    received: received,
                    pending: pending,
                    transactionType: transactionType,
                    isUrdu: isUrdu,
                  ),
                ],

                const SizedBox(height: 12),
                const DashedLineDivider(),
                const SizedBox(height: 12),

                // 6. Footer watermark
                Center(
                  child: UrduAwareText(
                    isUrdu
                        ? 'کاروباری ساتھی • ڈیجیٹل سرگرمی رسید'
                        : 'Karobari Sathi • Digital Activity Receipt',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 10,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 7. Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          side: const BorderSide(color: Colors.black26),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: UrduAwareText(
                          isUrdu ? 'بند کریں' : 'Close',
                          style: const TextStyle(
                            color: AppTheme.darkColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    if (activityMessage.canAddToLedger || isAdded) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isAdded
                                ? Colors.grey.shade300
                                : AppTheme.themeColor,
                            foregroundColor: isAdded
                                ? Colors.grey.shade600
                                : Colors.white,
                            disabledBackgroundColor: Colors.grey.shade300,
                            disabledForegroundColor: Colors.grey.shade600,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          onPressed: isAdded ? null : onAddToLedger,
                          child: UrduAwareText(
                            isAdded
                                ? (isUrdu
                                    ? 'کھاتے میں شامل ہے'
                                    : 'Already added')
                                : (isUrdu
                                    ? 'کھاتے میں شامل کریں'
                                    : 'Add to Ledger'),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isAdded
                                  ? Colors.grey.shade600
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptItemRow(dynamic rawItem) {
    if (rawItem is! Map) return const SizedBox.shrink();
    final item = Map<String, dynamic>.from(rawItem);
    final name = (item['description'] ?? item['name'] ?? '').toString();
    final qty = _number(item['quantity']);
    final total = _number(item['total']);
    final formattedQty =
        qty == qty.roundToDouble() ? qty.toInt().toString() : '$qty';
    final rawUnit = item['unit']?.toString().trim() ?? '';
    final unitStr = _translateUnit(rawUnit, isUrdu);

    final qtyLabel = qty > 0 ? '$formattedQty $unitStr' : '—';

    return Row(
      children: [
        // Item Name
        Expanded(
          flex: 4,
          child: UrduAwareText(
            name,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.darkColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // Quantity with translated Urdu unit label (e.g. "2 عدد", "5 کلو")
        Expanded(
          flex: 2,
          child: UrduAwareText(
            qtyLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // Total Amount (e.g. "Rs 1,000")
        Expanded(
          flex: 3,
          child: UrduAwareText(
            total > 0 ? Formatters.formatAmountWithCurrency(total) : '—',
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkColor,
            ),
          ),
        ),
      ],
    );
  }

  static String _translateUnit(String rawUnit, bool isUrdu) {
    if (!isUrdu) return rawUnit.isEmpty ? 'pcs' : rawUnit;
    final lower = rawUnit.trim().toLowerCase();
    switch (lower) {
      case 'pcs':
      case 'piece':
      case 'pieces':
      case 'item':
      case 'items':
      case 'unit':
      case 'units':
      case '':
        return 'عدد';
      case 'kg':
      case 'kilogram':
      case 'kilo':
      case 'kilos':
        return 'کلو';
      case 'liter':
      case 'litre':
      case 'ltr':
        return 'لیٹر';
      case 'box':
      case 'boxes':
        return 'ڈبہ';
      case 'pack':
      case 'packet':
      case 'packets':
        return 'پیکٹ';
      case 'bag':
      case 'bags':
      case 'sack':
        return 'بوری';
      case 'dozen':
      case 'dozens':
        return 'درجن';
      case 'meter':
      case 'meters':
      case 'm':
        return 'میٹر';
      case 'gram':
      case 'grams':
      case 'g':
        return 'گرام';
      case 'maund':
      case 'mann':
        return 'من';
      case 'ft':
      case 'feet':
      case 'foot':
        return 'فٹ';
      default:
        return rawUnit;
    }
  }

  Widget _buildFinancialBreakdown({
    required double amount,
    required double subtotal,
    required double discount,
    required double received,
    required double pending,
    required String transactionType,
    required bool isUrdu,
  }) {
    final effectiveTotal = subtotal > 0 ? subtotal : amount;

    final bool isPurchaseBySender = transactionType == 'expense';
    final bool isBilledToUser = transactionType == 'income';

    final String paidLabel = isPurchaseBySender
        ? (isUrdu ? 'وصول شدہ' : 'Received')
        : isBilledToUser
            ? (isUrdu ? 'ادا شدہ' : 'Paid')
            : (isUrdu ? 'وصول/ادا شدہ' : 'Paid/Received');

    final String pendingLabel = isPurchaseBySender
        ? (isUrdu ? 'ان کے ذمے (بقایا)' : 'They owe (Due)')
        : isBilledToUser
            ? (isUrdu ? 'آپ کے ذمے (واجب)' : 'You owe (Due)')
            : (isUrdu ? 'بقایا واجب الادا' : 'Pending / Due');

    final Color pendingColor = isPurchaseBySender
        ? AppTheme.incomeColor
        : AppTheme.expenseColor;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          if (effectiveTotal > 0)
            _buildSummaryLine(
              isUrdu ? 'کل رقم' : 'Total Amount',
              Formatters.formatAmountWithCurrency(effectiveTotal),
              isBold: true,
            ),
          if (discount > 0) ...[
            const SizedBox(height: 4),
            _buildSummaryLine(
              isUrdu ? 'رعایت' : 'Discount',
              '- ${Formatters.formatAmountWithCurrency(discount)}',
              textColor: AppTheme.incomeColor,
            ),
          ],
          if (received > 0) ...[
            const SizedBox(height: 4),
            _buildSummaryLine(
              paidLabel,
              Formatters.formatAmountWithCurrency(received),
              textColor: AppTheme.incomeColor,
            ),
          ],
          if (pending > 0) ...[
            const SizedBox(height: 4),
            _buildSummaryLine(
              pendingLabel,
              Formatters.formatAmountWithCurrency(pending),
              textColor: pendingColor,
              isBold: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryLine(
    String label,
    String value, {
    bool isBold = false,
    Color? textColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        UrduAwareText(
          label,
          style: TextStyle(
            fontSize: 12,
            color: textColor ?? AppTheme.darkColor,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        UrduAwareText(
          value,
          style: TextStyle(
            fontSize: 12,
            color: textColor ?? AppTheme.darkColor,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  static double _number(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
