import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Represents a transformation matrix for media elements on canvas
class CanvasTransform {
  final Offset position;
  final Size size;
  final double scale;
  final double rotation; // in radians
  final Rect cropRect; // normalized 0-1
  final double opacity;
  final bool flipHorizontal;
  final bool flipVertical;
  
  const CanvasTransform({
    this.position = const Offset(0, 0),
    this.size = const Size(100, 100),
    this.scale = 1.0,
    this.rotation = 0.0,
    this.cropRect = const Rect.fromLTWH(0, 0, 1, 1),
    this.opacity = 1.0,
    this.flipHorizontal = false,
    this.flipVertical = false,
  });
  
  /// Create default transform for a media element
  factory CanvasTransform.defaultForMedia({
    required Size canvasSize,
    required Size mediaSize,
  }) {
    // Safety checks for canvas size
    var safeCanvasSize = canvasSize;
    if (canvasSize.width <= 0 || canvasSize.height <= 0 || 
        !canvasSize.width.isFinite || !canvasSize.height.isFinite) {
      safeCanvasSize = const Size(400, 300);
    }
    
    // Safety checks for media size
    var safeMediaSize = mediaSize;
    if (mediaSize.width <= 0 || mediaSize.height <= 0 || 
        !mediaSize.width.isFinite || !mediaSize.height.isFinite) {
      safeMediaSize = const Size(1920, 1080); // Default 16:9 video
    }
    
    // Calculate size to fit in full canvas while maintaining aspect ratio
    final canvasAspect = safeCanvasSize.width / safeCanvasSize.height;
    final mediaAspect = safeMediaSize.width / safeMediaSize.height;
    
    // Safety check for aspect ratios
    final safeCanvasAspect = canvasAspect.isFinite && canvasAspect > 0 ? canvasAspect : 16/9;
    final safeMediaAspect = mediaAspect.isFinite && mediaAspect > 0 ? mediaAspect : 16/9;
    
    Size targetSize;
    if (safeMediaAspect > safeCanvasAspect) {
      // Media is wider than canvas - fit to canvas width (letterboxing)
      final width = safeCanvasSize.width;
      final height = width / safeMediaAspect;
      targetSize = Size(width, height);
    } else {
      // Media is taller than canvas - fit to canvas height (pillarboxing)
      final height = safeCanvasSize.height;
      final width = height * safeMediaAspect;
      targetSize = Size(width, height);
    }
    
    // Safety check for final target size
    if (!targetSize.width.isFinite || !targetSize.height.isFinite ||
        targetSize.width <= 0 || targetSize.height <= 0) {
      targetSize = Size(safeCanvasSize.width * 0.8, safeCanvasSize.height * 0.8);
    }
    
    // Center position within canvas
    final centerX = (safeCanvasSize.width - targetSize.width) / 2;
    final centerY = (safeCanvasSize.height - targetSize.height) / 2;
    
    return CanvasTransform(
      position: Offset(centerX, centerY),
      size: targetSize,
    );
  }
  
  /// Copy with new values
  CanvasTransform copyWith({
    Offset? position,
    Size? size,
    double? scale,
    double? rotation,
    Rect? cropRect,
    double? opacity,
    bool? flipHorizontal,
    bool? flipVertical,
  }) {
    return CanvasTransform(
      position: position ?? this.position,
      size: size ?? this.size,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      cropRect: cropRect ?? this.cropRect,
      opacity: opacity ?? this.opacity,
      flipHorizontal: flipHorizontal ?? this.flipHorizontal,
      flipVertical: flipVertical ?? this.flipVertical,
    );
  }
  
  /// Get the actual render bounds considering scale
  Rect get renderBounds {
    final scaledWidth = size.width * scale;
    final scaledHeight = size.height * scale;
    return Rect.fromLTWH(
      position.dx,
      position.dy,
      scaledWidth,
      scaledHeight,
    );
  }
  
  /// Get center point for rotation
  Offset get rotationCenter {
    return Offset(
      position.dx + (size.width * scale) / 2,
      position.dy + (size.height * scale) / 2,
    );
  }
  
