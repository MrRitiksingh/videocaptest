import 'package:flutter/material.dart';

/// Utility class for mapping cropped video regions to canvas coordinates
/// This implements the normalized crop approach from the plan
class CropCanvasMapper {
  /// Map a cropped video region to canvas coordinates with proper aspect ratio handling
  ///
  /// [cropRect] - Normalized crop rectangle (0-1 range) relative to original video
  /// [videoSize] - Original video dimensions
  /// [canvasSize] - Target canvas size (preview or export)
  /// [contain] - true for contain mode, false for fill mode
  static Rect mapCropToCanvas({
    required Rect cropRect,
    required Size videoSize,
    required Size canvasSize,
    bool contain = true,
  }) {
    // Step 1: Convert normalized crop to pixel coordinates in original video
    final cropPixel = Rect.fromLTWH(
      cropRect.left * videoSize.width,
      cropRect.top * videoSize.height,
      cropRect.width * videoSize.width,
      cropRect.height * videoSize.height,
    );

    // Step 2: Calculate scale factors to fit cropped region into canvas
    final scaleX = canvasSize.width / cropPixel.width;
    final scaleY = canvasSize.height / cropPixel.height;

    // Step 3: Choose scale based on contain/fill mode
    final scale = contain
        ? (scaleX < scaleY ? scaleX : scaleY)
        : // contain: use smaller scale
        (scaleX > scaleY ? scaleX : scaleY); // fill: use larger scale

    // Step 4: Calculate final size after scaling
    final scaledWidth = cropPixel.width * scale;
    final scaledHeight = cropPixel.height * scale;

    // Step 5: Center the scaled region in the canvas
    final centerX = (canvasSize.width - scaledWidth) / 2;
    final centerY = (canvasSize.height - scaledHeight) / 2;

    return Rect.fromLTWH(centerX, centerY, scaledWidth, scaledHeight);
  }

  /// Map cropped video to canvas with specific aspect ratio constraint
  ///
  /// [cropRect] - Normalized crop rectangle (0-1 range)
  /// [videoSize] - Original video dimensions
  /// [aspectRatio] - Target canvas aspect ratio
  /// [maxWidth] - Maximum width for the canvas
  /// [contain] - true for contain mode, false for fill mode
  static Rect mapCropToCanvasWithRatio({
    required Rect cropRect,
    required Size videoSize,
    required double aspectRatio,
    required double maxWidth,
    bool contain = true,
  }) {
    // Calculate canvas size based on aspect ratio
    final canvasSize =
        _calculateOptimalCanvasSize(Size(maxWidth, maxWidth), aspectRatio);

    return mapCropToCanvas(
      cropRect: cropRect,
      videoSize: videoSize,
      canvasSize: canvasSize,
      contain: contain,
    );
  }

  /// Calculate optimal canvas size that fits within container while maintaining aspect ratio
  static Size _calculateOptimalCanvasSize(
      Size containerSize, double aspectRatio) {
    // Safety checks
    if (containerSize.width <= 0 ||
        containerSize.height <= 0 ||
        !aspectRatio.isFinite ||
        aspectRatio <= 0) {
      return const Size(400, 300); // Safe fallback
    }

    final containerAspect = containerSize.width / containerSize.height;

    if (aspectRatio > containerAspect) {
      // Canvas is wider than container - fit to container width
      final width = containerSize.width;
      final height = width / aspectRatio;
      return Size(width, height);
    } else {
      // Canvas is taller than container - fit to container height
      final height = containerSize.height;
      final width = height * aspectRatio;
      return Size(width, height);
    }
  }

