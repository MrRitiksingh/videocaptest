import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:ai_video_creator_editor/screens/project/models/text_track_model.dart';
import 'package:ai_video_creator_editor/screens/project/models/video_track_model.dart';
import 'package:ai_video_creator_editor/utils/text_auto_wrap_helper.dart';
import 'canvas_font_manager.dart';
import '../canvas_configuration.dart';

/// Advanced canvas-based text overlay painter for media canvas renderer
/// 
/// Features:
/// - Dynamic canvas size support (no hardcoded dimensions)
/// - Local drag position support for smooth interactions
/// - Canvas-aware boundary constraints
/// - Rotation and scaling support
/// - Preview-to-export coordinate mapping
class CanvasTextOverlayPainter extends CustomPainter {
  final List<TextTrackModel> textTracks;
  final double currentTime;
  final Size canvasSize; // Dynamic canvas size (preview or export)
  final VideoTrackModel? currentVideoTrack;
  final int? selectedTextIndex;
  final bool isExportMode; // true for export, false for preview
  
  
  // Rotation state for showing rotation handles
  final TextTrackModel? rotatingTrack;
  final double? tempRotation;
  
  // Selection and interaction state for visual feedback
  final String? selectedTrackId;
  final String? draggingTrackId;
  
  // Canvas configuration for dual canvas system
  final CanvasConfiguration? canvasConfiguration;

  CanvasTextOverlayPainter({
    required this.textTracks,
    required this.currentTime,
    required this.canvasSize,
    this.currentVideoTrack,
    this.selectedTextIndex,
    this.isExportMode = false,
    this.rotatingTrack,
    this.tempRotation,
    this.selectedTrackId,
    this.draggingTrackId,
    this.canvasConfiguration,
  });

