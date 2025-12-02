import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Manages coordinate calculations for canvas-based text overlays and crop
///
/// KEY CONCEPT: The first time a video is fitted into a container determines the base container
/// for all subsequent operations (crop, rotation, etc.). This means:
///
/// 1. **Initial Fitting**: When a video is first loaded, it's fitted into the preview container
///    using letterboxing/pillarboxing as needed. This creates the "base container" with specific
///    dimensions and gaps.
///
/// 2. **Crop Operations**: When cropping is applied, the cropped video is fitted within the
///    SAME base container dimensions, not the full preview container.
///
/// 3. **Rotation Operations**: When rotation is applied, the rotated video is fitted within the
///    SAME base container dimensions, with gaps recalculated to center the rotated content.
///
/// 4. **Text Positioning**: All text positioning calculations use the current effective container
///    (which may be crop-adjusted or rotation-adjusted) but always within the original base container.
///
/// This ensures consistency and prevents text from jumping around when different operations are applied.
class CanvasCoordinateManager {
  /// Calculate container fitting parameters
  ///
  /// [videoWidth] - Full video width
  /// [videoHeight] - Full video height
  /// [containerWidth] - Preview container width
  /// [containerHeight] - Preview container height
  ///
  /// Returns container fitting parameters
  static Map<String, double> calculateContainerFitting({
    required double videoWidth,
    required double videoHeight,
    required double containerWidth,
    required double containerHeight,
  }) {
    print('=== BASIC CONTAINER FITTING CALCULATION DEBUG ===');
    print('Input parameters:');
    print('  Video width: $videoWidth');
    print('  Video height: $videoHeight');
    print('  Container width: $containerWidth');
    print('  Container height: $containerHeight');

    final videoAspectRatio = videoWidth / videoHeight;
    final containerAspectRatio = containerWidth / containerHeight;

    print('Aspect ratio calculations:');
    print(
        '  Video aspect ratio: $videoWidth / $videoHeight = $videoAspectRatio');
    print(
        '  Container aspect ratio: $containerWidth / $containerHeight = $containerAspectRatio');

    double actualPreviewWidth, actualPreviewHeight, gapLeft, gapTop;

    if (videoAspectRatio > containerAspectRatio) {
      // Video is wider - fit width, letterbox top/bottom
      print('Video is wider than container - fitting width:');
      actualPreviewWidth = containerWidth;
      actualPreviewHeight = containerWidth / videoAspectRatio;
      gapLeft = 0.0;
      gapTop = (containerHeight - actualPreviewHeight) / 2.0;

      print('  Fitting strategy: Fit width, letterbox top/bottom');
      print('  Actual preview width: $containerWidth (fits container width)');
      print(
          '  Actual preview height: $containerWidth / $videoAspectRatio = $actualPreviewHeight');
      print('  Gap left: 0.0 (no horizontal centering needed)');
      print(
          '  Gap top: ($containerHeight - $actualPreviewHeight) / 2.0 = $gapTop (centers height)');
    } else {
      // Video is taller - fit height, letterbox left/right
      print('Video is taller than container - fitting height:');
      actualPreviewHeight = containerHeight;
      actualPreviewWidth = containerHeight * videoAspectRatio;
      gapLeft = (containerWidth - actualPreviewWidth) / 2.0;
      gapTop = 0.0;

      print('  Fitting strategy: Fit height, letterbox left/right');
      print(
          '  Actual preview height: $containerHeight (fits container height)');
      print(
          '  Actual preview width: $containerHeight * $videoAspectRatio = $actualPreviewWidth');
      print(
          '  Gap left: ($containerWidth - $actualPreviewWidth) / 2.0 = $gapLeft (centers width)');
      print('  Gap top: 0.0 (no vertical centering needed)');
    }

    final result = {
      'actualPreviewWidth': actualPreviewWidth,
      'actualPreviewHeight': actualPreviewHeight,
      'gapLeft': gapLeft,
      'gapTop': gapTop,
    };

    print('Final result:');
    print('  actualPreviewWidth: $actualPreviewWidth');
    print('  actualPreviewHeight: $actualPreviewHeight');
    print('  gapLeft: $gapLeft');
    print('  gapTop: $gapTop');
    print('  Preview area: ${actualPreviewWidth} x ${actualPreviewHeight}');
    print('  Preview position: left=$gapLeft, top=$gapTop');
    print('  Container area: ${containerWidth} x ${containerHeight}');
    print('=== END BASIC CONTAINER FITTING CALCULATION DEBUG ===');

    return result;
  }

  /// Calculate crop-adjusted container fitting that shows only the cropped portion
  ///
  /// [videoWidth] - Full video width
  /// [videoHeight] - Full video height
  /// [containerWidth] - Preview container width
  /// [containerHeight] - Preview container height
  /// [cropRect] - Crop rectangle (can be in pixel coordinates or 0.0 to 1.0 coordinates)
  ///
  /// Returns crop-adjusted container fitting parameters
  /// ✅ FIXED: Now properly handles coordinate system offset when crop is applied from start
  /// This ensures that when cropRect.left = 0.0 and cropRect.top = 0.0, the coordinate system
  /// is properly adjusted to reflect that the cropped area gets centered in the preview
  static Map<String, double> calculateCropAdjustedContainerFitting({
    required double videoWidth,
    required double videoHeight,
    required Rect cropRect,
    required double containerWidth,
    required double containerHeight,
  }) {
    print('=== CROP-ADJUSTED CONTAINER FITTING CALCULATION DEBUG ===');
    print('Input parameters:');
    print('  Video width: $videoWidth');
    print('  Video height: $videoHeight');
    print('  Container width: $containerWidth');
    print('  Container height: $containerHeight');
    print(
        '  Crop rect: ${cropRect.left}, ${cropRect.top}, ${cropRect.right}, ${cropRect.bottom}');
    print('  Crop dimensions: ${cropRect.width} x ${cropRect.height}');

    // ✅ UNIVERSAL APPROACH: Always handle coordinate system offset for ANY crop
    // Every crop gets centered in the preview, so every crop needs offset calculation
    print(
        '  Universal crop handling: left=${cropRect.left}, top=${cropRect.top}');
    print('  Every crop gets centered - coordinate system offset needed');

    // Step 1: Determine if crop rect is in pixel coordinates or normalized coordinates
    bool isPixelCoordinates = false;
    if (cropRect.right > 1.0 || cropRect.bottom > 1.0) {
      isPixelCoordinates = true;
      print(
          '  Crop rect appears to be in PIXEL coordinates (values > 1.0 detected)');
    } else {
      print('  Crop rect appears to be in NORMALIZED coordinates (0.0 to 1.0)');
    }

    // Step 2: Calculate how the original video fits in the container (this gives us the target space)
    print('Step 2: Calculate original video fitting in container');
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

    print('Original video fitting results:');
    print('  Original preview width: $originalPreviewWidth');
    print('  Original preview height: $originalPreviewHeight');
    print('  Original gap left: $originalGapLeft');
    print('  Original gap top: $originalGapTop');

    // ✅ UNIVERSAL: Step 3: Always handle coordinate system offset for ANY crop
    print('Step 3: Handling coordinate system offset for ANY crop');
    print(
        '  When ANY crop is applied, the cropped area gets centered in the preview');
    print(
        '  This means the coordinate system shifts from the expected crop position');
    print(
        '  to the actual centered position, regardless of where the crop starts');

    // Calculate the scale factors from video to preview
    final scaleX = originalPreviewWidth / videoWidth;
    final scaleY = originalPreviewHeight / videoHeight;

    // Map the crop rectangle from video coordinates to preview coordinates
    final cropLeftInPreview = originalGapLeft + (cropRect.left * scaleX);
    final cropTopInPreview = originalGapTop + (cropRect.top * scaleY);
    final cropWidthInPreview = cropRect.width * scaleX;
    final cropHeightInPreview = cropRect.height * scaleY;

    print(
        '  Crop in preview: left=${cropLeftInPreview.toStringAsFixed(2)}, top=${cropTopInPreview.toStringAsFixed(2)}');
    print(
        '  Crop size in preview: ${cropWidthInPreview.toStringAsFixed(2)} x ${cropHeightInPreview.toStringAsFixed(2)}');

    // Now calculate how the cropped video fits within the original preview area
    final cropAspectRatio = cropWidthInPreview / cropHeightInPreview;
    final videoDisplayAspectRatio =
        originalPreviewWidth / originalPreviewHeight;

    double finalCropWidth, finalCropHeight, finalCropLeft, finalCropTop;

    if (cropAspectRatio > videoDisplayAspectRatio) {
      // Crop is wider - fit width, letterbox top/bottom within video area
      finalCropWidth = originalPreviewWidth;
      finalCropHeight = originalPreviewWidth / cropAspectRatio;
      finalCropTop =
          originalGapTop + (originalPreviewHeight - finalCropHeight) / 2.0;
      finalCropLeft = originalGapLeft;
    } else {
      // Crop is taller - fit height, letterbox left/right within video area
      finalCropHeight = originalPreviewHeight;
      finalCropWidth = originalPreviewHeight * cropAspectRatio;
      finalCropLeft =
          originalGapLeft + (originalPreviewWidth - finalCropWidth) / 2.0;
      finalCropTop = originalGapTop;
    }

    print(
        '  Final crop area: left=${finalCropLeft.toStringAsFixed(2)}, top=${finalCropTop.toStringAsFixed(2)}');
    print(
        '  Final crop size: ${finalCropWidth.toStringAsFixed(2)} x ${finalCropHeight.toStringAsFixed(2)}');

    // ✅ UNIVERSAL: Calculate the coordinate system offset for ANY crop
    // This is the difference between where the crop would be without centering
    // and where it actually gets positioned when centered in the preview
    final expectedCropLeft = originalGapLeft + (cropRect.left * scaleX);
    final expectedCropTop = originalGapTop + (cropRect.top * scaleY);

    final coordinateOffsetX = finalCropLeft - expectedCropLeft;
    final coordinateOffsetY = finalCropTop - expectedCropTop;

    print(
        '  Expected crop position: left=${expectedCropLeft.toStringAsFixed(2)}, top=${expectedCropTop.toStringAsFixed(2)}');
    print(
        '  Coordinate offset: X=${coordinateOffsetX.toStringAsFixed(2)}, Y=${coordinateOffsetY.toStringAsFixed(2)}');

    // ✅ UNIVERSAL: Return the FINAL cropped area with coordinate system offset already applied
    // This means text positions will automatically use the correct coordinate system
    final result = {
      'actualPreviewWidth': finalCropWidth, // Width of the cropped area
      'actualPreviewHeight': finalCropHeight, // Height of the cropped area
      'gapLeft': finalCropLeft, // Final gap left (includes centering offset)
      'gapTop': finalCropTop, // Final gap top (includes centering offset)
      'croppedVideoWidth': cropWidthInPreview,
      'croppedVideoHeight': cropHeightInPreview,
      'coordinateSystemOffsetX':
          coordinateOffsetX, // ✅ NEW: Store the offset for reference
      'coordinateSystemOffsetY':
          coordinateOffsetY, // ✅ NEW: Store the offset for reference
    };

    print('Final result (universal crop):');
    print(
        '  actualPreviewWidth: ${result['actualPreviewWidth']} (cropped area width)');
    print(
        '  actualPreviewHeight: ${result['actualPreviewHeight']} (cropped area height)');
    print('  gapLeft: ${result['gapLeft']} (includes centering offset)');
    print('  gapTop: ${result['gapTop']} (includes centering offset)');
    print('  croppedVideoWidth: ${result['croppedVideoWidth']}');
    print('  croppedVideoHeight: ${result['croppedVideoHeight']}');
    print('  coordinateSystemOffsetX: ${result['coordinateSystemOffsetX']}');
    print('  coordinateSystemOffsetY: ${result['coordinateSystemOffsetY']}');
    print('=== END CROP-ADJUSTED CONTAINER FITTING CALCULATION DEBUG ===');

    return result;
  }

