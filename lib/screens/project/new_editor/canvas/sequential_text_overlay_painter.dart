import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:ai_video_creator_editor/screens/project/models/text_track_model.dart';
import 'package:ai_video_creator_editor/screens/project/models/video_track_model.dart';
import 'package:ai_video_creator_editor/utils/text_auto_wrap_helper.dart';

/// Text overlay painter designed for sequential preview system
/// 
/// This painter renders text overlays on the sequential preview canvas where videos
/// are positioned and transformed individually. Text overlays are treated as global
/// canvas elements that appear above the current video.
class SequentialTextOverlayPainter extends CustomPainter {
  final List<TextTrackModel> textTracks;
  final double currentTime;
  final Size canvasSize;
  final VideoTrackModel? currentVideoTrack; // Current video context for reference
  final int? selectedTextIndex;

  SequentialTextOverlayPainter({
    required this.textTracks,
    required this.currentTime,
    required this.canvasSize,
    this.currentVideoTrack,
    this.selectedTextIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    print('🎨 SequentialTextOverlayPainter.paint()');
    print('   Canvas size: ${size.width} x ${size.height}');
    print('   Text tracks: ${textTracks.length}');
    print('   Current time: ${currentTime.toStringAsFixed(2)}s');
    
    for (int i = 0; i < textTracks.length; i++) {
      final track = textTracks[i];
      if (_isTextVisible(track, currentTime)) {
        print('   Rendering text: "${track.text}"');
        _drawTextTrack(canvas, track, size, i == selectedTextIndex);
      }
    }
  }

  bool _isTextVisible(TextTrackModel track, double currentTime) {
    final startTime = track.trimStartTime;
    final endTime = track.trimEndTime;
    return currentTime >= startTime && currentTime <= endTime;
  }

  void _drawTextTrack(Canvas canvas, TextTrackModel track, Size size, bool isSelected) {
    // Calculate font size with sequential preview scaling
    final fontSize = _calculateFontSize(track.fontSize);
    
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

    // Calculate text position on canvas
    final position = _calculateCanvasPosition(track);
    
    print('   Text "${track.text}": position (${position.dx}, ${position.dy}), fontSize: $fontSize');
    
    // Handle text wrapping
    final availableSize = _calculateAvailableSize(track, position);
    final wrappedLines = TextAutoWrapHelper.wrapTextToFit(
      track.text,
      availableSize.width,
      availableSize.height,
      textStyle,
    );

    // Draw text with rotation if needed
    if (track.rotation != 0) {
      _drawRotatedText(canvas, wrappedLines, textStyle, position, track.rotation);
    } else {
      _drawNormalText(canvas, wrappedLines, textStyle, position);
    }

    // Draw selection box if selected
    if (isSelected) {
      _drawSelectionBox(canvas, wrappedLines, textStyle, position, track.rotation);
    }
  }

  double _calculateFontSize(double baseFontSize) {
    // Scale fonts based on canvas size for sequential preview
    // Use a reference size of 800x600 for consistent scaling
    final scaleX = canvasSize.width / 800.0;
    final scaleY = canvasSize.height / 600.0;
    final scale = math.min(scaleX, scaleY);
    
    // Apply scaling with reasonable bounds
    final scaledSize = baseFontSize * scale.clamp(0.5, 2.5);
    
    print('   Font scaling: base=$baseFontSize, scale=$scale, result=$scaledSize');
    return scaledSize;
  }

  Offset _calculateCanvasPosition(TextTrackModel track) {
    // For sequential preview, text positions are treated as global canvas coordinates
    // The text position should be relative to the full canvas, not the current video
    
    // Direct mapping to canvas coordinates
    // Text positions are stored as canvas coordinates already
    return Offset(track.position.dx, track.position.dy);
  }

  Size _calculateAvailableSize(TextTrackModel track, Offset position) {
    // Calculate available space from position to canvas edge
    final availableWidth = canvasSize.width - position.dx - 20; // 20px margin
    final availableHeight = canvasSize.height - position.dy - 20; // 20px margin
    
    return Size(
      availableWidth.clamp(100.0, canvasSize.width * 0.8),
      availableHeight.clamp(50.0, canvasSize.height * 0.8),
    );
  }

  void _drawRotatedText(Canvas canvas, List<String> lines, TextStyle style, 
                       Offset position, double rotation) {
    // Calculate text dimensions
    final textWidth = _calculateMaxLineWidth(lines, style);
    final textHeight = _calculateTextHeight(lines, style);
    
    // Calculate rotation center
    final rotationCenter = Offset(
      position.dx + textWidth / 2,
      position.dy + textHeight / 2,
    );
    
    canvas.save();
    canvas.translate(rotationCenter.dx, rotationCenter.dy);
    canvas.rotate(rotation * math.pi / 180);
    canvas.translate(-textWidth / 2, -textHeight / 2);
    
    _drawNormalText(canvas, lines, style, Offset.zero);
    
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

  void _drawSelectionBox(Canvas canvas, List<String> lines, TextStyle style, 
                        Offset position, double rotation) {
    final textWidth = _calculateMaxLineWidth(lines, style);
    final textHeight = _calculateTextHeight(lines, style);
    
    final selectionRect = Rect.fromLTWH(
      position.dx - 2,
      position.dy - 2,
      textWidth + 4,
      textHeight + 4,
    );
    
    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    if (rotation != 0) {
      final rotationCenter = Offset(
        position.dx + textWidth / 2,
        position.dy + textHeight / 2,
      );
      
      canvas.save();
      canvas.translate(rotationCenter.dx, rotationCenter.dy);
      canvas.rotate(rotation * math.pi / 180);
      canvas.translate(-textWidth / 2, -textHeight / 2);
      
      final rotatedRect = Rect.fromLTWH(-2, -2, textWidth + 4, textHeight + 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rotatedRect, const Radius.circular(4.0)),
        borderPaint,
      );
      
      canvas.restore();
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(selectionRect, const Radius.circular(4.0)),
        borderPaint,
      );
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

  double _calculateTextHeight(List<String> lines, TextStyle style) {
    return TextAutoWrapHelper.calculateWrappedTextHeight(lines, style);
  }

  @override
  bool shouldRepaint(SequentialTextOverlayPainter oldDelegate) {
    return oldDelegate.textTracks != textTracks ||
           oldDelegate.currentTime != currentTime ||
           oldDelegate.canvasSize != canvasSize ||
           oldDelegate.currentVideoTrack != currentVideoTrack ||
           oldDelegate.selectedTextIndex != selectedTextIndex;
  }
}