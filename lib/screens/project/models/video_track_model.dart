import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/transition_picker.dart';

/// Crop model for video/image content with absolute coordinates
class CropModel {
  final double x;
  final double y;
  final double width;
  final double height;
  final bool enabled;
  final double sourceWidth;
  final double sourceHeight;

  CropModel({
    this.x = 0.0,
    this.y = 0.0,
    this.width = 1.0,
    this.height = 1.0,
    this.enabled = false,
    this.sourceWidth = 1920.0,
    this.sourceHeight = 1080.0,
  });

  /// Create crop model from normalized values (0.0 to 1.0)
  factory CropModel.fromNormalized({
    required double normalizedX,
    required double normalizedY,
    required double normalizedWidth,
    required double normalizedHeight,
    required double sourceWidth,
    required double sourceHeight,
    bool enabled = true,
  }) {
    return CropModel(
      x: normalizedX * sourceWidth,
      y: normalizedY * sourceHeight,
      width: normalizedWidth * sourceWidth,
      height: normalizedHeight * sourceHeight,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      enabled: enabled,
    );
  }

  /// Create crop model from Rect (for backwards compatibility)
  factory CropModel.fromRect(Rect rect, Size sourceSize,
      {bool enabled = true}) {
    return CropModel.fromNormalized(
      normalizedX: rect.left,
      normalizedY: rect.top,
      normalizedWidth: rect.width,
      normalizedHeight: rect.height,
      sourceWidth: sourceSize.width,
      sourceHeight: sourceSize.height,
      enabled: enabled,
    );
  }

  /// Validate crop parameters
  bool get isValid {
    return x >= 0 &&
        y >= 0 &&
        width > 0 &&
        height > 0 &&
        x + width <= sourceWidth &&
        y + height <= sourceHeight;
  }

  /// Get normalized crop values (0.0 to 1.0)
  Map<String, double> get normalized {
    return {
      'x': x / sourceWidth,
      'y': y / sourceHeight,
      'width': width / sourceWidth,
      'height': height / sourceHeight,
    };
  }

  /// Convert to normalized Rect (for backwards compatibility)
  Rect toNormalizedRect() {
    final norm = normalized;
    return Rect.fromLTWH(
      norm['x']!,
      norm['y']!,
      norm['width']!,
      norm['height']!,
    );
  }

  /// Generate FFmpeg crop filter with validation
  String toFFmpegFilter() {
    if (!enabled || !isValid) {
      return '';
    }

    final cropX = x.clamp(0.0, sourceWidth - 1).toInt();
    final cropY = y.clamp(0.0, sourceHeight - 1).toInt();
    final cropWidth = width.clamp(1.0, sourceWidth - cropX).toInt();
    final cropHeight = height.clamp(1.0, sourceHeight - cropY).toInt();

    return 'crop=$cropWidth:$cropHeight:$cropX:$cropY';
  }

  /// Convert to Flutter Rect in absolute coordinates
  Rect toRect() {
    return Rect.fromLTWH(x, y, width, height);
  }

  /// Get aspect ratio of the crop
  double get aspectRatio {
    return width / height;
  }

  /// Create a copy with modified values
  CropModel copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    bool? enabled,
    double? sourceWidth,
    double? sourceHeight,
  }) {
    return CropModel(
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      enabled: enabled ?? this.enabled,
      sourceWidth: sourceWidth ?? this.sourceWidth,
      sourceHeight: sourceHeight ?? this.sourceHeight,
    );
  }

  /// Constrain crop to maintain aspect ratio
  CropModel constrainToAspectRatio(double targetAspectRatio) {
    final currentAspectRatio = aspectRatio;

    if ((currentAspectRatio - targetAspectRatio).abs() < 0.01) {
      return this; // Already matches
    }

    double newWidth = width;
    double newHeight = height;

    if (currentAspectRatio > targetAspectRatio) {
      // Too wide, reduce width
      newWidth = height * targetAspectRatio;
    } else {
      // Too tall, reduce height
      newHeight = width / targetAspectRatio;
    }

    // Center the crop
    final newX = x + (width - newWidth) / 2;
    final newY = y + (height - newHeight) / 2;

    return copyWith(
      x: newX.clamp(0.0, sourceWidth - newWidth),
      y: newY.clamp(0.0, sourceHeight - newHeight),
      width: newWidth,
      height: newHeight,
    );
  }

  @override
  String toString() {
    return 'CropModel(x: $x, y: $y, width: $width, height: $height, enabled: $enabled)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CropModel &&
        other.x == x &&
        other.y == y &&
        other.width == width &&
        other.height == height &&
        other.enabled == enabled &&
        other.sourceWidth == sourceWidth &&
        other.sourceHeight == sourceHeight;
  }

  @override
  int get hashCode {
    return x.hashCode ^
        y.hashCode ^
        width.hashCode ^
        height.hashCode ^
        enabled.hashCode ^
        sourceWidth.hashCode ^
        sourceHeight.hashCode;
  }
}

