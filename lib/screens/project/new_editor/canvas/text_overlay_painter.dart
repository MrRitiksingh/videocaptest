import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:ai_video_creator_editor/screens/project/models/text_track_model.dart';
import 'package:ai_video_creator_editor/utils/text_auto_wrap_helper.dart';
import 'canvas_font_manager.dart';
import 'canvas_coordinate_manager.dart';
import 'text_rotation_manager.dart';

/// Renders text overlays on canvas with rotation and font scaling support
///
/// ✅ FIXED: Now uses rotation-aware gap calculations for consistent coordinate mapping
/// This ensures that text positioning, boundary constraints, and export coordinates
/// all use the same coordinate system, preventing positioning deviations when videos are rotated.
class TextOverlayPainter extends CustomPainter {
  final List<TextTrackModel> textTracks;
  final Rect? cropRect;
  final double currentTime;
  final Size containerSize;
  final Size videoSize;
  final Offset gapOffset;
  final bool isPreview;

  // Local drag state for smooth dragging
  final Map<String, Offset> _localDragPositions;

  // Rotation state for showing rotation handles
  final TextTrackModel? rotatingTrack;
  final double? tempRotation;

  // Selected track information
  final int selectedTextTrackIndex;

  // Video rotation for rotation-aware calculations
  final int videoRotation;

  TextOverlayPainter({
    required this.textTracks,
    this.cropRect,
    required this.currentTime,
    required this.containerSize,
    required this.videoSize,
    required this.gapOffset,
    required this.isPreview,
    Map<String, Offset>? localDragPositions,
    this.rotatingTrack,
    this.tempRotation,
    required this.selectedTextTrackIndex,
    this.videoRotation = 0,
  }) : _localDragPositions = localDragPositions ?? {};

  @override
  void paint(Canvas canvas, Size size) {
    for (final track in textTracks) {
      if (_isTrackVisible(track, currentTime)) {
        _drawTextOnCanvas(canvas, track, size);

        // Draw boundary box to show available area
        final fontSize = CanvasFontManager.calculateCanvasFontSize(
          baseFontSize: track.fontSize,
          targetSize: containerSize,
          videoSize: videoSize,
          isPreview: isPreview,
          videoRotation: videoRotation,
          cropRect:
              cropRect, // ✅ ADDED: Pass crop rectangle for rotation-aware calculations
        );
        final position = _getEffectivePosition(track, size, fontSize);

        _drawBoundaryBox(canvas, track, size, position, fontSize);

        // Draw selection box if this track is selected
        if (_isTrackSelected(track)) {
          _drawSelectionBox(canvas, track, size);

          // Note: Rotation handle removed - now using two-finger gestures
          // _drawRotationHandle(canvas, track, size, position, fontSize);
        }
      }
    }
  }

  bool _isTrackSelected(TextTrackModel track) {
    // Check if this track is currently selected by comparing with the selected index
    final trackIndex = textTracks.indexOf(track);
    return trackIndex == selectedTextTrackIndex;
  }