  /// ✅ NEW: Calculate the correctly adjusted position based on crop position
  /// This determines whether to add or subtract the coordinate offset based on where the crop is applied
  static Offset _calculateCorrectlyAdjustedPosition({
    required Offset textPosition,
    required double coordinateOffsetX,
    required double coordinateOffsetY,
    required Rect cropRect,
    required Size videoSize,
  }) {
    // For X offset: always subtract (crop from left shifts coordinate system right)
    final adjustedX = textPosition.dx - coordinateOffsetX;

    // For Y offset: determine direction based on crop position
    double adjustedY;

    if (cropRect.top == 0.0) {
      // Crop from top (e.g., cropRect.top = 0.0): coordinate system shifts DOWNWARD
      // So we need to SUBTRACT the offset (negative offset becomes positive shift)
      adjustedY = textPosition.dy - coordinateOffsetY;
    } else if (cropRect.bottom >= videoSize.height * 0.9) {
      // Crop from bottom (e.g., cropRect.bottom close to video height): coordinate system shifts UPWARD
      // So we need to ADD the offset (negative offset becomes negative shift)
      adjustedY = textPosition.dy + coordinateOffsetY;
    } else {
      // Middle crop: coordinate system shifts DOWNWARD (default behavior)
      adjustedY = textPosition.dy - coordinateOffsetY;
    }

    return Offset(adjustedX, adjustedY);
  }

  /// Calculate rotation-aware container fitting parameters
  ///
  /// [videoWidth] - Full video width
  /// [videoHeight] - Full video height
  /// [containerWidth] - Preview container width
  /// [containerHeight] - Preview container height
  /// [rotation] - Video rotation in degrees (0, 90, 180, 270)
  ///
  /// Returns rotation-aware container fitting parameters
  static Map<String, double> calculateRotationAwareContainerFitting({
    required double videoWidth,
    required double videoHeight,
    required double containerWidth,
    required double containerHeight,
    required int rotation,
  }) {
    // For 90° and 270° rotation, swap video dimensions
    double effectiveVideoWidth, effectiveVideoHeight;
    if (rotation == 90 || rotation == 270) {
      effectiveVideoWidth = videoHeight;
      effectiveVideoHeight = videoWidth;
    } else {
      effectiveVideoWidth = videoWidth;
      effectiveVideoHeight = videoHeight;
    }

    final videoAspectRatio = effectiveVideoWidth / effectiveVideoHeight;
    final containerAspectRatio = containerWidth / containerHeight;

    double actualPreviewWidth, actualPreviewHeight, gapLeft, gapTop;

    if (videoAspectRatio > containerAspectRatio) {
      // Rotated video is wider - fit width, letterbox top/bottom
      actualPreviewWidth = containerWidth;
      actualPreviewHeight = containerWidth / videoAspectRatio;
      gapLeft = 0.0;
      gapTop = (containerHeight - actualPreviewHeight) / 2.0;
    } else {
      // Rotated video is taller - fit height, letterbox left/right
      actualPreviewHeight = containerHeight;
      actualPreviewWidth = containerHeight * videoAspectRatio;
      gapLeft = (containerWidth - actualPreviewWidth) / 2.0;
      gapTop = 0.0;
    }

    return {
      'actualPreviewWidth': actualPreviewWidth,
      'actualPreviewHeight': actualPreviewHeight,
      'gapLeft': gapLeft,
      'gapTop': gapTop,
      'effectiveVideoWidth': effectiveVideoWidth,
      'effectiveVideoHeight': effectiveVideoHeight,
    };
  }