class VideoTrackModel {
  final String id;
  final File originalFile;
  final File processedFile;
  final int startTime;
  final int endTime;
  final int totalDuration;
  final bool hasOriginalAudio;
  // Video trim fields - similar to AudioTrackModel
  final double videoTrimStart;
  final double videoTrimEnd;
  final double originalDuration; // Store original duration before trim
  final DateTime lastModified; // Timestamp for tracking changes
  // Stretch functionality fields
  final bool isImageBased; // Flag to identify image-converted videos
  final double? customDuration; // Custom duration for stretched image videos

  // Canvas positioning properties
  final Offset canvasPosition; // Position on the canvas
  final Size canvasSize; // Size on the canvas
  final double canvasScale; // Scale factor
  final int canvasRotation; // Rotation in degrees (0, 90, 180, 270)
  final int canvasZIndex; // Layer order
  final CropModel? canvasCropModel; // Crop model with absolute coordinates
  final bool canvasVisible; // Visibility on canvas
  final double canvasOpacity; // Opacity (0.0-1.0)

  // Filter property
  final String
      filter; // Filter applied to this video asset (e.g., 'none', 'grayscale', 'vintage')

  // Transition properties
  final TransitionType?
      transitionToNext; // Transition from this track to next track
  final double
      transitionToNextDuration; // Duration of transition in seconds (default 1.0)

  // NEW — start transition (virtual gap at track[0])
  final TransitionType? transitionFromStart;
  final double? transitionFromStartDuration;

// NEW — end transition (virtual gap at last track)
  final TransitionType? transitionToEnd;
  final double? transitionToEndDuration;

  VideoTrackModel({
    String? id,
    required this.originalFile,
    required this.processedFile,
    this.startTime = 0,
    this.endTime = 0,
    this.totalDuration = 0,
    this.hasOriginalAudio = false,
    this.videoTrimStart = 0.0,
    double? videoTrimEnd,
    double? originalDuration,
    DateTime? lastModified,
    this.isImageBased = false,
    this.customDuration,
    // Canvas properties with defaults
    this.canvasPosition = const Offset(0, 0),
    this.canvasSize = const Size(100, 100),
    this.canvasScale = 1.0,
    this.canvasRotation = 0,
    this.canvasZIndex = 0,
    CropModel? canvasCropModel,
    this.canvasVisible = true,
    this.canvasOpacity = 1.0,
    // Filter property with default
    this.filter = 'none',
    // Transition properties with defaults
    this.transitionToNext,
    this.transitionToNextDuration = 1.0,
    this.transitionFromStart,
    this.transitionFromStartDuration,
    this.transitionToEnd,
    this.transitionToEndDuration,
  })  : id = id ?? const Uuid().v4(),
        videoTrimEnd = videoTrimEnd ?? totalDuration.toDouble(),
        originalDuration = originalDuration ?? totalDuration.toDouble(),
        lastModified = lastModified ?? DateTime.now(),
        canvasCropModel = canvasCropModel;

VideoTrackModel copyWith({
  String? id,
  File? originalFile,
  File? processedFile,
  int? startTime,
  int? endTime,
  int? totalDuration,
  bool? hasOriginalAudio,
  double? videoTrimStart,
  double? videoTrimEnd,
  double? originalDuration,
  DateTime? lastModified,
  bool? isImageBased,
  double? customDuration,

  // Canvas
  Offset? canvasPosition,
  Size? canvasSize,
  double? canvasScale,
  int? canvasRotation,
  int? canvasZIndex,
  CropModel? canvasCropModel,
  bool? canvasVisible,
  double? canvasOpacity,

  // Filters
  String? filter,

  // Transitions
  TransitionType? transitionToNext,
  double? transitionToNextDuration,

  TransitionType? transitionFromStart,
  double? transitionFromStartDuration,

  TransitionType? transitionToEnd,
  double? transitionToEndDuration,
}) {
  return VideoTrackModel(
    id: id ?? this.id,
    originalFile: originalFile ?? this.originalFile,
    processedFile: processedFile ?? this.processedFile,

    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    totalDuration: totalDuration ?? this.totalDuration,

    hasOriginalAudio: hasOriginalAudio ?? this.hasOriginalAudio,

    videoTrimStart: videoTrimStart ?? this.videoTrimStart,
    videoTrimEnd: videoTrimEnd ?? this.videoTrimEnd,
    originalDuration: originalDuration ?? this.originalDuration,

    lastModified: lastModified ?? this.lastModified,

    isImageBased: isImageBased ?? this.isImageBased,
    customDuration: customDuration ?? this.customDuration,

    // Canvas
    canvasPosition: canvasPosition ?? this.canvasPosition,
    canvasSize: canvasSize ?? this.canvasSize,
    canvasScale: canvasScale ?? this.canvasScale,
    canvasRotation: canvasRotation ?? this.canvasRotation,
    canvasZIndex: canvasZIndex ?? this.canvasZIndex,
    canvasCropModel: canvasCropModel ?? this.canvasCropModel,
    canvasVisible: canvasVisible ?? this.canvasVisible,
    canvasOpacity: canvasOpacity ?? this.canvasOpacity,

    // Filter
    filter: filter ?? this.filter,

    // Transitions — DO NOT BREAK THESE!!!
    transitionToNext: transitionToNext ?? this.transitionToNext,
    transitionToNextDuration:
        transitionToNextDuration ?? this.transitionToNextDuration,

    transitionFromStart: transitionFromStart ?? this.transitionFromStart,
    transitionFromStartDuration:
        transitionFromStartDuration ?? this.transitionFromStartDuration,

    transitionToEnd: transitionToEnd ?? this.transitionToEnd,
    transitionToEndDuration:
        transitionToEndDuration ?? this.transitionToEndDuration,
  );
}


