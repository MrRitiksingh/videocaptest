import 'package:flutter/material.dart';
import 'package:ai_video_creator_editor/screens/project/models/video_track_model.dart';
import 'dart:math' as math;

/// Preview crop mask widget that applies crop using ClipRect
/// Shows the cropped area in preview mode with proper scaling
class CropPreviewWidget extends StatefulWidget {
  final Widget child;
  final CropModel? cropModel;
  final Size videoSize;
  final Size previewSize;
  final bool showCropOverlay;
  final Function(CropModel cropModel)? onCropChanged;
  final VoidCallback? onCropToggle;

  const CropPreviewWidget({
    Key? key,
    required this.child,
    this.cropModel,
    required this.videoSize,
    required this.previewSize,
    this.showCropOverlay = false,
    this.onCropChanged,
    this.onCropToggle,
  }) : super(key: key);

  @override
  State<CropPreviewWidget> createState() => _CropPreviewWidgetState();
}

class _CropPreviewWidgetState extends State<CropPreviewWidget> {
  bool _isDragging = false;
  bool _isResizing = false;
  CropHandle? _activeHandle;
  Offset _dragStart = Offset.zero;
  CropModel? _tempCropModel;

  @override
  Widget build(BuildContext context) {
    final cropModel = widget.cropModel;

    if (cropModel == null || !cropModel.enabled) {
      return widget.child;
    }

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        // Cropped content
        _buildCroppedContent(cropModel),

        // Crop overlay (if enabled)
        if (widget.showCropOverlay) _buildCropOverlay(cropModel),
      ],
    );
  }

  /// Build cropped content like a new asset upload
  /// Step 1: Get original asset properties
  /// Step 2: Extract cropped area properties
  /// Step 3: Fit cropped area in canvas like new upload
  Widget _buildCroppedContent(CropModel cropModel) {
    print('🎬 CropPreviewWidget: New Asset Upload Simulation');

    // ============================================================================
    // STEP 1: Get Original Asset Properties
    // ============================================================================
    final originalSize = widget.videoSize;
    final originalAspectRatio = originalSize.width / originalSize.height;

    print('📷 STEP 1: Original Asset Properties');
    print('   Size: ${originalSize.width} x ${originalSize.height}');
    print('   Aspect Ratio: ${originalAspectRatio.toStringAsFixed(3)}');
    print(
        '   Resolution: ${(originalSize.width * originalSize.height / 1000000).toStringAsFixed(1)}MP');

    // ============================================================================
    // STEP 2: Extract Cropped Area Properties (This becomes our "new asset")
    // ============================================================================
    final croppedSize = Size(cropModel.width, cropModel.height);
    final croppedAspectRatio = croppedSize.width / croppedSize.height;
    final croppedResolution = croppedSize.width * croppedSize.height;

    print('✂️  STEP 2: Cropped Area Properties (New Asset)');
    print('   Position: (${cropModel.x}, ${cropModel.y})');
    print('   Size: ${croppedSize.width} x ${croppedSize.height}');
    print('   Aspect Ratio: ${croppedAspectRatio.toStringAsFixed(3)}');
    print(
        '   Resolution: ${(croppedResolution / 1000000).toStringAsFixed(1)}MP');

    // ============================================================================
    // STEP 3: Fit Cropped Area in Canvas (Like New Asset Upload)
    // ============================================================================
    final canvasSize = widget.previewSize;
    final canvasAspectRatio = canvasSize.width / canvasSize.height;

    print('🎯 STEP 3: Fitting Cropped Asset in Canvas');
    print('   Canvas: ${canvasSize.width} x ${canvasSize.height}');
    print('   Canvas AR: ${canvasAspectRatio.toStringAsFixed(3)}');

    // Calculate how to fit cropped content in canvas (same logic as asset upload)
    Size fittedSize;
    Offset fittedPosition;

    if (croppedAspectRatio > canvasAspectRatio) {
      // Cropped content is wider than canvas - fit to width
      fittedSize = Size(
        canvasSize.width,
        canvasSize.width / croppedAspectRatio,
      );
      fittedPosition = Offset(
        0,
        (canvasSize.height - fittedSize.height) / 2,
      );
    } else {
      // Cropped content is taller than canvas - fit to height
      fittedSize = Size(
        canvasSize.height * croppedAspectRatio,
        canvasSize.height,
      );
      fittedPosition = Offset(
        (canvasSize.width - fittedSize.width) / 2,
        0,
      );
    }

    print('   Fitted Size: ${fittedSize.width} x ${fittedSize.height}');
    print('   Fitted Position: (${fittedPosition.dx}, ${fittedPosition.dy})');

    // Calculate scale factor to show cropped area at fitted size
    final scale = fittedSize.width / croppedSize.width;
    print('   Scale Factor: ${scale.toStringAsFixed(3)}');

    // Calculate video position to center the crop in fitted area
    final videoLeft = fittedPosition.dx - (cropModel.x * scale);
    final videoTop = fittedPosition.dy - (cropModel.y * scale);
    final videoWidth = originalSize.width * scale;
    final videoHeight = originalSize.height * scale;

    print(
        '   Video Position: (${videoLeft.toStringAsFixed(1)}, ${videoTop.toStringAsFixed(1)})');
    print(
        '   Video Size: ${videoWidth.toStringAsFixed(1)} x ${videoHeight.toStringAsFixed(1)}');

    // ============================================================================
    // RENDER: Show cropped content fitted like new asset
    // ============================================================================
    return Container(
      width: canvasSize.width,
      height: canvasSize.height,
      color: Colors.black, // Canvas background
      child: Stack(
        children: [
          // Fitted crop area (like uploaded asset boundary)
          Positioned(
            left: fittedPosition.dx,
            top: fittedPosition.dy,
            width: fittedSize.width,
            height: fittedSize.height,
            child: ClipRect(
              child: Stack(
                children: [
                  // Position original video to show only crop
                  Positioned(
                    left: videoLeft - fittedPosition.dx,
                    top: videoTop - fittedPosition.dy,
                    width: videoWidth,
                    height: videoHeight,
                    child: widget.child,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build crop overlay with handles and mask
  Widget _buildCropOverlay(CropModel cropModel) {
    // Calculate scale factors
    final scaleX = widget.previewSize.width / widget.videoSize.width;
    final scaleY = widget.previewSize.height / widget.videoSize.height;

    // Scale crop coordinates to preview size
    final previewCropRect = Rect.fromLTWH(
      cropModel.x * scaleX,
      cropModel.y * scaleY,
      cropModel.width * scaleX,
      cropModel.height * scaleY,
    );

    return Positioned.fill(
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onPanStart: _handlePanStart,
        onPanUpdate: _handlePanUpdate,
        onPanEnd: _handlePanEnd,
        child: CustomPaint(
          painter: CropOverlayPainter(
            cropRect: previewCropRect,
            containerSize: widget.previewSize,
            isDragging: _isDragging,
            isResizing: _isResizing,
            activeHandle: _activeHandle,
          ),
          child: Container(),
        ),
      ),
    );
  }

  /// Handle tap down for crop manipulation
  void _handleTapDown(TapDownDetails details) {
    if (widget.cropModel == null) return;

    final scaleX = widget.previewSize.width / widget.videoSize.width;
    final scaleY = widget.previewSize.height / widget.videoSize.height;

    final previewCropRect = Rect.fromLTWH(
      widget.cropModel!.x * scaleX,
      widget.cropModel!.y * scaleY,
      widget.cropModel!.width * scaleX,
      widget.cropModel!.height * scaleY,
    );

    // Check if tap is on a handle
    final handle = _getHandleAtPosition(details.localPosition, previewCropRect);

    if (handle != null) {
      setState(() {
        _activeHandle = handle;
        _isResizing = true;
      });
    } else if (previewCropRect.contains(details.localPosition)) {
      setState(() {
        _isDragging = true;
      });
    }

    _dragStart = details.localPosition;
    _tempCropModel = widget.cropModel;
  }

  /// Handle pan start
  void _handlePanStart(DragStartDetails details) {
    _dragStart = details.localPosition;
  }

  /// Handle pan update
  void _handlePanUpdate(DragUpdateDetails details) {
    if (widget.cropModel == null || _tempCropModel == null) return;

    final delta = details.localPosition - _dragStart;
    final scaleX = widget.videoSize.width / widget.previewSize.width;
    final scaleY = widget.videoSize.height / widget.previewSize.height;

    CropModel newCropModel = _tempCropModel!;

    if (_isDragging) {
      // Move the entire crop area
      final newX = (_tempCropModel!.x + delta.dx * scaleX)
          .clamp(0.0, widget.videoSize.width - _tempCropModel!.width);
      final newY = (_tempCropModel!.y + delta.dy * scaleY)
          .clamp(0.0, widget.videoSize.height - _tempCropModel!.height);

      newCropModel = _tempCropModel!.copyWith(x: newX, y: newY);
    } else if (_isResizing && _activeHandle != null) {
      // Resize the crop area
      newCropModel = _resizeCrop(_tempCropModel!, delta, scaleX, scaleY);
    }

    setState(() {
      _tempCropModel = newCropModel;
    });

    widget.onCropChanged?.call(newCropModel);
  }

  /// Handle pan end
  void _handlePanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
      _isResizing = false;
      _activeHandle = null;
    });

    if (_tempCropModel != null) {
      widget.onCropChanged?.call(_tempCropModel!);
    }
  }

  /// Get handle at position
  CropHandle? _getHandleAtPosition(Offset position, Rect cropRect) {
    const handleSize = 12.0;

    // Check corner handles
    if (_isPointInHandle(position, cropRect.topLeft, handleSize)) {
      return CropHandle.topLeft;
    }
    if (_isPointInHandle(position, cropRect.topRight, handleSize)) {
      return CropHandle.topRight;
    }
    if (_isPointInHandle(position, cropRect.bottomLeft, handleSize)) {
      return CropHandle.bottomLeft;
    }
    if (_isPointInHandle(position, cropRect.bottomRight, handleSize)) {
      return CropHandle.bottomRight;
    }

    // Check edge handles
    if (_isPointInHandle(
        position, Offset(cropRect.center.dx, cropRect.top), handleSize)) {
      return CropHandle.topCenter;
    }
    if (_isPointInHandle(
        position, Offset(cropRect.center.dx, cropRect.bottom), handleSize)) {
      return CropHandle.bottomCenter;
    }
    if (_isPointInHandle(
        position, Offset(cropRect.left, cropRect.center.dy), handleSize)) {
      return CropHandle.leftCenter;
    }
    if (_isPointInHandle(
        position, Offset(cropRect.right, cropRect.center.dy), handleSize)) {
      return CropHandle.rightCenter;
    }

    return null;
  }

  /// Check if point is within handle bounds
  bool _isPointInHandle(Offset point, Offset handleCenter, double handleSize) {
    final handleRect = Rect.fromCenter(
      center: handleCenter,
      width: handleSize,
      height: handleSize,
    );
    return handleRect.contains(point);
  }

  /// Resize crop based on handle and delta
  CropModel _resizeCrop(
      CropModel cropModel, Offset delta, double scaleX, double scaleY) {
    final deltaX = delta.dx * scaleX;
    final deltaY = delta.dy * scaleY;

    double newX = cropModel.x;
    double newY = cropModel.y;
    double newWidth = cropModel.width;
    double newHeight = cropModel.height;

    switch (_activeHandle!) {
      case CropHandle.topLeft:
        newX = (cropModel.x + deltaX)
            .clamp(0.0, cropModel.x + cropModel.width - 10);
        newY = (cropModel.y + deltaY)
            .clamp(0.0, cropModel.y + cropModel.height - 10);
        newWidth = cropModel.width - (newX - cropModel.x);
        newHeight = cropModel.height - (newY - cropModel.y);
        break;
      case CropHandle.topRight:
        newY = (cropModel.y + deltaY)
            .clamp(0.0, cropModel.y + cropModel.height - 10);
        newWidth = (cropModel.width + deltaX)
            .clamp(10.0, widget.videoSize.width - cropModel.x);
        newHeight = cropModel.height - (newY - cropModel.y);
        break;
      case CropHandle.bottomLeft:
        newX = (cropModel.x + deltaX)
            .clamp(0.0, cropModel.x + cropModel.width - 10);
        newWidth = cropModel.width - (newX - cropModel.x);
        newHeight = (cropModel.height + deltaY)
            .clamp(10.0, widget.videoSize.height - cropModel.y);
        break;
      case CropHandle.bottomRight:
        newWidth = (cropModel.width + deltaX)
            .clamp(10.0, widget.videoSize.width - cropModel.x);
        newHeight = (cropModel.height + deltaY)
            .clamp(10.0, widget.videoSize.height - cropModel.y);
        break;
      case CropHandle.topCenter:
        newY = (cropModel.y + deltaY)
            .clamp(0.0, cropModel.y + cropModel.height - 10);
        newHeight = cropModel.height - (newY - cropModel.y);
        break;
      case CropHandle.bottomCenter:
        newHeight = (cropModel.height + deltaY)
            .clamp(10.0, widget.videoSize.height - cropModel.y);
        break;
      case CropHandle.leftCenter:
        newX = (cropModel.x + deltaX)
            .clamp(0.0, cropModel.x + cropModel.width - 10);
        newWidth = cropModel.width - (newX - cropModel.x);
        break;
      case CropHandle.rightCenter:
        newWidth = (cropModel.width + deltaX)
            .clamp(10.0, widget.videoSize.width - cropModel.x);
        break;
    }

    return cropModel.copyWith(
      x: newX,
      y: newY,
      width: newWidth,
      height: newHeight,
    );
  }
}

/// Custom clipper for crop functionality
class CropClipper extends CustomClipper<Rect> {
  final Rect cropRect;

  CropClipper({required this.cropRect});

  @override
  Rect getClip(Size size) {
    return cropRect;
  }

  @override
  bool shouldReclip(CropClipper oldClipper) {
    return oldClipper.cropRect != cropRect;
  }
}

/// Custom painter for crop overlay
class CropOverlayPainter extends CustomPainter {
  final Rect cropRect;
  final Size containerSize;
  final bool isDragging;
  final bool isResizing;
  final CropHandle? activeHandle;

  CropOverlayPainter({
    required this.cropRect,
    required this.containerSize,
    this.isDragging = false,
    this.isResizing = false,
    this.activeHandle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw darkened overlay outside crop area
    _drawOverlayMask(canvas, size);

    // Draw crop border
    _drawCropBorder(canvas);

    // Draw resize handles
    _drawResizeHandles(canvas);

    // Draw grid lines
    _drawGridLines(canvas);
  }

  void _drawOverlayMask(Canvas canvas, Size size) {
    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    // Create path that excludes the crop area
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(cropRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, overlayPaint);
  }

  void _drawCropBorder(Canvas canvas) {
    final borderPaint = Paint()
      ..color = isDragging ? Colors.yellow : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRect(cropRect, borderPaint);
  }

  void _drawResizeHandles(Canvas canvas) {
    const handleSize = 12.0;
    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final handles = [
      cropRect.topLeft,
      cropRect.topRight,
      cropRect.bottomLeft,
      cropRect.bottomRight,
      Offset(cropRect.center.dx, cropRect.top),
      Offset(cropRect.center.dx, cropRect.bottom),
      Offset(cropRect.left, cropRect.center.dy),
      Offset(cropRect.right, cropRect.center.dy),
    ];

    for (final handle in handles) {
      final handleRect = Rect.fromCenter(
        center: handle,
        width: handleSize,
        height: handleSize,
      );

      canvas.drawRect(handleRect, handlePaint);
      canvas.drawRect(handleRect, borderPaint);
    }
  }

  void _drawGridLines(Canvas canvas) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Rule of thirds grid
    final thirdWidth = cropRect.width / 3;
    final thirdHeight = cropRect.height / 3;

    // Vertical lines
    for (int i = 1; i < 3; i++) {
      final x = cropRect.left + thirdWidth * i;
      canvas.drawLine(
        Offset(x, cropRect.top),
        Offset(x, cropRect.bottom),
        gridPaint,
      );
    }

    // Horizontal lines
    for (int i = 1; i < 3; i++) {
      final y = cropRect.top + thirdHeight * i;
      canvas.drawLine(
        Offset(cropRect.left, y),
        Offset(cropRect.right, y),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(CropOverlayPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect ||
        oldDelegate.isDragging != isDragging ||
        oldDelegate.isResizing != isResizing ||
        oldDelegate.activeHandle != activeHandle;
  }
}

/// Crop handle positions
enum CropHandle {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  topCenter,
  bottomCenter,
  leftCenter,
  rightCenter,
}
