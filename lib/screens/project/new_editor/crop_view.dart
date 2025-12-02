import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class CropView extends StatefulWidget {
  final VideoPlayerController controller;
  final Function(Rect) onCropChanged;

  const CropView({
    super.key,
    required this.controller,
    required this.onCropChanged,
  });

  @override
  State<CropView> createState() => _CropViewState();
}

class _CropViewState extends State<CropView> {
  Rect _cropRect = Rect.zero;
  CropBoundaries _boundary = CropBoundaries.none;
  late Size _layout;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeCropRect();
  }

  void _initializeCropRect() {
    final videoSize = widget.controller.value.size;
    final containerSize = MediaQuery.of(context).size;

    // Calculate scaled dimensions to fit in container
    double scale = math.min(
        300 / videoSize.width, // Dialog width
        400 / videoSize.height // Dialog height
        );

    _layout = Size(videoSize.width * scale, videoSize.height * scale);

    _cropRect = Rect.fromCenter(
      center: Offset(_layout.width / 2, _layout.height / 2),
      width: _layout.width * 0.8,
      height: _layout.height * 0.8,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onCropChanged(_cropRect);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: _layout.width,
        height: _layout.height,
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            AspectRatio(
              aspectRatio: widget.controller.value.aspectRatio,
              child: VideoPlayer(widget.controller),
            ),
            CustomPaint(
              size: _layout,
              painter: CropOverlayPainter(
                cropRect: _cropRect,
                boundary: _boundary,
              ),
            ),
            _buildCropHandles(_layout),
          ],
        ),
      ),
    );
  }

  Widget _buildCropHandles(Size size) {
    return SizedBox.fromSize(
      size: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildHandle(CropBoundaries.topLeft, _cropRect.topLeft),
          _buildHandle(CropBoundaries.topRight, _cropRect.topRight),
          _buildHandle(CropBoundaries.bottomLeft, _cropRect.bottomLeft),
          _buildHandle(CropBoundaries.bottomRight, _cropRect.bottomRight),
        ],
      ),
    );
  }

  Widget _buildHandle(CropBoundaries boundary, Offset position) {
    return Positioned(
      left: position.dx - 12,
      top: position.dy - 12,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        // Improves touch detection
        onPanStart: (_) => setState(() => _boundary = boundary),
        onPanEnd: (_) => setState(() => _boundary = CropBoundaries.none),
        onPanUpdate: (details) => _updateCropRect(boundary, details),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: _boundary == boundary ? Colors.blue : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ),
    );
  }

  void _updateCropRect(CropBoundaries boundary, DragUpdateDetails details) {
    setState(() {
      final delta = details.delta;
      Rect newRect = _cropRect;

      switch (boundary) {
        case CropBoundaries.topLeft:
          newRect = Rect.fromLTRB(
            (_cropRect.left + delta.dx).clamp(0, _cropRect.right - 100),
            (_cropRect.top + delta.dy).clamp(0, _cropRect.bottom - 100),
            _cropRect.right,
            _cropRect.bottom,
          );
          break;
        case CropBoundaries.topRight:
          newRect = Rect.fromLTRB(
            _cropRect.left,
            (_cropRect.top + delta.dy).clamp(0, _cropRect.bottom - 100),
            (_cropRect.right + delta.dx)
                .clamp(_cropRect.left + 100, _layout.width),
            _cropRect.bottom,
          );
          break;
        case CropBoundaries.bottomLeft:
          newRect = Rect.fromLTRB(
            (_cropRect.left + delta.dx).clamp(0, _cropRect.right - 100),
            _cropRect.top,
            _cropRect.right,
            (_cropRect.bottom + delta.dy)
                .clamp(_cropRect.top + 100, _layout.height),
          );
          break;
        case CropBoundaries.bottomRight:
          newRect = Rect.fromLTRB(
            _cropRect.left,
            _cropRect.top,
            (_cropRect.right + delta.dx)
                .clamp(_cropRect.left + 100, _layout.width),
            (_cropRect.bottom + delta.dy)
                .clamp(_cropRect.top + 100, _layout.height),
          );
          break;
        case CropBoundaries.inside:
          final dx = delta.dx;
          final dy = delta.dy;
          final width = _cropRect.width;
          final height = _cropRect.height;

          double newLeft =
              (_cropRect.left + dx).clamp(0, _layout.width - width);
          double newTop =
              (_cropRect.top + dy).clamp(0, _layout.height - height);

          newRect = Rect.fromLTWH(newLeft, newTop, width, height);
          break;
        case CropBoundaries.none:
          break;
      }

      if (newRect.width >= 100 &&
          newRect.height >= 100 &&
          newRect.left >= 0 &&
          newRect.top >= 0 &&
          newRect.right <= _layout.width &&
          newRect.bottom <= _layout.height) {
        _cropRect = newRect;
        widget.onCropChanged(_cropRect);
      }
    });
  }
}

