import 'package:ai_video_creator_editor/components/crop/crop_preview_mixin.dart';
import 'package:ai_video_creator_editor/components/crop/enhanced_gesture_handler.dart';
import 'package:ai_video_creator_editor/components/crop/optimized_transform.dart';
import 'package:ai_video_creator_editor/components/crop/crop_grid.dart';
import 'package:ai_video_creator_editor/controllers/crop_state_manager.dart';
import 'package:ai_video_creator_editor/controllers/video_controller.dart';
import 'package:ai_video_creator_editor/screens/project/models/transform_data.dart';
import 'package:ai_video_creator_editor/utils/performance_monitor.dart';
import 'package:flutter/material.dart';

/// Optimized crop preview widget with enhanced performance and smooth interactions
class OptimizedCropPreview extends StatefulWidget {
  const OptimizedCropPreview({
    super.key,
    required this.controller,
    required this.overlayText,
    this.showGrid = false,
    this.margin = EdgeInsets.zero,
    this.enableHapticFeedback = true,
    this.animationDuration = const Duration(milliseconds: 200),
    this.animationCurve = Curves.easeOutCubic,
  });

  final VideoEditorController controller;
  final String overlayText;
  final bool showGrid;
  final EdgeInsets margin;
  final bool enableHapticFeedback;
  final Duration animationDuration;
  final Curve animationCurve;

  @override
  State<OptimizedCropPreview> createState() => _OptimizedCropPreviewState();
}