  /// Apply transformation to a canvas
  void applyToCanvas(Canvas canvas) {
    canvas.save();
    
    // Move to rotation center
    final center = rotationCenter;
    canvas.translate(center.dx, center.dy);
    
    // Apply rotation
    if (rotation != 0) {
      canvas.rotate(rotation);
    }
    
    // Apply flip
    if (flipHorizontal || flipVertical) {
      canvas.scale(
        flipHorizontal ? -1.0 : 1.0,
        flipVertical ? -1.0 : 1.0,
      );
    }
    
    // Move back from center
    canvas.translate(-center.dx, -center.dy);
    
    // Apply scale
    if (scale != 1.0) {
      canvas.scale(scale);
    }
  }
  
  /// Restore canvas after transformation
  void restoreCanvas(Canvas canvas) {
    canvas.restore();
  }
  
  /// Check if a point is within the transformed bounds
  bool containsPoint(Offset point) {
    if (rotation == 0) {
      return renderBounds.contains(point);
    }
    
    // For rotated bounds, transform point back to local space
    final center = rotationCenter;
    final dx = point.dx - center.dx;
    final dy = point.dy - center.dy;
    
    // Rotate point back
    final cos = math.cos(-rotation);
    final sin = math.sin(-rotation);
    final localX = dx * cos - dy * sin + center.dx;
    final localY = dx * sin + dy * cos + center.dy;
    
    return renderBounds.contains(Offset(localX, localY));
  }
  
  /// Get corner points for manipulation handles
  List<Offset> get cornerPoints {
    final bounds = renderBounds;
    final corners = [
      Offset(bounds.left, bounds.top), // Top-left
      Offset(bounds.right, bounds.top), // Top-right
      Offset(bounds.right, bounds.bottom), // Bottom-right
      Offset(bounds.left, bounds.bottom), // Bottom-left
    ];
    
    if (rotation != 0) {
      final center = rotationCenter;
      final cos = math.cos(rotation);
      final sin = math.sin(rotation);
      
      return corners.map((corner) {
        final dx = corner.dx - center.dx;
        final dy = corner.dy - center.dy;
        return Offset(
          dx * cos - dy * sin + center.dx,
          dx * sin + dy * cos + center.dy,
        );
      }).toList();
    }
    
    return corners;
  }
  
  /// Get rotation handle position (top center)
  Offset get rotationHandlePosition {
    final bounds = renderBounds;
    final handleOffset = Offset(bounds.center.dx, bounds.top - 30);
    
    if (rotation != 0) {
      final center = rotationCenter;
      final dx = handleOffset.dx - center.dx;
      final dy = handleOffset.dy - center.dy;
      final cos = math.cos(rotation);
      final sin = math.sin(rotation);
      
      return Offset(
        dx * cos - dy * sin + center.dx,
        dx * sin + dy * cos + center.dy,
      );
    }
    
    return handleOffset;
  }
  
  /// Convert to FFmpeg filter parameters
  String toFFmpegFilters({
    required Size outputSize,
    bool includePosition = true,
  }) {
    final filters = <String>[];
    
    // Apply crop first if needed
    if (cropRect != const Rect.fromLTWH(0, 0, 1, 1)) {
      final cropW = size.width * cropRect.width;
      final cropH = size.height * cropRect.height;
      final cropX = size.width * cropRect.left;
      final cropY = size.height * cropRect.top;
      filters.add('crop=$cropW:$cropH:$cropX:$cropY');
    }
    
    // Apply scale
    final scaledW = (size.width * scale).round();
    final scaledH = (size.height * scale).round();
    filters.add('scale=$scaledW:$scaledH');
    
    // Apply rotation
    if (rotation != 0) {
      final degrees = rotation * 180 / math.pi;
      filters.add('rotate=$degrees*PI/180');
    }
    
    // Apply flip
    if (flipHorizontal) {
      filters.add('hflip');
    }
    if (flipVertical) {
      filters.add('vflip');
    }
    
    // Apply position as overlay (needs to be done in export pipeline)
    if (includePosition) {
      final x = position.dx.round();
      final y = position.dy.round();
      // This will be used with overlay filter in the export pipeline
      filters.add('overlay=$x:$y');
    }
    
    return filters.join(',');
  }
  
  @override
  String toString() {
    return 'CanvasTransform(pos: $position, size: $size, scale: $scale, rotation: ${rotation * 180 / math.pi}°)';
  }
}