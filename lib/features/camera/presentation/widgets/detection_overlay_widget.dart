import 'package:flutter/material.dart';
import '../../../../shared/services/yolo_detection_service.dart';

/// Widget to display detection results as overlay on camera view
class DetectionOverlayWidget extends StatelessWidget {
  final List<DetectionResult> detections;
  final Size cameraViewSize;

  const DetectionOverlayWidget({
    super.key,
    required this.detections,
    required this.cameraViewSize,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: cameraViewSize,
      painter: DetectionPainter(detections),
    );
  }
}

/// Custom painter for drawing detection bounding boxes
class DetectionPainter extends CustomPainter {
  final List<DetectionResult> detections;

  DetectionPainter(this.detections);

  @override
  void paint(Canvas canvas, Size size) {
    for (final detection in detections) {
      _drawBoundingBox(canvas, size, detection);
    }
  }

  void _drawBoundingBox(Canvas canvas, Size size, DetectionResult detection) {
    // Calculate actual position on screen
    final rect = Rect.fromLTWH(
      detection.x,
      detection.y,
      detection.width,
      detection.height,
    );

    // Draw bounding box
    final paint = Paint()
      ..color = _getColorForLabel(detection.label)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawRect(rect, paint);

    // Draw label background
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${detection.label} ${(detection.confidence * 100).toStringAsFixed(1)}%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    final labelRect = Rect.fromLTWH(
      detection.x,
      detection.y - textPainter.height - 4,
      textPainter.width + 8,
      textPainter.height + 4,
    );

    final labelPaint = Paint()..color = _getColorForLabel(detection.label).withOpacity(0.8);

    canvas.drawRect(labelRect, labelPaint);

    // Draw label text
    textPainter.paint(
      canvas,
      Offset(detection.x + 4, detection.y - textPainter.height - 2),
    );
  }

  Color _getColorForLabel(String label) {
    // Return different colors for different labels
    switch (label.toLowerCase()) {
      case 'person':
        return Colors.green;
      case 'car':
        return Colors.blue;
      case 'truck':
        return Colors.orange;
      case 'bus':
        return Colors.purple;
      case 'motorcycle':
        return Colors.red;
      case 'bicycle':
        return Colors.yellow;
      case 'traffic light':
        return Colors.cyan;
      case 'stop sign':
        return Colors.red;
      default:
        return Colors.white;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate != this;
  }
}