class _OptimizedCropPreviewState extends State<OptimizedCropPreview>
    with CropPreviewMixin, PerformanceMonitoringMixin {
  late CropStateManager _cropStateManager;
  late VideoEditorController _controller;

  // Performance tracking
  final ValueNotifier<double> _fpsCounter = ValueNotifier(0.0);
  final ValueNotifier<String> _performanceStatus = ValueNotifier('Ready');

  // Animation state
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _cropStateManager = CropStateManager(_controller);

    // Initialize performance monitoring
    _startPerformanceMonitoring();

    super.initState();
  }

  @override
  void dispose() {
    _cropStateManager.dispose();
    _fpsCounter.dispose();
    _performanceStatus.dispose();
    super.dispose();
  }

  void _startPerformanceMonitoring() {
    // Monitor FPS and performance
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePerformanceMetrics();
    });
  }

  void _updatePerformanceMetrics() {
    monitorSyncOperation('_updatePerformanceMetrics', () {
      final stats = PerformanceMonitor.getOverallStats();
      final rating = stats['performanceRating'] as String;

      _performanceStatus.value = 'Performance: $rating';

      // Update FPS counter
      final totalOps = stats['totalOperations'] as int;
      final slowOps = stats['totalSlowOperations'] as int;

      if (totalOps > 0) {
        final fps = 1000.0 / (16.0 + (slowOps / totalOps) * 16.0);
        _fpsCounter.value = fps.clamp(30.0, 60.0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final size = constraints.biggest;
      if (size != viewerSize) {
        viewerSize = size;
        clearLayoutCache();
        updateRectFromBuild();
      }

      return Column(
        children: [
          // Performance status bar (debug mode)
          if (widget.showGrid) _buildPerformanceBar(),

          // Main crop preview
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: transform,
              builder: (_, TransformData transform, __) =>
                  buildView(context, transform),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildPerformanceBar() {
    return Container(
      height: 30,
      color: Colors.black54,
      child: Row(
        children: [
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: _performanceStatus,
              builder: (_, String status, __) => Text(
                status,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
          ValueListenableBuilder(
            valueListenable: _fpsCounter,
            builder: (_, double fps, __) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '${fps.toStringAsFixed(1)} FPS',
                style: TextStyle(
                  color: fps > 55
                      ? Colors.green
                      : fps > 45
                          ? Colors.orange
                          : Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget buildView(BuildContext context, TransformData transform) {
    if (!widget.showGrid) {
      return RepaintBoundary(
        child: _buildCropView(transform, widget.overlayText),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // Crop view with RepaintBoundary for performance
        RepaintBoundary(
          child: _buildCropView(transform, widget.overlayText),
        ),

        // Enhanced gesture handler
        OptimizedCropTransformWithAnimation(
          shouldAnimate: widget.showGrid,
          animationDuration: widget.animationDuration,
          animationCurve: widget.animationCurve,
          transform: TransformData(
            rotation: transform.rotation,
            scale: 1.0,
            translate: Offset.zero,
          ),
          child: EnhancedCropGestureHandler(
            enableHapticFeedback: widget.enableHapticFeedback,
            gestureThreshold: 2.0,
            expandedTouchArea: 24.0,
            onPanDown: _handlePanDown,
            onPanUpdate: _handlePanUpdate,
            onPanEnd: _handlePanEnd,
            onTapUp: _handleTapUp,
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }

  Widget _buildCropView(TransformData transform, String overlayText) {
    return Padding(
      padding: widget.margin,
      child: buildVideoView(
        _controller,
        transform,
        _cropStateManager.boundary.value,
        overlayText: overlayText,
        showGrid: widget.showGrid,
      ),
    );
  }

  // Enhanced gesture handling with performance monitoring
  void _handlePanDown(DragDownDetails details) {
    monitorSyncOperation('_handlePanDown', () {
      final boundary = _detectBoundary(details.localPosition);
      _cropStateManager.setBoundary(boundary);

      if (boundary != CropBoundaries.none) {
        _cropStateManager.setCropping(true);
        _startCropAnimation();
      }
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_cropStateManager.boundary.value == CropBoundaries.none) return;

    monitorSyncOperation('_handlePanUpdate', () {
      _updateCropRect(details.delta);
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_cropStateManager.boundary.value != CropBoundaries.none) {
      monitorSyncOperation('_handlePanEnd', () {
        _finalizeCrop();
        _cropStateManager.setCropping(false);
        _cropStateManager.setBoundary(CropBoundaries.none);
      });
    }
  }

  void _handleTapUp(TapUpDetails details) {
    // Handle tap events if needed
  }

  CropBoundaries _detectBoundary(Offset position) {
    if (rect.value == Rect.zero) return CropBoundaries.none;

    return OptimizedCropBoundaryDetector.detectBoundary(
      position,
      rect.value,
      24.0,
    );
  }

  void _updateCropRect(Offset delta) {
    if (rect.value == Rect.zero) return;

    final newRect = _calculateNewCropRect(delta);
    if (newRect != null) {
      rect.value = newRect;
      _cropStateManager.updateCropRect(newRect);
    }
  }

  Rect? _calculateNewCropRect(Offset delta) {
    final currentRect = rect.value;
    final boundary = _cropStateManager.boundary.value;

    double left = currentRect.left;
    double top = currentRect.top;
    double right = currentRect.right;
    double bottom = currentRect.bottom;

    switch (boundary) {
      case CropBoundaries.inside:
        left = (left + delta.dx).clamp(0, layout.width - currentRect.width);
        top = (top + delta.dy).clamp(0, layout.height - currentRect.height);
        break;
      case CropBoundaries.topLeft:
        left = (left + delta.dx).clamp(0, right - 50);
        top = (top + delta.dy).clamp(0, bottom - 50);
        break;
      case CropBoundaries.topRight:
        right = (right + delta.dx).clamp(left + 50, layout.width);
        top = (top + delta.dy).clamp(0, bottom - 50);
        break;
      case CropBoundaries.bottomRight:
        right = (right + delta.dx).clamp(left + 50, layout.width);
        bottom = (bottom + delta.dy).clamp(top + 50, layout.height);
        break;
      case CropBoundaries.bottomLeft:
        left = (left + delta.dx).clamp(0, right - 50);
        bottom = (bottom + delta.dy).clamp(top + 50, layout.height);
        break;
      case CropBoundaries.topCenter:
        top = (top + delta.dy).clamp(0, bottom - 50);
        break;
      case CropBoundaries.bottomCenter:
        bottom = (bottom + delta.dy).clamp(top + 50, layout.height);
        break;
      case CropBoundaries.centerLeft:
        left = (left + delta.dx).clamp(0, right - 50);
        break;
      case CropBoundaries.centerRight:
        right = (right + delta.dx).clamp(left + 50, layout.width);
        break;
      case CropBoundaries.none:
        return null;
    }

    final newRect = Rect.fromLTRB(left, top, right, bottom);

    // Validate minimum size
    if (newRect.width < 50 || newRect.height < 50) {
      return null;
    }

    return newRect;
  }

  void _startCropAnimation() {
    if (_isAnimating) return;

    setState(() {
      _isAnimating = true;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _isAnimating = false;
        });
      }
    });
  }

  void _finalizeCrop() {
    // Update controller with final crop values
    if (rect.value != Rect.zero) {
      final r = rect.value;
      _controller.cacheMinCrop = Offset(
        r.left / layout.width,
        r.top / layout.height,
      );
      _controller.cacheMaxCrop = Offset(
        r.right / layout.width,
        r.bottom / layout.height,
      );
    }

    // Update performance metrics
    _updatePerformanceMetrics();
  }

  @override
  void updateRectFromBuild() {
    if (widget.showGrid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        monitorSyncOperation('updateRectFromBuild', () {
          layout = _computeLayout();
          _cropStateManager.updateLayout(layout);
          transform.value = TransformData.fromController(_controller);
          _calculatePreferredCrop();
        });
      });
    } else {
      monitorSyncOperation('updateRectFromBuild', () {
        layout = _computeLayout();
        _cropStateManager.updateLayout(layout);
        rect.value = _calculateCroppedRect(_controller, layout);
        transform.value =
            TransformData.fromRect(rect.value, layout, viewerSize, _controller);
      });
    }
  }

  Size _computeLayout() => computeLayout(
        _controller,
        margin: widget.margin,
        shouldFlipped: _controller.isRotated && widget.showGrid,
      );

  void _calculatePreferredCrop() {
    if (rect.value == Rect.zero) return;

    final newRect = _calculateCroppedRect(
      _controller,
      layout,
      min: _controller.cacheMinCrop,
      max: _controller.cacheMaxCrop,
    );

    if (newRect != Rect.zero) {
      rect.value = newRect;
      _cropStateManager.updateCropRect(newRect);
    }
  }

  Rect _calculateCroppedRect(
    VideoEditorController controller,
    Size layout, {
    Offset? min,
    Offset? max,
  }) {
    final Offset minCrop = min ?? controller.minCrop;
    final Offset maxCrop = max ?? controller.maxCrop;

    return Rect.fromPoints(
      Offset(minCrop.dx * layout.width, minCrop.dy * layout.height),
      Offset(maxCrop.dx * layout.width, maxCrop.dy * layout.height),
    );
  }
}
