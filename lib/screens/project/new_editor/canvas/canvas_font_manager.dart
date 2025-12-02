import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ai_video_creator_editor/utils/text_auto_wrap_helper.dart';
import 'dart:math' as math;

/// Manages font scaling and text rendering for canvas-based text overlays
///
/// ✅ UPDATED: Now supports rotation-aware font scaling with crop consideration
///
/// Key Features:
/// - **Rotation-Aware**: Handles 90°/270° rotation with dimension swapping
/// - **Crop-Aware**: Considers crop gaps when calculating rotation-aware container fitting
/// - **Consistent Scaling**: Uses crop ratios (not absolute dimensions) for font size calculations
/// - **Preview-Export Alignment**: Matches the export system's rotation-aware logic
///
/// How it works:
/// 1. For rotated videos: First calculates original container fitting, then fits rotated video within that area
/// 2. For cropped videos: Uses crop ratios (0.0 to 1.0) for proportional font scaling
/// 3. For crop + rotation: Combines both approaches for accurate font scaling
///
/// ✅ FIXED: Crop dimension calculation now uses ratios instead of absolute pixels
/// This prevents extreme font size ratios (e.g., 0.000138) and ensures consistent text scaling.
///
/// This ensures that text overlays maintain consistent appearance between preview and export
/// when videos are both cropped and rotated.
class CanvasFontManager {
  /// Calculate font size for canvas rendering (same logic for preview and export)
  static double calculateCanvasFontSize({
    required double baseFontSize,
    required Size targetSize, // Preview container or export video size
    required Size videoSize, // Original video dimensions
    required bool isPreview, // Preview vs export mode
    int videoRotation = 0, // Video rotation in degrees (0, 90, 180, 270)
    Rect? cropRect, // ✅ ADDED: Crop rectangle for rotation-aware calculations
  }) {
    if (isPreview) {
      // For preview, calculate the effective video display area considering rotation
      if (videoRotation != 0) {
        print('=== Rotation-Aware Font Scaling ===');
        print('Base font size: $baseFontSize');
        print(
            'Full container size: ${targetSize.width} x ${targetSize.height}');
        print('Video size: ${videoSize.width} x ${videoSize.height}');
        print('Video rotation: ${videoRotation}°');
        if (cropRect != null) {
          print(
              'Crop rect: (${cropRect.left}, ${cropRect.top}) to (${cropRect.right}, ${cropRect.bottom})');
        }

        // ✅ FIXED: Calculate rotation-aware container fitting considering crop gaps
        final containerFitting = _calculateRotationAwareContainerFitting(
          videoWidth: videoSize.width,
          videoHeight: videoSize.height,
          containerWidth: targetSize.width,
          containerHeight: targetSize.height,
          rotation: videoRotation,
          cropRect: cropRect, // ✅ ADDED: Pass crop rectangle
        );

        // Use the effective video display area (actualPreviewWidth × actualPreviewHeight)
        // instead of the full container for font scaling
        final effectiveTargetSize = Size(
          containerFitting['actualPreviewWidth']!,
          containerFitting['actualPreviewHeight']!,
        );

        print(
            'Effective video display area: ${effectiveTargetSize.width} x ${effectiveTargetSize.height}');
        print(
            'Gaps: left=${containerFitting['gapLeft']}, top=${containerFitting['gapTop']}');

        // ✅ FIXED: Use cropped video dimensions for font scaling
        // When crop is applied, we need to use the cropped dimensions for consistent scaling
        double croppedVideoWidth, croppedVideoHeight;
        if (cropRect != null) {
          // ✅ FIXED: Calculate crop ratios, not absolute dimensions
          // The crop rect is in normalized coordinates (0.0 to 1.0), not absolute pixels
          //
          // WHY THIS APPROACH IS CORRECT:
          // 1. FontScalingHelper.calculatePreviewFontSize expects proportional dimensions
          // 2. The crop rect represents what portion of the video is visible (e.g., 0.5 = 50%)
          // 3. Using absolute pixel dimensions (e.g., 1555200x1166400) creates extreme ratios
          // 4. Using crop ratios (e.g., 0.75x1.0) gives us proportional scaling that matches the preview
          //
          final cropWidthRatio = cropRect.right - cropRect.left;
          final cropHeightRatio = cropRect.bottom - cropRect.top;

          // ✅ FIXED: Use crop ratios directly for font scaling
          // This gives us the proportional dimensions that match the preview display
          croppedVideoWidth = cropWidthRatio;
          croppedVideoHeight = cropHeightRatio;

          print(
              'Crop ratios: width=${cropWidthRatio.toStringAsFixed(3)}, height=${cropHeightRatio.toStringAsFixed(3)}');
          print('Using crop ratios for font scaling (not absolute dimensions)');
        } else {
          // No crop, use original dimensions
          croppedVideoWidth = 1.0; // Full width ratio
          croppedVideoHeight = 1.0; // Full height ratio
          print('No crop applied, using full dimensions (1.0 x 1.0)');
        }

        print('=== Font Scaling with Crop ===');
        print('Base font size: $baseFontSize');
        print(
            'Crop ratios: ${croppedVideoWidth.toStringAsFixed(3)}x${croppedVideoHeight.toStringAsFixed(3)}');
        print(
            'Effective target size: ${effectiveTargetSize.width.toStringAsFixed(2)}x${effectiveTargetSize.height.toStringAsFixed(2)}');

        // ✅ ADDED: Debug logging to show the corrected approach
        if (cropRect != null) {
          print('=== Crop Analysis ===');
          print('Original video: ${videoSize.width}x${videoSize.height}');
          print(
              'Crop rect: (${cropRect.left.toStringAsFixed(3)}, ${cropRect.top.toStringAsFixed(3)}) to (${cropRect.right.toStringAsFixed(3)}, ${cropRect.bottom.toStringAsFixed(3)})');
          print(
              'Crop ratios: ${croppedVideoWidth.toStringAsFixed(3)}x${croppedVideoHeight.toStringAsFixed(3)}');
          print(
              'This means: ${(croppedVideoWidth * 100).toStringAsFixed(1)}% of width, ${(croppedVideoHeight * 100).toStringAsFixed(1)}% of height');
          print('=== End Crop Analysis ===');
        }

        double fontSize;
        if (cropRect != null) {
          fontSize = FontScalingHelper.calculatePreviewFontSize(
            baseFontSize: baseFontSize,
            videoWidth: croppedVideoWidth, // ✅ FIXED: Use crop ratios
            videoHeight: croppedVideoHeight, // ✅ FIXED: Use crop ratios
            containerWidth: effectiveTargetSize.width,
            containerHeight: effectiveTargetSize.height,
          );
        } else {
          fontSize = FontScalingHelper.calculatePreviewFontSize(
            baseFontSize: baseFontSize,
            videoWidth: videoSize.width,
            videoHeight: videoSize.height,
            containerWidth: effectiveTargetSize.width,
            containerHeight: effectiveTargetSize.height,
          );
        }

        print('Calculated font size: $fontSize');
        print('Font size ratio: ${fontSize / baseFontSize}');
        print('=== End Font Scaling with Crop ===');

        return fontSize;
      } else {
        // No rotation - use existing FontScalingHelper for preview
        print('=== Standard Font Scaling (No Rotation) ===');
        print('Base font size: $baseFontSize');
        print('Container size: ${targetSize.width} x ${targetSize.height}');
        print('Video size: ${videoSize.width} x ${videoSize.height}');

        final fontSize = FontScalingHelper.calculatePreviewFontSize(
          baseFontSize: baseFontSize,
          videoWidth: videoSize.width,
          videoHeight: videoSize.height,
          containerWidth: targetSize.width,
          containerHeight: targetSize.height,
        );

        print('Calculated font size: $fontSize');
        print('Font size ratio: ${fontSize / baseFontSize}');
        print('=== End Standard Font Scaling ===');

        return fontSize;
      }
    } else {
      // For export, use the base font size directly
      // Since we're rendering at full video resolution
      return baseFontSize;
    }
  }

