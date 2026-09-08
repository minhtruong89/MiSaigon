import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Icon bánh răng thanh mảnh vẽ bằng CustomPainter
class ThinGearIcon extends StatelessWidget {
  final double size;
  final Color color;
  final double strokeWidth;

  const ThinGearIcon({
    super.key,
    this.size = 38,
    this.color = const Color(0xFF00A4E8),
    this.strokeWidth = 1.8,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ThinGearPainter(
        color: color,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class _ThinGearPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _ThinGearPainter({
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rOuter = size.width * 0.44;
    final rRoot = size.width * 0.35;
    final rInner = size.width * 0.16;

    const nTeeth = 8;
    final points = <Offset>[];

    for (var i = 0; i < nTeeth; i++) {
      final baseAng = i * (2 * math.pi / nTeeth);
      final a1 = baseAng - 0.12;
      final a2 = baseAng + 0.12;
      final a3 = baseAng + math.pi / nTeeth - 0.15;
      final a4 = baseAng + math.pi / nTeeth + 0.15;

      points.add(Offset(cx + rOuter * math.cos(a1), cy + rOuter * math.sin(a1)));
      points.add(Offset(cx + rOuter * math.cos(a2), cy + rOuter * math.sin(a2)));
      points.add(Offset(cx + rRoot * math.cos(a3), cy + rRoot * math.sin(a3)));
      points.add(Offset(cx + rRoot * math.cos(a4), cy + rRoot * math.sin(a4)));
    }

    final path = Path();
    if (points.isNotEmpty) {
      path.moveTo(points[0].dx, points[0].dy);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      path.close();
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);
    canvas.drawCircle(Offset(cx, cy), rInner, paint);
  }

  @override
  bool shouldRepaint(covariant _ThinGearPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