enum CropBoundaries {
  none,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  inside,
}

// class CropOverlayPainter extends CustomPainter {
//   final Rect cropRect;
//   final CropBoundaries boundary;
//
//   CropOverlayPainter({
//     required this.cropRect,
//     required this.boundary,
//   });
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint()
//       ..color = Colors.black54
//       ..style = PaintingStyle.fill;
//
//     canvas.drawPath(
//       Path.combine(
//         PathOperation.difference,
//         Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
//         Path()..addRect(cropRect),
//       ),
//       paint,
//     );
//
//     canvas.drawRect(
//       cropRect,
//       Paint()
//         ..color = Colors.white
//         ..style = PaintingStyle.stroke
//         ..strokeWidth = 2,
//     );
//   }
//
//   @override
//   bool shouldRepaint(CropOverlayPainter oldDelegate) =>
//       cropRect != oldDelegate.cropRect || boundary != oldDelegate.boundary;
// }
class CropOverlayPainter extends CustomPainter {
  final Rect cropRect;
  final CropBoundaries boundary;
  final double pointSize = 20.0; // Size of crop points

  CropOverlayPainter({
    required this.cropRect,
    required this.boundary,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw semi-transparent overlay
    final paint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.fill;

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRect(cropRect),
      ),
      paint,
    );

    // Draw crop rectangle border
    canvas.drawRect(
      cropRect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Draw corner points
    final pointPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Draw points at corners
    _drawPoint(canvas, cropRect.topLeft, pointPaint);
    _drawPoint(canvas, cropRect.topRight, pointPaint);
    _drawPoint(canvas, cropRect.bottomLeft, pointPaint);
    _drawPoint(canvas, cropRect.bottomRight, pointPaint);
  }

