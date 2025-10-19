import 'package:flutter/material.dart';
import '../providers/camera_providers.dart';

/// Widget that displays the current analysis status and detection information
class AnalysisStatusWidget extends StatelessWidget {
  final CameraState cameraState;
  final int detectionCount;

  const AnalysisStatusWidget({
    super.key,
    required this.cameraState,
    required this.detectionCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getStatusColor(),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status indicator
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getStatusColor(),
            ),
          ),

          const SizedBox(width: 12),

          // Status text
          Expanded(
            child: Text(
              _getStatusText(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Detection count (only show when camera is ready)
          if (cameraState == const CameraState.ready() && detectionCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$detectionCount detected',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    return cameraState.when(
      initial: () => Colors.grey,
      initializing: () => Colors.orange,
      ready: () => Colors.green,
      error: (message) => Colors.red,
      permissionDenied: () => Colors.orange,
    );
  }

  String _getStatusText() {
    return cameraState.when(
      initial: () => 'Camera not initialized',
      initializing: () => 'Initializing camera...',
      ready: () => 'Camera ready',
      error: (message) => 'Error: $message',
      permissionDenied: () => 'Camera permission needed',
    );
  }
}