  /// Calculate rotation-aware crop-adjusted container fitting
  ///
  /// [videoWidth] - Full video width
  /// [videoHeight] - Full video height
  /// [containerWidth] - Preview container width
  /// [containerHeight] - Preview container height
  /// [cropRect] - Crop rectangle (can be in pixel coordinates or 0.0 to 1.0 coordinates)
  /// [rotation] - Video rotation in degrees (0, 90, 180, 270)
  ///
  /// Returns rotation-aware crop-adjusted container fitting parameters
  static Map<String, double>
      calculateRotationAwareCropAdjustedContainerFitting({
    required double videoWidth,
    required double videoHeight,
    required double containerWidth,
    required double containerHeight,
    required Rect cropRect,
    required int rotation,
  }) {
    print(
        '=== ROTATION-AWARE CROP-ADJUSTED CONTAINER FITTING CALCULATION DEBUG ===');
    print('Input parameters:');
    print('  Video width: $videoWidth');
    print('  Video height: $videoHeight');
    print('  Container width: $containerWidth');
    print('  Container height: $containerHeight');
    print(
        '  Crop rect: ${cropRect.left}, ${cropRect.top}, ${cropRect.right}, ${cropRect.bottom}');
    print('  Crop dimensions: ${cropRect.width} x ${cropRect.height}');
    print('  Rotation: $rotation degrees');

    // Step 1: Determine if crop rect is in pixel coordinates or normalized coordinates
    bool isPixelCoordinates = false;
    if (cropRect.right > 1.0 || cropRect.bottom > 1.0) {
      isPixelCoordinates = true;
      print(
          '  Crop rect appears to be in PIXEL coordinates (values > 1.0 detected)');
    } else {
      print('  Crop rect appears to be in NORMALIZED coordinates (0.0 to 1.0)');
    }

    // Step 2: Calculate how the ORIGINAL video fits in the container (this is our base container)
    print(
        'Step 2: Calculate ORIGINAL video fitting in container (this becomes our base container)');
    print(
        '  IMPORTANT: This base container is used for ALL subsequent operations (crop, rotation)');
    print(
        '  The rotated video will be fitted within these original dimensions, not the full preview container');

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

    print('Original video fitting results (this is our base container):');
    print('  Original preview width: $originalPreviewWidth');
    print('  Original preview height: $originalPreviewHeight');
    print('  Original gap left: $originalGapLeft');
    print('  Original gap top: $originalGapTop');
    print(
        '  Original preview area: ${originalPreviewWidth} x ${originalPreviewHeight}');
    print(
        '  Original preview position: left=${originalGapLeft}, top=${originalGapTop}');

    // ✅ FIXED: Step 3: First rotate the CROP dimensions, then fit within the base container
    print(
        'Step 3: First rotate the CROP dimensions, then fit within the base container');

    // Calculate the effective crop dimensions after rotation
    double rotatedCropWidth, rotatedCropHeight;
    if (rotation == 90 || rotation == 270) {
      // For 90° and 270° rotation, swap crop dimensions
      rotatedCropWidth = cropRect.height;
      rotatedCropHeight = cropRect.width;
      print('  Rotation ${rotation}° detected - swapping crop dimensions:');
      print('    Original crop: ${cropRect.width} x ${cropRect.height}');
      print('    Rotated crop: ${rotatedCropWidth} x ${rotatedCropHeight}');
    } else {
      // For 0° and 180° rotation, keep original crop dimensions
      rotatedCropWidth = cropRect.width;
      rotatedCropHeight = cropRect.height;
      print('  No dimension swap needed for rotation ${rotation}°:');
      print('    Rotated crop: ${rotatedCropWidth} x ${rotatedCropHeight}');
    }

    // ✅ FIXED: Calculate how the ROTATED CROP fits within the ORIGINAL base container
    print(
        'Step 4: Calculate how ROTATED CROP fits within the ORIGINAL base container');

    // Calculate the aspect ratio of the rotated crop
    final rotatedCropAspectRatio = rotatedCropWidth / rotatedCropHeight;
    final baseContainerAspectRatio =
        originalPreviewWidth / originalPreviewHeight;

    print('Aspect ratio calculations:');
    print(
        '  Rotated crop aspect ratio: ${rotatedCropWidth} / ${rotatedCropHeight} = $rotatedCropAspectRatio');
    print(
        '  Base container aspect ratio: ${originalPreviewWidth} / ${originalPreviewHeight} = $baseContainerAspectRatio');

    double rotatedPreviewWidth,
        rotatedPreviewHeight,
        rotatedGapLeft,
        rotatedGapTop;

    if (rotatedCropAspectRatio > baseContainerAspectRatio) {
      // Rotated crop is wider than base container - fit width, letterbox top/bottom within base container
      rotatedPreviewWidth = originalPreviewWidth;
      rotatedPreviewHeight = originalPreviewWidth / rotatedCropAspectRatio;
      rotatedGapLeft = 0.0; // No horizontal centering needed
      rotatedGapTop = (originalPreviewHeight - rotatedPreviewHeight) /
          2.0; // Center height within base container

      print('Rotated crop is wider than base container - fitting width:');
      print(
          '  Rotated preview width: $rotatedPreviewWidth (fits base container width)');
      print(
          '  Rotated preview height: $rotatedPreviewHeight (calculated from aspect ratio)');
      print('  Rotated gap left: 0.0 (no horizontal centering needed)');
      print(
          '  Rotated gap top: (${originalPreviewHeight} - $rotatedPreviewHeight) / 2.0 = $rotatedGapTop (centers height within base container)');
    } else {
      // Rotated crop is taller than base container - fit height, letterbox left/right within base container
      rotatedPreviewHeight = originalPreviewHeight;
      rotatedPreviewWidth = originalPreviewHeight * rotatedCropAspectRatio;
      rotatedGapLeft = (originalPreviewWidth - rotatedPreviewWidth) /
          2.0; // Center width within base container
      rotatedGapTop = 0.0; // No vertical centering needed

      print('Rotated crop is taller than base container - fitting height:');
      print(
          '  Rotated preview height: $rotatedPreviewHeight (fits base container height)');
      print(
          '  Rotated preview width: $rotatedPreviewHeight * $rotatedCropAspectRatio = $rotatedPreviewWidth');
      print(
          '  Rotated gap left: (${originalPreviewWidth} - $rotatedPreviewWidth) / 2.0 = $rotatedGapLeft (centers width within base container)');
      print('  Rotated gap top: 0.0 (no vertical centering needed)');
    }

    // ✅ FIXED: Step 5: Calculate the FINAL gaps by combining original container gaps with rotated crop gaps
    final finalGapLeft = originalGapLeft + rotatedGapLeft;
    final finalGapTop = originalGapTop + rotatedGapTop;

    print(
        'Step 5: Calculate FINAL gaps by combining original container gaps with rotated crop gaps');
    print('  Original gap left: $originalGapLeft');
    print('  Original gap top: $originalGapTop');
    print('  Rotated crop gap left: $rotatedGapLeft');
    print('  Rotated crop gap top: $rotatedGapTop');
    print(
        '  Final gap left: $originalGapLeft + $rotatedGapLeft = $finalGapLeft');
    print('  Final gap top: $originalGapTop + $rotatedGapTop = $finalGapTop');

    // Step 6: Calculate the actual cropped video dimensions in pixels
    double croppedVideoWidth, croppedVideoHeight;
    if (isPixelCoordinates) {
      // Crop rect is already in pixel coordinates
      croppedVideoWidth = rotatedCropWidth; // Use rotated crop dimensions
      croppedVideoHeight = rotatedCropHeight;
      print(
          'Step 6: Crop rect is in pixel coordinates - using rotated dimensions');
      print('  Rotated crop width: ${rotatedCropWidth} pixels');
      print('  Rotated crop height: ${rotatedCropHeight} pixels');
    } else {
      // Crop rect is in normalized coordinates (0.0 to 1.0)
      croppedVideoWidth = (cropRect.right - cropRect.left) * rotatedCropWidth;
      croppedVideoHeight = (cropRect.bottom - cropRect.top) * rotatedCropHeight;
      print(
          'Step 6: Crop rect is in normalized coordinates - converting to pixels (using rotated dimensions)');
      print('  Crop width ratio: ${cropRect.width}');
      print('  Crop height ratio: ${cropRect.height}');
      print(
          '  Cropped video width: ${cropRect.width} * $rotatedCropWidth = $croppedVideoWidth');
      print(
          '  Cropped video height: ${cropRect.height} * $rotatedCropHeight = $croppedVideoHeight');
    }

    final result = {
      'actualPreviewWidth':
          rotatedPreviewWidth, // Width of rotated crop within base container
      'actualPreviewHeight':
          rotatedPreviewHeight, // Height of rotated crop within base container
      'gapLeft': finalGapLeft, // Final gap left (original + rotated crop)
      'gapTop': finalGapTop, // Final gap top (original + rotated crop)
      'croppedVideoWidth': croppedVideoWidth,
      'croppedVideoHeight': croppedVideoHeight,
      'effectiveVideoWidth': rotatedCropWidth,
      'effectiveVideoHeight': rotatedCropHeight,
      'coordinateSystemOffsetX':
          0.0, // ✅ NEW: No offset for rotation-aware crops
      'coordinateSystemOffsetY':
          0.0, // ✅ NEW: No offset for rotation-aware crops
    };

    print('Final result:');
    print(
        '  actualPreviewWidth: ${result['actualPreviewWidth']} (rotated crop width within base container)');
    print(
        '  actualPreviewHeight: ${result['actualPreviewHeight']} (rotated crop height within base container)');
    print('  gapLeft: ${result['gapLeft']} (final gap left)');
    print('  gapTop: ${result['gapTop']} (final gap top)');
    print('  croppedVideoWidth: ${result['croppedVideoWidth']}');
    print('  croppedVideoHeight: ${result['croppedVideoHeight']}');
    print('  effectiveVideoWidth: ${result['effectiveVideoWidth']}');
    print('  effectiveVideoHeight: ${result['effectiveVideoHeight']}');
    print('  isPixelCoordinates: $isPixelCoordinates (debug info)');
    print(
        '=== END ROTATION-AWARE CROP-ADJUSTED CONTAINER FITTING CALCULATION DEBUG ===');

    return result;
  }

  /// Convert preview coordinates to video coordinates
  static Offset calculateVideoPosition({
    required Offset previewPosition,
    required Size videoSize,
    required Size containerSize,
    required Offset gapOffset,
  }) {
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

    // Adjust for letterboxing/pillarboxing
    final adjustedPositionX = previewPosition.dx - gapLeft;
    final adjustedPositionY = previewPosition.dy - gapTop;

    // Map to full video coordinates
    final videoX = adjustedPositionX * (videoSize.width / actualPreviewWidth);
    final videoY = adjustedPositionY * (videoSize.height / actualPreviewHeight);

    return Offset(videoX, videoY);
  }

  /// Handle crop coordinate transformations
  static Offset calculateCropAdjustedPosition({
    required Offset basePosition,
    required Rect? cropRect,
    required Size containerSize,
    required Size videoSize,
  }) {
    if (cropRect == null) {
      return basePosition;
    }

    // Calculate how the original video fits in the container
    final originalFitting = calculateContainerFitting(
      videoWidth: videoSize.width,
      videoHeight: videoSize.height,
      containerWidth: containerSize.width,
      containerHeight: containerSize.height,
    );

    final originalGapLeft = originalFitting['gapLeft']!;
    final originalGapTop = originalFitting['gapTop']!;

    // Calculate how the cropped video fits in the container
    final croppedFitting = calculateCropAdjustedContainerFitting(
      videoWidth: videoSize.width,
      videoHeight: videoSize.height,
      containerWidth: containerSize.width,
      containerHeight: containerSize.height,
      cropRect: cropRect,
    );

    final croppedPreviewWidth = croppedFitting['actualPreviewWidth']!;
    final croppedPreviewHeight = croppedFitting['actualPreviewHeight']!;
    final croppedGapLeft = croppedFitting['gapLeft']!;
    final croppedGapTop = croppedFitting['gapTop']!;

    // Convert from preview coordinates to original video space
    final videoPosition = calculateVideoPosition(
      previewPosition: basePosition,
      videoSize: videoSize,
      containerSize: containerSize,
      gapOffset: Offset(originalGapLeft, originalGapTop),
    );

    // Convert from original video space to crop space
    final cropSpaceX = videoPosition.dx - (cropRect.left * videoSize.width);
    final cropSpaceY = videoPosition.dy - (cropRect.top * videoSize.height);

    // Map to cropped video coordinates (0.0 to 1.0)
    final croppedVideoX =
        cropSpaceX / ((cropRect.right - cropRect.left) * videoSize.width);
    final croppedVideoY =
        cropSpaceY / ((cropRect.bottom - cropRect.top) * videoSize.height);

    // Scale to final container coordinates using the CROPPED preview dimensions
    final finalX = (croppedVideoX * croppedPreviewWidth) + croppedGapLeft;
    final finalY = (croppedVideoY * croppedPreviewHeight) + croppedGapTop;

    return Offset(finalX, finalY);
  }

