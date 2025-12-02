import 'package:flutter/material.dart';
import 'package:ai_video_creator_editor/screens/project/models/text_track_model.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/video_editor_provider.dart';
import 'canvas_coordinate_manager.dart';
import 'text_rotation_manager.dart';
import 'dart:math' as math;

/// Handles user interactions on canvas-based text overlays
class CanvasInteractionHandler {
  final VideoEditorProvider provider;
  final Size containerSize;
  final Size videoSize;
  final Offset gapOffset;
  final Rect? cropRect;

  CanvasInteractionHandler({
    required this.provider,
    required this.containerSize,
    required this.videoSize,
    required this.gapOffset,
    this.cropRect,
  });

  /// Handle text dragging on canvas
  void handleTextDrag(DragUpdateDetails details, TextTrackModel track) {
    // Calculate new position
    final newPosition = Offset(
      track.position.dx + details.delta.dx,
      track.position.dy + details.delta.dy,
    );

    // Validate and clamp coordinates
    final validatedPosition =
        CanvasCoordinateManager.validateAndClampCoordinates(
      position: newPosition,
      containerSize: containerSize,
      videoSize: videoSize,
      cropRect: cropRect,
      boundaryBuffer: 10.0,
      rotation: provider.videoEditorController?.rotation ?? 0,
    );

    // Update track position
    final updatedTrack = track.copyWith(position: validatedPosition);
    final index = provider.textTracks.indexOf(track);
    provider.updateTextTrackModel(index, updatedTrack);
  }

  /// Handle text rotation on canvas
  void handleTextRotation(double angle, TextTrackModel track) {
    // Update track rotation
    final updatedTrack = track.copyWith(rotation: angle);
    final index = provider.textTracks.indexOf(track);
    provider.updateTextTrackModel(index, updatedTrack);
  }

  /// Handle text selection/tap on canvas
  void handleTextTap(TapDownDetails details) {
    final tappedTrack = hitTestText(details.localPosition);
    if (tappedTrack != null) {
      // Select the tapped track
      final index = provider.textTracks.indexOf(tappedTrack);
      provider.setTextTrackIndex(index);
    }
  }

  /// Calculate hit testing for text elements
  TextTrackModel? hitTestText(Offset position) {
    for (final track in provider.textTracks) {
      if (_isTrackVisible(track)) {
        final textBounds = _calculateTextBounds(track);
        if (textBounds.contains(position)) {
          return track;
        }
      }
    }
    return null;
  }

  /// Check if track is currently visible
  bool _isTrackVisible(TextTrackModel track) {
    final currentTime = provider.currentVideoTime;
    final startTime = track.trimStartTime;
    final endTime = track.trimEndTime;
    return currentTime >= startTime && currentTime < endTime;
  }

  /// Calculate text bounds for hit testing
  Rect _calculateTextBounds(TextTrackModel track) {
    // Calculate font size
    final fontSize = _calculateFontSize(track);

    // Create text style
    final textStyle = TextStyle(
      fontSize: fontSize,
      fontFamily: track.fontFamily,
      height: 1.0,
    );

    // Calculate available space
    final availableSize = CanvasCoordinateManager.calculateAvailableSpace(
      textPosition: track.position,
      containerSize: containerSize,
      videoSize: videoSize,
      cropRect: cropRect,
      boundaryBuffer: 10.0,
      rotation: provider.videoEditorController?.rotation ?? 0,
    );

    // Get wrapped lines
    final wrappedLines = _getWrappedLines(track.text, availableSize, textStyle);

    // Calculate text dimensions
    final textWidth = _calculateMaxLineWidth(wrappedLines, textStyle);
    final textHeight = _calculateTextHeight(wrappedLines, textStyle);

    // Calculate position considering rotation
    final adjustedPosition =
        _calculateAdjustedPosition(track, textWidth, textHeight);

    // Return bounds
    if (track.rotation != 0) {
      // For rotated text, use rotated bounds
      final rotatedBounds = TextRotationManager.calculateRotatedTextBounds(
        textWidth: textWidth,
        textHeight: textHeight,
        rotation: track.rotation,
      );

      return Rect.fromLTWH(
        adjustedPosition.dx,
        adjustedPosition.dy,
        rotatedBounds['width']!,
        rotatedBounds['height']!,
      );
    } else {
      return Rect.fromLTWH(
        adjustedPosition.dx,
        adjustedPosition.dy,
        textWidth,
        textHeight,
      );
    }
  }

  /// Calculate font size for the track
  double _calculateFontSize(TextTrackModel track) {
    // Use the same font scaling logic as the painter
    if (provider.useCanvasForTextOverlays) {
      // For canvas mode, calculate preview font size
      return _calculatePreviewFontSize(track);
    } else {
      // Fallback to base font size
      return track.fontSize;
    }
  }

  /// Calculate preview font size using existing logic
  double _calculatePreviewFontSize(TextTrackModel track) {
    // This would use the same logic as FontScalingHelper
    // For now, return a reasonable scaled size
    final scaleFactor = containerSize.width / videoSize.width;
    return track.fontSize * scaleFactor;
  }

  /// Get wrapped text lines
  List<String> _getWrappedLines(String text, Size maxSize, TextStyle style) {
    // Import and use TextAutoWrapHelper here
    // For now, return single line
    return [text];
  }

