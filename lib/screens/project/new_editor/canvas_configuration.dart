import 'package:flutter/material.dart';
import 'video_editor_page_updated.dart';

/// Configuration for dual canvas system - maintains separate preview and export dimensions
class CanvasConfiguration {
  final Size previewCanvasSize;    // Dynamic, container-based size used in preview
  final Size exportCanvasSize;     // Fixed high-resolution size for export
  final double scaleFactor;        // Ratio for scaling from preview to export
  
  CanvasConfiguration({
    required this.previewCanvasSize,
    required this.exportCanvasSize,
  }) : scaleFactor = exportCanvasSize.width / previewCanvasSize.width;
  
  /// Create configuration from container size and canvas ratio
  factory CanvasConfiguration.fromContainer({
    required Size containerSize,
    required CanvasRatio canvasRatio,
  }) {
    final previewSize = canvasRatio.getOptimalCanvasSize(containerSize);
    final exportSize = canvasRatio.exportSize;
    
    return CanvasConfiguration(
      previewCanvasSize: previewSize,
      exportCanvasSize: exportSize,
    );
  }
  
  /// Scale position from preview to export coordinates
  Offset scalePositionToExport(Offset previewPosition) {
    return Offset(
      previewPosition.dx * scaleFactor,
      previewPosition.dy * scaleFactor,
    );
  }
  
  /// Scale size from preview to export coordinates  
  Size scaleSizeToExport(Size previewSize) {
    return Size(
      previewSize.width * scaleFactor,
      previewSize.height * scaleFactor,
    );
  }
  
  /// Scale font size from preview to export
  double scaleFontSizeToExport(double previewFontSize) {
    return previewFontSize * scaleFactor;
  }
  
  /// Scale position from export to preview coordinates
  Offset scalePositionToPreview(Offset exportPosition) {
    return Offset(
      exportPosition.dx / scaleFactor,
      exportPosition.dy / scaleFactor,
    );
  }
  
  /// Scale size from export to preview coordinates
  Size scaleSizeToPreview(Size exportSize) {
    return Size(
      exportSize.width / scaleFactor,
      exportSize.height / scaleFactor,
    );
  }
  
  @override
  String toString() {
    return 'CanvasConfiguration(\n'
        '  preview: ${previewCanvasSize.width}x${previewCanvasSize.height}\n'
        '  export: ${exportCanvasSize.width}x${exportCanvasSize.height}\n'
        '  scale: ${scaleFactor.toStringAsFixed(3)}x\n'
        ')';
  }
}