  /// Calculate available space for text wrapping
  static Size calculateAvailableSpace({
    required Offset textPosition,
    required Size containerSize,
    required Size videoSize,
    required Rect? cropRect,
    required double boundaryBuffer,
    int rotation = 0,
    Map<String, double>? preCalculatedContainerFitting,
  }) {
    print('=== AVAILABLE SPACE CALCULATION DEBUG ===');
    print('Input parameters:');
    print('  Text position: (${textPosition.dx}, ${textPosition.dy})');
    print('  Container size: ${containerSize.width} x ${containerSize.height}');
    print('  Video size: ${videoSize.width} x ${videoSize.height}');
    print('  Crop rect: $cropRect');
    print('  Rotation: $rotation degrees');
    print('  Boundary buffer: $boundaryBuffer');
    print('  Pre-calculated fitting: ${preCalculatedContainerFitting != null}');

    if (cropRect == null) {
      print('=== NO CROP SCENARIO ===');
      // Use pre-calculated container fitting if provided, otherwise calculate it
      final containerFitting = preCalculatedContainerFitting ??
          (rotation != 0
              ? calculateRotationAwareContainerFitting(
                  videoWidth: videoSize.width,
                  videoHeight: videoSize.height,
                  containerWidth: containerSize.width,
                  containerHeight: containerSize.height,
                  rotation: rotation,
                )
              : calculateContainerFitting(
                  videoWidth: videoSize.width,
                  videoHeight: videoSize.height,
                  containerWidth: containerSize.width,
                  containerHeight: containerSize.height,
                ));

      final actualPreviewWidth = containerFitting['actualPreviewWidth']!;
      final actualPreviewHeight = containerFitting['actualPreviewHeight']!;
      final gapLeft = containerFitting['gapLeft']!;
      final gapTop = containerFitting['gapTop']!;

      print('Container fitting results:');
      print('  Actual preview width: $actualPreviewWidth');
      print('  Actual preview height: $actualPreviewHeight');
      print('  Gap left: $gapLeft');
      print('  Gap top: $gapTop');

      // For rotation, we need to consider the effective video dimensions
      // The rotated video might have different display area than the container
      double effectivePreviewWidth, effectivePreviewHeight;

      if (rotation != 0) {
        // For rotated video, the effective dimensions are what actually gets displayed
        // This accounts for letterboxing/pillarboxing due to rotation
        effectivePreviewWidth = actualPreviewWidth;
        effectivePreviewHeight = actualPreviewHeight;
        print('Rotation detected - using effective dimensions:');
        print('  Effective preview width: $effectivePreviewWidth');
        print('  Effective preview height: $effectivePreviewHeight');
      } else {
        // No rotation - use full preview area
        effectivePreviewWidth = actualPreviewWidth;
        effectivePreviewHeight = actualPreviewHeight;
        print('No rotation - using full preview area:');
        print('  Effective preview width: $effectivePreviewWidth');
        print('  Effective preview height: $effectivePreviewHeight');
      }

      // Calculate boundaries using effective dimensions
      final maxX = gapLeft + effectivePreviewWidth;
      final maxY = gapTop + effectivePreviewHeight;

      print('Boundary calculations:');
      print('  Min X (gap left): $gapLeft');
      print('  Max X (gap left + effective width): $maxX');
      print('  Min Y (gap top): $gapTop');
      print('  Max Y (gap top + effective height): $maxY');

      // Calculate available space from current position to boundaries
      // IMPORTANT: For rotated videos, we need to constrain to the actual preview area
      final availableWidth = maxX - textPosition.dx - boundaryBuffer;
      final availableHeight = maxY - textPosition.dy - boundaryBuffer;

      print('Available space calculation:');
      print(
          '  Available width: $maxX - ${textPosition.dx} - $boundaryBuffer = $availableWidth');
      print(
          '  Available height: $maxY - ${textPosition.dy} - $boundaryBuffer = $availableHeight');

      // Debug logging for rotation scenarios
      if (rotation != 0) {
        print('=== ROTATION-AWARE AVAILABLE SPACE DEBUG ===');
        print(
            'Container size: ${containerSize.width} x ${containerSize.height}');
        print('Video size: ${videoSize.width} x ${videoSize.height}');
        print('Rotation: $rotation degrees');
        print(
            'Using pre-calculated container fitting: ${preCalculatedContainerFitting != null}');
        print(
            'Container fitting - actualPreviewWidth: $actualPreviewWidth, actualPreviewHeight: $actualPreviewHeight');
        print('Container fitting - gapLeft: $gapLeft, gapTop: $gapTop');
        print(
            'Effective preview dimensions: ${effectivePreviewWidth} x ${effectivePreviewHeight}');
        print('Text position: $textPosition');
        print(
            'Boundaries - minX: $gapLeft, maxX: $maxX, minY: $gapTop, maxY: $maxY');
        print(
            'Available space before clamping: ${availableWidth} x ${availableHeight}');
        print(
            'Available space after clamping: ${availableWidth.clamp(0, effectivePreviewWidth)} x ${availableHeight.clamp(0, effectivePreviewHeight)}');
        print('=== END ROTATION-AWARE AVAILABLE SPACE DEBUG ===');
      }

      // Clamp available space to the actual preview dimensions
      // This prevents text from extending beyond the rotated video boundaries
      final finalSize = Size(
        availableWidth.clamp(0, effectivePreviewWidth),
        availableHeight.clamp(0, effectivePreviewHeight),
      );

      print('Final available space (clamped):');
      print('  Width: ${finalSize.width}');
      print('  Height: ${finalSize.height}');
      print('=== END NO CROP SCENARIO ===');
      print('=== END AVAILABLE SPACE CALCULATION DEBUG ===');

      return finalSize;
    }

    // --- CROP APPLIED ---
    print('=== CROP APPLIED SCENARIO ===');
    print('Crop rect details:');
    print('  Crop left: ${cropRect.left}');
    print('  Crop top: ${cropRect.top}');
    print('  Crop right: ${cropRect.right}');
    print('  Crop bottom: ${cropRect.bottom}');
    print('  Crop width: ${cropRect.width}');
    print('  Crop height: ${cropRect.height}');
    print('  Crop aspect ratio: ${cropRect.width / cropRect.height}');

    // Use rotation-aware crop-adjusted fitting
    final containerFitting = rotation != 0
        ? calculateRotationAwareCropAdjustedContainerFitting(
            videoWidth: videoSize.width,
            videoHeight: videoSize.height,
            containerWidth: containerSize.width,
            containerHeight: containerSize.height,
            cropRect: cropRect,
            rotation: rotation,
          )
        : calculateCropAdjustedContainerFitting(
            videoWidth: videoSize.width,
            videoHeight: videoSize.height,
            containerWidth: containerSize.width,
            containerHeight: containerSize.height,
            cropRect: cropRect,
          );

    final actualPreviewWidth = containerFitting['actualPreviewWidth']!;
    final actualPreviewHeight = containerFitting['actualPreviewHeight']!;
    final gapLeft = containerFitting['gapLeft']!;
    final gapTop = containerFitting['gapTop']!;

    print('Container fitting results (crop-adjusted):');
    print('  Actual preview width: $actualPreviewWidth');
    print('  Actual preview height: $actualPreviewHeight');
    print('  Gap left: $gapLeft');
    print('  Gap top: $gapTop');

    // ✅ FIXED: For rotation-aware fitting, the gaps already include both original container gaps AND rotation adjustments
    // We should NOT recalculate crop gaps on top of this
    if (rotation != 0) {
      print(
          '  IMPORTANT: Using rotation-aware fitting - gaps already include rotation adjustments');
      print(
          '  No need to recalculate crop gaps - using pre-calculated values directly');

      // ✅ FIXED: Check if we have coordinate system offset from crop from start
      final coordinateOffsetX =
          containerFitting['coordinateSystemOffsetX'] ?? 0.0;
      final coordinateOffsetY =
          containerFitting['coordinateSystemOffsetY'] ?? 0.0;

      if (coordinateOffsetX != 0.0 || coordinateOffsetY != 0.0) {
        print(
            '  Coordinate system offset detected: X=$coordinateOffsetX, Y=$coordinateOffsetY');
        print(
            '  This indicates crop was applied from start - adjusting text position');

        // Adjust text position by the coordinate system offset
        // ✅ FIXED: Determine the correct direction based on crop position
        final adjustedTextPosition = _calculateCorrectlyAdjustedPosition(
          textPosition: textPosition,
          coordinateOffsetX: coordinateOffsetX,
          coordinateOffsetY: coordinateOffsetY,
          cropRect: cropRect,
          videoSize: videoSize,
        );
        print('  Original text position: $textPosition');
        print('  Adjusted text position: $adjustedTextPosition');

        // Use adjusted position for calculations
        final minX = gapLeft;
        final maxX = gapLeft + actualPreviewWidth;
        final minY = gapTop;
        final maxY = gapTop + actualPreviewHeight;

        print('Final crop area boundaries (using adjusted position):');
        print('  Min X: $minX');
        print('  Max X: $maxX');
        print('  Min Y: $minY');
        print('  Max Y: $maxY');
        print('  Final crop area: ${maxX - minX} x ${maxY - minY}');

        // Calculate available space using the adjusted position
        final availableWidth = maxX - adjustedTextPosition.dx - boundaryBuffer;
        final availableHeight = maxY - adjustedTextPosition.dy - boundaryBuffer;

        print('Available space calculation (using adjusted position):');
        print(
            '  Available width: $maxX - ${adjustedTextPosition.dx} - $boundaryBuffer = $availableWidth');
        print(
            '  Available height: $maxY - ${adjustedTextPosition.dy} - $boundaryBuffer = $availableHeight');

        final finalSize = Size(
          availableWidth.clamp(0, actualPreviewWidth),
          availableHeight.clamp(0, actualPreviewHeight),
        );

        print('Final available space (clamped to pre-calculated dimensions):');
        print(
            '  Width: $availableWidth clamped to [0, $actualPreviewWidth] = ${finalSize.width}');
        print(
            '  Height: $availableHeight clamped to [0, $actualPreviewHeight] = ${finalSize.height}');
        print('=== END CROP APPLIED SCENARIO ===');
        print('=== END AVAILABLE SPACE CALCULATION DEBUG ===');

        return finalSize;
      } else {
        print('  No coordinate system offset - using standard calculation');

        // Use the pre-calculated gaps directly (they already include everything)
        final minX = gapLeft;
        final maxX = gapLeft + actualPreviewWidth;
        final minY = gapTop;
        final maxY = gapTop + actualPreviewHeight;

        print(
            'Final crop area boundaries (using pre-calculated rotation-aware fitting):');
        print('  Min X: $minX');
        print('  Max X: $maxX');
        print('  Min Y: $minY');
        print('  Max Y: $maxY');
        print('  Final crop area: ${maxX - minX} x ${maxY - minY}');

        // For rotated video, use the container fitting directly
        final remappedPosition = textPosition;
        print('Rotation detected - using container fitting directly:');
        print('  Remapped position: $remappedPosition (same as input)');

        // Calculate available space using the remapped position
        final availableWidth = maxX - remappedPosition.dx - boundaryBuffer;
        final availableHeight = maxY - remappedPosition.dy - boundaryBuffer;

        print(
            'Available space calculation (using pre-calculated rotation-aware fitting):');
        print(
            '  Available width: $maxX - ${remappedPosition.dx} - $boundaryBuffer = $availableWidth');
        print(
            '  Available height: $maxY - ${remappedPosition.dy} - $boundaryBuffer = $availableHeight');

        final finalSize = Size(
          availableWidth.clamp(0, actualPreviewWidth),
          availableHeight.clamp(0, actualPreviewHeight),
        );

        print('Final available space (clamped to pre-calculated dimensions):');
        print(
            '  Width: $availableWidth clamped to [0, $actualPreviewWidth] = ${finalSize.width}');
        print(
            '  Height: $availableHeight clamped to [0, $actualPreviewHeight] = ${finalSize.height}');
        print('=== END CROP APPLIED SCENARIO ===');
        print('=== END AVAILABLE SPACE CALCULATION DEBUG ===');

        return finalSize;
      }
    }

    // ✅ FIXED: For non-rotated crop, use the existing logic but with proper gap handling
    print('  No rotation - using standard crop logic with proper gap handling');

    // ✅ FIXED: Check if we have coordinate system offset from crop from start
    final coordinateOffsetX =
        containerFitting['coordinateSystemOffsetX'] ?? 0.0;
    final coordinateOffsetY =
        containerFitting['coordinateSystemOffsetY'] ?? 0.0;

    if (coordinateOffsetX != 0.0 || coordinateOffsetY != 0.0) {
      print(
          '  Coordinate system offset detected: X=$coordinateOffsetX, Y=$coordinateOffsetY');
      print(
          '  This indicates crop was applied from start - adjusting text position');

      // Adjust text position by the coordinate system offset
      // ✅ FIXED: Determine the correct direction based on crop position
      final adjustedTextPosition = _calculateCorrectlyAdjustedPosition(
        textPosition: textPosition,
        coordinateOffsetX: coordinateOffsetX,
        coordinateOffsetY: coordinateOffsetY,
        cropRect: cropRect,
        videoSize: videoSize,
      );
      print('  Original text position: $textPosition');
      print('  Adjusted text position: $adjustedTextPosition');

      // Use adjusted position for calculations
      final minX = gapLeft;
      final maxX = gapLeft + actualPreviewWidth;
      final minY = gapTop;
      final maxY = gapTop + actualPreviewHeight;

      print('Final crop area boundaries (using adjusted position):');
      print('  Min X: $minX');
      print('  Max X: $maxX');
      print('  Min Y: $minY');
      print('  Max Y: $maxY');
      print('  Final crop area: ${maxX - minX} x ${maxY - minY}');

      // Calculate available space using the adjusted position
      final availableWidth = maxX - adjustedTextPosition.dx - boundaryBuffer;
      final availableHeight = maxY - adjustedTextPosition.dy - boundaryBuffer;

      print('Available space calculation (using adjusted position):');
      print(
          '  Available width: $maxX - ${adjustedTextPosition.dx} - $boundaryBuffer = $availableWidth');
      print(
          '  Available height: $maxY - ${adjustedTextPosition.dy} - $boundaryBuffer = $availableHeight');

      final finalSize = Size(
        availableWidth.clamp(0, actualPreviewWidth),
        availableHeight.clamp(0, actualPreviewHeight),
      );

      print('Final available space (clamped to crop dimensions):');
      print(
          '  Width: $availableWidth clamped to [0, $actualPreviewWidth] = ${finalSize.width}');
      print(
          '  Height: $availableHeight clamped to [0, $actualPreviewHeight] = ${finalSize.height}');
      print('=== END CROP APPLIED SCENARIO ===');
      print('=== END AVAILABLE SPACE CALCULATION DEBUG ===');

      return finalSize;
    } else {
      print('  No coordinate system offset - using standard calculation');

      // For crop with rotation, we need to calculate the effective crop area
      final effectiveVideoWidth = videoSize.width;
      final effectiveVideoHeight = videoSize.height;

      print('Effective video dimensions (no rotation):');
      print('  Effective video width: $effectiveVideoWidth');
      print('  Effective video height: $effectiveVideoHeight');

      // Calculate the effective crop dimensions in the video space
      final cropAspectRatio = cropRect.width / cropRect.height;
      final videoDisplayAspectRatio = actualPreviewWidth / actualPreviewHeight;

      print('Aspect ratio calculations:');
      print('  Crop aspect ratio: $cropAspectRatio');
      print('  Video display aspect ratio: $videoDisplayAspectRatio');

      double croppedPreviewWidth,
          croppedPreviewHeight,
          croppedGapLeft = 0.0,
          croppedGapTop = 0.0;
      if (cropAspectRatio > videoDisplayAspectRatio) {
        // Crop is wider than video display area - fit width, letterbox top/bottom within video area
        croppedPreviewWidth = actualPreviewWidth;
        croppedPreviewHeight = actualPreviewWidth / cropAspectRatio;
        croppedGapTop = (actualPreviewHeight - croppedPreviewHeight) / 2.0;
        print('Crop is wider than video display - fitting width:');
        print(
            '  Cropped preview width: $croppedPreviewWidth (fits video display width)');
        print(
            '  Cropped preview height: $croppedPreviewHeight (calculated from aspect ratio)');
        print(
            '  Cropped gap top: $croppedGapTop (centers height within video area)');
        print(
            '  Cropped gap left: $croppedGapLeft (no horizontal centering needed)');
      } else {
        // Crop is taller than video display area - fit height, letterbox left/right within video area
        croppedPreviewHeight = actualPreviewHeight;
        croppedPreviewWidth = actualPreviewHeight * cropAspectRatio;
        croppedGapLeft = (actualPreviewWidth - croppedPreviewWidth) / 2.0;
        print('Crop is taller than video display - fitting height:');
        print(
            '  Cropped preview height: $croppedPreviewHeight (fits video display height)');
        print(
            '  Cropped preview width: $croppedPreviewWidth (calculated from aspect ratio)');
        print(
            '  Cropped gap left: $croppedGapLeft (centers width within video area)');
        print(
            '  Cropped gap top: $croppedGapTop (no vertical centering needed)');
      }

      // Final position within the video display area
      final finalGapLeft = gapLeft + croppedGapLeft;
      final finalGapTop = gapTop + croppedGapTop;

      print('Final gap calculations:');
      print('  Base gap left: $gapLeft');
      print('  Base gap top: $gapTop');
      print('  Cropped gap left: $croppedGapLeft');
      print('  Cropped gap top: $croppedGapTop');
      print('  Final gap left: $finalGapLeft');
      print('  Final gap top: $finalGapTop');

      // Clamp to visible crop area in container
      final minX = finalGapLeft;
      final maxX = finalGapLeft + croppedPreviewWidth;
      final minY = finalGapTop;
      final maxY = finalGapTop + croppedPreviewHeight;

      print('Final crop area boundaries:');
      print('  Min X: $minX');
      print('  Max X: $maxX');
      print('  Min Y: $minY');
      print('  Max Y: $maxY');
      print('  Final crop area: ${maxX - minX} x ${maxY - minY}');

      // For non-rotated video, use the existing crop logic
      print('No rotation - applying crop coordinate mapping:');
      print('  Original text position: $textPosition');

      // First, convert from preview coordinates to original video display area
      final originalVideoX = (textPosition.dx - gapLeft) *
          (effectiveVideoWidth / actualPreviewWidth);
      final originalVideoY = (textPosition.dy - gapTop) *
          (effectiveVideoHeight / actualPreviewHeight);

      print('  Converted to original video coordinates:');
      print(
          '    Original video X: (${textPosition.dx} - $gapLeft) * (${effectiveVideoWidth} / $actualPreviewWidth) = $originalVideoX');
      print(
          '    Original video Y: (${textPosition.dy} - $gapTop) * (${effectiveVideoHeight} / $actualPreviewHeight) = $originalVideoY');

      // Then, convert from original video space to crop space
      final cropSpaceX = originalVideoX - cropRect.left;
      final cropSpaceY = originalVideoY - cropRect.top;

      print('  Converted to crop space:');
      print(
          '    Crop space X: $originalVideoX - ${cropRect.left} = $cropSpaceX');
      print(
          '    Crop space Y: $originalVideoY - ${cropRect.top} = $cropSpaceY');

      // Map to container space (cropped video area)
      final xInContainer =
          finalGapLeft + (cropSpaceX * (croppedPreviewWidth / cropRect.width));
      final yInContainer =
          finalGapTop + (cropSpaceY * (croppedPreviewHeight / cropRect.height));

      print('  Mapped to container space:');
      print(
          '    Container X: $finalGapLeft + ($cropSpaceX * (${croppedPreviewWidth} / ${cropRect.width})) = $xInContainer');
      print(
          '    Container Y: $finalGapTop + ($cropSpaceY * (${croppedPreviewHeight} / ${cropRect.height})) = $yInContainer');

      // Clamp to visible crop area in container
      final displayX = xInContainer.clamp(minX, maxX);
      final displayY = yInContainer.clamp(minY, maxY);

      print('  Clamped to visible crop area:');
      print(
          '    Display X: $xInContainer clamped to [$minX, $maxX] = $displayX');
      print(
          '    Display Y: $yInContainer clamped to [$minY, $maxY] = $displayY');

      final remappedPosition = Offset(displayX, displayY);
      print('  Final remapped position: $remappedPosition');

      // Calculate available space using the remapped position
      final availableWidth = maxX - remappedPosition.dx - boundaryBuffer;
      final availableHeight = maxY - remappedPosition.dy - boundaryBuffer;

      print('Available space calculation (using remapped position):');
      print(
          '  Available width: $maxX - ${remappedPosition.dx} - $boundaryBuffer = $availableWidth');
      print(
          '  Available height: $maxY - ${remappedPosition.dy} - $boundaryBuffer = $availableHeight');

      final finalSize = Size(
        availableWidth.clamp(0, croppedPreviewWidth),
        availableHeight.clamp(0, croppedPreviewHeight),
      );

      print('Final available space (clamped to crop dimensions):');
      print(
          '  Width: $availableWidth clamped to [0, $croppedPreviewWidth] = ${finalSize.width}');
      print(
          '  Height: $availableHeight clamped to [0, $croppedPreviewHeight] = ${finalSize.height}');
      print('=== END CROP APPLIED SCENARIO ===');
      print('=== END AVAILABLE SPACE CALCULATION DEBUG ===');

      return finalSize;
    } // ✅ FIXED: Close the else block for coordinate system offset handling
  }