  void _drawSelectionBox(Canvas canvas, TextTrackModel track, Size size) {
    // Calculate text bounds using the same font size calculation
    final fontSize = CanvasFontManager.calculateCanvasFontSize(
      baseFontSize: track.fontSize,
      targetSize: containerSize,
      videoSize: videoSize,
      isPreview: isPreview,
      videoRotation: videoRotation,
      cropRect:
          cropRect, // ✅ ADDED: Pass crop rectangle for rotation-aware calculations
    );

    final textStyle = TextStyle(
      fontSize: fontSize,
      fontFamily: track.fontFamily,
      height: 1.0,
    );

    final availableSize = _calculateAvailableSize(track, size);
    final wrappedLines = TextAutoWrapHelper.wrapTextToFit(
      track.text,
      availableSize.width,
      availableSize.height,
      textStyle,
    );

    final textWidth = _calculateMaxLineWidth(wrappedLines, textStyle);
    final textHeight =
        TextAutoWrapHelper.calculateWrappedTextHeight(wrappedLines, textStyle);

    // Calculate position using effective position (considering local drag)
    final position = _getEffectivePosition(track, size, fontSize);

    // Draw selection box considering rotation
    // Use local tempRotation for immediate visual feedback during rotation
    final effectiveRotation = tempRotation ?? track.rotation;
    if (effectiveRotation != 0) {
      // ✅ FIXED: Use rotation-aware gap calculation for consistent selection box constraints
      Map<String, double> containerFitting;
      if (cropRect != null) {
        containerFitting =
            CanvasCoordinateManager.calculateCropAdjustedContainerFitting(
          videoWidth: videoSize.width,
          videoHeight: videoSize.height,
          containerWidth: size.width,
          containerHeight: size.height,
          cropRect: cropRect!,
        );
      } else {
        // ✅ FIXED: Use the gapOffset parameter which should already be rotation-aware
        // This ensures selection box constraints use the same coordinate system as positioning
        if (gapOffset != Offset.zero) {
          print('=== Selection Box: Using Gap Offset (Rotation-Aware) ===');
          containerFitting = {
            'actualPreviewWidth': size.width - (gapOffset.dx * 2),
            'actualPreviewHeight': size.height - (gapOffset.dy * 2),
            'gapLeft': gapOffset.dx,
            'gapTop': gapOffset.dy,
          };
          print('=== End Selection Box: Gap Offset ===');
        } else {
          containerFitting = CanvasCoordinateManager.calculateContainerFitting(
            videoWidth: videoSize.width,
            videoHeight: videoSize.height,
            containerWidth: size.width,
            containerHeight: size.height,
          );
        }
      }

      // For rotated text, calculate adjusted position to keep text within video preview boundaries
      final adjustedPosition =
          TextRotationManager.calculateRotatedPositionWithVideoBounds(
        basePosition: position,
        textWidth: textWidth,
        textHeight: textHeight,
        rotation: track.rotation,
        containerSize: size,
        videoSize: videoSize,
        containerFitting: containerFitting,
        cropRect: cropRect,
      );

      // Calculate rotation center using adjusted position
      final rotationCenter = TextRotationManager.calculateRotationCenter(
        textPosition: adjustedPosition,
        textWidth: textWidth,
        textHeight: textHeight,
        rotation: track.rotation,
      );

      // Apply rotation transformation
      TextRotationManager.applyRotationToCanvas(
        canvas: canvas,
        rotationCenter: rotationCenter,
        rotation: track.rotation,
      );

      // Draw the selection box at the adjusted position with original dimensions
      final selectionRect = Rect.fromLTWH(
        adjustedPosition.dx - 2,
        adjustedPosition.dy - 2,
        textWidth + 4,
        textHeight + 4,
      );

      // Draw curved border with black color and weight 1
      final borderPaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      // Draw rounded rectangle for curved corners
      final roundedRect =
          RRect.fromRectAndRadius(selectionRect, const Radius.circular(4.0));
      canvas.drawRRect(roundedRect, borderPaint);

      // Restore canvas state
      TextRotationManager.restoreCanvasState(canvas);
    } else {
      // No rotation - simple rectangular selection
      final selectionRect = Rect.fromLTWH(
        position.dx - 2,
        position.dy - 2,
        textWidth + 4,
        textHeight + 4,
      );

      // Draw curved border with black color and weight 1
      final borderPaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      // Draw rounded rectangle for curved corners
      final roundedRect =
          RRect.fromRectAndRadius(selectionRect, const Radius.circular(4.0));
      canvas.drawRRect(roundedRect, borderPaint);
    }
  }

  // Note: Rotation handle methods removed - now using two-finger gestures for rotation
  // The rotation handle drawing was replaced with gesture-based rotation in the canvas interaction handler

  bool _isTrackVisible(TextTrackModel track, double currentTime) {
    final startTime = track.trimStartTime * 1000;
    final endTime = track.trimEndTime * 1000;
    final currentTimeMs = currentTime * 1000;
    return currentTimeMs >= startTime && currentTimeMs < endTime;
  }

