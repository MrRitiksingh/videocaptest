import 'package:flutter/material.dart';
import 'package:ai_video_creator_editor/screens/project/models/video_track_model.dart';
import 'package:ai_video_creator_editor/screens/project/models/canvas_transform.dart';
import 'dart:math' as math;

enum ManipulationMode {
  none,
  drag,
  resize,
  rotate,
  crop,
}

enum ResizeHandle {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  top,
  bottom,
  left,
  right,
}

/// Handles user interactions for media manipulation on canvas
class MediaManipulationHandler {
  final Size canvasSize;
  final Function(VideoTrackModel) onTrackUpdate;
  
  ManipulationMode _mode = ManipulationMode.none;
  ResizeHandle? _activeHandle;
  Offset _startPosition = Offset.zero;
  VideoTrackModel? _activeTrack;
  CanvasTransform? _startTransform;
  double _startRotation = 0;
  double _startScale = 1.0;
  
  MediaManipulationHandler({
    required this.canvasSize,
    required this.onTrackUpdate,
  });
  
  /// Start drag operation
  void startDrag(VideoTrackModel track, Offset position) {
    print('\n👋 === MANIPULATION HANDLER: START DRAG ===');
    print('👋 Track ID: ${track.id}');
    print('👋 Start position: (${position.dx.toStringAsFixed(2)}, ${position.dy.toStringAsFixed(2)})');
    print('👋 Track canvas position: (${track.canvasPosition.dx.toStringAsFixed(2)}, ${track.canvasPosition.dy.toStringAsFixed(2)})');
    print('👋 Track canvas size: ${track.canvasSize.width.toStringAsFixed(2)} x ${track.canvasSize.height.toStringAsFixed(2)}');

    _mode = ManipulationMode.drag;
    _activeTrack = track;
    _startPosition = position;
    _startTransform = _trackToTransform(track);

    print('👋 Start transform position: (${_startTransform!.position.dx.toStringAsFixed(2)}, ${_startTransform!.position.dy.toStringAsFixed(2)})');
    print('👋 Start transform size: ${_startTransform!.size.width.toStringAsFixed(2)} x ${_startTransform!.size.height.toStringAsFixed(2)}');
    print('👋 Manipulation mode set to: $_mode');
  }
  
  /// Update drag position
  void updateDrag(Offset position) {
    print('\n🔄 === MANIPULATION HANDLER: UPDATE DRAG ===');
    print('🔄 Current mode: $_mode');
    print('🔄 Active track: ${_activeTrack?.id ?? "null"}');

    if (_mode != ManipulationMode.drag || _activeTrack == null) {
      print('❌ Update drag REJECTED - mode: $_mode, activeTrack: ${_activeTrack?.id ?? "null"}');
      return;
    }

    print('🔄 Current position: (${position.dx.toStringAsFixed(2)}, ${position.dy.toStringAsFixed(2)})');
    print('🔄 Start position: (${_startPosition.dx.toStringAsFixed(2)}, ${_startPosition.dy.toStringAsFixed(2)})');

    final delta = position - _startPosition;
    print('🔄 Delta: (${delta.dx.toStringAsFixed(2)}, ${delta.dy.toStringAsFixed(2)})');

    final newPosition = Offset(
      _startTransform!.position.dx + delta.dx,
      _startTransform!.position.dy + delta.dy,
    );
    print('🔄 New position (before constraint): (${newPosition.dx.toStringAsFixed(2)}, ${newPosition.dy.toStringAsFixed(2)})');

    // Constrain to canvas bounds (should allow negative positions)
    final constrainedPosition = _constrainToCanvas(newPosition, _startTransform!.size);
    print('🔄 Constrained position: (${constrainedPosition.dx.toStringAsFixed(2)}, ${constrainedPosition.dy.toStringAsFixed(2)})');

    // Update track
    final updatedTrack = _activeTrack!.copyWith(
      canvasPosition: constrainedPosition,
    );
    print('🔄 Updating track with new position');
    onTrackUpdate(updatedTrack);
  }
  
