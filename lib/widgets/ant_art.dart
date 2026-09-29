import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Yukarıdan bakılmış bir karınca çizimi (uygulama logosu).
class AntLogo extends StatelessWidget {
  const AntLogo({super.key, this.size = 48, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _AntPainter(color ?? Theme.of(context).colorScheme.primary)),
      );
}

class _AntPainter extends CustomPainter {
  _AntPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    final body = Paint()..color = color;
    final leg = Paint()
      ..color = color
      ..strokeWidth = 4 * s
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Bacaklar (3 çift)
    final legs = [
      [const Offset(50, 45), const Offset(30, 30), const Offset(20, 18)],
      [const Offset(50, 50), const Offset(28, 52), const Offset(14, 50)],
      [const Offset(50, 55), const Offset(30, 70), const Offset(22, 86)],
    ];
    for (final l in legs) {
      for (final mirror in [false, true]) {
        Offset m(Offset o) => Offset(mirror ? 100 - o.dx : o.dx, o.dy) * s;
        final path = Path()
          ..moveTo(m(l[0]).dx, m(l[0]).dy)
          ..lineTo(m(l[1]).dx, m(l[1]).dy)
          ..lineTo(m(l[2]).dx, m(l[2]).dy);
        canvas.drawPath(path, leg);
      }
    }
    // Antenler
    final antenna = Path()
      ..moveTo(46 * s, 22 * s)
      ..quadraticBezierTo(38 * s, 8 * s, 28 * s, 6 * s)
      ..moveTo(54 * s, 22 * s)
      ..quadraticBezierTo(62 * s, 8 * s, 72 * s, 6 * s);
    canvas.drawPath(antenna, leg..strokeWidth = 3 * s);

    // Baş, göğüs, karın
    canvas.drawOval(Rect.fromCenter(center: Offset(50 * s, 25 * s), width: 18 * s, height: 16 * s), body);
    canvas.drawOval(Rect.fromCenter(center: Offset(50 * s, 47 * s), width: 14 * s, height: 22 * s), body);
    canvas.drawOval(Rect.fromCenter(center: Offset(50 * s, 75 * s), width: 26 * s, height: 34 * s), body);

    // Gözler
    final eye = Paint()..color = AntColors.amber;
    canvas.drawCircle(Offset(45.5 * s, 22 * s), 2.2 * s, eye);
    canvas.drawCircle(Offset(54.5 * s, 22 * s), 2.2 * s, eye);
  }

  @override
  bool shouldRepaint(_AntPainter old) => old.color != color;
}

/// Toprak altı tünelleri ve odacıklarıyla karınca yuvası kesiti.
/// Giriş ekranında arka plan olarak kullanılır.
class AntNestBackground extends StatelessWidget {
  const AntNestBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      painter: _NestPainter(dark),
      child: child,
    );
  }
}

class _NestPainter extends CustomPainter {
  _NestPainter(this.dark);
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final sky = Paint()..color = dark ? AntColors.night : AntColors.cream;
    canvas.drawRect(Offset.zero & size, sky);

    final groundTop = h * 0.30;
    final soil = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: dark
            ? [const Color(0xFF3A281E), const Color(0xFF1E140F)]
            : [const Color(0xFFD9B99A), const Color(0xFFB88B67)],
      ).createShader(Rect.fromLTWH(0, groundTop, w, h - groundTop));

    // Tepecik (yuva girişi)
    final ground = Path()
      ..moveTo(0, groundTop + 20)
      ..quadraticBezierTo(w * 0.25, groundTop + 10, w * 0.40, groundTop - 10)
      ..quadraticBezierTo(w * 0.5, groundTop - 40, w * 0.60, groundTop - 10)
      ..quadraticBezierTo(w * 0.75, groundTop + 10, w, groundTop + 20)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(ground, soil);

    // Tüneller
    final tunnel = Paint()
      ..color = (dark ? const Color(0xFF140D0A) : const Color(0xFF8A5E43))
          .withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    final chamber = Paint()..color = tunnel.color;
    final t = Path()
      ..moveTo(w * 0.5, groundTop - 30)
      ..cubicTo(w * 0.45, groundTop + 60, w * 0.62, groundTop + 90, w * 0.55, h * 0.55)
      ..cubicTo(w * 0.5, h * 0.65, w * 0.3, h * 0.62, w * 0.2, h * 0.72)
      ..moveTo(w * 0.55, h * 0.55)
      ..cubicTo(w * 0.7, h * 0.6, w * 0.82, h * 0.7, w * 0.8, h * 0.85)
      ..moveTo(w * 0.2, h * 0.72)
      ..cubicTo(w * 0.15, h * 0.8, w * 0.3, h * 0.9, w * 0.45, h * 0.92);
    canvas.drawPath(t, tunnel);
    for (final c in [
      Offset(w * 0.2, h * 0.72),
      Offset(w * 0.8, h * 0.85),
      Offset(w * 0.45, h * 0.92),
      Offset(w * 0.55, h * 0.55),
    ]) {
      canvas.drawOval(Rect.fromCenter(center: c, width: 70, height: 36), chamber);
    }

    // Küçük karıncalar (noktalar) — tünel boyunca
    final ant = Paint()..color = dark ? AntColors.amber.withValues(alpha: 0.7) : AntColors.soilDark;
    final rnd = math.Random(10);
    for (var i = 0; i < 14; i++) {
      final x = w * (0.1 + rnd.nextDouble() * 0.8);
      final y = groundTop + 30 + rnd.nextDouble() * (h - groundTop - 40);
      canvas.drawCircle(Offset(x, y), 2.4, ant);
      canvas.drawCircle(Offset(x + 4, y), 1.8, ant);
      canvas.drawCircle(Offset(x + 7.5, y), 2.8, ant);
    }
  }

  @override
  bool shouldRepaint(_NestPainter old) => old.dark != dark;
}