  void _drawTextOnCanvas(Canvas canvas, TextTrackModel track, Size size) {
    // Calculate font size using unified scaling system
    final fontSize = CanvasFontManager.calculateCanvasFontSize(
      baseFontSize: track.fontSize,
      targetSize: containerSize,
      videoSize: videoSize,
      isPreview: isPreview,
      videoRotation: videoRotation,
      cropRect:
          cropRect, // ✅ ADDED: Pass crop rectangle for rotation-aware calculations
    );

    // Create text style with calculated font size
    final textStyle = TextStyle(
      color: track.textColor,
      fontSize: fontSize,
      fontFamily: track.fontFamily,
      height: 1.0,
    );

    // Calculate available space for text wrapping
    final availableSize = _calculateAvailableSize(track, size);

    // Use existing TextAutoWrapHelper for consistent wrapping
    final wrappedLines = TextAutoWrapHelper.wrapTextToFit(
      track.text,
      availableSize.width,
      availableSize.height,
      textStyle,
    );

    // Calculate text position with proper scaling, using local drag position if available
    final position = _getEffectivePosition(track, size, fontSize);

    // ✅ ADDED: Print final drawing position
    print('=== Final Drawing Position Debug ===');
    print('Track: "${track.text}"');
    print('Track ID: ${track.id}');
    print('Final drawing position: (${position.dx}, ${position.dy})');
    print('Font size: $fontSize');
    print('Rotation: ${tempRotation ?? track.rotation}°');
    print('=== End Final Drawing Position Debug ===');

    // Draw text with rotation if needed
    // Use local tempRotation for immediate visual feedback during rotation
    final effectiveRotation = tempRotation ?? track.rotation;
    if (effectiveRotation != 0) {
      _drawRotatedText(
          canvas, wrappedLines, textStyle, position, effectiveRotation);
    } else {
      _drawNormalText(canvas, wrappedLines, textStyle, position);
    }
  }

  /// Get the effective position considering local drag state
  Offset _getEffectivePosition(
      TextTrackModel track, Size size, double fontSize) {
    // Check if we have a local drag position for this track
    final localPosition = _localDragPositions[track.id];
    if (localPosition != null) {
      // ✅ ADDED: Print local drag position usage
      print('=== Local Drag Position Debug ===');
      print('Track: "${track.text}"');
      print('Track ID: ${track.id}');
      print(
          'Using local drag position: (${localPosition.dx}, ${localPosition.dy})');
      print('checking update after reload ----------------------------');
      print(
          'Original track position: (${track.position.dx}, ${track.position.dy})');
      print(
          'Position difference: (${(localPosition.dx - track.position.dx).toStringAsFixed(2)}, ${(localPosition.dy - track.position.dy).toStringAsFixed(2)})');
      print('=== End Local Drag Position Debug ===');

      // Use local drag position for smooth dragging
      return localPosition;
    }

    // Use the original track position
    return _calculateTextPosition(track, size, fontSize);
  }