  /// Start resize operation
  void startResize(VideoTrackModel track, ResizeHandle handle, Offset position) {
    _mode = ManipulationMode.resize;
    _activeTrack = track;
    _activeHandle = handle;
    _startPosition = position;
    _startTransform = _trackToTransform(track);
    _startScale = track.canvasScale;
  }
  
  /// Update resize
  void updateResize(Offset position) {
    if (_mode != ManipulationMode.resize || _activeTrack == null) return;
    
    final delta = position - _startPosition;
    final transform = _startTransform!;
    
    // Calculate new size based on handle
    Size newSize = transform.size;
    Offset newPosition = transform.position;
    
    switch (_activeHandle!) {
      case ResizeHandle.topLeft:
        newSize = Size(
          (transform.size.width - delta.dx).clamp(50, canvasSize.width),
          (transform.size.height - delta.dy).clamp(50, canvasSize.height),
        );
        newPosition = Offset(
          transform.position.dx + (transform.size.width - newSize.width),
          transform.position.dy + (transform.size.height - newSize.height),
        );
        break;
      case ResizeHandle.topRight:
        newSize = Size(
          (transform.size.width + delta.dx).clamp(50, canvasSize.width),
          (transform.size.height - delta.dy).clamp(50, canvasSize.height),
        );
        newPosition = Offset(
          transform.position.dx,
          transform.position.dy + (transform.size.height - newSize.height),
        );
        break;
      case ResizeHandle.bottomLeft:
        newSize = Size(
          (transform.size.width - delta.dx).clamp(50, canvasSize.width),
          (transform.size.height + delta.dy).clamp(50, canvasSize.height),
        );
        newPosition = Offset(
          transform.position.dx + (transform.size.width - newSize.width),
          transform.position.dy,
        );
        break;
      case ResizeHandle.bottomRight:
        newSize = Size(
          (transform.size.width + delta.dx).clamp(50, canvasSize.width),
          (transform.size.height + delta.dy).clamp(50, canvasSize.height),
        );
        break;
      case ResizeHandle.top:
        newSize = Size(
          transform.size.width,
          (transform.size.height - delta.dy).clamp(50, canvasSize.height),
        );
        newPosition = Offset(
          transform.position.dx,
          transform.position.dy + (transform.size.height - newSize.height),
        );
        break;
      case ResizeHandle.bottom:
        newSize = Size(
          transform.size.width,
          (transform.size.height + delta.dy).clamp(50, canvasSize.height),
        );
        break;
      case ResizeHandle.left:
        newSize = Size(
          (transform.size.width - delta.dx).clamp(50, canvasSize.width),
          transform.size.height,
        );
        newPosition = Offset(
          transform.position.dx + (transform.size.width - newSize.width),
          transform.position.dy,
        );
        break;
      case ResizeHandle.right:
        newSize = Size(
          (transform.size.width + delta.dx).clamp(50, canvasSize.width),
          transform.size.height,
        );
        break;
    }
    
    // Update track
    final updatedTrack = _activeTrack!.copyWith(
      canvasPosition: newPosition,
      canvasSize: newSize,
    );
    onTrackUpdate(updatedTrack);
  }
  
  /// Start rotation
  void startRotation(VideoTrackModel track, Offset position) {
    _mode = ManipulationMode.rotate;
    _activeTrack = track;
    _startPosition = position;
    _startTransform = _trackToTransform(track);
    _startRotation = track.canvasRotation.toDouble();
  }
  
  /// Update rotation
  void updateRotation(Offset position) {
    if (_mode != ManipulationMode.rotate || _activeTrack == null) return;
    
    final transform = _startTransform!;
    final center = transform.rotationCenter;
    
    // Calculate angle from center to current position
    final angle1 = math.atan2(
      _startPosition.dy - center.dy,
      _startPosition.dx - center.dx,
    );
    final angle2 = math.atan2(
      position.dy - center.dy,
      position.dx - center.dx,
    );
    
    // Calculate rotation delta in degrees
    final deltaRadians = angle2 - angle1;
    final deltaDegrees = deltaRadians * 180 / math.pi;
    
    // Apply rotation with snapping to 45-degree increments
    var newRotation = (_startRotation + deltaDegrees) % 360;
    if ((newRotation % 45).abs() < 5) {
      newRotation = (newRotation / 45).round() * 45.0;
    }
    
    // Update track
    final updatedTrack = _activeTrack!.copyWith(
      canvasRotation: newRotation.round(),
    );
    onTrackUpdate(updatedTrack);
  }
  
