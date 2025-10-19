import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';

import '../../../../shared/services/yolo_detection_service.dart';

// YOLO detection service provider
final yoloDetectionServiceProvider = Provider<YoloDetectionService>((ref) {
  return YoloDetectionService();
});

// Detection state provider
final detectionStateProvider = StateNotifierProvider<DetectionNotifier, DetectionState>((ref) {
  return DetectionNotifier(ref.read(yoloDetectionServiceProvider));
});

// Real-time detection stream provider
final realTimeDetectionProvider = StreamProvider<List<DetectionResult>>((ref) {
  final notifier = ref.read(detectionStateProvider.notifier);
  return notifier.detectionStream;
});

// Detection state management
enum DetectionStatus { initial, initializing, ready, detecting, error }

class DetectionState {
  final DetectionStatus status;
  final String? errorMessage;

  const DetectionState(this.status, {this.errorMessage});

  static const DetectionState initial = DetectionState(DetectionStatus.initial);
  static const DetectionState initializing = DetectionState(DetectionStatus.initializing);
  static const DetectionState ready = DetectionState(DetectionStatus.ready);
  static const DetectionState detecting = DetectionState(DetectionStatus.detecting);

  factory DetectionState.error(String message) => DetectionState(DetectionStatus.error, errorMessage: message);
}

class DetectionNotifier extends StateNotifier<DetectionState> {
  final YoloDetectionService _detectionService;

  // Stream controller for real-time detections
  late Stream<List<DetectionResult>> _detectionStream;

  DetectionNotifier(this._detectionService) : super(DetectionState.initial) {
    _detectionStream = Stream.empty();
  }

  /// Get the detection stream
  Stream<List<DetectionResult>> get detectionStream => _detectionStream;

  /// Initialize the YOLO detection service
  Future<void> initializeDetection() async {
    if (state.status != DetectionStatus.initial) return;

    state = DetectionState.initializing;

    try {
      await _detectionService.initialize();
      state = DetectionState.ready;
    } catch (e) {
      state = DetectionState.error('Failed to initialize detection: ${e.toString()}');
    }
  }

  /// Start real-time detection on camera frames
  Future<void> startDetection() async {
    if (!_detectionService.isInitialized) {
      await initializeDetection();
    }

    if (state.status != DetectionStatus.ready) return;

    state = DetectionState.detecting;
  }

  /// Process a single camera frame for detection
  Future<List<DetectionResult>?> processFrame(CameraImage cameraImage) async {
    if (!_detectionService.isInitialized || state.status != DetectionStatus.detecting) {
      return null;
    }

    try {
      return await _detectionService.detectObjects(cameraImage);
    } catch (e) {
      print('Error processing frame: $e');
      return null;
    }
  }

  /// Stop detection
  void stopDetection() {
    if (state.status == DetectionStatus.detecting) {
      state = DetectionState.ready;
    }
  }

  /// Reset detection state
  void reset() {
    state = DetectionState.initial;
  }

  /// Dispose resources
  @override
  void dispose() {
    _detectionService.dispose();
    super.dispose();
  }
}
