import 'package:ai_video_creator_editor/components/crop/optimized_crop_preview.dart';
import 'package:ai_video_creator_editor/controllers/crop_state_manager.dart';
import 'package:ai_video_creator_editor/controllers/video_controller.dart';
import 'package:ai_video_creator_editor/utils/performance_monitor.dart';
import 'package:flutter/material.dart';

/// Integration example showing how to use optimized crop components
class OptimizedCropIntegration extends StatefulWidget {
  const OptimizedCropIntegration({
    super.key,
    required this.videoController,
  });

  final VideoEditorController videoController;

  @override
  State<OptimizedCropIntegration> createState() =>
      _OptimizedCropIntegrationState();
}

class _OptimizedCropIntegrationState extends State<OptimizedCropIntegration>
    with PerformanceMonitoringMixin {
  late CropStateManager _cropStateManager;
  bool _showPerformanceOverlay = false;
  bool _enableOptimizations = true;

  // Performance metrics
  final ValueNotifier<Map<String, dynamic>> _performanceStats =
      ValueNotifier({});

  @override
  void initState() {
    super.initState();
    _cropStateManager = CropStateManager(widget.videoController);

    // Start performance monitoring
    _startPerformanceMonitoring();

    super.initState();
  }

  @override
  void dispose() {
    _cropStateManager.dispose();
    _performanceStats.dispose();
    super.dispose();
  }

  void _startPerformanceMonitoring() {
    // Update performance stats every second
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _updatePerformanceStats();
        _startPerformanceMonitoring();
      }
    });
  }

  void _updatePerformanceStats() {
    monitorSyncOperation('_updatePerformanceStats', () {
      _performanceStats.value = PerformanceMonitor.getOverallStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Optimized Crop Preview'),
        actions: [
          // Performance toggle
          IconButton(
            icon: Icon(
                _showPerformanceOverlay ? Icons.speed : Icons.info_outline),
            onPressed: () {
              setState(() {
                _showPerformanceOverlay = !_showPerformanceOverlay;
              });
            },
            tooltip: 'Toggle Performance Overlay',
          ),
          // Optimization toggle
          IconButton(
            icon: Icon(_enableOptimizations ? Icons.tune : Icons.tune_outlined),
            onPressed: () {
              setState(() {
                _enableOptimizations = !_enableOptimizations;
              });
            },
            tooltip: 'Toggle Optimizations',
          ),
        ],
      ),
      body: Column(
        children: [
          // Performance overlay
          if (_showPerformanceOverlay) _buildPerformanceOverlay(),

          // Main crop preview
          Expanded(
            child: _enableOptimizations
                ? _buildOptimizedCropPreview()
                : _buildStandardCropPreview(),
          ),

          // Control panel
          _buildControlPanel(),
        ],
      ),
    );
  }

  Widget _buildPerformanceOverlay() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.black87,
      child: ValueListenableBuilder(
        valueListenable: _performanceStats,
        builder: (_, Map<String, dynamic> stats, __) {
          final rating = stats['performanceRating'] ?? 'N/A';
          final totalOps = stats['totalOperations'] ?? 0;
          final slowOps = stats['totalSlowOperations'] ?? 0;
          final slowPercentage = stats['overallSlowPercentage'] ?? '0.0%';

          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Performance Rating: $rating',
                      style: TextStyle(
                        color: _getRatingColor(rating),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Operations: $totalOps | Slow: $slowOps ($slowPercentage)',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () {
                  PerformanceMonitor.clearStats();
                  _updatePerformanceStats();
                },
                tooltip: 'Clear Stats',
              ),
            ],
          );
        },
      ),
    );
  }

  Color _getRatingColor(String rating) {
    switch (rating) {
      case 'Excellent':
        return Colors.green;
      case 'Good':
        return Colors.lightGreen;
      case 'Fair':
        return Colors.orange;
      case 'Poor':
        return Colors.red;
      case 'Critical':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  Widget _buildOptimizedCropPreview() {
    return OptimizedCropPreview(
      controller: widget.videoController,
      overlayText: 'Optimized Preview',
      showGrid: true,
      margin: const EdgeInsets.all(16),
      enableHapticFeedback: true,
      animationDuration: const Duration(milliseconds: 200),
      animationCurve: Curves.easeOutCubic,
    );
  }

  Widget _buildStandardCropPreview() {
    // This would be your existing crop preview implementation
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Text(
          'Standard Crop Preview\n(Not Optimized)',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Optimization Controls',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // Performance metrics
          ValueListenableBuilder(
            valueListenable: _performanceStats,
            builder: (_, Map<String, dynamic> stats, __) {
              final operations = stats['operations'] as List<dynamic>? ?? [];

              return Column(
                children: [
                  if (operations.isNotEmpty) ...[
                    const Text('Operation Performance:',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    ...operations.map((op) {
                      final opStats = PerformanceMonitor.getOperationStats(op);
                      final rating = opStats['performanceRating'] as String;
                      final count = opStats['totalOperations'] as int;
                      final slowCount = opStats['slowOperations'] as int;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$op: $count ops',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getRatingColor(rating),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                rating,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10),
                              ),
                            ),
                            if (slowCount > 0)
                              Text(
                                ' ($slowCount slow)',
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 10,
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          // Optimization tips
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '💡 Optimization Tips:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                const SizedBox(height: 4),
                const Text(
                  '• Use RepaintBoundary for complex widgets\n'
                  '• Cache expensive calculations\n'
                  '• Throttle gesture events to 60fps\n'
                  '• Monitor performance in real-time',
                  style: TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Usage example for the optimized crop system
class OptimizedCropUsageExample extends StatelessWidget {
  const OptimizedCropUsageExample({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.crop, size: 64, color: Colors.blue),
            SizedBox(height: 16),
            Text(
              'Optimized Crop System',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Ready for integration with your video editor',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 24),
            Text(
              'Key Features:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text('• Performance monitoring & FPS tracking'),
            Text('• Gesture optimization & haptic feedback'),
            Text('• Transform caching & smooth animations'),
            Text('• Unified coordinate system'),
            Text('• Real-time performance metrics'),
          ],
        ),
      ),
    );
  }
}
