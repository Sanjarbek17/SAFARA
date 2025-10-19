import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';

import '../providers/camera_providers.dart';
import '../widgets/camera_view_widget.dart';
import '../widgets/analysis_status_widget.dart';

class CameraPage extends ConsumerStatefulWidget {
  const CameraPage({super.key});

  @override
  ConsumerState<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends ConsumerState<CameraPage> {
  late CameraController _cameraController;
  bool _isCameraInitialized = false;

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

  @override
  void dispose() {
    if (_isCameraInitialized) {
      _cameraController.dispose();
    }
    ref.read(cameraStateProvider.notifier).disposeCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraStateProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.7),
        foregroundColor: Colors.white,
        title: const Text(
          'Camera View',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          if (_isCameraInitialized)
            CameraViewWidget(cameraController: _cameraController)
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: AnalysisStatusWidget(
              cameraState: cameraState,
              detectionCount: 0,
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
                    final notifier = ref.read(cameraStateProvider.notifier);

                    cameraState.when(
                      initial: () => notifier.initializeCamera(),
                      initializing: () {},
                      ready: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Camera is ready!'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      error: (message) => notifier.reset(),
                      permissionDenied: () => notifier.requestPermission(),
                    );
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cameraState.when(
                        initial: () => Colors.grey,
                        initializing: () => Colors.orange,
                        ready: () => Colors.green,
                        error: (message) => Colors.red,
                        permissionDenied: () => Colors.orange,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      cameraState.when(
                        initial: () => Icons.camera_alt,
                        initializing: () => Icons.hourglass_empty,
                        ready: () => Icons.check,
                        error: (message) => Icons.refresh,
                        permissionDenied: () => Icons.security,
                      ),
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
