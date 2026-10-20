import 'package:flutter/material.dart';

/// A crisp, transparent vector mark inspired by the supplied Tâm An logo.
/// The old red/gold outer medallion is intentionally omitted.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _BrandLogoPainter()),
      );
}

class _BrandLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 100;
    final sy = size.height / 100;
    canvas.save();
    canvas.scale(sx, sy);

    final navy = Paint()..color = const Color(0xff123d78);
    final blue = Paint()..color = const Color(0xff168ed0);
    final gold = Paint()..color = const Color(0xffffb629);
    final green = Paint()..color = const Color(0xff087f52);
    final wave = Paint()
      ..color = const Color(0xff078ca0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final hull = Path()
      ..moveTo(17, 58)
      ..cubicTo(33, 64, 63, 64, 84, 56)
      ..cubicTo(78, 70, 63, 75, 45, 73)
      ..cubicTo(31, 72, 22, 67, 17, 58)
      ..close();
    canvas.drawPath(hull, navy);

    final sailBlue = Path()
      ..moveTo(43, 53)
      ..lineTo(58, 14)
      ..cubicTo(60, 31, 56, 45, 50, 55)
      ..close();
    canvas.drawPath(sailBlue, blue);

    final sailGold = Path()
      ..moveTo(52, 54)
      ..cubicTo(60, 43, 63, 31, 62, 19)
      ..cubicTo(75, 33, 77, 47, 68, 57)
      ..close();
    canvas.drawPath(sailGold, gold);

    final mast = Paint()
      ..color = const Color(0xfff6fbff)
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(59, 14), const Offset(51, 56), mast);

    final firstWave = Path()
      ..moveTo(17, 81)
      ..cubicTo(28, 74, 35, 87, 46, 81)
      ..cubicTo(57, 75, 64, 87, 75, 81)
      ..cubicTo(80, 78, 84, 79, 88, 81);
    canvas.drawPath(firstWave, wave);
    final secondWave = Path()
      ..moveTo(26, 89)
      ..cubicTo(34, 84, 40, 94, 49, 89)
      ..cubicTo(58, 84, 64, 94, 73, 89);
    canvas.drawPath(secondWave, wave..color = const Color(0xff4db8be)..strokeWidth = 2.8);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