  // Factory constructor for backward compatibility with old parameter names
  factory CanvasTextOverlayPainter.legacy({
    required List<TextTrackModel> textTracks,
    required double currentTime,
    required Size containerSize,
    required Size videoSize,
    bool isGlobal = false,
    int? selectedTextTrackIndex,
  }) {
    return CanvasTextOverlayPainter(
      textTracks: textTracks,
      currentTime: currentTime,
      canvasSize: containerSize, // Use containerSize as canvasSize
      selectedTextIndex: selectedTextTrackIndex,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    print('🎨 CanvasTextOverlayPainter.paint()');
    print('   Canvas size: ${size.width} x ${size.height}');
    print('   Text tracks: ${textTracks.length}');
    print('   Current time: ${currentTime.toStringAsFixed(2)}s');
    print('   Export mode: $isExportMode');

    // Get all visible tracks at current time
    final visibleTracks = <TextTrackModel>[];
    for (int i = 0; i < textTracks.length; i++) {
      final track = textTracks[i];
      if (_isTrackVisible(track, currentTime)) {
        visibleTracks.add(track);
      }
    }

    // Sort visible tracks by laneIndex (lower lane = drawn first = behind)
    // This ensures proper z-order for multi-lane support
    visibleTracks.sort((a, b) => a.laneIndex.compareTo(b.laneIndex));

    print('   Visible tracks: ${visibleTracks.length} (sorted by lane)');

    // Render tracks in lane order
    for (final track in visibleTracks) {
      final originalIndex = textTracks.indexOf(track);
      final isSelected = originalIndex == selectedTextIndex;
      print('   Rendering text: "${track.text}" (lane ${track.laneIndex})');
      _drawTextTrack(canvas, track, size, isSelected);
    }
  }

  bool _isTrackVisible(TextTrackModel track, double currentTime) {
    final startTime = track.trimStartTime;
    final endTime = track.trimEndTime;
    return currentTime >= startTime && currentTime <= endTime;
  }

  void _drawTextTrack(Canvas canvas, TextTrackModel track, Size size, bool isSelected) {
    // Calculate font size with canvas-aware scaling
    final fontSize = _calculateCanvasFontSize(track.fontSize, size);
    
    // Create text style
    final textStyle = TextStyle(
      color: track.textColor,
      fontSize: fontSize,
      fontFamily: track.fontFamily,
      height: 1.0,
      shadows: [
        Shadow(
          offset: const Offset(1, 1),
          blurRadius: 2,
          color: Colors.black.withValues(alpha: 0.5),
        ),
      ],
    );

    // Get effective position (considering local drag)
    final position = _getEffectivePosition(track, size);
    
    print('   Text "${track.text}": position (${position.dx}, ${position.dy}), fontSize: $fontSize');
    
    // Calculate available space for text wrapping
    final availableSize = _calculateAvailableSize(track, position, size);
    
    // Use TextAutoWrapHelper for consistent wrapping
    final wrappedLines = TextAutoWrapHelper.wrapTextToFit(
      track.text,
      availableSize.width,
      availableSize.height,
      textStyle,
    );

    // Draw text with rotation if needed
    // Use local tempRotation for immediate visual feedback during rotation
    final effectiveRotation = (rotatingTrack?.id == track.id) ? 
        (tempRotation ?? track.rotation) : track.rotation;
        
    if (effectiveRotation != 0) {
      _drawRotatedText(canvas, wrappedLines, textStyle, position, effectiveRotation, size);
    } else {
      _drawNormalText(canvas, wrappedLines, textStyle, position);
    }

    // Draw visual feedback (only in preview mode)
    if (!isExportMode) {
      _drawVisualFeedback(canvas, track, wrappedLines, textStyle, position, effectiveRotation, isSelected);
    }
  }

  /// Calculate font size with canvas-aware scaling
  double _calculateCanvasFontSize(double baseFontSize, Size canvasSize) {
    if (canvasConfiguration != null) {
      // Use CanvasConfiguration for consistent dual canvas scaling
      if (isExportMode) {
        // For export mode, use export canvas size and scale from preview
        final exportCanvasSize = canvasConfiguration!.exportCanvasSize;
        final referenceWidth = 1920.0; // Reference width for export scaling
        final scale = exportCanvasSize.width / referenceWidth;
        final scaledFontSize = baseFontSize * scale.clamp(0.5, 3.0);
        
        print('🔤 Canvas Text Overlay - Export font scaling:');
        print('   Base font size: $baseFontSize');
        print('   Export canvas: ${exportCanvasSize.width}x${exportCanvasSize.height}');
        print('   Scale factor: ${scale.toStringAsFixed(3)}');
        print('   Scaled font size: $scaledFontSize');
        
        return scaledFontSize;
      } else {
        // For preview mode, use preview canvas size
        final previewCanvasSize = canvasConfiguration!.previewCanvasSize;
        final referenceWidth = 1920.0; // Reference width for preview scaling
        final scale = previewCanvasSize.width / referenceWidth;
        final scaledFontSize = baseFontSize * scale.clamp(0.5, 3.0);
        
        print('🔤 Canvas Text Overlay - Preview font scaling:');
        print('   Base font size: $baseFontSize');
        print('   Preview canvas: ${previewCanvasSize.width}x${previewCanvasSize.height}');
        print('   Scale factor: ${scale.toStringAsFixed(3)}');
        print('   Scaled font size: $scaledFontSize');
        
        return scaledFontSize;
      }
    } else {
      // Fallback to old method if no CanvasConfiguration provided
      if (isExportMode) {
        // For export mode, use base font size scaled by canvas size
        final referenceWidth = 1920.0; // Reference width for export scaling
        final scale = canvasSize.width / referenceWidth;
        return baseFontSize * scale.clamp(0.5, 3.0);
      } else {
        // For preview mode, scale based on preview canvas size
        // Use CanvasFontManager for consistent scaling
        return CanvasFontManager.calculateCanvasFontSize(
          baseFontSize: baseFontSize,
          targetSize: canvasSize,
          videoSize: canvasSize, // Use canvas size as video size for media renderer
          isPreview: true,
          videoRotation: 0, // No video rotation in media canvas context
        );
      }
    }
  }

  /// Get the effective position - now simply uses track position since local positions are embedded
  Offset _getEffectivePosition(TextTrackModel track, Size canvasSize) {
    // TextTrackModel objects now have local positions embedded directly in them
    // from _createTextTracksWithLocalPositions() in MediaCanvasRenderer
    // 
    // For visual feedback, we should NOT apply position adjustment here because
    // the rotation transformation should use the original base position as the center
    // The text rendering itself handles positioning correctly with the embedded local positions
    return _calculateCanvasPosition(track, canvasSize);
  }

  /// Calculate canvas position for text track
  Offset _calculateCanvasPosition(TextTrackModel track, Size canvasSize) {
    if (isExportMode) {
      // For export mode, use the track position directly as it should already be
      // scaled appropriately for the export canvas dimensions
      return track.position;
    } else {
      // For preview mode, the track position should work directly with the canvas
      // since we're now using canvas-based positioning throughout
      return track.position;
    }
  }

  /// Calculate available space for text wrapping within dynamic canvas boundaries
  Size _calculateAvailableSize(TextTrackModel track, Offset position, Size canvasSize) {
    // Dynamic canvas-aware boundary calculation with proportional buffers
    final boundaryBufferX = canvasSize.width * 0.02; // 2% of canvas width
    final boundaryBufferY = canvasSize.height * 0.02; // 2% of canvas height
    
    // Calculate actual available space from text position to canvas edges
    final availableWidth = canvasSize.width - position.dx - boundaryBufferX;
    final availableHeight = canvasSize.height - position.dy - boundaryBufferY;
    
    // Dynamic minimum sizes based on canvas dimensions (for extreme edge cases only)
    final minWidth = math.max(100.0, canvasSize.width * 0.15); // At least 15% of canvas width
    final minHeight = math.max(50.0, canvasSize.height * 0.1);  // At least 10% of canvas height
    
    // Use full available space instead of artificial 85% constraint
    return Size(
      math.max(availableWidth, minWidth), // Use actual available width or minimum
      math.max(availableHeight, minHeight), // Use actual available height or minimum
    );
  }

  void _drawRotatedText(Canvas canvas, List<String> lines, TextStyle style,
                       Offset position, double rotation, Size canvasSize) {
    // Calculate text dimensions
    final textWidth = _calculateMaxLineWidth(lines, style);
    final textHeight = TextAutoWrapHelper.calculateWrappedTextHeight(lines, style);

    // Since we now store visual positions, the position parameter is already
    // where the text should visually appear. We need to calculate the rotation
    // center relative to this visual position.
    final rotationCenter = Offset(
      position.dx + textWidth / 2,
      position.dy + textHeight / 2,
    );

    // Apply rotation transformation around the text's center
    canvas.save();
    canvas.translate(rotationCenter.dx, rotationCenter.dy);
    canvas.rotate(rotation * 3.14159 / 180.0); // Convert degrees to radians
    canvas.translate(-rotationCenter.dx, -rotationCenter.dy);

    // Draw text at the visual position
    _drawNormalText(canvas, lines, style, position);

    // Restore canvas state
    canvas.restore();
  }

  void _drawNormalText(Canvas canvas, List<String> lines, TextStyle style, Offset position) {
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
      textPainter.dispose();
    }
  }

