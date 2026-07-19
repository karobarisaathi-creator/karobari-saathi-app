// lib/core/widgets/simple_spinning_ring.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:account_app/core/theme/app_theme.dart';

class SimpleSpinningRing extends StatefulWidget {
  final double size;
  final Duration duration;
  final Color? ringColor;
  final Color? dotColor;
  final bool autoStart;

  const SimpleSpinningRing({
    super.key,
    this.size = 80,
    this.duration = const Duration(seconds: 1),
    this.ringColor,
    this.dotColor,
    this.autoStart = true,
  });

  @override
  State<SimpleSpinningRing> createState() => _SimpleSpinningRingState();
}

class _SimpleSpinningRingState extends State<SimpleSpinningRing>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pulseController;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    if (widget.autoStart) {
      _controller.repeat();
      _pulseController.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ringColor = widget.ringColor ?? AppTheme.themeColor;
    final dotColor = widget.dotColor ?? AppTheme.themeColor;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final pulseValue = _pulseController.value;
            final scale = 1 + (0.3 * (0.5 - 0.5 * math.cos(pulseValue * 2 * math.pi)));
            
            return Container(
              width: widget.size,
              height: widget.size,
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Spinning ring (Thin background)
                  Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ringColor.withValues(alpha: 0.1),
                        width: 3,
                      ),
                    ),
                  ),
                  
                  // Spinning ring (Active part)
                  Transform.rotate(
                    angle: _controller.value * 2 * math.pi,
                    child: SizedBox(










                      
                      width: widget.size,
                      height: widget.size,
                      child: CircularProgressIndicator(
                        value: 0.25, // Only quarter ring
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                      ),
                    ),
                  ),
                  
                  // Inner dot with pulse
                  Transform.scale(
                    scale: scale,
                    child: Container(
                      width: widget.size * 0.2,
                      height: widget.size * 0.2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dotColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
