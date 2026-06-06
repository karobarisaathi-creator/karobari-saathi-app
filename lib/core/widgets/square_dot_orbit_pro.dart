// lib/core/widgets/square_dot_orbit_pro.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:account_app/core/theme/app_theme.dart';

class SquareDotOrbitPro extends StatefulWidget {
  final double size;
  final Duration duration;
  final bool autoStart;

  const SquareDotOrbitPro({
    super.key,
    this.size = 200,
    this.duration = const Duration(seconds: 2), // تیز رفتار
    this.autoStart = true,
  });

  @override
  State<SquareDotOrbitPro> createState() => _SquareDotOrbitProState();
}

class _SquareDotOrbitProState extends State<SquareDotOrbitPro>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();

    if (widget.autoStart) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _controller.stop();
      } else {
        _controller.repeat();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = _controller.value;
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12), // آپ کے اسٹینڈرڈ کے مطابق
            border: Border.all(
              color: AppTheme.goldColor.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Path glow (Sharp lines)
              _buildPathGlow(value),
              
              // Inner path (Sharp lines)
              _buildInnerPath(value),
              
              // Trail dots (Tilted movement)
              Transform.rotate(
                angle: pi / 4, // 45 degree tilt
                child: Transform.scale(
                  scale: 0.85,
                  child: Stack(
                    children: List.generate(8, (index) {
                      final delay = -(index * 0.1); // فاصلہ بڑھا دیا گیا ہے
                      // سائز کو مزید کم کر دیا گیا ہے (3 سے 6.5 کے درمیان)
                      final size = 3.0 + (index * 0.5);
                      
                      return _buildDot(
                        value: value,
                        size: size,
                        color1: AppTheme.goldColor,
                        delay: delay,
                      );
                    }),
                  ),
                ),
              ),
              
              // Corner sparkles (No shadow, no opacity)
              _buildSparkle(0.05, 0.05, 0),
              _buildSparkle(0.05, 0.95, 0.5),
              _buildSparkle(0.95, 0.05, 1.0),
              _buildSparkle(0.95, 0.95, 1.5),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPathGlow(double value) {
    return Container(
      width: widget.size * 0.85,
      height: widget.size * 0.85,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      transform: Matrix4.identity()
        ..rotateZ(value * 0.2 * pi)
        ..scale(1 + 0.02 * sin(value * 2 * pi)),
    );
  }

  Widget _buildInnerPath(double value) {
    return Container(
      width: widget.size * 0.7,
      height: widget.size * 0.7,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.03),
          width: 1,
        ),
      ),
      transform: Matrix4.identity()
        ..scale(1 + 0.03 * sin(value * 4 * pi)),
    );
  }

  Widget _buildDot({
    required double value,
    required double size,
    required Color color1,
    required double delay,
  }) {
    final t = (value + delay) % 1.0;
    final pos = _getSquarePathPosition(t, widget.size);

    return Positioned(
      left: pos.dx - size / 2,
      top: pos.dy - size / 2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color1, // مکمل واضح کلر
        ),
        transform: Matrix4.identity()
          ..scale(1 + 0.1 * sin(value * 4 * pi + delay * 10)),
      ),
    );
  }

  Widget _buildSparkle(double x, double y, double delay) {
    return Positioned(
      left: widget.size * x - 1.5,
      top: widget.size * y - 1.5,
      child: Container(
        width: 4,
        height: 4,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
      ),
    );
  }

  Offset _getSquarePathPosition(double t, double size) {
    const margin = 20.0;
    final innerSize = size - (2 * margin);

    if (t < 0.25) {
      final progress = t / 0.25;
      return Offset(margin + progress * innerSize, margin);
    } else if (t < 0.5) {
      final progress = (t - 0.25) / 0.25;
      return Offset(size - margin, margin + progress * innerSize);
    } else if (t < 0.75) {
      final progress = (t - 0.5) / 0.25;
      return Offset(size - margin - progress * innerSize, size - margin);
    } else {
      final progress = (t - 0.75) / 0.25;
      return Offset(margin, size - margin - progress * innerSize);
    }
  }
}
