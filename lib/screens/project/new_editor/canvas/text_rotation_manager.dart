import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Manages text rotation calculations for canvas-based text overlays
class TextRotationManager {
  /// Calculate rotated text bounds (same logic for preview and export)
  static Map<String, double> calculateRotatedTextBounds({
    required double textWidth,
    required double textHeight,
    required double rotation,
  }) {
    if (rotation == 0) {
      return {
        'width': textWidth,
        'height': textHeight,
        'offsetX': 0.0,
        'offsetY': 0.0,
        'centerX': textWidth / 2,
        'centerY': textHeight / 2,
      };
    }

    final angleRad = rotation * math.pi / 180.0;
    final cosAngle = math.cos(angleRad);
    final sinAngle = math.sin(angleRad);

    // Calculate the corners of the original rectangle
    final corners = [
      [0.0, 0.0], // top-left
      [textWidth, 0.0], // top-right
      [textWidth, textHeight], // bottom-right
      [0.0, textHeight], // bottom-left
    ];

    // Rotate each corner and find the bounding box
    double minX = double.infinity;
    double maxX = -double.infinity;
    double minY = double.infinity;
    double maxY = -double.infinity;

    for (final corner in corners) {
      final x = corner[0];
      final y = corner[1];

      // Rotate the point around the center
      final rotatedX = x * cosAngle - y * sinAngle;
      final rotatedY = x * sinAngle + y * cosAngle;

      minX = math.min(minX, rotatedX);
      maxX = math.max(maxX, rotatedX);
      minY = math.min(minY, rotatedY);
      maxY = math.max(maxY, rotatedY);
    }

    // Calculate the dimensions of the bounding box
    final rotatedWidth = (maxX - minX).ceil().toDouble();
    final rotatedHeight = (maxY - minY).ceil().toDouble();

    // Calculate the offset needed to position the rotated text correctly
    final offsetX = (rotatedWidth - textWidth) / 2.0;
    final offsetY = (rotatedHeight - textHeight) / 2.0;

    return {
      'width': rotatedWidth,
      'height': rotatedHeight,
      'offsetX': offsetX,
      'offsetY': offsetY,
      'centerX': rotatedWidth / 2,
      'centerY': rotatedHeight / 2,
    };
  }

  /// Calculate adjusted position for rotated text
  static Offset calculateRotatedPosition({
    required Offset basePosition,
    required double textWidth,
    required double textHeight,
    required double rotation,
    required Size containerSize,
  }) {
    if (rotation == 0) return basePosition;

    final bounds = calculateRotatedTextBounds(
      textWidth: textWidth,
      textHeight: textHeight,
      rotation: rotation,
    );

    // Adjust position to account for rotation expansion
    final adjustedX = basePosition.dx - bounds['offsetX']!;
    final adjustedY = basePosition.dy - bounds['offsetY']!;

    // Ensure text stays within container bounds
    // Use more conservative clamping to prevent text from going outside visible area
    final minX = 0.0;
    final maxX = (containerSize.width - (bounds['width']! as num).toDouble())
        .clamp(0.0, containerSize.width);
    final minY = 0.0;
    final maxY = (containerSize.height - (bounds['height']! as num).toDouble())
        .clamp(0.0, containerSize.height);

    final clampedX = adjustedX.clamp(minX, maxX);
    final clampedY = adjustedY.clamp(minY, maxY);

    return Offset(clampedX, clampedY);
  }

  /// Calculate adjusted position for rotated text with video preview boundary constraints
  static Offset calculateRotatedPositionWithVideoBounds({
    required Offset basePosition,
    required double textWidth,
    required double textHeight,
    required double rotation,
    required Size containerSize,
    required Size videoSize,
    required Map<String, double> containerFitting,
    Rect? cropRect,
  }) {
    if (rotation == 0) return basePosition;

    final bounds = calculateRotatedTextBounds(
      textWidth: textWidth,
      textHeight: textHeight,
      rotation: rotation,
    );

    // Get video preview area boundaries
    final actualPreviewWidth = containerFitting['actualPreviewWidth']!;
    final actualPreviewHeight = containerFitting['actualPreviewHeight']!;
    final gapLeft = containerFitting['gapLeft']!;
    final gapTop = containerFitting['gapTop']!;

    // Adjust position to account for rotation expansion
    final adjustedX = basePosition.dx - bounds['offsetX']!;
    final adjustedY = basePosition.dy - bounds['offsetY']!;

    // Calculate boundaries within the actual video preview area (not full container)
    final minX = gapLeft;
    final maxX = gapLeft + actualPreviewWidth - bounds['width']!;
    final minY = gapTop;
    final maxY = gapTop + actualPreviewHeight - bounds['height']!;

    // Ensure text stays within video preview boundaries
    final clampedX = adjustedX.clamp(minX, maxX);
    final clampedY = adjustedY.clamp(minY, maxY);

    return Offset(clampedX, clampedY);
  }

