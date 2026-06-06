import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/theme/app_theme.dart';

class VisualShimmerCard extends StatelessWidget {
  final Animation<double> animation;
  final bool isUrdu;
  final String fontFamily;

  const VisualShimmerCard({
    super.key, 
    required this.animation,
    required this.isUrdu,
    required this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            double wavePosition = (math.sin(animation.value * 2 * math.pi - math.pi / 2) + 1) / 2;
            return Container(
              height: 220,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppTheme.darkColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 60, height: 60,
                              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(width: 120, height: 16, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4))),
                                  const SizedBox(height: 8),
                                  Container(width: 70, height: 12, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4))),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(width: double.infinity, height: 40, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8))),
                        const SizedBox(height: 10),
                        Container(width: double.infinity, height: 40, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8))),
                      ],
                    ),
                  ),
                  Positioned(
                    top: wavePosition * 220 - 40,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            AppTheme.themeColor.withValues(alpha: 0.2),
                            AppTheme.themeColor.withValues(alpha: 0.5),
                            AppTheme.themeColor.withValues(alpha: 0.2),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 30),
        Text(
          isUrdu ? "کاروباری ایجنٹ پروڈکٹ کا تجزیہ کر رہا ہے..." : "Business Agent is analyzing product...",
          style: TextStyle(
            color: AppTheme.darkColor.withValues(alpha: 0.7), 
            fontFamily: fontFamily,
            fontSize: 16
          ),
        ),
        const SizedBox(height: 10),
        const LinearProgressIndicator(backgroundColor: Colors.black12, color: AppTheme.themeColor),
      ],
    );
  }
}