  void _drawPoint(Canvas canvas, Offset position, Paint paint) {
    canvas.drawCircle(position, pointSize / 2, paint);
    // Draw border around point
    canvas.drawCircle(
      position,
      pointSize / 2,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(CropOverlayPainter oldDelegate) =>
      cropRect != oldDelegate.cropRect || boundary != oldDelegate.boundary;
}
// crop_view.dart
// import 'package:flutter/material.dart';
// import 'package:video_player/video_player.dart';
//
// class CropView extends StatefulWidget {
//   final VideoPlayerController controller;
//   final Function(Rect) onCropChanged;
//
//   const CropView({
//     super.key,
//     required this.controller,
//     required this.onCropChanged,
//   });
//
//   @override
//   CropViewState createState() => CropViewState();
// }
//
// class CropViewState extends State<CropView> {
//   Rect _cropRect = Rect.zero;
//   double _aspectRatio = 1.0;
//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     _initializeCropRect();
//   }
//
//   // @override
//   // void initState() {
//   //   super.initState();
//   //   _initializeCropRect();
//   // }
//
//   void _initializeCropRect() {
//     final videoSize = widget.controller.value.size;
//     final screenSize = MediaQuery.of(context).size;
//     final videoAspectRatio = videoSize.width / videoSize.height;
//
//     _aspectRatio = videoAspectRatio;
//     _cropRect = Rect.fromCenter(
//       center: Offset(screenSize.width / 2, screenSize.height / 2),
//       width: screenSize.width * 0.8,
//       height: screenSize.width * 0.8 / videoAspectRatio,
//     );
//
//     // Delay the crop update
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       widget.onCropChanged(_cropRect);
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       children: [
//         Center(
//           child: AspectRatio(
//             aspectRatio: _aspectRatio,
//             child: VideoPlayer(widget.controller),
//           ),
//         ),
//         _buildCropOverlay(),
//         _buildCropHandles(),
//       ],
//     );
//   }
//
//   Widget _buildCropOverlay() {
//     return CustomPaint(
//       painter: CropOverlayPainter(
//         cropRect: _cropRect,
//         color: Colors.black54,
//       ),
//     );
//   }
//
//   Widget _buildCropHandles() {
//     return Stack(
//       children: [
//         // Corner handles
//         _buildHandle(Alignment.topLeft, _cropRect.topLeft),
//         _buildHandle(Alignment.topRight, _cropRect.topRight),
//         _buildHandle(Alignment.bottomLeft, _cropRect.bottomLeft),
//         _buildHandle(Alignment.bottomRight, _cropRect.bottomRight),
//       ],
//     );
//   }
//
//   Widget _buildHandle(Alignment alignment, Offset position) {
//     return Positioned(
//       left: position.dx - 12,
//       top: position.dy - 12,
//       child: GestureDetector(
//         onPanUpdate: (details) => _updateCropRect(alignment, details),
//         child: Container(
//           width: 24,
//           height: 24,
//           decoration: BoxDecoration(
//             color: Colors.white,
//             shape: BoxShape.circle,
//           ),
//         ),
//       ),
//     );
//   }
//
//   void _updateCropRect(Alignment alignment, DragUpdateDetails details) {
//     setState(() {
//       final delta = details.delta;
//       Rect newRect = _cropRect;
//
//       switch (alignment) {
//         case Alignment.topLeft:
//           newRect = Rect.fromLTRB(
//             _cropRect.left + delta.dx,
//             _cropRect.top + delta.dy,
//             _cropRect.right,
//             _cropRect.bottom,
//           );
//           break;
//         case Alignment.topRight:
//           newRect = Rect.fromLTRB(
//             _cropRect.left,
//             _cropRect.top + delta.dy,
//             _cropRect.right + delta.dx,
//             _cropRect.bottom,
//           );
//           break;
//         case Alignment.bottomLeft:
//           newRect = Rect.fromLTRB(
//             _cropRect.left + delta.dx,
//             _cropRect.top,
//             _cropRect.right,
//             _cropRect.bottom + delta.dy,
//           );
//           break;
//         case Alignment.bottomRight:
//           newRect = Rect.fromLTRB(
//             _cropRect.left,
//             _cropRect.top,
//             _cropRect.right + delta.dx,
//             _cropRect.bottom + delta.dy,
//           );
//           break;
//       }
//
//       if (newRect.width >= 100 && newRect.height >= 100) {
//         _cropRect = newRect;
//         widget.onCropChanged(_cropRect);
//       }
//     });
//   }
// }
//
// class CropOverlayPainter extends CustomPainter {
//   final Rect cropRect;
//   final Color color;
//
//   CropOverlayPainter({
//     required this.cropRect,
//     required this.color,
//   });
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint()
//       ..color = color
//       ..style = PaintingStyle.fill;
//
//     // Draw semi-transparent overlay outside crop area
//     canvas.drawPath(
//       Path.combine(
//         PathOperation.difference,
//         Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
//         Path()..addRect(cropRect),
//       ),
//       paint,
//     );
//
//     // Draw crop rectangle border
//     canvas.drawRect(
//       cropRect,
//       Paint()
//         ..color = Colors.white
//         ..style = PaintingStyle.stroke
//         ..strokeWidth = 2,
//     );
//   }
//
//   @override
//   bool shouldRepaint(CropOverlayPainter oldDelegate) =>
//       cropRect != oldDelegate.cropRect || color != oldDelegate.color;
// }