  /// Get the actual render rectangle on canvas
  Rect get canvasRenderRect {
    return Rect.fromLTWH(
      canvasPosition.dx,
      canvasPosition.dy,
      canvasSize.width * canvasScale,
      canvasSize.height * canvasScale,
    );
  }

  /// Check if this video contains a point on the canvas
  bool containsCanvasPoint(Offset point) {
    return canvasRenderRect.contains(point);
  }

  /// Get crop rect in normalized format (for backwards compatibility)
  Rect get canvasCropRect {
    return canvasCropModel?.toNormalizedRect() ??
        const Rect.fromLTWH(0, 0, 1, 1);
  }

  /// Check if crop is enabled and valid
  bool get hasCrop {
    return canvasCropModel?.enabled == true && canvasCropModel?.isValid == true;
  }

  /// Factory constructor for canvas-positioned video
  factory VideoTrackModel.withCanvasPosition({
    required File originalFile,
    required File processedFile,
    required Offset position,
    required Size size,
    String? id,
    int startTime = 0,
    int endTime = 0,
    int totalDuration = 0,
    bool hasOriginalAudio = false,
    double videoTrimStart = 0.0,
    double? videoTrimEnd,
    double? originalDuration,
    bool isImageBased = false,
    double? customDuration,
    double canvasScale = 1.0,
    int canvasRotation = 0,
    int canvasZIndex = 0,
    CropModel? canvasCropModel,
    bool canvasVisible = true,
    double canvasOpacity = 1.0,
    String filter = 'none',
    TransitionType? transitionToNext,
    double transitionToNextDuration = 1.0,
    // ✅ add missing start transition
    TransitionType? transitionFromStart,
    double? transitionFromStartDuration,

    // existing end transition fields
    TransitionType? transitionToEnd,
    double? transitionToEndDuration,
  }) {
    return VideoTrackModel(
      id: id,
      originalFile: originalFile,
      processedFile: processedFile,
      startTime: startTime,
      endTime: endTime,
      totalDuration: totalDuration,
      hasOriginalAudio: hasOriginalAudio,
      videoTrimStart: videoTrimStart,
      videoTrimEnd: videoTrimEnd,
      originalDuration: originalDuration,
      isImageBased: isImageBased,
      customDuration: customDuration,
      canvasPosition: position,
      canvasSize: size,
      canvasScale: canvasScale,
      canvasRotation: canvasRotation,
      canvasZIndex: canvasZIndex,
      canvasCropModel: canvasCropModel,
      canvasVisible: canvasVisible,
      canvasOpacity: canvasOpacity,
      filter: filter,
      transitionToNext: transitionToNext,
      transitionToNextDuration: transitionToNextDuration,
      // ✅ fixed
      transitionFromStart: transitionFromStart,
      transitionFromStartDuration: transitionFromStartDuration,

      transitionToEnd: transitionToEnd,
      transitionToEndDuration: transitionToEndDuration,
    );
  }
}
