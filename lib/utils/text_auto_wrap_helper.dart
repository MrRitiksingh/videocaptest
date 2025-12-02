import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class TextAutoWrapHelper {
  /// Wraps text to fit within specified width and height constraints
  static List<String> wrapTextToFit(
    String text,
    double maxWidth,
    double maxHeight,
    TextStyle style,
  ) {
    if (text.isEmpty) return [];

    // Split text into words
    List<String> words = text.split(' ');
    List<String> lines = [];
    String currentLine = '';
    double currentHeight = 0;

    // Use TextPainter to get accurate line height with normal spacing
    final TextPainter lineHeightPainter = TextPainter(
      text: TextSpan(text: 'A', style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    lineHeightPainter.layout();
    double lineHeight = lineHeightPainter.height *
        1.0; // Use normal line height to match preview
    lineHeightPainter.dispose(); // Dispose TextPainter to free memory

    for (String word in words) {
      String testLine = currentLine.isEmpty ? word : '$currentLine $word';
      double lineWidth = _calculateTextWidth(testLine, style);

      if (lineWidth <= maxWidth) {
        currentLine = testLine;
      } else {
        if (currentLine.isNotEmpty) {
          // Check if adding this line would exceed height
          if (currentHeight + lineHeight <= maxHeight) {
            lines.add(currentLine);
            currentHeight += lineHeight;
            currentLine = word;
          } else {
            // Can't fit more lines, stop here
            break;
          }
        } else {
          // Single word is too long, force break it
          if (currentHeight + lineHeight <= maxHeight) {
            lines.add(word);
            currentHeight += lineHeight;
          } else {
            break;
          }
        }
      }
    }

    // Add the last line if there's space
    if (currentLine.isNotEmpty && currentHeight + lineHeight <= maxHeight) {
      lines.add(currentLine);
    }

    return lines;
  }

  /// Wraps text to fit within specified width only
  static List<String> wrapText(String text, double maxWidth, TextStyle style) {
    if (text.isEmpty) return [];

    List<String> words = text.split(' ');
    List<String> lines = [];
    String currentLine = '';

    for (String word in words) {
      String testLine = currentLine.isEmpty ? word : '$currentLine $word';
      double lineWidth = _calculateTextWidth(testLine, style);

      if (lineWidth <= maxWidth) {
        currentLine = testLine;
      } else {
        if (currentLine.isNotEmpty) {
          lines.add(currentLine);
          currentLine = word;
        } else {
          // Word is too long, force break
          lines.add(word);
        }
      }
    }

    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }

    return lines;
  }

  /// Calculates the width of text with given style
  static double _calculateTextWidth(String text, TextStyle style) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    painter.layout();
    final width = painter.width;
    painter.dispose(); // Dispose TextPainter to free memory
    return width;
  }

  /// Efficient method to calculate multiple text widths with minimal memory allocation
  static Map<String, double> calculateTextWidths(
      List<String> texts, TextStyle style) {
    final Map<String, double> widths = {};

    for (String text in texts) {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      );
      painter.layout();
      widths[text] = painter.width;
      painter.dispose(); // Dispose TextPainter to free memory
    }

    return widths;
  }

  /// Optimized text wrapping that minimizes TextPainter allocations
  static List<String> wrapTextOptimized(
    String text,
    double maxWidth,
    double maxHeight,
    TextStyle style,
  ) {
    if (text.isEmpty) return [];

    // Split text into words
    List<String> words = text.split(' ');
    List<String> lines = [];
    String currentLine = '';
    double currentHeight = 0;

    // Use TextPainter to get accurate line height with normal spacing
    final TextPainter lineHeightPainter = TextPainter(
      text: TextSpan(text: 'A', style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    lineHeightPainter.layout();
    double lineHeight = lineHeightPainter.height * 1.0;
    lineHeightPainter.dispose(); // Dispose TextPainter to free memory

    for (String word in words) {
      String testLine = currentLine.isEmpty ? word : '$currentLine $word';
      double lineWidth = _calculateTextWidth(testLine, style);

      if (lineWidth <= maxWidth) {
        currentLine = testLine;
      } else {
        if (currentLine.isNotEmpty) {
          // Check if adding this line would exceed height
          if (currentHeight + lineHeight <= maxHeight) {
            lines.add(currentLine);
            currentHeight += lineHeight;
            currentLine = word;
          } else {
            // Can't fit more lines, stop here
            break;
          }
        } else {
          // Single word is too long, force break it
          if (currentHeight + lineHeight <= maxHeight) {
            lines.add(word);
            currentHeight += lineHeight;
          } else {
            break;
          }
        }
      }
    }

    // Add the last line if there's space
    if (currentLine.isNotEmpty && currentHeight + lineHeight <= maxHeight) {
      lines.add(currentLine);
    }

    return lines;
  }

  /// Calculates the height needed for wrapped text
  static double calculateWrappedTextHeight(
    List<String> lines,
    TextStyle style,
  ) {
    if (lines.isEmpty) return 0;

    // Use TextPainter to get accurate line height with normal spacing
    final TextPainter painter = TextPainter(
      text: TextSpan(
          text: 'A',
          style: style), // Use a single character for baseline measurement
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    painter.layout();
    double lineHeight =
        painter.height * 1.0; // Use normal line height to match preview
    painter.dispose(); // Dispose TextPainter to free memory

    return lines.length * lineHeight;
  }

  /// Gets the maximum number of lines that can fit in given height
  static int getMaxLines(double maxHeight, TextStyle style) {
    // Use TextPainter to get accurate line height with normal spacing
    final TextPainter painter = TextPainter(
      text: TextSpan(text: 'A', style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    painter.layout();
    double lineHeight =
        painter.height * 1.0; // Use normal line height to match preview
    painter.dispose(); // Dispose TextPainter to free memory

    return (maxHeight / lineHeight).floor();
  }
}

/// Utility class for consistent font scaling between preview and export
class FontScalingHelper {
  /// Calculate preview font size based on container and video dimensions
  ///
  /// [baseFontSize] - Original font size from text track
  /// [videoWidth] - Full video width
  /// [videoHeight] - Full video height
  /// [containerWidth] - Preview container width
  /// [containerHeight] - Preview container height
  ///
  /// Returns the scaled font size for preview display
  static double calculatePreviewFontSize({
    required double baseFontSize,
    required double videoWidth,
    required double videoHeight,
    required double containerWidth,
    required double containerHeight,
  }) {
    // Calculate how video fits in container (letterboxing/pillarboxing)
    final videoAspectRatio = videoWidth / videoHeight;
    final containerAspectRatio = containerWidth / containerHeight;

    double actualPreviewWidth, actualPreviewHeight;

    if (videoAspectRatio > containerAspectRatio) {
      // Video is wider - fit width, letterbox top/bottom
      actualPreviewWidth = containerWidth;
      actualPreviewHeight = containerWidth / videoAspectRatio;
    } else {
      // Video is taller - fit height, letterbox left/right
      actualPreviewHeight = containerHeight;
      actualPreviewWidth = containerHeight * videoAspectRatio;
    }

    // Calculate font size based on actual video area in preview
    return baseFontSize * (actualPreviewWidth / videoWidth);
  }

  /// Calculate export font size based on preview font size and scaling factor
  ///
  /// [previewFontSize] - Font size used in preview
  /// [videoWidth] - Full video width
  /// [actualPreviewWidth] - Actual width of video area in preview
  ///
  /// Returns the scaled font size for export
  static double calculateExportFontSize({
    required double previewFontSize,
    required double videoWidth,
    required double actualPreviewWidth,
  }) {
    // Export font size is inverse of preview scaling
    return previewFontSize * (videoWidth / actualPreviewWidth);
  }

  /// Calculate export boundary buffer based on preview boundary buffer
  ///
  /// [previewBoundaryBuffer] - Boundary buffer used in preview
  /// [videoWidth] - Full video width
  /// [actualPreviewWidth] - Actual width of video area in preview
  ///
  /// Returns the scaled boundary buffer for export
  static double calculateExportBoundaryBuffer({
    required double previewBoundaryBuffer,
    required double videoWidth,
    required double actualPreviewWidth,
  }) {
    // Scale boundary buffer proportionally
    return previewBoundaryBuffer * (videoWidth / actualPreviewWidth);
  }

  /// Calculate available width for text in preview
  ///
  /// [maxX] - Maximum X position (right boundary)
  /// [positionX] - X position of text in preview coordinates
  /// [buffer] - Boundary buffer
  ///
  /// Returns available width for text wrapping in preview
  static double calculatePreviewAvailableWidth({
    required double maxX,
    required double positionX,
    required double buffer,
  }) {
    return maxX - positionX - buffer;
  }

  /// Calculate available width for text in export
  ///
  /// [previewAvailableWidth] - Available width calculated in preview
  /// [videoWidth] - Full video width
  /// [actualPreviewWidth] - Actual width of video area in preview
  ///
  /// Returns available width for text wrapping in export
  static double calculateExportAvailableWidth({
    required double previewAvailableWidth,
    required double videoWidth,
    required double actualPreviewWidth,
  }) {
    // Scale available width proportionally
    return previewAvailableWidth * (videoWidth / actualPreviewWidth);
  }

  /// Calculate video position from preview position
  ///
  /// [previewPositionX] - X position in preview coordinates
  /// [previewPositionY] - Y position in preview coordinates
  /// [videoWidth] - Full video width
  /// [videoHeight] - Full video height
  /// [actualPreviewWidth] - Actual width of video area in preview
  /// [actualPreviewHeight] - Actual height of video area in preview
  /// [gapLeft] - Left gap from letterboxing
  /// [gapTop] - Top gap from letterboxing
  ///
  /// Returns position in full video coordinates
  static Offset calculateVideoPosition({
    required double previewPositionX,
    required double previewPositionY,
    required double videoWidth,
    required double videoHeight,
    required double actualPreviewWidth,
    required double actualPreviewHeight,
    required double gapLeft,
    required double gapTop,
  }) {
    // Adjust for letterboxing/pillarboxing
    final adjustedPositionX = previewPositionX - gapLeft;
    final adjustedPositionY = previewPositionY - gapTop;

    // Map to full video coordinates
    final videoX = adjustedPositionX * (videoWidth / actualPreviewWidth);
    final videoY = adjustedPositionY * (videoHeight / actualPreviewHeight);

    return Offset(videoX, videoY);
  }

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
    final videoAspectRatio = videoWidth / videoHeight;
    final containerAspectRatio = containerWidth / containerHeight;

    double actualPreviewWidth, actualPreviewHeight, gapLeft, gapTop;

    if (videoAspectRatio > containerAspectRatio) {
      // Video is wider - fit width, letterbox top/bottom
      actualPreviewWidth = containerWidth;
      actualPreviewHeight = containerWidth / videoAspectRatio;
      gapLeft = 0.0;
      gapTop = (containerHeight - actualPreviewHeight) / 2.0;
    } else {
      // Video is taller - fit height, letterbox left/right
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
    };
  }
}

/// Utility class for managing TextPainter instances to prevent memory leaks
class TextPainterManager {
  static final Map<String, TextPainter> _cache = {};
  static int _cacheHits = 0;
  static int _cacheMisses = 0;

  /// Get a TextPainter instance, either from cache or create new
  static TextPainter getTextPainter(String text, TextStyle style) {
    final key = '${text}_${style.fontSize}_${style.fontFamily}';

    if (_cache.containsKey(key)) {
      _cacheHits++;
      return _cache[key]!;
    }

    _cacheMisses++;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    _cache[key] = painter;
    return painter;
  }

  /// Dispose a TextPainter and remove from cache
  static void disposeTextPainter(String text, TextStyle style) {
    final key = '${text}_${style.fontSize}_${style.fontFamily}';
    final painter = _cache.remove(key);
    painter?.dispose();
  }

  /// Clear all cached TextPainter instances
  static void clearCache() {
    for (final painter in _cache.values) {
      painter.dispose();
    }
    _cache.clear();
  }

  /// Get cache statistics
  static Map<String, dynamic> getCacheStats() {
    return {
      'cacheSize': _cache.length,
      'cacheHits': _cacheHits,
      'cacheMisses': _cacheMisses,
      'hitRate': _cacheHits / (_cacheHits + _cacheMisses),
    };
  }

  /// Optimized method to calculate text width with caching
  static double calculateTextWidthCached(String text, TextStyle style) {
    final painter = getTextPainter(text, style);
    painter.layout();
    final width = painter.width;
    disposeTextPainter(text, style);
    return width;
  }
}
