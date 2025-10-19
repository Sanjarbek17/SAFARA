import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
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
  static const String _modelPath = 'assets/models/best copy.pt';
  
  YOLO? _yolo;
  bool _isInitialized = false;
  File? _modelFile;

  /// Initialize the YOLO detector with the model
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load the model from assets and copy to temporary location
      final ByteData data = await rootBundle.load(_modelPath);
      final Uint8List bytes = data.buffer.asUint8List();
      
      // Create temporary file for the model
      final Directory tempDir = Directory.systemTemp;
      _modelFile = File('${tempDir.path}/best_copy.pt');
      await _modelFile!.writeAsBytes(bytes);
      
      // Initialize YOLO with the model
      _yolo = YOLO(
        modelPath: _modelFile!.path,
        task: YOLOTask.detect,
        useGpu: false, // Set to true if you want GPU acceleration
      );
      
      // Load the model
      await _yolo!.loadModel();
      
      _isInitialized = true;
      print('YOLO detector initialized successfully with model: ${_modelFile!.path}');
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
      // Convert CameraImage to the format required by YOLO
      final img.Image? image = _convertCameraImage(cameraImage);
      if (image == null) return null;

      // Convert image to bytes (PNG format)
      final Uint8List imageBytes = Uint8List.fromList(img.encodePng(image));

      // Perform YOLO detection
      final Map<String, dynamic> results = await _yolo!.predict(
        imageBytes,
        confidenceThreshold: 0.5, // Adjust confidence threshold as needed
        iouThreshold: 0.4, // Adjust IoU threshold as needed
      );

      // Parse results and convert to DetectionResult objects
      final List<DetectionResult> detections = [];
      
      if (results.containsKey('results') && results['results'] is List) {
        final List<dynamic> resultsList = results['results'];
        
        for (final dynamic result in resultsList) {
          if (result is Map<String, dynamic>) {
            try {
              final YOLOResult yoloResult = YOLOResult.fromMap(result);
              detections.add(DetectionResult.fromYOLOResult(yoloResult));
            } catch (e) {
              print('Error parsing YOLO result: $e');
              continue;
            }
          }
        }
      }

      return detections;
    } catch (e) {
      print('Error during object detection: $e');
      return null;
    }
  }

  /// Convert CameraImage to img.Image format
  img.Image? _convertCameraImage(CameraImage cameraImage) {
    try {
      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        return _convertYUV420ToImage(cameraImage);
      } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
        return _convertBGRA8888ToImage(cameraImage);
      } else {
        print('Unsupported image format: ${cameraImage.format.group}');
        return null;
      }
    } catch (e) {
      print('Error converting camera image: $e');
      return null;
    }
  }

  /// Convert YUV420 format to img.Image
  img.Image? _convertYUV420ToImage(CameraImage cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;

    final int uvRowStride = cameraImage.planes[1].bytesPerRow;
    final int uvPixelStride = cameraImage.planes[1].bytesPerPixel ?? 1;

    final img.Image image = img.Image(width, height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int uvIndex = uvPixelStride * (x ~/ 2).floor() + uvRowStride * (y ~/ 2).floor();
        final int index = y * width + x;

        final yp = cameraImage.planes[0].bytes[index];
        final up = cameraImage.planes[1].bytes[uvIndex];
        final vp = cameraImage.planes[2].bytes[uvIndex];

        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91).round().clamp(0, 255);
        int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);

        image.setPixel(x, y, img.Color.fromRgb(r, g, b));
      }
    }

    return image;
  }

  /// Convert BGRA8888 format to img.Image
  img.Image? _convertBGRA8888ToImage(CameraImage cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;
    final Uint8List bytes = cameraImage.planes[0].bytes;

    final img.Image image = img.Image(width, height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int index = (y * width + x) * 4;
        final int b = bytes[index];
        final int g = bytes[index + 1];
        final int r = bytes[index + 2];
        final int a = bytes[index + 3];

        image.setPixel(x, y, img.Color.fromRgba(r, g, b, a));
      }
    }

    return image;
  }

  /// Dispose the detector and clean up resources
  void dispose() {
    if (_isInitialized) {
      try {
        _yolo?.dispose();
        _modelFile?.deleteSync();
      } catch (e) {
        print('Error disposing YOLO detector: $e');
      }
      _yolo = null;
      _modelFile = null;
      _isInitialized = false;
      print('YOLO detector disposed');
    }
  }
}