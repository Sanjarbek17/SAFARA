import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

// Detection state provider - simplified for YOLOView integration
final detectionStateProvider = StateNotifierProvider<DetectionNotifier, DetectionState>((ref) {
  return DetectionNotifier();
});

// Current detections provider
final currentDetectionsProvider = StateProvider<List<YOLOResult>>((ref) => []);

// Detection state management
enum DetectionStatus { idle, detecting, error }

class DetectionState {
  final DetectionStatus status;
  final int detectionCount;
  final String? errorMessage;

  const DetectionState({
    required this.status,
    this.detectionCount = 0,
    this.errorMessage,
  });

  static const DetectionState idle = DetectionState(status: DetectionStatus.idle);
  static const DetectionState detecting = DetectionState(status: DetectionStatus.detecting);

  factory DetectionState.error(String message) => DetectionState(
    status: DetectionStatus.error,
    errorMessage: message,
  );

  DetectionState copyWith({
    DetectionStatus? status,
    int? detectionCount,
    String? errorMessage,
  }) {
    return DetectionState(
      status: status ?? this.status,
      detectionCount: detectionCount ?? this.detectionCount,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class DetectionNotifier extends StateNotifier<DetectionState> {
  DetectionNotifier() : super(DetectionState.idle);

  /// Update detections from YOLOView
  void updateDetections(List<YOLOResult> detections) {
    state = state.copyWith(
      status: DetectionStatus.detecting,
      detectionCount: detections.length,
    );
  }

  /// Handle error
  void setError(String message) {
    state = DetectionState.error(message);
  }

  /// Reset to idle
  void reset() {
    state = DetectionState.idle;
  }
}