  /// Draw boundary box around text to show available area
  void _drawBoundaryBox(Canvas canvas, TextTrackModel track, Size size,
      Offset position, double fontSize) {
    // ✅ ADDED: Print boundary box debug
    print('=== Boundary Box Debug ===');
    print('Track: "${track.text}"');
    print('Track ID: ${track.id}');
    print('Input position: (${position.dx}, ${position.dy})');
    print('Font size: $fontSize');
    print('Container size: ${size.width} x ${size.height}');

    // Calculate text dimensions
    final textStyle = TextStyle(
      fontSize: fontSize,
      fontFamily: track.fontFamily,
      height: 1.0,
    );

    // Calculate available space for text wrapping
    final availableSize = _calculateAvailableSize(track, size);

    // Use existing TextAutoWrapHelper for consistent wrapping
    final wrappedLines = TextAutoWrapHelper.wrapTextToFit(
      track.text,
      availableSize.width,
      availableSize.height,
      textStyle,
    );

    // Calculate text dimensions
    final textWidth = _calculateMaxLineWidth(wrappedLines, textStyle);
    final textHeight =
        TextAutoWrapHelper.calculateWrappedTextHeight(wrappedLines, textStyle);

    print(
        'Text dimensions: ${textWidth.toStringAsFixed(2)} x ${textHeight.toStringAsFixed(2)}');
    print(
        'Available space: ${availableSize.width.toStringAsFixed(2)} x ${availableSize.height.toStringAsFixed(2)}');
    print('Wrapped lines: ${wrappedLines.length}');
    print('=== End Boundary Box Debug ===');

    // Draw boundary box considering rotation
    // Use local tempRotation for immediate visual feedback during rotation
    final effectiveRotation = tempRotation ?? track.rotation;
    if (effectiveRotation != 0) {
      // ✅ FIXED: Use rotation-aware gap calculation for consistent boundary box constraints
      Map<String, double> containerFitting;
      if (cropRect != null) {
        containerFitting =
            CanvasCoordinateManager.calculateCropAdjustedContainerFitting(
          videoWidth: videoSize.width,
          videoHeight: videoSize.height,
          containerWidth: size.width,
          containerHeight: size.height,
          cropRect: cropRect!,
        );
      } else {
        // ✅ FIXED: Use the gapOffset parameter which should already be rotation-aware
        // This ensures boundary box constraints use the same coordinate system as positioning
        if (gapOffset != Offset.zero) {
          print('=== Boundary Box: Using Gap Offset (Rotation-Aware) ===');
          containerFitting = {
            'actualPreviewWidth': size.width - (gapOffset.dx * 2),
            'actualPreviewHeight': size.height - (gapOffset.dy * 2),
            'gapLeft': gapOffset.dx,
            'gapTop': gapOffset.dy,
          };
          print('=== End Boundary Box: Gap Offset ===');
        } else {
          containerFitting = CanvasCoordinateManager.calculateContainerFitting(
            videoWidth: videoSize.width,
            videoHeight: videoSize.height,
            containerWidth: size.width,
            containerHeight: size.height,
          );
        }
      }

      // For rotated text, calculate adjusted position to keep text within video preview boundaries
      final adjustedPosition =
          TextRotationManager.calculateRotatedPositionWithVideoBounds(
        basePosition: position,
        textWidth: textWidth,
        textHeight: textHeight,
        rotation: effectiveRotation,
        containerSize: size,
        videoSize: videoSize,
        containerFitting: containerFitting,
        cropRect: cropRect,
      );

      // Calculate rotation center using adjusted position
      final rotationCenter = TextRotationManager.calculateRotationCenter(
        textPosition: adjustedPosition,
        textWidth: textWidth,
        textHeight: textHeight,
        rotation: effectiveRotation,
      );

      // Apply rotation transformation
      TextRotationManager.applyRotationToCanvas(
        canvas: canvas,
        rotationCenter: rotationCenter,
        rotation: effectiveRotation,
      );

      // Draw the boundary box at the adjusted position with original dimensions
      final boundaryBox = Rect.fromLTWH(
        adjustedPosition.dx - 4,
        adjustedPosition.dy - 4,
        textWidth + 8,
        textHeight + 8,
      );

      // ✅ ADDED: Print rotated boundary box position
      print('=== Rotated Boundary Box Position ===');
      print(
          'Adjusted position: (${adjustedPosition.dx.toStringAsFixed(2)}, ${adjustedPosition.dy.toStringAsFixed(2)})');
      print(
          'Boundary box: (${boundaryBox.left.toStringAsFixed(2)}, ${boundaryBox.top.toStringAsFixed(2)}) to (${boundaryBox.right.toStringAsFixed(2)}, ${boundaryBox.bottom.toStringAsFixed(2)})');
      print(
          'Boundary box size: ${boundaryBox.width.toStringAsFixed(2)} x ${boundaryBox.height.toStringAsFixed(2)}');
      print('=== End Rotated Boundary Box Position ===');

      // Draw curved border with black color and weight 1
      final borderPaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      // Draw rounded rectangle for curved corners
      final roundedRect =
          RRect.fromRectAndRadius(boundaryBox, const Radius.circular(4.0));
      canvas.drawRRect(roundedRect, borderPaint);

      // Restore canvas state
      TextRotationManager.restoreCanvasState(canvas);
    } else {
      // No rotation - simple rectangular boundary
      final boundaryBox = Rect.fromLTWH(
        position.dx - 4,
        position.dy - 4,
        textWidth + 8,
        textHeight + 8,
      );

      // ✅ ADDED: Print non-rotated boundary box position
      print('=== Non-Rotated Boundary Box Position ===');
      print(
          'Base position: (${position.dx.toStringAsFixed(2)}, ${position.dy.toStringAsFixed(2)})');
      print(
          'Boundary box: (${boundaryBox.left.toStringAsFixed(2)}, ${boundaryBox.top.toStringAsFixed(2)}) to (${boundaryBox.right.toStringAsFixed(2)}, ${boundaryBox.bottom.toStringAsFixed(2)})');
      print(
          'Boundary box size: ${boundaryBox.width.toStringAsFixed(2)} x ${boundaryBox.height.toStringAsFixed(2)}');
      print('=== End Non-Rotated Boundary Box Position ===');

      // Draw curved border with black color and weight 1
      final borderPaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      // Draw rounded rectangle for curved corners
      final roundedRect =
          RRect.fromRectAndRadius(boundaryBox, const Radius.circular(4.0));
      canvas.drawRRect(roundedRect, borderPaint);
    }
  }

