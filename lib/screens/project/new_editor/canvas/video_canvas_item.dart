import 'package:flutter/material.dart';
import 'package:ai_video_creator_editor/controllers/video_controller.dart';
import 'package:ai_video_creator_editor/screens/project/models/text_track_model.dart';

/// Represents an individual video item on the canvas with its own properties
class VideoCanvasItem {
  final String id;
  final VideoEditorController controller;
  
  // Canvas positioning
  Offset position;
  Size size;
  double scale;
  int rotation; // 0, 90, 180, 270 degrees
  int zIndex;
  
  // Individual video properties
  Rect cropRect;
  bool isSelected;
  bool isVisible;
  double opacity;
  
  // Text overlays specific to this video
  List<TextTrackModel> textTracks;
  
  // Original video dimensions for aspect ratio calculations
  late final Size originalVideoSize;
  late final double aspectRatio;

  VideoCanvasItem({
    required this.id,
    required this.controller,
    required this.position,
    required this.size,
    this.scale = 1.0,
    this.rotation = 0,
    this.zIndex = 0,
    Rect? cropRect,
    this.isSelected = false,
    this.isVisible = true,
    this.opacity = 1.0,
    List<TextTrackModel>? textTracks,
  }) : cropRect = cropRect ?? Rect.fromLTWH(0, 0, 1, 1),
       textTracks = textTracks ?? [] {
    // Initialize original video size and aspect ratio
    final videoSize = controller.video.value.size;
    originalVideoSize = videoSize;
    aspectRatio = videoSize.width / videoSize.height;
  }

  /// Creates a VideoCanvasItem with automatic sizing based on canvas dimensions
  factory VideoCanvasItem.autoSized({
    required String id,
    required VideoEditorController controller,
    required Size canvasSize,
    Offset? position,
    int? zIndex,
  }) {
    final videoSize = controller.video.value.size;
    final videoAspectRatio = videoSize.width / videoSize.height;
    
    // Calculate optimal size that fits within canvas while preserving aspect ratio
    Size itemSize;
    if (videoAspectRatio > 1) {
      // Landscape video
      itemSize = Size(
        canvasSize.width * 0.6, // 60% of canvas width
        (canvasSize.width * 0.6) / videoAspectRatio,
      );
    } else {
      // Portrait video
      itemSize = Size(
        canvasSize.height * 0.6 * videoAspectRatio,
        canvasSize.height * 0.6, // 60% of canvas height
      );
    }
    
    // Center position if not provided
    final defaultPosition = position ?? Offset(
      (canvasSize.width - itemSize.width) / 2,
      (canvasSize.height - itemSize.height) / 2,
    );
    
    return VideoCanvasItem(
      id: id,
      controller: controller,
      position: defaultPosition,
      size: itemSize,
      zIndex: zIndex ?? 0,
    );
  }

  /// Get the actual rendered rectangle on canvas
  Rect get renderRect {
    return Rect.fromLTWH(
      position.dx,
      position.dy,
      size.width * scale,
      size.height * scale,
    );
  }

  /// Get the cropped area within the video
  Rect get croppedVideoRect {
    final videoSize = controller.video.value.size;
    return Rect.fromLTWH(
      cropRect.left * videoSize.width,
      cropRect.top * videoSize.height,
      cropRect.width * videoSize.width,
      cropRect.height * videoSize.height,
    );
  }

  /// Check if a point is within this video item
  bool containsPoint(Offset point) {
    return renderRect.contains(point);
  }

  /// Get selection handles for resizing/moving
  List<Rect> get selectionHandles {
    if (!isSelected) return [];
    
    final rect = renderRect;
    const handleSize = 12.0;
    
    return [
      // Corner handles
      Rect.fromCenter(center: rect.topLeft, width: handleSize, height: handleSize),
      Rect.fromCenter(center: rect.topRight, width: handleSize, height: handleSize),
      Rect.fromCenter(center: rect.bottomLeft, width: handleSize, height: handleSize),
      Rect.fromCenter(center: rect.bottomRight, width: handleSize, height: handleSize),
      
      // Edge handles
      Rect.fromCenter(center: Offset(rect.center.dx, rect.top), width: handleSize, height: handleSize),
      Rect.fromCenter(center: Offset(rect.center.dx, rect.bottom), width: handleSize, height: handleSize),
      Rect.fromCenter(center: Offset(rect.left, rect.center.dy), width: handleSize, height: handleSize),
      Rect.fromCenter(center: Offset(rect.right, rect.center.dy), width: handleSize, height: handleSize),
    ];
  }

  /// Update position maintaining canvas boundaries
  void updatePosition(Offset newPosition, Size canvasSize) {
    final maxX = canvasSize.width - (size.width * scale);
    final maxY = canvasSize.height - (size.height * scale);
    
    position = Offset(
      newPosition.dx.clamp(0.0, maxX),
      newPosition.dy.clamp(0.0, maxY),
    );
  }

