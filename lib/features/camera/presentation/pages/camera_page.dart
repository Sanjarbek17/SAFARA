import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:ultralytics_yolo/widgets/yolo_controller.dart';

class CameraPage extends ConsumerStatefulWidget {
  const CameraPage({super.key});

  @override
  ConsumerState<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends ConsumerState<CameraPage> {
  final YOLOViewController _yoloController = YOLOViewController();
  List<YOLOResult> _currentDetections = [];
  double _fps = 0.0;
  bool _isModelLoaded = false;

  @override
  void initState() {
    super.initState();
    // Configure YOLO thresholds
    _yoloController.setThresholds(
      confidenceThreshold: 0.5,
      iouThreshold: 0.45,
      numItemsThreshold: 30,
    );
  }

  void _handleDetectionResults(List<YOLOResult> results) {
    if (mounted) {
      setState(() {
        _currentDetections = results;
        _isModelLoaded = true;
      });
    }
  }

  void _handlePerformanceMetrics(YOLOPerformanceMetrics metrics) {
    if (mounted) {
      setState(() {
        _fps = metrics.fps;
      });
    }
  }

  @override
  void dispose() {
    // YOLOView handles its own disposal
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          // FPS indicator
          if (_fps > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${_fps.toStringAsFixed(1)} FPS',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // YOLOView handles camera and detection automatically
          YOLOView(
            modelPath: 'best_float16.tflite',
            task: YOLOTask.detect,
            controller: _yoloController,
            onResult: _handleDetectionResults,
            onPerformanceMetrics: _handlePerformanceMetrics,
            confidenceThreshold: 0.5,
            iouThreshold: 0.45,
            showNativeUI: false,
            showOverlays: false, // Disable to avoid double overlays
            cameraResolution: '720p',
          ),

          // Status information overlay
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                // Status indicator
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
                        _isModelLoaded ? Icons.check_circle : Icons.pending,
                        color: _isModelLoaded ? Colors.green : Colors.orange,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isModelLoaded ? 'Model Loaded • Detecting' : 'Loading Model...',
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
                  border: Border.all(color: Colors.green.withOpacity(0.3), width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detected Objects (${_currentDetections.length}):',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...(_currentDetections
                        .take(5)
                        .map(
                          (detection) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• ${detection.className} (${(detection.confidence * 100).toStringAsFixed(1)}%)',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        )
                        .toList()),
                    if (_currentDetections.length > 5)
                      Text(
                        '... and ${_currentDetections.length - 5} more',
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

          // Bottom action buttons
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

                // Camera switch button
                FloatingActionButton.extended(
                  onPressed: () async {
                    try {
                      await _yoloController.switchCamera();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Camera switched'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to switch camera: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  backgroundColor: Colors.green,
                  icon: const Icon(Icons.cameraswitch, color: Colors.white),
                  label: const Text(
                    'Switch',
                    style: TextStyle(color: Colors.white),
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
                  backgroundColor: Colors.orange,
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
