import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

/// Detection result data class
class DetectionResult {
  final String label;
  final double confidence;
  final double x;
  final double y;
  final double width;
  final double height;

  DetectionResult({
    required this.label,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// Create DetectionResult from YOLOResult
  factory DetectionResult.fromYOLOResult(YOLOResult yoloResult) {
    return DetectionResult(
      label: yoloResult.className,
      confidence: yoloResult.confidence,
      x: yoloResult.boundingBox.left,
      y: yoloResult.boundingBox.top,
      width: yoloResult.boundingBox.width,
      height: yoloResult.boundingBox.height,
    );
  }
}

/// Service for handling YOLO object detection
class YoloDetectionService {
  // Note: Using built-in model for now. Replace with your converted model later:
  // static const String _modelPath = 'assets/models/best_copy.tflite'; // For Android
  // static const String _modelPath = 'assets/models/best_copy.mlmodel'; // For iOS

  YOLO? _yolo;
  bool _isInitialized = false;

  /// Initialize the YOLO detector with the model
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Use your custom TensorFlow Lite model
      _yolo = YOLO(
        modelPath: 'best_float16.tflite', // Model in Android assets folder
        task: YOLOTask.detect,
      );

      // Load the model
      await _yolo!.loadModel();

      _isInitialized = true;
      print('YOLO detector initialized successfully with best_float16.tflite model');
    } catch (e) {
      print('Failed to initialize YOLO detector: $e');
      rethrow;
    }
  }

  /// Check if the detector is initialized
  bool get isInitialized => _isInitialized;

  /// Detect objects in camera image
  Future<List<DetectionResult>?> detectObjects(CameraImage cameraImage) async {
    if (!_isInitialized || _yolo == null) {
      throw StateError('YOLO detector not initialized. Call initialize() first.');
    }

    try {
      // Convert CameraImage to proper format for YOLO
      final Uint8List imageBytes = _convertCameraImageToBytes(cameraImage);

      // Run YOLO prediction
      final results = await _yolo!.predict(imageBytes);

      // Extract detections from results
      final boxes = results['boxes'] as List<dynamic>? ?? [];

      // Convert to DetectionResult objects
      return boxes.map((box) {
        return DetectionResult(
          label: box['class'] as String,
          confidence: (box['confidence'] as num).toDouble(),
          x: (box['x'] as num).toDouble(),
          y: (box['y'] as num).toDouble(),
          width: (box['width'] as num).toDouble(),
          height: (box['height'] as num).toDouble(),
        );
      }).toList();
    } catch (e) {
      print('Error during object detection: $e');
      return null;
    }
  }

  /// Convert CameraImage to Uint8List format expected by YOLO
  Uint8List _convertCameraImageToBytes(CameraImage cameraImage) {
    try {
      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        return _convertYUV420ToRGB(cameraImage);
      } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
        return _convertBGRA8888ToRGB(cameraImage);
      } else {
        // Fallback: just return the first plane bytes
        return cameraImage.planes[0].bytes;
      }
    } catch (e) {
      print('Error converting camera image: $e');
      // Fallback: return first plane bytes
      return cameraImage.planes[0].bytes;
    }
  }

  /// Convert YUV420 to RGB format
  Uint8List _convertYUV420ToRGB(CameraImage cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;

    final int uvRowStride = cameraImage.planes[1].bytesPerRow;
    final int uvPixelStride = cameraImage.planes[1].bytesPerPixel ?? 1;

    final Uint8List rgbBytes = Uint8List(width * height * 3);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int uvIndex = uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
        final int index = y * width + x;

        final int yp = cameraImage.planes[0].bytes[index];
        final int up = cameraImage.planes[1].bytes[uvIndex];
        final int vp = cameraImage.planes[2].bytes[uvIndex];

        // YUV to RGB conversion
        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91).round().clamp(0, 255);
        int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);

        final int rgbIndex = index * 3;
        rgbBytes[rgbIndex] = r;
        rgbBytes[rgbIndex + 1] = g;
        rgbBytes[rgbIndex + 2] = b;
      }
    }

    return rgbBytes;
  }

  /// Convert BGRA8888 to RGB format
  Uint8List _convertBGRA8888ToRGB(CameraImage cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;
    final Uint8List bytes = cameraImage.planes[0].bytes;

    final Uint8List rgbBytes = Uint8List(width * height * 3);

    for (int i = 0; i < width * height; i++) {
      final int bgraIndex = i * 4;
      final int rgbIndex = i * 3;

      rgbBytes[rgbIndex] = bytes[bgraIndex + 2]; // R
      rgbBytes[rgbIndex + 1] = bytes[bgraIndex + 1]; // G
      rgbBytes[rgbIndex + 2] = bytes[bgraIndex]; // B
    }

    return rgbBytes;
  }

  /// Dispose the detector and clean up resources
  void dispose() {
    if (_isInitialized) {
      try {
        _yolo?.dispose();
      } catch (e) {
        print('Error disposing YOLO detector: $e');
      }
      _yolo = null;
      _isInitialized = false;
      print('YOLO detector disposed');
    }
  }
}
