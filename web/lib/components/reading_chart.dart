import 'package:flutter/material.dart';
import '../api/client.dart';
import 'dart:math' as math;

class ReadingChart extends StatelessWidget {
  final List<Reading> readings;

  const ReadingChart({super.key, required this.readings});

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return const Center(child: Text('No data to display'));
    }

    // Reverse to show oldest to newest
    final sortedReadings = List<Reading>.from(readings.reversed);

    // Calculate min/max for scaling
    final values = sortedReadings.map((r) => r.value).toList();
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = maxValue - minValue;
    const padding = 0.1; // 10% padding
    final valuePadding = range * padding;

    return CustomPaint(
      painter: _ChartPainter(
        readings: sortedReadings,
        minValue: minValue - valuePadding,
        maxValue: maxValue + valuePadding,
      ),
      child: Container(),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<Reading> readings;
  final double minValue;
  final double maxValue;

  _ChartPainter({
    required this.readings,
    required this.minValue,
    required this.maxValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (readings.isEmpty) return;

    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = Colors.blue.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final valueRange = maxValue - minValue;
    final width = size.width;
    final height = size.height;
    const padding = 40.0;

    final plotWidth = width - padding * 2;
    final plotHeight = height - padding * 2;

    // Draw grid lines
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 1;

    for (int i = 0; i <= 5; i++) {
      final y = padding + (plotHeight / 5) * i;
      canvas.drawLine(
        Offset(padding, y),
        Offset(width - padding, y),
        gridPaint,
      );
    }

    // Limit chart to last 100 points for performance
    // API already limits to 100, but protect against future changes
    final chartReadings = readings.length > 100 
        ? readings.sublist(readings.length - 100) 
        : readings;

    // Draw data points
    for (int i = 0; i < chartReadings.length; i++) {
      final reading = chartReadings[i];
      final x = padding + (plotWidth / (readings.length - 1)) * i;
      final normalizedValue = (reading.value - minValue) / valueRange;
      final y = padding + plotHeight - (normalizedValue * plotHeight);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, height - padding);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      // Draw point
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = Colors.blue);
    }

    // Close fill path
    fillPath.lineTo(width - padding, height - padding);
    fillPath.close();

    // Draw fill
    canvas.drawPath(fillPath, fillPaint);

    // Draw line
    canvas.drawPath(path, paint);

    // Draw labels
    final textStyle = TextStyle(color: Colors.grey[700], fontSize: 10);
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // Y-axis labels
    for (int i = 0; i <= 5; i++) {
      final value = minValue + (valueRange / 5) * (5 - i);
      textPainter.text = TextSpan(
        text: value.toStringAsFixed(3),
        style: textStyle,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(5, padding + (plotHeight / 5) * i - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_ChartPainter oldDelegate) {
    return oldDelegate.readings != readings ||
        oldDelegate.minValue != minValue ||
        oldDelegate.maxValue != maxValue;
  }
}