  /// Calculate the preview area for a cropped video in a container
  ///
  /// [cropRect] - Normalized crop rectangle (0-1 range)
  /// [videoSize] - Original video dimensions
  /// [containerSize] - Container size for preview
  /// [contain] - true for contain mode, false for fill mode
  static Rect calculateCroppedPreviewArea({
    required Rect cropRect,
    required Size videoSize,
    required Size containerSize,
    bool contain = true,
  }) {
    // First, calculate how the original video fits in the container
    final videoAspectRatio = videoSize.width / videoSize.height;
    final containerAspectRatio = containerSize.width / containerSize.height;

    double previewWidth, previewHeight, gapLeft, gapTop;

    if (videoAspectRatio > containerAspectRatio) {
      // Video is wider than container - fit to container width
      previewWidth = containerSize.width;
      previewHeight = containerSize.width / videoAspectRatio;
      gapLeft = 0;
      gapTop = (containerSize.height - previewHeight) / 2;
    } else {
      // Video is taller than container - fit to container height
      previewHeight = containerSize.height;
      previewWidth = containerSize.height * videoAspectRatio;
      gapLeft = (containerSize.width - previewWidth) / 2;
      gapTop = 0;
    }

    // Now map the cropped region to this preview area
    final cropPixel = Rect.fromLTWH(
      cropRect.left * videoSize.width,
      cropRect.top * videoSize.height,
      cropRect.width * videoSize.width,
      cropRect.height * videoSize.height,
    );

    // Calculate scale factors from video to preview
    final scaleX = previewWidth / videoSize.width;
    final scaleY = previewHeight / videoSize.height;

    // Map crop to preview coordinates
    final cropLeftInPreview = gapLeft + (cropRect.left * scaleX);
    final cropTopInPreview = gapTop + (cropRect.top * scaleY);
    final cropWidthInPreview = cropRect.width * scaleX;
    final cropHeightInPreview = cropRect.height * scaleY;

    return Rect.fromLTWH(
      cropLeftInPreview,
      cropTopInPreview,
      cropWidthInPreview,
      cropHeightInPreview,
    );
  }

  /// Generate FFmpeg crop and scale filter for export
  ///
  /// [cropRect] - Normalized crop rectangle (0-1 range)
  /// [videoSize] - Original video dimensions
  /// [targetSize] - Target export size
  /// [contain] - true for contain mode, false for fill mode
  static String generateFFmpegFilter({
    required Rect cropRect,
    required Size videoSize,
    required Size targetSize,
    bool contain = true,
  }) {
    // Convert normalized crop to pixel coordinates
    final cropX = (cropRect.left * videoSize.width).toInt();
    final cropY = (cropRect.top * videoSize.height).toInt();
    final cropWidth = (cropRect.width * videoSize.width).toInt();
    final cropHeight = (cropRect.height * videoSize.height).toInt();

    // Calculate scale factors
    final scaleX = targetSize.width / cropWidth;
    final scaleY = targetSize.height / cropHeight;
    final scale = contain
        ? (scaleX < scaleY ? scaleX : scaleY)
        : (scaleX > scaleY ? scaleX : scaleY);

    final scaledWidth = (cropWidth * scale).toInt();
    final scaledHeight = (cropHeight * scale).toInt();

    // Calculate padding to center the scaled video
    final padX = (targetSize.width - scaledWidth) / 2;
    final padY = (targetSize.height - scaledHeight) / 2;

    return 'crop=$cropWidth:$cropHeight:$cropX:$cropY,'
        'scale=$scaledWidth:$scaledHeight,'
        'pad=${targetSize.width.toInt()}:${targetSize.height.toInt()}:'
        '${padX.toInt()}:${padY.toInt()}:black';
  }

  /// Calculate the effective video area after cropping for text positioning
  ///
  /// [cropRect] - Normalized crop rectangle (0-1 range)
  /// [videoSize] - Original video dimensions
  /// [containerSize] - Container size for preview
  static Rect calculateEffectiveVideoArea({
    required Rect cropRect,
    required Size videoSize,
    required Size containerSize,
  }) {
    // Calculate the cropped preview area
    final croppedArea = calculateCroppedPreviewArea(
      cropRect: cropRect,
      videoSize: videoSize,
      containerSize: containerSize,
      contain: true,
    );

    return croppedArea;
  }

  /// Convert text position from original video space to cropped video space
  ///
  /// [textPosition] - Position in original video coordinates
  /// [cropRect] - Normalized crop rectangle (0-1 range)
  /// [videoSize] - Original video dimensions
  /// [containerSize] - Container size for preview
  static Offset convertTextPositionToCroppedSpace({
    required Offset textPosition,
    required Rect cropRect,
    required Size videoSize,
    required Size containerSize,
  }) {
    // Calculate the effective video area
    final effectiveArea = calculateEffectiveVideoArea(
      cropRect: cropRect,
      videoSize: videoSize,
      containerSize: containerSize,
    );

    // Convert text position to percentage within the cropped area
    final percentX =
        (textPosition.dx - effectiveArea.left) / effectiveArea.width;
    final percentY =
        (textPosition.dy - effectiveArea.top) / effectiveArea.height;

    // Clamp to valid range
    final clampedX = percentX.clamp(0.0, 1.0);
    final clampedY = percentY.clamp(0.0, 1.0);

    return Offset(clampedX, clampedY);
  }
}