  /// Start scale operation for pinch gestures
  void startScale(VideoTrackModel track, double initialScale) {
    _activeTrack = track;
    _startScale = track.canvasScale; // Save initial scale for relative scaling
    print('🔍 Scale operation started - initial scale: $_startScale');
  }

  /// Handle pinch gesture for scaling
  void handlePinchScale(double scaleChange) {
    if (_activeTrack == null) return;

    // Apply relative scaling from initial scale
    final newScale = (_startScale * scaleChange).clamp(0.1, 5.0);

    // Add scale smoothing/snapping for common values (1.0x, 2.0x, etc.)
    final snappedScale = _snapToCommonScales(newScale);

    final updatedTrack = _activeTrack!.copyWith(
      canvasScale: snappedScale,
    );
    onTrackUpdate(updatedTrack);

    print('🔍 Scale updated: ${snappedScale.toStringAsFixed(2)}x (raw: ${newScale.toStringAsFixed(2)}x)');
  }

  /// Snap scale values to common scales for better UX
  double _snapToCommonScales(double scale) {
    const snapThreshold = 0.05;
    const snapValues = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0];

    for (final snapValue in snapValues) {
      if ((scale - snapValue).abs() < snapThreshold) {
        return snapValue;
      }
    }
    return scale;
  }
  
  /// Start crop operation
  void startCrop(VideoTrackModel track, Offset position) {
    _mode = ManipulationMode.crop;
    _activeTrack = track;
    _startPosition = position;
    _startTransform = _trackToTransform(track);
  }
  
  /// Update crop
  void updateCrop(Rect newCropRect) {
    if (_mode != ManipulationMode.crop || _activeTrack == null) return;
    
    // Ensure crop rect is normalized (0-1)
    final normalizedCrop = Rect.fromLTRB(
      newCropRect.left.clamp(0, 1),
      newCropRect.top.clamp(0, 1),
      newCropRect.right.clamp(0, 1),
      newCropRect.bottom.clamp(0, 1),
    );
    
    // Convert to CropModel - we need video size for this
    // For now, use a default video size or get it from the track
    final videoSize = _activeTrack!.canvasSize; // Use canvas size as approximation
    final cropModel = CropModel.fromRect(normalizedCrop, videoSize, enabled: true);
    
    final updatedTrack = _activeTrack!.copyWith(
      canvasCropModel: cropModel,
    );
    onTrackUpdate(updatedTrack);
  }
  
  /// End any active manipulation
  void endManipulation() {
    print('\n🔚 === MANIPULATION HANDLER: END MANIPULATION ===');
    print('🔚 Current mode: $_mode');
    print('🔚 Active track: ${_activeTrack?.id ?? "null"}');
    print('🔚 Active handle: $_activeHandle');

    _mode = ManipulationMode.none;
    _activeHandle = null;
    _activeTrack = null;
    _startTransform = null;

    print('🔚 Manipulation ended - mode reset to: $_mode');
  }
  
  /// Check which handle is at position - DISABLED (user wants only drag functionality)
  ResizeHandle? getHandleAtPosition(VideoTrackModel track, Offset position) {
    // Resize handles disabled - user wants only drag functionality
    return null;

    // ORIGINAL CODE COMMENTED OUT:
    // final transform = _trackToTransform(track);
    // final corners = transform.cornerPoints;
    // const handleSize = 24.0; // Touch target size
    //
    // // Check corner handles
    // if (_isNearPoint(position, corners[0], handleSize)) return ResizeHandle.topLeft;
    // if (_isNearPoint(position, corners[1], handleSize)) return ResizeHandle.topRight;
    // if (_isNearPoint(position, corners[2], handleSize)) return ResizeHandle.bottomRight;
    // if (_isNearPoint(position, corners[3], handleSize)) return ResizeHandle.bottomLeft;
    //
    // // Check edge handles (middle of each edge)
    // final bounds = transform.renderBounds;
    // if (_isNearPoint(position, Offset(bounds.center.dx, bounds.top), handleSize))
    //   return ResizeHandle.top;
    // if (_isNearPoint(position, Offset(bounds.center.dx, bounds.bottom), handleSize))
    //   return ResizeHandle.bottom;
    // if (_isNearPoint(position, Offset(bounds.left, bounds.center.dy), handleSize))
    //   return ResizeHandle.left;
    // if (_isNearPoint(position, Offset(bounds.right, bounds.center.dy), handleSize))
    //   return ResizeHandle.right;
    //
    // return null;
  }
  
  /// Check if position is near rotation handle - DISABLED (user wants only drag functionality)
  bool isNearRotationHandle(VideoTrackModel track, Offset position) {
    // Rotation handle disabled - user wants only drag functionality
    return false;

    // ORIGINAL CODE COMMENTED OUT:
    // final transform = _trackToTransform(track);
    // return _isNearPoint(position, transform.rotationHandlePosition, 24.0);
  }
  
  /// Check if position is inside track bounds
  bool isInsideTrack(VideoTrackModel track, Offset position) {
    print('\n🗺 === CHECKING IF INSIDE TRACK ===');
    print('🗺 Track ID: ${track.id}');
    print('🗺 Check position: (${position.dx.toStringAsFixed(2)}, ${position.dy.toStringAsFixed(2)})');

    final transform = _trackToTransform(track);
    print('🗺 Transform bounds: ${transform.renderBounds}');
    print('🗺 Transform position: (${transform.position.dx.toStringAsFixed(2)}, ${transform.position.dy.toStringAsFixed(2)})');
    print('🗺 Transform size: ${transform.size.width.toStringAsFixed(2)} x ${transform.size.height.toStringAsFixed(2)}');
    print('🗺 Transform scale: ${transform.scale.toStringAsFixed(2)}');
    print('🗺 Transform rotation: ${transform.rotation.toStringAsFixed(2)} rad');

    final result = transform.containsPoint(position);
    print('🗺 Contains point result: $result');

    return result;
  }
  
  /// Reset to default transformation
  VideoTrackModel resetTransformation(VideoTrackModel track) {
    final defaultTransform = CanvasTransform.defaultForMedia(
      canvasSize: canvasSize,
      mediaSize: track.canvasSize,
    );
    
    return track.copyWith(
      canvasPosition: defaultTransform.position,
      canvasSize: defaultTransform.size,
      canvasScale: 1.0,
      canvasRotation: 0,
      canvasCropModel: null, // Reset crop to none
    );
  }
  
  // Helper methods
  
  CanvasTransform _trackToTransform(VideoTrackModel track) {
    return CanvasTransform(
      position: track.canvasPosition,
      size: track.canvasSize,
      scale: track.canvasScale,
      rotation: -track.canvasRotation * (math.pi / 180), // Negated for correct visual direction
      cropRect: Rect.fromLTWH(
        track.canvasCropRect.left,
        track.canvasCropRect.top,
        track.canvasCropRect.width,
        track.canvasCropRect.height,
      ),
      opacity: track.canvasOpacity,
    );
  }
  
  Offset _constrainToCanvas(Offset position, Size size) {
    // Allow assets to be positioned anywhere (including outside canvas bounds)
    // Visual clipping will be handled by the canvas renderer
    return position;
  }
  
  bool _isNearPoint(Offset p1, Offset p2, double threshold) {
    return (p1 - p2).distance <= threshold;
  }
  
  ManipulationMode get currentMode => _mode;
  bool get isManipulating => _mode != ManipulationMode.none;
}