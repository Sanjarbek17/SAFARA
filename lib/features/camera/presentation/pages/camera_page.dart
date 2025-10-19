import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'dart:async';

import '../providers/camera_providers.dart';
import '../providers/detection_providers.dart';
import '../widgets/camera_view_widget.dart';
import '../widgets/analysis_status_widget.dart';
import '../widgets/detection_overlay_widget.dart';
import '../../../../shared/services/yolo_detection_service.dart';

class CameraPage extends ConsumerStatefulWidget {
  const CameraPage({super.key});

  @override
  ConsumerState<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends ConsumerState<CameraPage> {
  late CameraController _cameraController;
  bool _isCameraInitialized = false;
  bool _isDetectionActive = false;
  List<DetectionResult> _currentDetections = [];
  Timer? _detectionTimer;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _cameraController = CameraController(
          cameras[0],
          ResolutionPreset.high,
          enableAudio: false,
        );

        await _cameraController.initialize();

        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });

          await ref.read(cameraStateProvider.notifier).initializeCamera();
          await ref.read(detectionStateProvider.notifier).initializeDetection();
        }
      }
    } catch (e) {
      print('Error initializing camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera initialization failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startDetection() async {
    if (!_isCameraInitialized || _isDetectionActive) return;

    setState(() {
      _isDetectionActive = true;
    });

    await ref.read(detectionStateProvider.notifier).startDetection();

    // Start processing frames at regular intervals
    _detectionTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (!_isDetectionActive || !_cameraController.value.isStreamingImages) return;

      try {
        // Capture current frame
        _cameraController.startImageStream((CameraImage image) async {
          if (!_isDetectionActive) return;

          final detections = await ref.read(detectionStateProvider.notifier).processFrame(image);

          if (detections != null && mounted) {
            setState(() {
              _currentDetections = detections;
            });
          }
        });

        // Stop image stream after processing
        await Future.delayed(const Duration(milliseconds: 100));
        await _cameraController.stopImageStream();
      } catch (e) {
        print('Error during detection: $e');
      }
    });
  }

  void _stopDetection() {
    if (!_isDetectionActive) return;

    setState(() {
      _isDetectionActive = false;
      _currentDetections = [];
    });

    _detectionTimer?.cancel();
    _detectionTimer = null;

    ref.read(detectionStateProvider.notifier).stopDetection();

    try {
      if (_cameraController.value.isStreamingImages) {
        _cameraController.stopImageStream();
      }
    } catch (e) {
      print('Error stopping image stream: $e');
    }
  }

  String _getDetectionStateText(DetectionState detectionState) {
    switch (detectionState.status) {
      case DetectionStatus.initial:
        return 'Detection Not Started';
      case DetectionStatus.initializing:
        return 'Initializing YOLO...';
      case DetectionStatus.ready:
        return 'Ready to Detect';
      case DetectionStatus.detecting:
        return 'Detecting Objects';
      case DetectionStatus.error:
        return 'Error: ${detectionState.errorMessage}';
    }
  }

  @override
  void dispose() {
    _stopDetection();
    if (_isCameraInitialized) {
      _cameraController.dispose();
    }
    ref.read(cameraStateProvider.notifier).disposeCamera();
    ref.read(detectionStateProvider.notifier).dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraStateProvider);
    final detectionState = ref.watch(detectionStateProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.7),
        foregroundColor: Colors.white,
        title: const Text(
          'YOLO Camera Detection',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
        actions: [
          // Detection toggle button
          IconButton(
            onPressed: () {
              if (_isDetectionActive) {
                _stopDetection();
              } else {
                _startDetection();
              }
            },
            icon: Icon(
              _isDetectionActive ? Icons.pause : Icons.play_arrow,
              color: _isDetectionActive ? Colors.red : Colors.green,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_isCameraInitialized)
            Stack(
              children: [
                CameraViewWidget(cameraController: _cameraController),
                // Detection overlay
                if (_currentDetections.isNotEmpty)
                  Positioned.fill(
                    child: DetectionOverlayWidget(
                      detections: _currentDetections,
                      cameraViewSize: MediaQuery.of(context).size,
                    ),
                  ),
              ],
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // Status information
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                AnalysisStatusWidget(
                  cameraState: cameraState,
                  detectionCount: _currentDetections.length,
                ),
                const SizedBox(height: 8),
                // Detection state indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isDetectionActive ? Icons.visibility : Icons.visibility_off,
                        color: _isDetectionActive ? Colors.green : Colors.grey,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getDetectionStateText(detectionState),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Detection results panel
          if (_currentDetections.isNotEmpty)
            Positioned(
              bottom: 120,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detected Objects (${_currentDetections.length}):',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...(_currentDetections
                        .take(3)
                        .map(
                          (detection) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• ${detection.label} (${(detection.confidence * 100).toStringAsFixed(1)}%)',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        )
                        .toList()),
                    if (_currentDetections.length > 3)
                      Text(
                        '... and ${_currentDetections.length - 3} more',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            ),

          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Voice commands coming soon!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.mic, color: Colors.white),
                ),

                GestureDetector(
                  onTap: () {
                    if (_isDetectionActive) {
                      _stopDetection();
                    } else {
                      _startDetection();
                    }
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isDetectionActive ? Colors.red : Colors.green,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isDetectionActive ? Icons.stop : Icons.play_arrow,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),

                FloatingActionButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Map view coming soon!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.map, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
