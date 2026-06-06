import 'dart:io';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_filter_chip.dart';

class VisualResultCard extends StatelessWidget {
  final Map<String, String> result;
  final File? image;
  final bool isTracked;
  final Function(bool) onTrackChanged;
  final String Function(String?, bool) getFont;
  final bool isUrdu;
  final String fontFamily;

  const VisualResultCard({
    super.key, 
    required this.result, 
    this.image, 
    required this.isTracked,
    required this.onTrackChanged,
    required this.getFont,
    required this.isUrdu,
    required this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    final confidence = int.tryParse(result['confidence'] ?? '0') ?? 0;
    
    // Clean price formatting
    String cleanPrice = result['price'] ?? "0";
    cleanPrice = cleanPrice.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPrice.isNotEmpty) {
      try {
        final val = int.parse(cleanPrice);
        cleanPrice = val.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => "${m[1]},");
      } catch (e) {
        cleanPrice = result['price']!;
      }
    }

    final category = (result['category'] ?? "").toLowerCase();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkColor, 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))
        ]
      ),
      child: Column(
        crossAxisAlignment: isUrdu ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (image != null) 
                ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(image!, width: 70, height: 70, fit: BoxFit.cover))
              else 
                Container(
                  width: 70, height: 70, 
                  decoration: BoxDecoration(color: AppTheme.themeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), 
                  child: Icon(_getCategoryIcon(category), size: 35, color: AppTheme.themeColor)
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, 
                  children: [
                    Text(
                      result['name'] ?? (isUrdu ? "نامعلوم" : "Unknown"), 
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: getFont(result['name'], isUrdu))
                    ), 
                    const SizedBox(height: 4), 
                    Text(
                      result['brand'] ?? (isUrdu ? "تلاش کے نتائج" : "Search Result"), 
                      style: TextStyle(color: Colors.white60, fontSize: 14, fontFamily: getFont(result['brand'], isUrdu))
                    )
                  ]
                ) 
              ),
              Column(
                children: [
                  Text("$confidence%", style: TextStyle(color: confidence > 80 ? Colors.green : Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)), 
                  Text(isUrdu ? "اعتماد" : "Confidence", style: TextStyle(color: Colors.white38, fontSize: 10, fontFamily: isUrdu ? 'NooriNastaleeq' : null))
                ]
              ),
            ],
          ),
          const Divider(height: 40, color: Colors.white12),
          
          Row(
            textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            children: [
              _buildStatItem(isUrdu ? "مارکیٹ قیمت" : "Market Price", "Rs $cleanPrice", highlight: true), 
              _buildStatItem(isUrdu ? "کیٹیگری" : "Category", result['category'] ?? "General"),
            ]
          ),

          if (result['specs'] != null && result['specs']!.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildSpecsGrid(result['specs']!, category),
          ],
          
          const SizedBox(height: 24),
          if (result['pros'] != null || result['cons'] != null) 
            Directionality(
              textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  if (result['pros'] != null) 
                    Expanded(child: _buildPointList(isUrdu ? "خوبیاں" : "Pros", result['pros']!, Colors.green)), 
                  if (result['cons'] != null) 
                    Expanded(child: _buildPointList(isUrdu ? "کمیاں" : "Cons", result['cons']!, Colors.redAccent)),
                ],
              ),
            ),
          
          if (result['advice'] != null && result['advice']!.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.themeColor.withValues(alpha: 0.2))),
              child: Column(
                crossAxisAlignment: isUrdu ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: isUrdu ? MainAxisAlignment.end : MainAxisAlignment.start, children: [Icon(PhosphorIcons.lightbulb(PhosphorIconsStyle.fill), size: 16, color: Colors.amber), const SizedBox(width: 8), Text(isUrdu ? "ایجنٹ کا مشورہ" : "Agent's Advice", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: isUrdu ? 'NooriNastaleeq' : null))]),
                  const SizedBox(height: 6),
                  Text(result['advice']!, textAlign: isUrdu ? TextAlign.right : TextAlign.left, style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4, fontFamily: getFont(result['advice'], isUrdu))),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            children: [
              Text(isUrdu ? "قیمت گرنے پر الرٹ" : "Track Price Drops", style: TextStyle(color: Colors.white70, fontSize: 14, fontFamily: isUrdu ? 'NooriNastaleeq' : null)), 
              Switch(value: isTracked, onChanged: onTrackChanged, activeThumbColor: AppTheme.themeColor)
            ]
          ),
        ],
      ),
    );
  }

  Widget _buildSpecsGrid(String specs, String category) {
    // Attempt to parse "Key: Value, Key: Value"
    final List<String> parts = specs.split(',');
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: isUrdu ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            isUrdu ? "تکنیکی معلومات:" : "Technical Specs:", 
            style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: isUrdu ? 'NooriNastaleeq' : null)
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: parts.map((s) {
              final kv = s.split(':');
              final key = kv[0].trim();
              final val = kv.length > 1 ? kv[1].trim() : "";
              return _buildSpecChip(key, val);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecChip(String key, String val) {
    IconData icon = _getSpecIcon(key);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.themeColor),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(key, style: const TextStyle(color: Colors.white38, fontSize: 9)),
              Text(val, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    final catId = category.toLowerCase();
    try {
      // Find matching icon from centralized categories
      final match = AppFilterChip.productCategories.firstWhere(
        (c) => c.id == catId || c.labelEn.toLowerCase() == catId
      );
      return match.icon;
    } catch (e) {
      return PhosphorIcons.cube(); // Default icon
    }
  }

  IconData _getSpecIcon(String key) {
    final k = key.toLowerCase();
    if (k.contains("ram")) return PhosphorIcons.memory();
    if (k.contains("storage") || k.contains("memory")) return PhosphorIcons.database();
    if (k.contains("processor") || k.contains("chip")) return PhosphorIcons.cpu();
    if (k.contains("engine")) return PhosphorIcons.engine();
    if (k.contains("year") || k.contains("model")) return PhosphorIcons.calendar();
    if (k.contains("mileage")) return PhosphorIcons.gauge();
    if (k.contains("color")) return PhosphorIcons.palette();
    if (k.contains("size")) return PhosphorIcons.ruler();
    return PhosphorIcons.info();
  }

  Widget _buildStatItem(String label, String value, {bool highlight = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Text(label, textAlign: TextAlign.start, style: TextStyle(color: Colors.white38, fontSize: 12, fontFamily: isUrdu ? 'NooriNastaleeq' : null)), 
          const SizedBox(height: 4), 
          Text(value, textAlign: TextAlign.start, style: TextStyle(color: highlight ? AppTheme.themeColor : Colors.white, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: getFont(value, isUrdu)))
        ] 
      ),
    );
  }

  Widget _buildPointList(String title, String points, Color color) {
    final list = points.split(',');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, 
      children: [
        Text(title, textAlign: TextAlign.start, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: isUrdu ? 'NooriNastaleeq' : null)), 
        const SizedBox(height: 6), 
        ...list.take(2).map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 4), 
          child: Row(children: [Icon(Icons.circle, size: 4, color: color.withValues(alpha: 0.5)), const SizedBox(width: 6), Expanded(child: Text(p.trim(), textAlign: TextAlign.start, style: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: getFont(p, isUrdu)), maxLines: 1, overflow: TextOverflow.ellipsis))])
        )) 
      ] 
    );
  }
}