  /// Calculate maximum line width
  double _calculateMaxLineWidth(List<String> lines, TextStyle style) {
    double maxWidth = 0;
    for (final line in lines) {
      final textPainter = TextPainter(
        text: TextSpan(text: line, style: style),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      maxWidth = math.max(maxWidth, textPainter.width);
      textPainter.dispose();
    }
    return maxWidth;
  }

  /// Calculate total text height
  double _calculateTextHeight(List<String> lines, TextStyle style) {
    if (lines.isEmpty) return 0;

    final textPainter = TextPainter(
      text: TextSpan(text: lines.first, style: style),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    final lineHeight = textPainter.height;
    textPainter.dispose();

    return lines.length * lineHeight;
  }

  /// Calculate adjusted position considering rotation
  Offset _calculateAdjustedPosition(
      TextTrackModel track, double textWidth, double textHeight) {
    if (track.rotation == 0) {
      return track.position;
    }

    // Calculate rotated bounds
    final rotatedBounds = TextRotationManager.calculateRotatedTextBounds(
      textWidth: textWidth,
      textHeight: textHeight,
      rotation: track.rotation,
    );

    // Adjust position for rotation
    final adjustedX = track.position.dx - rotatedBounds['offsetX']!;
    final adjustedY = track.position.dy - rotatedBounds['offsetY']!;

    return Offset(adjustedX, adjustedY);
  }

  /// Check if a position is within text bounds
  bool isPositionInTextBounds(Offset position, TextTrackModel track) {
    final textBounds = _calculateTextBounds(track);
    return textBounds.contains(position);
  }

  /// Get all visible text tracks at current time
  List<TextTrackModel> getVisibleTextTracks() {
    return provider.textTracks
        .where((track) => _isTrackVisible(track))
        .toList();
  }

  /// Calculate drag boundaries for a specific track
  Rect calculateDragBoundaries(TextTrackModel track) {
    if (cropRect == null) {
      // No crop - use normal fitting
      final containerFitting =
          CanvasCoordinateManager.calculateContainerFitting(
        videoWidth: videoSize.width,
        videoHeight: videoSize.height,
        containerWidth: containerSize.width,
        containerHeight: containerSize.height,
      );

      final actualPreviewWidth = containerFitting['actualPreviewWidth']!;
      final actualPreviewHeight = containerFitting['actualPreviewHeight']!;
      final gapLeft = containerFitting['gapLeft']!;
      final gapTop = containerFitting['gapTop']!;

      // No crop - use full video area boundaries
      final minX = gapLeft;
      final maxX = gapLeft + actualPreviewWidth;
      final minY = gapTop;
      final maxY = gapTop + actualPreviewHeight;

      return Rect.fromLTWH(minX, minY, maxX - minX, maxY - minY);
    }

    // --- CROP APPLIED ---
    // Use the exact same logic as the working non-canvas approach

    // First, calculate how the original video is displayed (same as no-crop)
    final videoAspectRatio = videoSize.width / videoSize.height;
    final containerAspectRatio = containerSize.width / containerSize.height;

    double actualPreviewWidth, actualPreviewHeight, gapLeft = 0.0, gapTop = 0.0;
    if (videoAspectRatio > containerAspectRatio) {
      // Original video is wider - fit width, letterbox top/bottom
      actualPreviewWidth = containerSize.width;
      actualPreviewHeight = containerSize.width / videoAspectRatio;
      gapTop = (containerSize.height - actualPreviewHeight) / 2.0;
    } else {
      // Original video is taller - fit height, letterbox left/right
      actualPreviewHeight = containerSize.height;
      actualPreviewWidth = containerSize.height * videoAspectRatio;
      gapLeft = (containerSize.width - actualPreviewWidth) / 2.0;
    }

    // Now use ONLY the original video display area as the container for the cropped video
    // This means the cropped video is constrained to the same area where original video was shown
    final cropAspectRatio = cropRect!.width / cropRect!.height;
    final videoDisplayAspectRatio = actualPreviewWidth / actualPreviewHeight;

    double croppedPreviewWidth,
        croppedPreviewHeight,
        croppedGapLeft = 0.0,
        croppedGapTop = 0.0;
    if (cropAspectRatio > videoDisplayAspectRatio) {
      // Crop is wider than video display area: fit width, letterbox top/bottom within video area
      croppedPreviewWidth = actualPreviewWidth;
      croppedPreviewHeight = actualPreviewWidth / cropAspectRatio;
      croppedGapTop = (actualPreviewHeight - croppedPreviewHeight) / 2.0;
    } else {
      // Crop is taller than video display area: fit height, letterbox left/right within video area
      croppedPreviewHeight = actualPreviewHeight;
      croppedPreviewWidth = actualPreviewHeight * cropAspectRatio;
      croppedGapLeft = (actualPreviewWidth - croppedPreviewWidth) / 2.0;
    }

    // Final position within the original video display area (not the full container)
    final finalGapLeft = gapLeft + croppedGapLeft;
    final finalGapTop = gapTop + croppedGapTop;

    // Calculate boundaries based on the cropped video area
    final minX = finalGapLeft;
    final maxX = finalGapLeft + croppedPreviewWidth;
    final minY = finalGapTop;
    final maxY = finalGapTop + croppedPreviewHeight;

    return Rect.fromLTWH(minX, minY, maxX - minX, maxY - minY);
  }
}