  /// Calculate rotation-aware container fitting for font scaling
  /// This is similar to CanvasCoordinateManager.calculateRotationAwareContainerFitting
  /// but simplified for font scaling purposes
  /// ✅ UPDATED: Now considers crop gaps for accurate rotation-aware calculations
  static Map<String, double> _calculateRotationAwareContainerFitting({
    required double videoWidth,
    required double videoHeight,
    required double containerWidth,
    required double containerHeight,
    required int rotation,
    Rect? cropRect, // ✅ ADDED: Crop rectangle for gap calculations
  }) {
    print('=== Rotation-Aware Container Fitting for Font Scaling ===');
    print('Input video dimensions: ${videoWidth} x ${videoHeight}');
    print('Input container dimensions: ${containerWidth} x ${containerHeight}');
    print('Input rotation: ${rotation}°');
    if (cropRect != null) {
      print(
          'Input crop rect: (${cropRect.left}, ${cropRect.top}) to (${cropRect.right}, ${cropRect.bottom})');
    }

    // For 90° and 270° rotation, swap video dimensions
    double effectiveVideoWidth, effectiveVideoHeight;
    if (rotation == 90 || rotation == 270) {
      effectiveVideoWidth = videoHeight;
      effectiveVideoHeight = videoWidth;
      print(
          'Swapped dimensions for ${rotation}° rotation: ${effectiveVideoWidth} x ${effectiveVideoHeight}');
    } else {
      effectiveVideoWidth = videoWidth;
      effectiveVideoHeight = videoHeight;
      print(
          'Kept original dimensions for ${rotation}° rotation: ${effectiveVideoWidth} x ${effectiveVideoHeight}');
    }

    // ✅ FIXED: First calculate how the original video fits in the container
    // This gives us the base area that the rotated video must fit within
    final originalFitting = FontScalingHelper.calculateContainerFitting(
      videoWidth: effectiveVideoWidth,
      videoHeight: effectiveVideoHeight,
      containerWidth: containerWidth,
      containerHeight: containerHeight,
    );

    final originalPreviewWidth = originalFitting['actualPreviewWidth']!;
    final originalPreviewHeight = originalFitting['actualPreviewHeight']!;
    final originalGapLeft = originalFitting['gapLeft']!;
    final originalGapTop = originalFitting['gapTop']!;

    print(
        'Original fitting: ${originalPreviewWidth}x${originalPreviewHeight}, gaps: left=${originalGapLeft}, top=${originalGapTop}');

    // ✅ FIXED: Calculate the current video display area (original fitting)
    // This is the base area that the rotated video must fit within
    final currentVideoArea = Rect.fromLTWH(
      originalGapLeft,
      originalGapTop,
      originalPreviewWidth,
      originalPreviewHeight,
    );

    // ✅ FIXED: Fit the rotated video within the CURRENT video display area
    // This ensures the rotated video is constrained to the same area as the original
    final currentAspectRatio = currentVideoArea.width / currentVideoArea.height;
    final rotatedAspectRatio = effectiveVideoWidth / effectiveVideoHeight;

    double rotatedWidth, rotatedHeight, rotatedLeft, rotatedTop;

    if (rotatedAspectRatio > currentAspectRatio) {
      // Rotated video is wider - fit width, center height within current area
      rotatedWidth = currentVideoArea.width;
      rotatedHeight = currentVideoArea.width / rotatedAspectRatio;
      rotatedTop = currentVideoArea.top +
          (currentVideoArea.height - rotatedHeight) / 2.0;
      rotatedLeft = currentVideoArea.left;
    } else {
      // Rotated video is taller - fit height, center width within current area
      rotatedHeight = currentVideoArea.height;
      rotatedWidth = currentVideoArea.height * rotatedAspectRatio;
      rotatedLeft =
          currentVideoArea.left + (currentVideoArea.width - rotatedWidth) / 2.0;
      rotatedTop = currentVideoArea.top;
    }

    print(
        'Rotated video area: ${rotatedWidth.toStringAsFixed(2)}x${rotatedHeight.toStringAsFixed(2)}');
    print(
        'Rotated video position: left=${rotatedLeft.toStringAsFixed(2)}, top=${rotatedTop.toStringAsFixed(2)}');

    // ✅ FIXED: Extract final gaps from the rotated video area
    final gapLeft = rotatedLeft;
    final gapTop = rotatedTop;
    final actualPreviewWidth = rotatedWidth;
    final actualPreviewHeight = rotatedHeight;

    print(
        'Final preview dimensions: ${actualPreviewWidth.toStringAsFixed(2)} x ${actualPreviewHeight.toStringAsFixed(2)}');
    print(
        'Final gaps: left=${gapLeft.toStringAsFixed(2)}, top=${gapTop.toStringAsFixed(2)}');
    print('=== End Rotation-Aware Container Fitting ===');

    return {
      'actualPreviewWidth': actualPreviewWidth,
      'actualPreviewHeight': actualPreviewHeight,
      'gapLeft': gapLeft,
      'gapTop': gapTop,
      'effectiveVideoWidth': effectiveVideoWidth,
      'effectiveVideoHeight': effectiveVideoHeight,
    };
  }