  /// Calculate rotation center for canvas transformation
  static Offset calculateRotationCenter({
    required Offset textPosition,
    required double textWidth,
    required double textHeight,
    required double rotation,
  }) {
    if (rotation == 0) return textPosition;

    final bounds = calculateRotatedTextBounds(
      textWidth: textWidth,
      textHeight: textHeight,
      rotation: rotation,
    );

    return Offset(
      textPosition.dx + bounds['centerX']!,
      textPosition.dy + bounds['centerY']!,
    );
  }

  /// Apply rotation transformation to canvas
  static void applyRotationToCanvas({
    required Canvas canvas,
    required Offset rotationCenter,
    required double rotation,
  }) {
    if (rotation == 0) return;

    // Save canvas state
    canvas.save();

    // Apply rotation transformation
    canvas.translate(rotationCenter.dx, rotationCenter.dy);
    canvas.rotate(rotation * math.pi / 180);
    canvas.translate(-rotationCenter.dx, -rotationCenter.dy);
  }

  /// Restore canvas state after rotation
  static void restoreCanvasState(Canvas canvas) {
    canvas.restore();
  }

  /// Calculate text bounds considering rotation for boundary checking
  static Rect calculateTextBoundsWithRotation({
    required String text,
    required TextStyle style,
    required Offset position,
    required double rotation,
    required Size maxSize,
  }) {
    // Create TextPainter to measure text dimensions
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    textPainter.layout();

    final textWidth = textPainter.width;
    final textHeight = textPainter.height;
    textPainter.dispose();

    if (rotation == 0) {
      return Rect.fromLTWH(position.dx, position.dy, textWidth, textHeight);
    }

    // Calculate rotated bounds
    final rotatedBounds = calculateRotatedTextBounds(
      textWidth: textWidth,
      textHeight: textHeight,
      rotation: rotation,
    );

    final adjustedPosition = calculateRotatedPosition(
      basePosition: position,
      textWidth: textWidth,
      textHeight: textHeight,
      rotation: rotation,
      containerSize: maxSize,
    );

    return Rect.fromLTWH(
      adjustedPosition.dx,
      adjustedPosition.dy,
      rotatedBounds['width']!,
      rotatedBounds['height']!,
    );
  }

  /// Calculate the visual position where text appears after rotation
  /// This is the position that should be stored to match visual appearance
  static Offset calculateVisualPositionAfterRotation({
    required Offset originalPosition,
    required double textWidth,
    required double textHeight,
    required double rotation,
  }) {
    if (rotation == 0) return originalPosition;

    // For visual position storage, we want to store where the top-left corner
    // of the text appears after rotation. Since rotation happens around the center,
    // the visual position is the same as the original position for center-based rotation.
    // However, if the user drags during rotation, we need to account for that.

    // The key insight: For center-based rotation, the visual top-left position
    // after rotation is the same as the original position, but if there's translation
    // during rotation, we need to preserve that.

    return originalPosition;
  }

  /// Calculate the final visual position after rotation and potential translation
  /// This accounts for both rotation transform and any drag movement
  static Offset calculateFinalVisualPosition({
    required Offset basePosition,
    required Offset dragOffset,
    required double textWidth,
    required double textHeight,
    required double rotation,
  }) {
    // Apply drag offset to base position
    final draggedPosition = basePosition + dragOffset;

    // If no rotation, just return the dragged position
    if (rotation == 0) return draggedPosition;

    // For rotated text, the visual position is where the text appears
    // after both translation and rotation are applied
    return draggedPosition;
  }

}
