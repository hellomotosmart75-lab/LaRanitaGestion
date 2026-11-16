import 'package:flutter/material.dart';

class RanaLogo extends StatelessWidget {
  final double size;
  const RanaLogo({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _RanaPainter()),
      );
}

class _RanaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final p = Paint()..style = PaintingStyle.fill;

    // Fondo de agua
    p.color = const Color(0xFF26A69A);
    canvas.drawCircle(Offset(w / 2, h / 2), w / 2, p);

    // Nenúfar
    p.color = const Color(0xFF2E7D32);
    canvas.drawOval(Rect.fromLTWH(w * 0.08, h * 0.70, w * 0.84, h * 0.22), p);

    // Cabeza y ojos salidos
    p.color = const Color(0xFF66BB6A);
    canvas.drawOval(Rect.fromLTWH(w * 0.15, h * 0.38, w * 0.70, h * 0.42), p);
    canvas.drawCircle(Offset(w * 0.33, h * 0.40), w * 0.14, p);
    canvas.drawCircle(Offset(w * 0.67, h * 0.40), w * 0.14, p);

    // Ojos
    p.color = Colors.white;
    canvas.drawCircle(Offset(w * 0.33, h * 0.40), w * 0.09, p);
    canvas.drawCircle(Offset(w * 0.67, h * 0.40), w * 0.09, p);
    p.color = const Color(0xFF212121);
    canvas.drawCircle(Offset(w * 0.34, h * 0.41), w * 0.045, p);
    canvas.drawCircle(Offset(w * 0.68, h * 0.41), w * 0.045, p);

    // Mejillas
    p.color = const Color(0xFFF8BBD0).withOpacity(0.8);
    canvas.drawCircle(Offset(w * 0.25, h * 0.62), w * 0.05, p);
    canvas.drawCircle(Offset(w * 0.75, h * 0.62), w * 0.05, p);

    // Sonrisa
    final linea = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.03
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF1B5E20);
    canvas.drawArc(
        Rect.fromLTWH(w * 0.34, h * 0.52, w * 0.32, h * 0.18), 0.2, 2.7, false, linea);

    // Gorro de chef
    p.color = Colors.white;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.30, h * 0.17, w * 0.40, h * 0.08),
            const Radius.circular(4)),
        p);
    canvas.drawCircle(Offset(w * 0.36, h * 0.15), w * 0.08, p);
    canvas.drawCircle(Offset(w * 0.50, h * 0.11), w * 0.09, p);
    canvas.drawCircle(Offset(w * 0.64, h * 0.15), w * 0.08, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