  Size _calculateAvailableSize(TextTrackModel track, Size containerSize) {
    // ✅ ADDED: Print available space calculation debug
    print('=== Available Space Calculation Debug ===');
    print('Track: "${track.text}"');
    print('Track ID: ${track.id}');
    print('Track position: (${track.position.dx}, ${track.position.dy})');
    print('Container size: ${containerSize.width} x ${containerSize.height}');
    print('Video size: ${videoSize.width} x ${videoSize.height}');
    print('Crop rect: $cropRect');
    print('Boundary buffer: 10.0');

    // Get the container fitting that was already calculated in _calculatePreviewPosition
    Map<String, double> containerFitting;
    if (cropRect != null) {
      containerFitting =
          CanvasCoordinateManager.calculateCropAdjustedContainerFitting(
        videoWidth: videoSize.width,
        videoHeight: videoSize.height,
        containerWidth: containerSize.width,
        containerHeight: containerSize.height,
        cropRect: cropRect!,
      );
    } else {
      if (gapOffset != Offset.zero) {
        // Use the same gap offset logic as _calculatePreviewPosition
        containerFitting = {
          'actualPreviewWidth': containerSize.width - (gapOffset.dx * 2),
          'actualPreviewHeight': containerSize.height - (gapOffset.dy * 2),
          'gapLeft': gapOffset.dx,
          'gapTop': gapOffset.dy,
        };
      } else {
        containerFitting = CanvasCoordinateManager.calculateContainerFitting(
          videoWidth: videoSize.width,
          videoHeight: videoSize.height,
          containerWidth: containerSize.width,
          containerHeight: containerSize.height,
        );
      }
    }

    // Normal calculation when not dragging - pass the pre-calculated container fitting
    final availableSize = CanvasCoordinateManager.calculateAvailableSpace(
      textPosition: track.position,
      containerSize: containerSize,
      videoSize: videoSize,
      cropRect: cropRect,
      boundaryBuffer: 10.0,
      rotation: videoRotation,
      preCalculatedContainerFitting: containerFitting,
    );

    print(
        'Calculated available space: ${availableSize.width.toStringAsFixed(2)} x ${availableSize.height.toStringAsFixed(2)}');
    print('=== End Available Space Calculation Debug ===');

    return availableSize;
  }

  Offset _calculateTextPosition(
      TextTrackModel track, Size size, double fontSize) {
    if (isPreview) {
      return _calculatePreviewPosition(track, size);
    } else {
      return _calculateExportPosition(track, size);
    }
  }