  /// Get the actual video area boundaries for positioning
  static Rect getVideoAreaBoundaries({
    required Size containerSize,
    required Size videoSize,
    required Rect? cropRect,
    int rotation = 0,
  }) {
    print('=== VIDEO AREA BOUNDARIES CALCULATION DEBUG ===');
    print('Input parameters:');
    print('  Container size: ${containerSize.width} x ${containerSize.height}');
    print('  Video size: ${videoSize.width} x ${videoSize.height}');
    print('  Crop rect: $cropRect');
    print('  Rotation: $rotation degrees');

    if (cropRect == null) {
      print('=== NO CROP SCENARIO ===');
      // No crop - use rotation-aware fitting
      final containerFitting = rotation != 0
          ? calculateRotationAwareContainerFitting(
              videoWidth: videoSize.width,
              videoHeight: videoSize.height,
              containerWidth: containerSize.width,
              containerHeight: containerSize.height,
              rotation: rotation,
            )
          : calculateContainerFitting(
              videoWidth: videoSize.width,
              videoHeight: videoSize.height,
              containerWidth: containerSize.width,
              containerHeight: containerSize.height,
            );

      final actualPreviewWidth = containerFitting['actualPreviewWidth']!;
      final actualPreviewHeight = containerFitting['actualPreviewHeight']!;
      final gapLeft = containerFitting['gapLeft']!;
      final gapTop = containerFitting['gapTop']!;

      print('Container fitting results:');
      print('  Actual preview width: $actualPreviewWidth');
      print('  Actual preview height: $actualPreviewHeight');
      print('  Gap left: $gapLeft');
      print('  Gap top: $gapTop');

      // No crop - return full preview area boundaries
      final result = Rect.fromLTWH(
        gapLeft,
        gapTop,
        actualPreviewWidth,
        actualPreviewHeight,
      );

      print('Full video area boundaries:');
      print('  Left: $gapLeft');
      print('  Top: $gapTop');
      print('  Width: $actualPreviewWidth');
      print('  Height: $actualPreviewHeight');
      print('  Right: ${gapLeft + actualPreviewWidth}');
      print('  Bottom: ${gapTop + actualPreviewHeight}');
      print('=== END NO CROP SCENARIO ===');
      print('=== END VIDEO AREA BOUNDARIES CALCULATION DEBUG ===');

      return result;
    }

    // --- CROP APPLIED ---
    print('=== CROP APPLIED SCENARIO ===');
    print('Crop rect details:');
    print('  Crop left: ${cropRect.left}');
    print('  Crop top: ${cropRect.top}');
    print('  Crop right: ${cropRect.right}');
    print('  Crop bottom: ${cropRect.bottom}');
    print('  Crop width: ${cropRect.width}');
    print('  Crop height: ${cropRect.height}');
    print('  Crop aspect ratio: ${cropRect.width / cropRect.height}');

    // Use rotation-aware crop-adjusted fitting
    final containerFitting = rotation != 0
        ? calculateRotationAwareCropAdjustedContainerFitting(
            videoWidth: videoSize.width,
            videoHeight: videoSize.height,
            containerWidth: containerSize.width,
            containerHeight: containerSize.height,
            cropRect: cropRect,
            rotation: rotation,
          )
        : calculateCropAdjustedContainerFitting(
            videoWidth: videoSize.width,
            videoHeight: videoSize.height,
            containerWidth: containerSize.width,
            containerHeight: containerSize.height,
            cropRect: cropRect,
          );

    final actualPreviewWidth = containerFitting['actualPreviewWidth']!;
    final actualPreviewHeight = containerFitting['actualPreviewHeight']!;
    final gapLeft = containerFitting['gapLeft']!;
    final gapTop = containerFitting['gapTop']!;

    print('Container fitting results (crop-adjusted):');
    print('  Actual preview width: $actualPreviewWidth');
    print('  Actual preview height: $actualPreviewHeight');
    print('  Gap left: $gapLeft');
    print('  Gap top: $gapTop');

    // For crop with rotation, we need to calculate the effective crop area
    final cropAspectRatio = cropRect.width / cropRect.height;
    final videoDisplayAspectRatio = actualPreviewWidth / actualPreviewHeight;

    print('Aspect ratio calculations:');
    print('  Crop aspect ratio: $cropAspectRatio');
    print('  Video display aspect ratio: $videoDisplayAspectRatio');

    double croppedPreviewWidth,
        croppedPreviewHeight,
        croppedGapLeft = 0.0,
        croppedGapTop = 0.0;
    if (cropAspectRatio > videoDisplayAspectRatio) {
      // Crop is wider than video display area: fit width, letterbox top/bottom within video area
      croppedPreviewWidth = actualPreviewWidth;
      croppedPreviewHeight = actualPreviewWidth / cropAspectRatio;
      croppedGapTop = (actualPreviewHeight - croppedPreviewHeight) / 2.0;
      print('Crop is wider - fitting width:');
      print(
          '  Cropped preview width: $croppedPreviewWidth (fits container width)');
      print(
          '  Cropped preview height: $croppedPreviewHeight (calculated from aspect ratio)');
      print(
          '  Cropped gap top: $croppedGapTop (centers height within video area)');
      print(
          '  Cropped gap left: $croppedGapLeft (no horizontal centering needed)');
    } else {
      // Crop is taller than video display area: fit height, letterbox left/right within video area
      croppedPreviewHeight = actualPreviewHeight;
      croppedPreviewWidth = actualPreviewHeight * cropAspectRatio;
      croppedGapLeft = (actualPreviewWidth - croppedPreviewWidth) / 2.0;
      print('Crop is taller - fitting height:');
      print(
          '  Cropped preview height: $croppedPreviewHeight (fits container height)');
      print(
          '  Cropped preview width: $croppedPreviewWidth (calculated from aspect ratio)');
      print(
          '  Cropped gap left: $croppedGapLeft (centers width within video area)');
      print('  Cropped gap top: $croppedGapTop (no vertical centering needed)');
    }

    // Final position within the rotated video display area
    final finalGapLeft = gapLeft + croppedGapLeft;
    final finalGapTop = gapTop + croppedGapTop;

    print('Final gap calculations:');
    print('  Base gap left: $gapLeft');
    print('  Base gap top: $gapTop');
    print('  Cropped gap left: $croppedGapLeft');
    print('  Cropped gap top: $croppedGapTop');
    print('  Final gap left: $finalGapLeft');
    print('  Final gap top: $finalGapTop');

    final result = Rect.fromLTWH(
      finalGapLeft,
      finalGapTop,
      croppedPreviewWidth,
      croppedPreviewHeight,
    );

    print('Final cropped video area boundaries:');
    print('  Left: $finalGapLeft');
    print('  Top: $finalGapTop');
    print('  Width: $croppedPreviewWidth');
    print('  Height: $croppedPreviewHeight');
    print('  Right: ${finalGapLeft + croppedPreviewWidth}');
    print('  Bottom: ${finalGapTop + croppedPreviewHeight}');
    print('=== END CROP APPLIED SCENARIO ===');
    print('=== END VIDEO AREA BOUNDARIES CALCULATION DEBUG ===');

    return result;
  }