  /// Update size maintaining aspect ratio
  void updateSize(Size newSize, {bool maintainAspectRatio = true}) {
    if (maintainAspectRatio) {
      final newAspectRatio = newSize.width / newSize.height;
      if (newAspectRatio != aspectRatio) {
        // Adjust height to maintain aspect ratio
        size = Size(newSize.width, newSize.width / aspectRatio);
      } else {
        size = newSize;
      }
    } else {
      size = newSize;
    }
  }

  /// Apply rotation (90 degree increments)
  void rotate(int degrees) {
    rotation = (rotation + degrees) % 360;
    
    // Swap width/height for 90/270 degree rotations
    if (degrees == 90 || degrees == 270) {
      size = Size(size.height, size.width);
    }
  }

  /// Update crop rectangle
  void updateCrop(Rect newCropRect) {
    cropRect = Rect.fromLTRB(
      newCropRect.left.clamp(0.0, 1.0),
      newCropRect.top.clamp(0.0, 1.0),
      newCropRect.right.clamp(0.0, 1.0),
      newCropRect.bottom.clamp(0.0, 1.0),
    );
  }

  /// Add text overlay to this video
  void addTextOverlay(TextTrackModel textTrack) {
    textTracks.add(textTrack);
  }

  /// Remove text overlay from this video
  void removeTextOverlay(String textTrackId) {
    textTracks.removeWhere((track) => track.id == textTrackId);
  }

  /// Clone this video item
  VideoCanvasItem clone() {
    return VideoCanvasItem(
      id: id,
      controller: controller,
      position: position,
      size: size,
      scale: scale,
      rotation: rotation,
      zIndex: zIndex,
      cropRect: cropRect,
      isSelected: false, // Don't clone selection state
      isVisible: isVisible,
      opacity: opacity,
      textTracks: textTracks.map((track) => track.copyWith()).toList(),
    );
  }

  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'position': {'x': position.dx, 'y': position.dy},
      'size': {'width': size.width, 'height': size.height},
      'scale': scale,
      'rotation': rotation,
      'zIndex': zIndex,
      'cropRect': {
        'left': cropRect.left,
        'top': cropRect.top,
        'right': cropRect.right,
        'bottom': cropRect.bottom,
      },
      'isVisible': isVisible,
      'opacity': opacity,
      'textTracks': textTracks.map((track) => {
        'id': track.id,
        'text': track.text,
        'trimStartTime': track.trimStartTime,
        'trimEndTime': track.trimEndTime,
        'textColor': track.textColor.value,
        'fontSize': track.fontSize,
        'fontFamily': track.fontFamily,
        'position': {'x': track.position.dx, 'y': track.position.dy},
        'rotation': track.rotation,
      }).toList(),
    };
  }

  /// Create from map for deserialization
  factory VideoCanvasItem.fromMap(
    Map<String, dynamic> map,
    VideoEditorController controller,
  ) {
    return VideoCanvasItem(
      id: map['id'],
      controller: controller,
      position: Offset(map['position']['x'], map['position']['y']),
      size: Size(map['size']['width'], map['size']['height']),
      scale: map['scale'] ?? 1.0,
      rotation: map['rotation'] ?? 0,
      zIndex: map['zIndex'] ?? 0,
      cropRect: Rect.fromLTRB(
        map['cropRect']['left'],
        map['cropRect']['top'],
        map['cropRect']['right'],
        map['cropRect']['bottom'],
      ),
      isVisible: map['isVisible'] ?? true,
      opacity: map['opacity'] ?? 1.0,
      textTracks: (map['textTracks'] as List<dynamic>?)
          ?.map((trackMap) => TextTrackModel(
            id: trackMap['id'],
            text: trackMap['text'],
            trimStartTime: trackMap['trimStartTime'] ?? 0.0,
            trimEndTime: trackMap['trimEndTime'] ?? 0.0,
            textColor: Color(trackMap['textColor'] ?? 0xFFFFFFFF),
            fontSize: trackMap['fontSize'] ?? 24.0,
            fontFamily: trackMap['fontFamily'] ?? 'Arial',
            position: Offset(trackMap['position']['x'], trackMap['position']['y']),
            rotation: trackMap['rotation'] ?? 0.0,
          ))
          .cast<TextTrackModel>()
          .toList() ?? [],
    );
  }

  @override
  String toString() {
    return 'VideoCanvasItem(id: $id, position: $position, size: $size, rotation: $rotation°)';
  }
}

/// Enum for handle positions during resize operations
enum ResizeHandle {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  topCenter,
  bottomCenter,
  centerLeft,
  centerRight,
  none,
}

/// Helper class for detecting which resize handle was touched
class ResizeHandleDetector {
  static ResizeHandle detectHandle(Offset touchPoint, VideoCanvasItem item) {
    final handles = item.selectionHandles;
    
    for (int i = 0; i < handles.length; i++) {
      if (handles[i].contains(touchPoint)) {
        return ResizeHandle.values[i];
      }
    }
    
    return ResizeHandle.none;
  }
}