  Offset _calculatePreviewPosition(TextTrackModel track, Size containerSize) {
    // ✅ FIXED: Use rotation-aware gap calculation for consistent coordinate mapping
    Map<String, double> containerFitting;

    if (cropRect != null) {
      containerFitting =
          CanvasCoordinateManager.calculateCropAdjustedContainerFitting(
        videoWidth: videoSize.width,
        videoHeight: videoSize.height,
        containerWidth: containerSize.width,
        containerHeight: containerSize.height,
        cropRect: cropRect!, // Non-null assertion since we checked above
      );
    } else {
      // ✅ FIXED: Use the gapOffset parameter which should already be rotation-aware
      // This ensures coordinate mapping uses the same gaps as boundary constraints
      if (gapOffset != Offset.zero) {
        print('=== Preview Position: Using Gap Offset (Rotation-Aware) ===');
        // Use the gapOffset which should already be rotation-aware from the provider
        // This ensures consistency between coordinate mapping and boundary constraints
        containerFitting = {
          'actualPreviewWidth': containerSize.width - (gapOffset.dx * 2),
          'actualPreviewHeight': containerSize.height - (gapOffset.dy * 2),
          'gapLeft': gapOffset.dx,
          'gapTop': gapOffset.dy,
        };
        print('=== End Preview Position: Gap Offset ===');
      } else {
        containerFitting = CanvasCoordinateManager.calculateContainerFitting(
          videoWidth: videoSize.width,
          videoHeight: videoSize.height,
          containerWidth: containerSize.width,
          containerHeight: containerSize.height,
        );
      }
    }

    final actualPreviewWidth = containerFitting['actualPreviewWidth']!;
    final actualPreviewHeight = containerFitting['actualPreviewHeight']!;
    final gapLeft = containerFitting['gapLeft']!;
    final gapTop = containerFitting['gapTop']!;

    // ✅ ADDED: Print overlay position coordinates for debugging
    print('=== Text Overlay Position Debug ===');
    print('Track: "${track.text}"');
    print('Track ID: ${track.id}');
    print('Container size: ${containerSize.width} x ${containerSize.height}');
    print('Video size: ${videoSize.width} x ${videoSize.height}');
    print('Crop rect: $cropRect');
    print('Container fitting: $containerFitting');
    print('Gaps: left=$gapLeft, top=$gapTop');
    print('Preview area: ${actualPreviewWidth} x ${actualPreviewHeight}');

    // Show original track position (stored in model)
    print('checking update after reload ----------------------------');
    print(
        'Original track position (model): (${track.position.dx}, ${track.position.dy})');

    // Map from preview coordinates to video coordinates
    final videoX =
        (track.position.dx - gapLeft) * (videoSize.width / actualPreviewWidth);
    final videoY =
        (track.position.dy - gapTop) * (videoSize.height / actualPreviewHeight);

    print(
        'Video coordinates: (${videoX.toStringAsFixed(2)}, ${videoY.toStringAsFixed(2)})');
    print(
        'Video position percentages: X=${((videoX / videoSize.width) * 100).toStringAsFixed(2)}%, Y=${((videoY / videoSize.height) * 100).toStringAsFixed(2)}%');

    // Map back to preview coordinates
    final previewX = (videoX * actualPreviewWidth / videoSize.width) + gapLeft;
    final previewY = (videoY * actualPreviewHeight / videoSize.height) + gapTop;

    print(
        'Calculated preview position: (${previewX.toStringAsFixed(2)}, ${previewY.toStringAsFixed(2)})');
    print(
        'Position difference: (${(previewX - track.position.dx).toStringAsFixed(2)}, ${(previewY - track.position.dy).toStringAsFixed(2)})');
    print('=== End Text Overlay Position Debug ===');

    return Offset(previewX, previewY);
  }