  /// Validate and clamp coordinates to prevent crashes
  static Offset validateAndClampCoordinates({
    required Offset position,
    required Size containerSize,
    required Size videoSize,
    required Rect? cropRect,
    required double boundaryBuffer,
    int rotation = 0,
  }) {
    if (cropRect == null) {
      // No crop - use rotation-aware fitting
      final containerFitting = rotation != 0
          ? calculateRotationAwareContainerFitting(
              videoWidth: videoSize.width,
              videoHeight: videoSize.height,
              containerWidth: containerSize.width,
              containerHeight: containerSize.height,
              rotation: rotation,
            )
          : calculateContainerFitting(
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

      // Clamp coordinates to video bounds (strict boundaries, no overflow)
      final clampedX = position.dx.clamp(minX, maxX);
      final clampedY = position.dy.clamp(minY, maxY);

      return Offset(clampedX, clampedY);
    }

    // --- CROP APPLIED ---
    // Use rotation-aware crop-adjusted fitting
    final containerFitting = rotation != 0
        ? calculateRotationAwareCropAdjustedContainerFitting(
            videoWidth: videoSize.width,
            videoHeight: videoSize.height,
            containerWidth: containerSize.width,
            containerHeight: containerSize.height,
            cropRect: cropRect,
            rotation: rotation,
          )
        : calculateCropAdjustedContainerFitting(
            videoWidth: videoSize.width,
            videoHeight: videoSize.height,
            containerWidth: containerSize.width,
            containerHeight: containerSize.height,
            cropRect: cropRect,
          );

    final actualPreviewWidth = containerFitting['actualPreviewWidth']!;
    final actualPreviewHeight = containerFitting['actualPreviewHeight']!;
    final gapLeft = containerFitting['gapLeft']!;
    final gapTop = containerFitting['gapTop']!;

    // For crop with rotation, we need to calculate the effective crop area
    final cropAspectRatio = cropRect.width / cropRect.height;
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

    // Final position within the rotated video display area
    final finalGapLeft = gapLeft + croppedGapLeft;
    final finalGapTop = gapTop + croppedGapTop;

    // Calculate boundaries - these are the cropped video area boundaries
    final minX = finalGapLeft;
    final maxX = finalGapLeft + croppedPreviewWidth;
    final minY = finalGapTop;
    final maxY = finalGapTop + croppedPreviewHeight;

    // Clamp coordinates to cropped video bounds
    final clampedX = position.dx.clamp(minX, maxX);
    final clampedY = position.dy.clamp(minY, maxY);

    return Offset(clampedX, clampedY);
  }

  /// Check if coordinates are valid (not NaN or infinite)
  static bool areCoordinatesValid(Offset position) {
    return !position.dx.isNaN &&
        !position.dx.isInfinite &&
        !position.dy.isNaN &&
        !position.dy.isInfinite;
  }

  /// Calculate text boundaries considering text dimensions and rotation
  static Rect calculateTextBoundaries({
    required Offset textPosition,
    required Size textSize,
    required double rotation,
    required Size containerSize,
    required Size videoSize,
    required Rect? cropRect,
  }) {
    print('=== TEXT BOUNDARIES CALCULATION DEBUG ===');
    print('Input parameters:');
    print('  Text position: (${textPosition.dx}, ${textPosition.dy})');
    print('  Text size: ${textSize.width} x ${textSize.height}');
    print('  Text rotation: $rotation degrees');
    print('  Container size: ${containerSize.width} x ${containerSize.height}');
    print('  Video size: ${videoSize.width} x ${videoSize.height}');
    print('  Crop rect: $cropRect');

    if (cropRect == null) {
      print('=== NO CROP SCENARIO ===');
      // No crop - use rotation-aware fitting
      final containerFitting = rotation != 0
          ? calculateRotationAwareContainerFitting(
              videoWidth: videoSize.width,
              videoHeight: videoSize.height,
              containerWidth: containerSize.width,
              containerHeight: containerSize.height,
              rotation: rotation.toInt(),
            )
          : calculateContainerFitting(
              videoWidth: videoSize.width,
              videoHeight: videoSize.height,
              containerWidth: containerSize.width,
              containerHeight: containerSize.height,
            );

      final actualPreviewWidth = containerFitting['actualPreviewWidth']!;
      final actualPreviewHeight = containerFitting['actualPreviewHeight']!;
      final gapLeft = containerFitting['gapLeft']!;
      final gapTop = containerFitting['gapTop']!;

      print('Container fitting results:');
      print('  Actual preview width: $actualPreviewWidth');
      print('  Actual preview height: $actualPreviewHeight');
      print('  Gap left: $gapLeft');
      print('  Gap top: $gapTop');

      // For rotation, we need to consider the effective video dimensions
      // The rotated video might have different display area than the container
      double effectivePreviewWidth, effectivePreviewHeight;

      if (rotation != 0) {
        // For rotated video, the effective dimensions are what actually gets displayed
        // This accounts for letterboxing/pillarboxing due to rotation
        effectivePreviewWidth = actualPreviewWidth;
        effectivePreviewHeight = actualPreviewHeight;
        print('Rotation detected - using effective dimensions:');
        print('  Effective preview width: $effectivePreviewWidth');
        print('  Effective preview height: $effectivePreviewHeight');
      } else {
        // No rotation - use full preview area
        effectivePreviewWidth = actualPreviewWidth;
        effectivePreviewHeight = actualPreviewHeight;
        print('No rotation - using full preview area:');
        print('  Effective preview width: $effectivePreviewWidth');
        print('  Effective preview height: $effectivePreviewHeight');
      }

      // No crop - use full video area boundaries
      final minX = gapLeft;
      final maxX = gapLeft + effectivePreviewWidth;
      final minY = gapTop;
      final maxY = gapTop + effectivePreviewHeight;

      print('Full video area boundaries:');
      print('  Min X (gap left): $minX');
      print('  Max X (gap left + effective width): $maxX');
      print('  Min Y (gap top): $minY');
      print('  Max Y (gap top + effective height): $maxY');

      // If text is rotated, calculate the bounding box
      if (rotation != 0) {
        print('Text rotation detected - calculating rotated bounding box:');
        final angleRad = rotation * math.pi / 180.0;
        final cosAngle = math.cos(angleRad).abs();
        final sinAngle = math.sin(angleRad).abs();

        // Calculate rotated bounding box dimensions
        final rotatedWidth =
            textSize.width * cosAngle + textSize.height * sinAngle;
        final rotatedHeight =
            textSize.width * sinAngle + textSize.height * cosAngle;

        print('  Original text size: ${textSize.width} x ${textSize.height}');
        print(
            '  Rotation angle: ${rotation}° (${angleRad.toStringAsFixed(4)} radians)');
        print('  Cos(angle): ${cosAngle.toStringAsFixed(4)}');
        print('  Sin(angle): ${sinAngle.toStringAsFixed(4)}');
        print(
            '  Rotated width: ${textSize.width} * ${cosAngle.toStringAsFixed(4)} + ${textSize.height} * ${sinAngle.toStringAsFixed(4)} = $rotatedWidth');
        print(
            '  Rotated height: ${textSize.width} * ${sinAngle.toStringAsFixed(4)} + ${textSize.height} * ${cosAngle.toStringAsFixed(4)} = $rotatedHeight');

        // Calculate boundaries considering rotated text
        final textMinX = textPosition.dx;
        final textMinY = textPosition.dy;

        print('  Text position: (${textPosition.dx}, ${textPosition.dy})');
        print('  Text min X: $textMinX');
        print('  Text min Y: $textMinY');

        // Clamp to video area
        final clampedMinX = textMinX.clamp(minX, maxX - rotatedWidth);
        final clampedMinY = textMinY.clamp(minY, maxY - rotatedHeight);

        print('  Clamping to video area:');
        print(
            '    Min X: $textMinX clamped to [$minX, ${maxX - rotatedWidth}] = $clampedMinX');
        print(
            '    Min Y: $textMinY clamped to [$minY, ${maxY - rotatedHeight}] = $clampedMinY');

        final result = Rect.fromLTWH(
            clampedMinX, clampedMinY, rotatedWidth, rotatedHeight);

        print('Final rotated text boundaries:');
        print('  Left: $clampedMinX');
        print('  Top: $clampedMinY');
        print('  Width: $rotatedWidth');
        print('  Height: $rotatedHeight');
        print('  Right: ${clampedMinX + rotatedWidth}');
        print('  Bottom: ${clampedMinY + rotatedHeight}');
        print('=== END NO CROP SCENARIO ===');
        print('=== END TEXT BOUNDARIES CALCULATION DEBUG ===');

        return result;
      } else {
        // No rotation - simple rectangular boundaries
        print('No text rotation - using simple rectangular boundaries:');
        final textMinX = textPosition.dx;
        final textMinY = textPosition.dy;

        print('  Text position: (${textPosition.dx}, ${textPosition.dy})');
        print('  Text min X: $textMinX');
        print('  Text min Y: $textMinY');

        // Clamp to video area
        final clampedMinX = textMinX.clamp(minX, maxX - textSize.width);
        final clampedMinY = textMinY.clamp(minY, maxY - textSize.height);

        print('  Clamping to video area:');
        print(
            '    Min X: $textMinX clamped to [$minX, ${maxX - textSize.width}] = $clampedMinX');
        print(
            '    Min Y: $textMinY clamped to [$minY, ${maxY - textSize.height}] = $clampedMinY');

        final result = Rect.fromLTWH(
            clampedMinX, clampedMinY, textSize.width, textSize.height);

        print('Final text boundaries:');
        print('  Left: $clampedMinX');
        print('  Top: $clampedMinY');
        print('  Width: ${textSize.width}');
        print('  Height: ${textSize.height}');
        print('  Right: ${clampedMinX + textSize.width}');
        print('  Bottom: ${clampedMinY + textSize.height}');
        print('=== END NO CROP SCENARIO ===');
        print('=== END TEXT BOUNDARIES CALCULATION DEBUG ===');

        return result;
      }
    }

    // --- CROP APPLIED ---
    print('=== CROP APPLIED SCENARIO ===');
    print('Using the exact same logic as the working non-canvas approach');

    // First, calculate how the original video is displayed (same as no-crop)
    final videoAspectRatio = videoSize.width / videoSize.height;
    final containerAspectRatio = containerSize.width / containerSize.height;

    print('Video fitting calculations:');
    print('  Video aspect ratio: $videoAspectRatio');
    print('  Container aspect ratio: $containerAspectRatio');

    double actualPreviewWidth, actualPreviewHeight, gapLeft = 0.0, gapTop = 0.0;
    if (videoAspectRatio > containerAspectRatio) {
      // Original video is wider - fit width, letterbox top/bottom
      actualPreviewWidth = containerSize.width;
      actualPreviewHeight = containerSize.width / videoAspectRatio;
      gapTop = (containerSize.height - actualPreviewHeight) / 2.0;
      print('Video is wider - fitting width:');
      print(
          '  Actual preview width: $actualPreviewWidth (fits container width)');
      print(
          '  Actual preview height: $actualPreviewHeight (calculated from aspect ratio)');
      print('  Gap top: $gapTop (centers height within container)');
      print('  Gap left: $gapLeft (no horizontal centering needed)');
    } else {
      // Original video is taller - fit height, letterbox left/right
      actualPreviewHeight = containerSize.height;
      actualPreviewWidth = containerSize.height * videoAspectRatio;
      gapLeft = (containerSize.width - actualPreviewWidth) / 2.0;
      print('Video is taller - fitting height:');
      print(
          '  Actual preview height: $actualPreviewHeight (fits container height)');
      print(
          '  Actual preview width: $actualPreviewWidth (calculated from aspect ratio)');
      print('  Gap left: $gapLeft (centers width within container)');
      print('  Gap top: $gapTop (no vertical centering needed)');
    }

    // Now use ONLY the original video display area as the container for the cropped video
    // This means the cropped video is constrained to the same area where original video was shown
    final cropAspectRatio = cropRect.width / cropRect.height;
    final videoDisplayAspectRatio = actualPreviewWidth / actualPreviewHeight;

    print('Crop fitting calculations:');
    print('  Crop aspect ratio: $cropAspectRatio');
    print('  Video display aspect ratio: $videoDisplayAspectRatio');

    double croppedPreviewWidth,
        croppedPreviewHeight,
        croppedGapLeft = 0.0,
        croppedGapTop = 0.0;
    if (cropAspectRatio > videoDisplayAspectRatio) {
      // Crop is wider than video display area - fit width, letterbox top/bottom within video area
      croppedPreviewWidth = actualPreviewWidth;
      croppedPreviewHeight = actualPreviewWidth / cropAspectRatio;
      croppedGapTop = (actualPreviewHeight - croppedPreviewHeight) / 2.0;
      print('Crop is wider than video display - fitting width:');
      print(
          '  Cropped preview width: $croppedPreviewWidth (fits video display width)');
      print(
          '  Cropped preview height: $croppedPreviewHeight (calculated from aspect ratio)');
      print(
          '  Cropped gap top: $croppedGapTop (centers height within video area)');
      print(
          '  Cropped gap left: $croppedGapLeft (no horizontal centering needed)');
    } else {
      // Crop is taller than video display area - fit height, letterbox left/right within video area
      croppedPreviewHeight = actualPreviewHeight;
      croppedPreviewWidth = actualPreviewHeight * cropAspectRatio;
      croppedGapLeft = (actualPreviewWidth - croppedPreviewWidth) / 2.0;
      print('Crop is taller than video display - fitting height:');
      print(
          '  Cropped preview height: $croppedPreviewHeight (fits video display height)');
      print(
          '  Cropped preview width: $croppedPreviewWidth (calculated from aspect ratio)');
      print(
          '  Cropped gap left: $croppedGapLeft (centers width within video area)');
      print('  Cropped gap top: $croppedGapTop (no vertical centering needed)');
    }

    // Final position within the original video display area (not the full container)
    final finalGapLeft = gapLeft + croppedGapLeft;
    final finalGapTop = gapTop + croppedGapTop;

    print('Final gap calculations:');
    print('  Base gap left: $gapLeft');
    print('  Base gap top: $gapTop');
    print('  Cropped gap left: $croppedGapLeft');
    print('  Cropped gap top: $croppedGapTop');
    print('  Final gap left: $finalGapLeft');
    print('  Final gap top: $finalGapTop');

    // Calculate cropped video area boundaries
    final minX = finalGapLeft;
    final maxX = finalGapLeft + croppedPreviewWidth;
    final minY = finalGapTop;
    final maxY = finalGapTop + croppedPreviewHeight;

    print('Final cropped video area boundaries:');
    print('  Min X: $minX');
    print('  Max X: $maxX');
    print('  Min Y: $minY');
    print('  Max Y: $maxY');
    print('  Final crop area: ${maxX - minX} x ${maxY - minY}');

    // If text is rotated, calculate the bounding box
    if (rotation != 0) {
      print('Text rotation detected - calculating rotated bounding box:');
      final angleRad = rotation * math.pi / 180.0;
      final cosAngle = math.cos(angleRad).abs();
      final sinAngle = math.sin(angleRad).abs();

      // Calculate rotated bounding box dimensions
      final rotatedWidth =
          textSize.width * cosAngle + textSize.height * sinAngle;
      final rotatedHeight =
          textSize.width * sinAngle + textSize.height * cosAngle;

      print('  Original text size: ${textSize.width} x ${textSize.height}');
      print(
          '  Rotation angle: ${rotation}° (${angleRad.toStringAsFixed(4)} radians)');
      print('  Cos(angle): ${cosAngle.toStringAsFixed(4)}');
      print('  Sin(angle): ${sinAngle.toStringAsFixed(4)}');
      print(
          '  Rotated width: ${textSize.width} * ${cosAngle.toStringAsFixed(4)} + ${textSize.height} * ${sinAngle.toStringAsFixed(4)} = $rotatedWidth');
      print(
          '  Rotated height: ${textSize.width} * ${sinAngle.toStringAsFixed(4)} + ${textSize.height} * ${cosAngle.toStringAsFixed(4)} = $rotatedHeight');

      // Calculate boundaries considering rotated text
      final textMinX = textPosition.dx;
      final textMinY = textPosition.dy;

      print('  Text position: (${textPosition.dx}, ${textPosition.dy})');
      print('  Text min X: $textMinX');
      print('  Text min Y: $textMinY');

      // Clamp to cropped video area
      final clampedMinX = textMinX.clamp(minX, maxX - rotatedWidth);
      final clampedMinY = textMinY.clamp(minY, maxY - rotatedHeight);

      print('  Clamping to cropped video area:');
      print(
          '    Min X: $textMinX clamped to [$minX, ${maxX - rotatedWidth}] = $clampedMinX');
      print(
          '    Min Y: $textMinY clamped to [$minY, ${maxY - rotatedHeight}] = $clampedMinY');

      final result =
          Rect.fromLTWH(clampedMinX, clampedMinY, rotatedWidth, rotatedHeight);

      print('Final rotated text boundaries (within crop):');
      print('  Left: $clampedMinX');
      print('  Top: $clampedMinY');
      print('  Width: $rotatedWidth');
      print('  Height: $rotatedHeight');
      print('  Right: ${clampedMinX + rotatedWidth}');
      print('  Bottom: ${clampedMinY + rotatedHeight}');
      print('=== END CROP APPLIED SCENARIO ===');
      print('=== END TEXT BOUNDARIES CALCULATION DEBUG ===');

      return result;
    } else {
      // No rotation - simple rectangular boundaries
      print('No text rotation - using simple rectangular boundaries:');
      final textMinX = textPosition.dx;
      final textMinY = textPosition.dy;

      print('  Text position: (${textPosition.dx}, ${textPosition.dy})');
      print('  Text min X: $textMinX');
      print('  Text min Y: $textMinY');

      // Clamp to cropped video area
      final clampedMinX = textMinX.clamp(minX, maxX - textSize.width);
      final clampedMinY = textMinY.clamp(minY, maxY - textSize.height);

      print('  Clamping to cropped video area:');
      print(
          '    Min X: $textMinX clamped to [$minX, ${maxX - textSize.width}] = $clampedMinX');
      print(
          '    Min Y: $textMinY clamped to [$minY, ${maxY - textSize.height}] = $clampedMinY');

      final result = Rect.fromLTWH(
          clampedMinX, clampedMinY, textSize.width, textSize.height);

      print('Final text boundaries (within crop):');
      print('  Left: $clampedMinX');
      print('  Top: $clampedMinY');
      print('  Width: ${textSize.width}');
      print('  Height: ${textSize.height}');
      print('  Right: ${clampedMinX + textSize.width}');
      print('  Bottom: ${clampedMinY + textSize.height}');
      print('=== END CROP APPLIED SCENARIO ===');
      print('=== END TEXT BOUNDARIES CALCULATION DEBUG ===');

      return result;
    }
  }
}