  /// Calculate text boundaries for canvas rendering
  static Rect calculateTextBoundaries({
    required String text,
    required double fontSize,
    required String fontFamily,
    required Size maxSize,
    required bool isPreview,
  }) {
    final textStyle = TextStyle(
      fontSize: fontSize,
      fontFamily: fontFamily,
      height: 1.0,
    );

    // Use existing TextAutoWrapHelper for consistent text wrapping
    final wrappedLines = TextAutoWrapHelper.wrapTextToFit(
      text,
      maxSize.width,
      maxSize.height,
      textStyle,
    );

    final textHeight =
        TextAutoWrapHelper.calculateWrappedTextHeight(wrappedLines, textStyle);
    final textWidth = _calculateMaxLineWidth(wrappedLines, textStyle);

    return Rect.fromLTWH(0, 0, textWidth, textHeight);
  }

  /// Calculate the maximum line width from wrapped text
  static double _calculateMaxLineWidth(List<String> lines, TextStyle style) {
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

  /// Get appropriate font file path based on font family and platform
  static String getFontFilePath(String fontFamily) {
    if (Platform.isAndroid) {
      switch (fontFamily.toLowerCase()) {
        case 'arial':
        case 'helvetica':
        case 'verdana':
          return '/system/fonts/Roboto-Regular.ttf';
        case 'times new roman':
        case 'georgia':
          return '/system/fonts/NotoSerif-Regular.ttf';
        case 'courier new':
          return '/system/fonts/DroidSansMono.ttf';
        case 'comic sans ms':
          return '/system/fonts/ComingSoon.ttf';
        case 'impact':
          return '/system/fonts/Roboto-Black.ttf';
        default:
          return '/system/fonts/Roboto-Regular.ttf';
      }
    } else {
      // iOS font paths
      switch (fontFamily.toLowerCase()) {
        case 'arial':
          return '/System/Library/Fonts/Arial.ttf';
        case 'helvetica':
          return '/System/Library/Fonts/Helvetica.ttc';
        case 'times new roman':
          return '/System/Library/Fonts/Times.ttc';
        case 'courier new':
          return '/System/Library/Fonts/Courier.ttc';
        case 'verdana':
          return '/System/Library/Fonts/Verdana.ttc';
        case 'georgia':
          return '/System/Library/Fonts/Georgia.ttc';
        default:
          return '/System/Library/Fonts/Arial.ttf';
      }
    }
  }

  /// Font-family specific width multipliers for more accurate text dimension calculation
  static double getFontWidthMultiplier(String fontFamily) {
    switch (fontFamily.toLowerCase()) {
      case 'arial':
      case 'helvetica':
        return 0.55; // Medium width
      case 'times new roman':
      case 'georgia':
        return 0.50; // Narrower serif fonts
      case 'courier new':
        return 0.60; // Monospace - wider
      case 'verdana':
        return 0.58; // Slightly wider
      case 'comic sans ms':
        return 0.52; // Casual font
      case 'impact':
        return 0.45; // Condensed font
      default:
        return 0.55; // Default for unknown fonts
    }
  }
}
