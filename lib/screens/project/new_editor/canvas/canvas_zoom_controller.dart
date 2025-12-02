import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Controller for managing canvas zoom and pan functionality
class CanvasZoomController extends ChangeNotifier {
  // Zoom state
  double _zoomScale = 1.0;
  Offset _panOffset = Offset.zero;

  // Zoom constraints
  static const double _minZoom = 0.1;
  static const double _maxZoom = 5.0;
  static const double _defaultZoom = 1.0;

  // Canvas size for boundary calculations
  Size _canvasSize = Size.zero;
  Size _containerSize = Size.zero;

  // Gesture state
  bool _isGestureActive = false;
  Offset _gestureStartOffset = Offset.zero;
  double _gestureStartScale = 1.0;

  // Getters
  double get zoomScale => _zoomScale;
  Offset get panOffset => _panOffset;
  bool get isZoomed => _zoomScale != _defaultZoom || _panOffset != Offset.zero;
  bool get isGestureActive => _isGestureActive;
  Size get canvasSize => _canvasSize;
  Size get containerSize => _containerSize;

  /// Initialize with canvas and container sizes
  void initialize({
    required Size canvasSize,
    required Size containerSize,
  }) {
    _canvasSize = canvasSize;
    _containerSize = containerSize;
    notifyListeners();
  }

  /// Update canvas size (when canvas ratio changes)
  void updateCanvasSize(Size canvasSize) {
    if (_canvasSize != canvasSize) {
      _canvasSize = canvasSize;
      _constrainPanOffset();
      notifyListeners();
    }
  }

  /// Update container size (when preview container resizes)
  void updateContainerSize(Size containerSize) {
    if (_containerSize != containerSize) {
      _containerSize = containerSize;
      _constrainPanOffset();
      notifyListeners();
    }
  }

  /// Set zoom scale with constraints
  void setZoom(double scale, {Offset? focalPoint}) {
    final constrainedScale = scale.clamp(_minZoom, _maxZoom);

    if (focalPoint != null && _zoomScale != constrainedScale) {
      // Adjust pan offset to zoom towards focal point
      _adjustPanForZoom(constrainedScale, focalPoint);
    }

    _zoomScale = constrainedScale;
    _constrainPanOffset();
    notifyListeners();
  }

  /// Set pan offset with constraints
  void setPan(Offset offset) {
    _panOffset = offset;
    _constrainPanOffset();
    notifyListeners();
  }

  /// Reset zoom and pan to default
  void reset() {
    _zoomScale = _defaultZoom;
    _panOffset = Offset.zero;
    notifyListeners();
  }

  /// Fit canvas to container (zoom to fit)
  void fitToContainer() {
    if (_canvasSize.isEmpty || _containerSize.isEmpty) return;

    final scaleX = _containerSize.width / _canvasSize.width;
    final scaleY = _containerSize.height / _canvasSize.height;
    final fitScale = math.min(scaleX, scaleY).clamp(_minZoom, _maxZoom);

    _zoomScale = fitScale;
    _panOffset = Offset.zero; // Center when fitting
    notifyListeners();
  }

  /// Start gesture (pinch or pan)
  void startGesture(Offset position, double scale) {
    _isGestureActive = true;
    _gestureStartOffset = _panOffset;
    _gestureStartScale = _zoomScale;
  }

  /// Update gesture (during pinch or pan)
  void updateGesture({
    Offset? panDelta,
    double? scaleChange,
    Offset? focalPoint,
  }) {
    if (!_isGestureActive) return;

    // Handle zoom change
    if (scaleChange != null && scaleChange != 1.0) {
      final newScale = (_gestureStartScale * scaleChange).clamp(_minZoom, _maxZoom);

      if (focalPoint != null) {
        _adjustPanForZoom(newScale, focalPoint);
      }

      _zoomScale = newScale;
    }

    // Handle pan change
    if (panDelta != null) {
      _panOffset = _gestureStartOffset + panDelta;
    }

    _constrainPanOffset();
    notifyListeners();
  }

  /// End gesture
  void endGesture() {
    _isGestureActive = false;
    _constrainPanOffset();
    notifyListeners();
  }

