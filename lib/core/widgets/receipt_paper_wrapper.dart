import 'package:flutter/material.dart';

/// Clipper that creates jagged / saw-tooth cut edges at the top and bottom of the receipt
class ReceiptClipper extends CustomClipper<Path> {
  final double toothWidth;
  final double toothHeight;
  final bool clipTop;
  final bool clipBottom;

  const ReceiptClipper({
    this.toothWidth = 10.0,
    this.toothHeight = 6.0,
    this.clipTop = true,
    this.clipBottom = true,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final numTeeth = (size.width / toothWidth).floor();
    final actualToothWidth = size.width / numTeeth;

    // Top edge (saw-tooth cut)
    if (clipTop) {
      path.moveTo(0, toothHeight);
      for (int i = 0; i < numTeeth; i++) {
        final x1 = i * actualToothWidth + (actualToothWidth / 2);
        final y1 = 0.0;
        final x2 = (i + 1) * actualToothWidth;
        final y2 = toothHeight;
        path.lineTo(x1, y1);
        path.lineTo(x2, y2);
      }
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
    }

    // Right edge
    path.lineTo(size.width, size.height - (clipBottom ? toothHeight : 0));

    // Bottom edge (saw-tooth cut right to left)
    if (clipBottom) {
      for (int i = numTeeth; i > 0; i--) {
        final x1 = (i - 1) * actualToothWidth + (actualToothWidth / 2);
        final y1 = size.height;
        final x2 = (i - 1) * actualToothWidth;
        final y2 = size.height - toothHeight;
        path.lineTo(x1, y1);
        path.lineTo(x2, y2);
      }
    } else {
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    }

    // Left edge
    path.lineTo(0, clipTop ? toothHeight : 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant ReceiptClipper oldClipper) {
    return oldClipper.toothWidth != toothWidth ||
        oldClipper.toothHeight != toothHeight ||
        oldClipper.clipTop != clipTop ||
        oldClipper.clipBottom != clipBottom;
  }
}

/// Draws soft drop shadow and border along the clipped receipt path
class ReceiptShadowPainter extends CustomPainter {
  final ReceiptClipper clipper;

  ReceiptShadowPainter({required this.clipper});

  @override
  void paint(Canvas canvas, Size size) {
    final path = clipper.getClip(size);

    // Draw drop shadow
    canvas.drawShadow(
      path,
      Colors.black.withValues(alpha: 0.35),
      8.0,
      true,
    );

    // Draw subtle border stroke
    final borderPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant ReceiptShadowPainter oldDelegate) => false;
}

/// Dashed line divider commonly seen on paper receipts
class DashedLineDivider extends StatelessWidget {
  final Color color;
  final double height;
  final double dashWidth;
  final double dashSpace;

  const DashedLineDivider({
    super.key,
    this.color = Colors.black26,
    this.height = 1,
    this.dashWidth = 5,
    this.dashSpace = 4,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.maxWidth;
        final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color),
              ),
            );
          }),
        );
      },
    );
  }
}
