import 'package:flutter/material.dart';

class GoogleLogoWidget extends StatelessWidget {
  final double size;
  
  const GoogleLogoWidget({Key? key, this.size = 20}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Proper Google "G" logo with accurate proportions
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: GoogleLogoPainter(),
      ),
    );
  }
}

class GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double outerRadius = size.width * 0.45;
    final double innerRadius = size.width * 0.28;
    final double strokeWidth = outerRadius - innerRadius;
    
    // Google's official brand colors
    final Paint bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    
    final Paint redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    
    final Paint yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    
    final Paint greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    
    final Rect arcRect = Rect.fromCircle(
      center: Offset(centerX, centerY),
      radius: outerRadius - strokeWidth / 2,
    );
    
    // The Google "G" is made of 4 arc segments:
    // Blue: top-right quarter (270° to 360°/0°)
    // Red: top-left quarter (180° to 270°)
    // Yellow: bottom-left quarter (90° to 180°)
    // Green: bottom-right quarter, but with a gap for the horizontal bar (0° to 90° approximately)
    
    const double startAngle = -90.0 * (3.14159 / 180); // -90 degrees in radians
    const double sweepAngle = 90.0 * (3.14159 / 180);  // 90 degrees sweep
    
    // Blue arc (top-right, 12 o'clock to 3 o'clock)
    canvas.drawArc(
      arcRect,
      startAngle, // Start at -90° (top)
      sweepAngle, // Sweep 90°
      false,
      bluePaint,
    );
    
    // Red arc (top-left, 9 o'clock to 12 o'clock)
    canvas.drawArc(
      arcRect,
      startAngle - sweepAngle, // Start at -180° (left)
      sweepAngle,              // Sweep 90°
      false,
      redPaint,
    );
    
    // Yellow arc (bottom-left, 6 o'clock to 9 o'clock)
    canvas.drawArc(
      arcRect,
      90.0 * (3.14159 / 180), // Start at 90° (bottom)
      sweepAngle,             // Sweep 90°
      false,
      yellowPaint,
    );
    
    // Green arc (bottom-right, 3 o'clock to ~5 o'clock)
    // Slightly reduced to make room for horizontal bar
    canvas.drawArc(
      arcRect,
      0.0,                    // Start at 0° (right)
      65.0 * (3.14159 / 180), // Sweep ~65° (less than 90° to leave gap)
      false,
      greenPaint,
    );
    
    // Blue horizontal bar on the right side (completes the "G" opening)
    final double barWidth = strokeWidth * 1.8;
    final double barHeight = strokeWidth * 0.95;
    final double barStartX = centerX + outerRadius - strokeWidth / 2 - barWidth;
    final double barStartY = centerY - barHeight / 2;
    
    final Paint barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    
    final RRect horizontalBar = RRect.fromRectAndRadius(
      Rect.fromLTWH(barStartX, barStartY, barWidth, barHeight),
      Radius.circular(barHeight / 2),
    );
    
    canvas.drawRRect(horizontalBar, barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