  /// Get transformation matrix for the canvas
  Matrix4 getTransformMatrix() {
    return Matrix4.identity()
      ..translate(_panOffset.dx, _panOffset.dy)
      ..scale(_zoomScale);
  }

  /// Convert screen coordinates to canvas coordinates
  Offset screenToCanvas(Offset screenPosition) {
    // Account for pan and zoom transformations
    final adjustedPosition = screenPosition - _panOffset;
    return Offset(
      adjustedPosition.dx / _zoomScale,
      adjustedPosition.dy / _zoomScale,
    );
  }

  /// Convert canvas coordinates to screen coordinates
  Offset canvasToScreen(Offset canvasPosition) {
    // Apply zoom and pan transformations
    final scaledPosition = Offset(
      canvasPosition.dx * _zoomScale,
      canvasPosition.dy * _zoomScale,
    );
    return scaledPosition + _panOffset;
  }

  /// Adjust pan offset when zooming to maintain focal point
  void _adjustPanForZoom(double newScale, Offset focalPoint) {
    if (_canvasSize.isEmpty) return;

    // Calculate the focal point relative to the canvas center
    final canvasCenter = Offset(_canvasSize.width / 2, _canvasSize.height / 2);
    final focalFromCenter = focalPoint - canvasCenter;

    // Calculate the change in scale
    final scaleChange = newScale / _zoomScale;

    // Adjust pan offset to keep the focal point stationary
    final panAdjustment = focalFromCenter * (1 - scaleChange);
    _panOffset += panAdjustment;
  }

  /// Constrain pan offset to prevent excessive panning beyond bounds
  void _constrainPanOffset() {
    if (_canvasSize.isEmpty || _containerSize.isEmpty) return;

    // Calculate scaled canvas size
    final scaledCanvasWidth = _canvasSize.width * _zoomScale;
    final scaledCanvasHeight = _canvasSize.height * _zoomScale;

    // Calculate maximum allowed pan offsets
    final maxPanX = math.max(0.0, (scaledCanvasWidth - _containerSize.width) / 2);
    final maxPanY = math.max(0.0, (scaledCanvasHeight - _containerSize.height) / 2);

    // If canvas is smaller than container (zoomed out), allow centering
    final minPanX = -maxPanX;
    final minPanY = -maxPanY;

    // Constrain pan offset
    _panOffset = Offset(
      _panOffset.dx.clamp(minPanX, maxPanX),
      _panOffset.dy.clamp(minPanY, maxPanY),
    );
  }

  /// Check if a canvas area is visible in the current view
  bool isAreaVisible(Rect canvasRect) {
    if (_containerSize.isEmpty || _canvasSize.isEmpty) return true;

    // Transform canvas rect to screen coordinates
    final scaledRect = Rect.fromLTWH(
      canvasRect.left * _zoomScale,
      canvasRect.top * _zoomScale,
      canvasRect.width * _zoomScale,
      canvasRect.height * _zoomScale,
    );

    final translatedRect = scaledRect.translate(_panOffset.dx, _panOffset.dy);

    // Check if rect intersects with container bounds
    final containerRect = Offset.zero & _containerSize;
    return translatedRect.overlaps(containerRect);
  }

  /// Get the visible area of canvas in canvas coordinates
  Rect getVisibleCanvasArea() {
    if (_containerSize.isEmpty || _zoomScale == 0) {
      return Offset.zero & _canvasSize;
    }

    // Calculate the visible area in screen coordinates
    final visibleScreenRect = Offset.zero & _containerSize;

    // Transform to canvas coordinates
    final topLeft = screenToCanvas(visibleScreenRect.topLeft);
    final bottomRight = screenToCanvas(visibleScreenRect.bottomRight);

    // Constrain to canvas bounds
    final canvasRect = Offset.zero & _canvasSize;
    final visibleRect = Rect.fromLTRB(
      math.max(topLeft.dx, canvasRect.left),
      math.max(topLeft.dy, canvasRect.top),
      math.min(bottomRight.dx, canvasRect.right),
      math.min(bottomRight.dy, canvasRect.bottom),
    );

    return visibleRect;
  }

  @override
  void dispose() {
    super.dispose();
  }
}