  /// Draw comprehensive visual feedback for text interactions
  void _drawVisualFeedback(Canvas canvas, TextTrackModel track, List<String> lines, 
                          TextStyle style, Offset position, double rotation, bool isSelected) {
    final textWidth = _calculateMaxLineWidth(lines, style);
    final textHeight = TextAutoWrapHelper.calculateWrappedTextHeight(lines, style);
    
    // Determine feedback state
    final isDragging = draggingTrackId == track.id;
    final isTrackSelected = selectedTrackId == track.id || isSelected;
    final isHovered = false; // Could be enhanced with hover detection
    
    // Choose colors and styles based on state
    Color borderColor;
    double strokeWidth;
    double opacity;
    
    if (isDragging) {
      borderColor = Colors.orange;
      strokeWidth = 3.0;
      opacity = 0.8;
    } else if (isTrackSelected) {
      borderColor = Colors.blue;
      strokeWidth = 2.5;
      opacity = 0.9;
    } else if (isHovered) {
      borderColor = Colors.grey;
      strokeWidth = 1.5;
      opacity = 0.6;
    } else {
      return; // No visual feedback needed
    }
    
    final borderPaint = Paint()
      ..color = borderColor.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
      
    // Background highlight for dragging
    final backgroundPaint = isDragging ? (Paint()
      ..color = borderColor.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill) : null;
    
    final padding = isDragging ? 8.0 : 4.0;
    final cornerRadius = isDragging ? 8.0 : 4.0;
    
    final selectionRect = Rect.fromLTWH(
      position.dx - padding,
      position.dy - padding,
      textWidth + padding * 2,
      textHeight + padding * 2,
    );
    
    if (rotation != 0) {
      // Use the same rotation approach as text rendering for consistent visual feedback
      // Since we now store visual positions, calculate rotation center relative to visual position
      final rotationCenter = Offset(
        position.dx + textWidth / 2,
        position.dy + textHeight / 2,
      );

      // Apply rotation transformation around the text's center (same as text rendering)
      canvas.save();
      canvas.translate(rotationCenter.dx, rotationCenter.dy);
      canvas.rotate(rotation * 3.14159 / 180.0); // Convert degrees to radians
      canvas.translate(-rotationCenter.dx, -rotationCenter.dy);
      
      // Draw selection box at original position in rotated coordinate system
      final rotatedSelectionRect = Rect.fromLTWH(
        position.dx - padding,
        position.dy - padding,
        textWidth + padding * 2,
        textHeight + padding * 2,
      );
      final roundedRect = RRect.fromRectAndRadius(rotatedSelectionRect, Radius.circular(cornerRadius));
      
      // Draw background if dragging
      if (backgroundPaint != null) {
        canvas.drawRRect(roundedRect, backgroundPaint);
      }
      
      // Draw border
      canvas.drawRRect(roundedRect, borderPaint);
      
      // Draw corner handles for selected state
      if (isTrackSelected && !isDragging) {
        _drawCornerHandles(canvas, rotatedSelectionRect, strokeWidth);
      }
      
      // Restore canvas state (same as text rendering)
      canvas.restore();
    } else {
      // Draw normal feedback
      final roundedRect = RRect.fromRectAndRadius(selectionRect, Radius.circular(cornerRadius));
      
      // Draw background if dragging
      if (backgroundPaint != null) {
        canvas.drawRRect(roundedRect, backgroundPaint);
      }
      
      // Draw border
      canvas.drawRRect(roundedRect, borderPaint);
      
      // Draw corner handles for selected state
      if (isTrackSelected && !isDragging) {
        _drawCornerHandles(canvas, selectionRect, strokeWidth);
      }
    }
    
    // Draw drag indicator
    if (isDragging) {
      _drawDragIndicator(canvas, position, textWidth, textHeight, borderColor);
    }
  }
  
