import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

/// Custom painter for drawing YOLO detection bounding boxes
/// Use this instead of built-in YOLOView overlays if they have rendering issues
class DetectionOverlayPainter extends CustomPainter {
  final List<YOLOResult> detections;

  DetectionOverlayPainter({
    required this.detections,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (detections.isEmpty) return;

    for (var detection in detections) {
      final box = detection.boundingBox;

      // Better detection: Check if width/height are in pixel space (>1)
      // If width/height are pixels, then left/top are also pixels (not normalized)
      final isPixelSpace = box.width > 1.0 || box.height > 1.0;

      double left, top, boxWidth, boxHeight;

      if (!isPixelSpace) {
        // Case 1: All values are normalized (0-1)
        left = box.left * size.width;
        top = box.top * size.height;
        boxWidth = box.width * size.width;
        boxHeight = box.height * size.height;
      } else {
        // Case 2: All coordinates are in pixel space
        // The coordinates are already in screen pixel space
        // Box is appearing slightly UP and RIGHT of actual object
        // So we need to shift it DOWN (positive Y) and LEFT (negative X)
        const offsetX = -10.0; // Negative = move left
        const offsetY = 10.0; // Positive = move down

        left = box.left + offsetX;
        top = box.top + offsetY;
        boxWidth = box.width;
        boxHeight = box.height;
      }

      // Debug first detection
      if (detection == detections.first) {
        print('DEBUG - Canvas: ${size.width}x${size.height}');
        print('DEBUG - Original: left=${box.left}, top=${box.top}, w=${box.width}, h=${box.height}');
        print('DEBUG - With offset: left=$left, top=$top, w=$boxWidth, h=$boxHeight');
        print('DEBUG - Mode: ${isPixelSpace ? "Pixel space (offset: -10x, +10y)" : "Normalized"}');
      }

      final rect = Rect.fromLTWH(left, top, boxWidth, boxHeight);

      // Draw bounding box
      final paint = Paint()
        ..color = Colors.green.withOpacity(0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      canvas.drawRect(rect, paint);

      // Draw filled background for label
      final labelPaint = Paint()
        ..color = Colors.green.withOpacity(0.9)
        ..style = PaintingStyle.fill;

      final label = '${detection.className} ${(detection.confidence * 100).toStringAsFixed(0)}%';
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      // Position label above the box (or inside if near top)
      final labelTop = top > textPainter.height + 8 ? top - textPainter.height - 4 : top + 4;

      final labelRect = Rect.fromLTWH(
        left,
        labelTop,
        textPainter.width + 8,
        textPainter.height + 4,
      );

      canvas.drawRect(labelRect, labelPaint);
      textPainter.paint(canvas, Offset(left + 4, labelTop + 2));
    }
  }

  @override
  bool shouldRepaint(DetectionOverlayPainter oldDelegate) {
    return detections != oldDelegate.detections;
  }
}

/// Widget wrapper for the detection overlay
class DetectionOverlay extends StatelessWidget {
  final List<YOLOResult> detections;

  const DetectionOverlay({
    super.key,
    required this.detections,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: DetectionOverlayPainter(
        detections: detections,
      ),
      child: Container(),
    );
  }
}
