import 'package:ai_video_creator_editor/components/crop/crop_grid.dart';
import 'package:ai_video_creator_editor/utils/performance_monitor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Enhanced gesture handler for smooth crop operations
class EnhancedCropGestureHandler extends StatefulWidget {
  const EnhancedCropGestureHandler({
    super.key,
    required this.child,
    required this.onPanDown,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onTapUp,
    this.enableHapticFeedback = true,
    this.gestureThreshold = 2.0,
    this.expandedTouchArea = 24.0,
  });

  final Widget child;
  final Function(DragDownDetails) onPanDown;
  final Function(DragUpdateDetails) onPanUpdate;
  final Function(DragEndDetails) onPanEnd;
  final Function(TapUpDetails) onTapUp;
  final bool enableHapticFeedback;
  final double gestureThreshold;
  final double expandedTouchArea;

  @override
  State<EnhancedCropGestureHandler> createState() =>
      _EnhancedCropGestureHandlerState();
}

class _EnhancedCropGestureHandlerState extends State<EnhancedCropGestureHandler>
    with PerformanceMonitoringMixin {
  // Gesture state tracking
  bool _isPanning = false;
  Offset _lastPanPosition = Offset.zero;
  DateTime _lastPanTime = DateTime.now();

  // Performance optimization
  static const Duration _minPanInterval = Duration(milliseconds: 16); // 60fps

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanDown: _handlePanDown,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      onTapUp: widget.onTapUp,
      onTapCancel: _handleTapCancel,
      behavior: HitTestBehavior.opaque,
      child: widget.child,
    );
  }

  void _handlePanDown(DragDownDetails details) {
    monitorSyncOperation('_handlePanDown', () {
      _isPanning = true;
      _lastPanPosition = details.localPosition;
      _lastPanTime = DateTime.now();

      if (widget.enableHapticFeedback) {
        HapticFeedback.lightImpact();
      }

      widget.onPanDown(details);
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isPanning) return;

    monitorSyncOperation('_handlePanUpdate', () {
      final now = DateTime.now();
      final timeSinceLastPan = now.difference(_lastPanTime);

      // Throttle pan events for performance
      if (timeSinceLastPan < _minPanInterval) {
        return;
      }

      final delta = details.localPosition - _lastPanPosition;
      final distance = delta.distance;

      // Only process if movement exceeds threshold
      if (distance < widget.gestureThreshold) {
        return;
      }

      // Update last position and time
      _lastPanPosition = details.localPosition;
      _lastPanTime = now;

      // Call the actual pan update handler
      widget.onPanUpdate(details);
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!_isPanning) return;

    monitorSyncOperation('_handlePanEnd', () {
      _isPanning = false;

      if (widget.enableHapticFeedback) {
        HapticFeedback.lightImpact();
      }

      widget.onPanEnd(details);
    });
  }

  void _handleTapCancel() {
    // Handle tap cancellation if needed
  }
}

/// Optimized crop boundary detector with enhanced touch areas
class OptimizedCropBoundaryDetector {
  /// Detect which crop boundary was touched with optimized touch areas
  static CropBoundaries detectBoundary(
    Offset touchPosition,
    Rect cropRect,
    double expandedArea,
  ) {
    final expandedRect = _getExpandedRect(cropRect, expandedArea);

    if (!expandedRect.contains(touchPosition)) {
      return CropBoundaries.none;
    }

    // Check corners first (highest priority)
    if (_isInCorner(touchPosition, cropRect, expandedArea)) {
      return _getCornerBoundary(touchPosition, cropRect);
    }

    // Check edges
    if (_isInEdge(touchPosition, cropRect, expandedArea)) {
      return _getEdgeBoundary(touchPosition, cropRect);
    }

    // Check center area
    if (_isInCenter(touchPosition, cropRect, expandedArea)) {
      return CropBoundaries.inside;
    }

    return CropBoundaries.none;
  }

  static Rect _getExpandedRect(Rect rect, double expandedArea) {
    return Rect.fromCenter(
      center: rect.center,
      width: rect.width + expandedArea * 2,
      height: rect.height + expandedArea * 2,
    );
  }

  static bool _isInCorner(Offset position, Rect rect, double expandedArea) {
    final cornerSize = expandedArea * 2;

    // Top-left corner
    if (position.dx <= rect.left + cornerSize &&
        position.dy <= rect.top + cornerSize) {
      return true;
    }

    // Top-right corner
    if (position.dx >= rect.right - cornerSize &&
        position.dy <= rect.top + cornerSize) {
      return true;
    }

    // Bottom-left corner
    if (position.dx <= rect.left + cornerSize &&
        position.dy >= rect.bottom - cornerSize) {
      return true;
    }

    // Bottom-right corner
    if (position.dx >= rect.right - cornerSize &&
        position.dy >= rect.bottom - cornerSize) {
      return true;
    }

    return false;
  }

  static CropBoundaries _getCornerBoundary(Offset position, Rect rect) {
    final centerX = rect.left + rect.width / 2;
    final centerY = rect.top + rect.height / 2;

    if (position.dx <= centerX && position.dy <= centerY) {
      return CropBoundaries.topLeft;
    } else if (position.dx > centerX && position.dy <= centerY) {
      return CropBoundaries.topRight;
    } else if (position.dx <= centerX && position.dy > centerY) {
      return CropBoundaries.bottomLeft;
    } else {
      return CropBoundaries.bottomRight;
    }
  }

  static bool _isInEdge(Offset position, Rect rect, double expandedArea) {
    final edgeSize = expandedArea;

    // Top edge
    if (position.dy <= rect.top + edgeSize &&
        position.dx > rect.left + edgeSize &&
        position.dx < rect.right - edgeSize) {
      return true;
    }

    // Bottom edge
    if (position.dy >= rect.bottom - edgeSize &&
        position.dx > rect.left + edgeSize &&
        position.dx < rect.right - edgeSize) {
      return true;
    }

    // Left edge
    if (position.dx <= rect.left + edgeSize &&
        position.dy > rect.top + edgeSize &&
        position.dy < rect.bottom - edgeSize) {
      return true;
    }

    // Right edge
    if (position.dx >= rect.right - edgeSize &&
        position.dy > rect.top + edgeSize &&
        position.dy < rect.bottom - edgeSize) {
      return true;
    }

    return false;
  }

  static CropBoundaries _getEdgeBoundary(Offset position, Rect rect) {
    final centerX = rect.left + rect.width / 2;
    final centerY = rect.top + rect.height / 2;

    if (position.dy <= centerY) {
      return CropBoundaries.topCenter;
    } else if (position.dy > centerY) {
      return CropBoundaries.bottomCenter;
    } else if (position.dx <= centerX) {
      return CropBoundaries.centerLeft;
    } else {
      return CropBoundaries.centerRight;
    }
  }

  static bool _isInCenter(Offset position, Rect rect, double expandedArea) {
    final centerRect = Rect.fromCenter(
      center: rect.center,
      width: rect.width - expandedArea * 2,
      height: rect.height - expandedArea * 2,
    );

    return centerRect.contains(position);
  }
}