  /// Draw corner handles for text manipulation
  void _drawCornerHandles(Canvas canvas, Rect rect, double strokeWidth) {
    final handleSize = 8.0;
    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final handleBorderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    
    // Draw handles at corners
    final corners = [
      Offset(rect.left, rect.top),
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.bottom),
      Offset(rect.left, rect.bottom),
    ];
    
    for (final corner in corners) {
      final handleRect = Rect.fromCenter(
        center: corner,
        width: handleSize,
        height: handleSize,
      );
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(handleRect, const Radius.circular(2.0)),
        handlePaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(handleRect, const Radius.circular(2.0)),
        handleBorderPaint,
      );
    }
  }
  
  /// Draw drag movement indicator
  void _drawDragIndicator(Canvas canvas, Offset position, double textWidth, double textHeight, Color color) {
    // Draw center crosshair
    final centerX = position.dx + textWidth / 2;
    final centerY = position.dy + textHeight / 2;
    final crosshairSize = 12.0;
    
    final crosshairPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    // Horizontal line
    canvas.drawLine(
      Offset(centerX - crosshairSize, centerY),
      Offset(centerX + crosshairSize, centerY),
      crosshairPaint,
    );
    
    // Vertical line
    canvas.drawLine(
      Offset(centerX, centerY - crosshairSize),
      Offset(centerX, centerY + crosshairSize),
      crosshairPaint,
    );
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
  bool shouldRepaint(CanvasTextOverlayPainter oldDelegate) {
    return oldDelegate.textTracks != textTracks ||
           oldDelegate.currentTime != currentTime ||
           oldDelegate.canvasSize != canvasSize ||
           oldDelegate.currentVideoTrack != currentVideoTrack ||
           oldDelegate.selectedTextIndex != selectedTextIndex ||
           oldDelegate.isExportMode != isExportMode ||
           oldDelegate.tempRotation != tempRotation ||
           oldDelegate.selectedTrackId != selectedTrackId ||
           oldDelegate.draggingTrackId != draggingTrackId;
  }
}