  Offset _calculateExportPosition(TextTrackModel track, Size containerSize) {
    // ✅ FIXED: Use rotation-aware gap calculation for consistent export positioning
    Map<String, double> containerFitting;

    if (cropRect != null) {
      containerFitting =
          CanvasCoordinateManager.calculateCropAdjustedContainerFitting(
        videoWidth: videoSize.width,
        videoHeight: videoSize.height,
        containerWidth: containerSize.width,
        containerHeight: containerSize.height,
        cropRect: cropRect!, // Non-null assertion since we checked above
      );
    } else {
      // ✅ FIXED: Use the gapOffset parameter which should already be rotation-aware
      // This ensures export positioning uses the same coordinate system as preview
      if (gapOffset != Offset.zero) {
        print('=== Export Position: Using Gap Offset (Rotation-Aware) ===');
        // Use the gapOffset which should already be rotation-aware from the provider
        containerFitting = {
          'actualPreviewWidth': containerSize.width - (gapOffset.dx * 2),
          'actualPreviewHeight': containerSize.height - (gapOffset.dy * 2),
          'gapLeft': gapOffset.dx,
          'gapTop': gapOffset.dy,
        };
        print('=== End Export Position: Gap Offset ===');
      } else {
        containerFitting = CanvasCoordinateManager.calculateContainerFitting(
          videoWidth: videoSize.width,
          videoHeight: videoSize.height,
          containerWidth: containerSize.width,
          containerHeight: containerSize.height,
        );
      }
    }

    final actualPreviewWidth = containerFitting['actualPreviewWidth']!;
    final actualPreviewHeight = containerFitting['actualPreviewHeight']!;
    final gapLeft = containerFitting['gapLeft']!;
    final gapTop = containerFitting['gapTop']!;

    // ✅ ADDED: Print export position coordinates for debugging
    print('=== Text Export Position Debug ===');
    print('Track: "${track.text}"');
    print('Track ID: ${track.id}');
    print('Container size: ${containerSize.width} x ${containerSize.height}');
    print('Video size: ${videoSize.width} x ${videoSize.height}');
    print('Crop rect: $cropRect');
    print('Container fitting: $containerFitting');
    print('Gaps: left=$gapLeft, top=$gapTop');
    print('Preview area: ${actualPreviewWidth} x ${actualPreviewHeight}');

    // Show original track position (stored in model)
    print(
        'Original track position (model): (${track.position.dx}, ${track.position.dy})');

    // Map from preview coordinates to export coordinates
    final exportX =
        (track.position.dx - gapLeft) * (videoSize.width / actualPreviewWidth);
    final exportY =
        (track.position.dy - gapTop) * (videoSize.height / actualPreviewHeight);

    print(
        'Export coordinates: (${exportX.toStringAsFixed(2)}, ${exportY.toStringAsFixed(2)})');
    print(
        'Export position percentages: X=${((exportX / videoSize.width) * 100).toStringAsFixed(2)}%, Y=${((exportY / videoSize.height) * 100).toStringAsFixed(2)}%');
    print('=== End Text Export Position Debug ===');

    return Offset(exportX, exportY);
  }

