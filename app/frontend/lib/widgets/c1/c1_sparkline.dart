import 'package:flutter/material.dart';

class C1Sparkline extends StatelessWidget {
  final List<double> data;
  final Color color;
  final double lineWidth;

  const C1Sparkline({
    Key? key,
    required this.data,
    required this.color,
    this.lineWidth = 2.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox();
    }
    
    return CustomPaint(
      painter: _SparklinePainter(
        data: data,
        lineColor: color,
        lineWidth: lineWidth,
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;
  final double lineWidth;

  _SparklinePainter({
    required this.data,
    required this.lineColor,
    required this.lineWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    
    // Find min and max
    double max = data.reduce((a, b) => a > b ? a : b);
    double min = data.reduce((a, b) => a < b ? a : b);
    if (max == min) {
      max += 1;
      min -= 1;
    }

    final double xStep = size.width / (data.length - 1);
    final double yRange = max - min;

    for (int i = 0; i < data.length; i++) {
      final x = i * xStep;
      // y is inverted (0 is top)
      final y = size.height - ((data[i] - min) / yRange) * size.height;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.data != data || 
           oldDelegate.lineColor != lineColor || 
           oldDelegate.lineWidth != lineWidth;
  }
}
