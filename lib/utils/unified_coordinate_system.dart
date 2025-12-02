import 'package:flutter/material.dart';

/// Unified coordinate system utility that consolidates multiple coordinate systems
/// and provides caching for performance optimization
class UnifiedCoordinateSystem {
  static final Map<String, dynamic> _cache = {};

  /// Cached coordinate conversions for container fitting calculations
  static Map<String, double> calculateContainerFitting({
    required double videoWidth,
    required double videoHeight,
    required double containerWidth,
    required double containerHeight,
    String? cacheKey,
  }) {
    final key = cacheKey ??
        '${videoWidth}x${videoHeight}_${containerWidth}x${containerHeight}';

    if (_cache.containsKey(key)) {
      return _cache[key];
    }

    final videoAspectRatio = videoWidth / videoHeight;
    final containerAspectRatio = containerWidth / containerHeight;

    double actualPreviewWidth, actualPreviewHeight, gapLeft = 0.0, gapTop = 0.0;

    if (videoAspectRatio > containerAspectRatio) {
      // Video is wider - fit width, letterbox top/bottom
      actualPreviewWidth = containerWidth;
      actualPreviewHeight = containerWidth / videoAspectRatio;
      gapTop = (containerHeight - actualPreviewHeight) / 2.0;
    } else {
      // Video is taller - fit height, letterbox left/right
      actualPreviewHeight = containerHeight;
      actualPreviewWidth = containerHeight * videoAspectRatio;
      gapLeft = (containerWidth - actualPreviewWidth) / 2.0;
    }

    final result = {
      'actualPreviewWidth': actualPreviewWidth,
      'actualPreviewHeight': actualPreviewHeight,
      'gapLeft': gapLeft,
      'gapTop': gapTop,
    };

    _cache[key] = result;
    return result;
  }

  /// Cached crop-adjusted container fitting calculations
  static Map<String, double> calculateCropAdjustedContainerFitting({
    required double videoWidth,
    required double videoHeight,
    required double containerWidth,
    required double containerHeight,
    required Rect cropRect,
    String? cacheKey,
  }) {
    final key = cacheKey ??
        'crop_${videoWidth}x${videoHeight}_${containerWidth}x${containerHeight}_${cropRect.left}_${cropRect.top}_${cropRect.width}_${cropRect.height}';

    if (_cache.containsKey(key)) {
      return _cache[key];
    }

    // First, calculate how the original video fits in the container
    final originalFitting = calculateContainerFitting(
      videoWidth: videoWidth,
      videoHeight: videoHeight,
      containerWidth: containerWidth,
      containerHeight: containerHeight,
    );

    final originalPreviewWidth = originalFitting['actualPreviewWidth']!;
    final originalPreviewHeight = originalFitting['actualPreviewHeight']!;
    final originalGapLeft = originalFitting['gapLeft']!;
    final originalGapTop = originalFitting['gapTop']!;

    // The preview container dimensions and gaps remain the SAME
    // Only the video content changes (shows cropped portion)
    final result = {
      'actualPreviewWidth': originalPreviewWidth,
      'actualPreviewHeight': originalPreviewHeight,
      'gapLeft': originalGapLeft,
      'gapTop': originalGapTop,
      'croppedVideoWidth': (cropRect.right - cropRect.left) * videoWidth,
      'croppedVideoHeight': (cropRect.bottom - cropRect.top) * videoHeight,
    };

    _cache[key] = result;
    return result;
  }

  /// Convert preview coordinates to video coordinates with caching
  static Offset calculateVideoPosition({
    required Offset previewPosition,
    required Size videoSize,
    required Size containerSize,
    required Offset gapOffset,
    String? cacheKey,
  }) {
    final key = cacheKey ??
        'video_pos_${videoSize.width}x${videoSize.height}_${containerSize.width}x${containerSize.height}_${gapOffset.dx}_${gapOffset.dy}';

    if (_cache.containsKey(key)) {
      final cached = _cache[key] as Map<String, double>;
      return Offset(cached['x']!, cached['y']!);
    }

    // Calculate video position
    final videoX = (previewPosition.dx - gapOffset.dx) /
        (containerSize.width - gapOffset.dx * 2) *
        videoSize.width;
    final videoY = (previewPosition.dy - gapOffset.dy) /
        (containerSize.height - gapOffset.dy * 2) *
        videoSize.height;

    final result = Offset(videoX, videoY);
    _cache[key] = {'x': videoX, 'y': videoY};

    return result;
  }

  /// Convert video coordinates to preview coordinates with caching
  static Offset calculatePreviewPosition({
    required Offset videoPosition,
    required Size videoSize,
    required Size containerSize,
    required Offset gapOffset,
    String? cacheKey,
  }) {
    final key = cacheKey ??
        'preview_pos_${videoSize.width}x${videoSize.height}_${containerSize.width}x${containerSize.height}_${gapOffset.dx}_${gapOffset.dy}';

    if (_cache.containsKey(key)) {
      final cached = _cache[key] as Map<String, double>;
      return Offset(cached['x']!, cached['y']!);
    }

    // Calculate preview position
    final previewX = (videoPosition.dx / videoSize.width) *
            (containerSize.width - gapOffset.dx * 2) +
        gapOffset.dx;
    final previewY = (videoPosition.dy / videoSize.height) *
            (containerSize.height - gapOffset.dy * 2) +
        gapOffset.dy;

    final result = Offset(previewX, previewY);
    _cache[key] = {'x': previewX, 'y': previewY};

    return result;
  }

  /// Calculate crop boundaries with performance optimization
  static Rect calculateCropBoundaries({
    required Size containerSize,
    required Size videoSize,
    required Rect? cropRect,
    required double boundaryBuffer,
    String? cacheKey,
  }) {
    if (cropRect == null) {
      // No crop - use normal fitting
      final containerFitting = calculateContainerFitting(
        videoWidth: videoSize.width,
        videoHeight: videoSize.height,
        containerWidth: containerSize.width,
        containerHeight: containerSize.height,
      );

      final actualPreviewWidth = containerFitting['actualPreviewWidth']!;
      final actualPreviewHeight = containerFitting['actualPreviewHeight']!;
      final gapLeft = containerFitting['gapLeft']!;
      final gapTop = containerFitting['gapTop']!;

      // No crop - return full preview area boundaries
      return Rect.fromLTWH(
        gapLeft,
        gapTop,
        actualPreviewWidth,
        actualPreviewHeight,
      );
    }

    // Use cached crop-adjusted fitting
    final croppedFitting = calculateCropAdjustedContainerFitting(
      videoWidth: videoSize.width,
      videoHeight: videoSize.height,
      containerWidth: containerSize.width,
      containerHeight: containerSize.height,
      cropRect: cropRect,
    );

    final actualPreviewWidth = croppedFitting['actualPreviewWidth']!;
    final actualPreviewHeight = croppedFitting['actualPreviewHeight']!;
    final gapLeft = croppedFitting['gapLeft']!;
    final gapTop = croppedFitting['gapTop']!;

    // Calculate boundaries based on the cropped video area
    final minX = gapLeft;
    final maxX = gapLeft + actualPreviewWidth;
    final minY = gapTop;
    final maxY = gapTop + actualPreviewHeight;

    return Rect.fromLTWH(minX, minY, maxX - minX, maxY - minY);
  }

  /// Clear all caches when needed (call when video changes or memory pressure)
  static void clearCache() {
    _cache.clear();
  }

  /// Get cache size for debugging
  static int get cacheSize => _cache.length;
}