  void _drawRotatedText(Canvas canvas, List<String> lines, TextStyle style,
      Offset position, double rotation) {
    // ✅ ADDED: Print rotated text positioning debug
    print('=== Rotated Text Positioning Debug ===');
    print('Text: "${lines.join(' ')}"');
    print('Base position: (${position.dx}, ${position.dy})');
    print('Rotation: ${rotation}°');

    // Calculate text dimensions
    final textWidth = _calculateMaxLineWidth(lines, style);
    final textHeight =
        TextAutoWrapHelper.calculateWrappedTextHeight(lines, style);

    print(
        'Text dimensions: ${textWidth.toStringAsFixed(2)} x ${textHeight.toStringAsFixed(2)}');

    // Note: Rotated bounds are now calculated internally in calculateRotatedPositionWithVideoBounds

    // ✅ FIXED: Use rotation-aware gap calculation for consistent rotated text constraints
    Map<String, double> containerFitting;
    if (cropRect != null) {
      containerFitting =
          CanvasCoordinateManager.calculateCropAdjustedContainerFitting(
        videoWidth: videoSize.width,
        videoHeight: videoSize.height,
        containerWidth: containerSize.width,
        containerHeight: containerSize.height,
        cropRect: cropRect!,
      );
    } else {
      // ✅ FIXED: Use the gapOffset parameter which should already be rotation-aware
      // This ensures rotated text constraints use the same coordinate system as positioning
      if (gapOffset != Offset.zero) {
        print('=== Rotated Text: Using Gap Offset (Rotation-Aware) ===');
        containerFitting = {
          'actualPreviewWidth': containerSize.width - (gapOffset.dx * 2),
          'actualPreviewHeight': containerSize.height - (gapOffset.dy * 2),
          'gapLeft': gapOffset.dx,
          'gapTop': gapOffset.dy,
        };
        print('=== End Rotated Text: Gap Offset ===');
      } else {
        containerFitting = CanvasCoordinateManager.calculateContainerFitting(
          videoWidth: videoSize.width,
          videoHeight: videoSize.height,
          containerWidth: containerSize.width,
          containerHeight: containerSize.height,
        );
      }
    }

    // Calculate adjusted position to keep rotated text within video preview boundaries
    final adjustedPosition =
        TextRotationManager.calculateRotatedPositionWithVideoBounds(
      basePosition: position,
      textWidth: textWidth,
      textHeight: textHeight,
      rotation: rotation,
      containerSize: containerSize,
      videoSize: videoSize,
      containerFitting: containerFitting,
      cropRect: cropRect,
    );

    print(
        'Adjusted position for rotation: (${adjustedPosition.dx.toStringAsFixed(2)}, ${adjustedPosition.dy.toStringAsFixed(2)})');
    print(
        'Position adjustment: (${(adjustedPosition.dx - position.dx).toStringAsFixed(2)}, ${(adjustedPosition.dy - position.dy).toStringAsFixed(2)})');
    print('=== End Rotated Text Positioning Debug ===');

    // Calculate rotation center using adjusted position
    final rotationCenter = TextRotationManager.calculateRotationCenter(
      textPosition: adjustedPosition,
      textWidth: textWidth,
      textHeight: textHeight,
      rotation: rotation,
    );

    // Apply rotation transformation
    TextRotationManager.applyRotationToCanvas(
      canvas: canvas,
      rotationCenter: rotationCenter,
      rotation: rotation,
    );

    // Draw text at adjusted position
    _drawNormalText(canvas, lines, style, adjustedPosition);

    // Restore canvas state
    TextRotationManager.restoreCanvasState(canvas);
  }

  void _drawNormalText(
      Canvas canvas, List<String> lines, TextStyle style, Offset position) {
    // ✅ ADDED: Print normal text drawing debug
    print('=== Normal Text Drawing Debug ===');
    print('Text: "${lines.join(' ')}"');
    print('Drawing position: (${position.dx}, ${position.dy})');
    print('Number of lines: ${lines.length}');
    print('=== End Normal Text Drawing Debug ===');

    double currentY = position.dy;

    for (final line in lines) {
      final textSpan = TextSpan(text: line, style: style);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.left,
      );

      textPainter.layout();
      textPainter.paint(canvas, Offset(position.dx, currentY));

      currentY += textPainter.height;

      // Dispose TextPainter to free memory
      textPainter.dispose();
    }
  }

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

  @override
  bool shouldRepaint(TextOverlayPainter oldDelegate) {
    return oldDelegate.textTracks != textTracks ||
        oldDelegate.cropRect != cropRect ||
        oldDelegate.currentTime != currentTime ||
        oldDelegate.containerSize != containerSize ||
        oldDelegate.videoSize != videoSize ||
        oldDelegate.gapOffset != gapOffset ||
        oldDelegate.isPreview != isPreview ||
        oldDelegate.tempRotation != tempRotation;
  }

  @override
  bool shouldRebuildSemantics(TextOverlayPainter oldDelegate) => false;
}
