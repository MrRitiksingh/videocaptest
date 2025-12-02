import 'dart:math';

import 'package:ai_video_creator_editor/components/crop/crop_preview_mixin.dart';
import 'package:ai_video_creator_editor/controllers/crop_state_manager.dart';
import 'package:ai_video_creator_editor/controllers/video_controller.dart';
import 'package:ai_video_creator_editor/screens/project/models/transform_data.dart';
import 'package:ai_video_creator_editor/utils/helpers.dart';
import 'package:ai_video_creator_editor/utils/performance_monitor.dart';
import 'package:flutter/material.dart';

@protected
enum CropBoundaries {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  inside,
  topCenter,
  centerRight,
  centerLeft,
  bottomCenter,
  none,
}

class CropGridViewer extends StatefulWidget {
  const CropGridViewer.preview(
      {super.key, required this.controller, required this.overlayText})
      : showGrid = false,
        rotateCropArea = true,
        margin = EdgeInsets.zero;

  const CropGridViewer.edit({
    super.key,
    required this.controller,
    this.margin = const EdgeInsets.symmetric(horizontal: 20),
    this.rotateCropArea = true,
  })  : showGrid = true,
        overlayText = '';

  final VideoEditorController controller;
  final String overlayText;
  final bool showGrid;
  final EdgeInsets margin;
  final bool rotateCropArea;

  @override
  State<CropGridViewer> createState() => _CropGridViewerState();
}

class _CropGridViewerState extends State<CropGridViewer>
    with CropPreviewMixin, PerformanceMonitoringMixin {
  CropBoundaries _boundary = CropBoundaries.none;
  late VideoEditorController _controller;
  late CropStateManager _cropStateManager;

  /// Minimum size of the cropped area
  late final double minRectSize = _controller.cropStyle.boundariesLength * 2;

  @override
  void initState() {
    _controller = widget.controller;
    _cropStateManager = CropStateManager(_controller);

    _controller.addListener(widget.showGrid ? _updateRect : _scaleRect);
    if (widget.showGrid) {
      _controller.cacheMaxCrop = _controller.maxCrop;
      _controller.cacheMinCrop = _controller.minCrop;
    }

    super.initState();
  }

  @override
  void dispose() {
    _controller.removeListener(widget.showGrid ? _updateRect : _scaleRect);
    _cropStateManager.dispose();
    super.dispose();
  }

  /// Returns the proper aspect ratio to apply depending on view rotation
  double? get aspectRatio => widget.rotateCropArea == false &&
          _controller.isRotated &&
          _controller.preferredCropAspectRatio != null
      ? getOppositeRatio(_controller.preferredCropAspectRatio!)
      : _controller.preferredCropAspectRatio;

  Size _computeLayout() => computeLayout(
        _controller,
        margin: widget.margin,
        shouldFlipped: _controller.isRotated && widget.showGrid,
      );

  /// Update crop [Rect] after change in [_controller] such as change of aspect ratio
  void _updateRect() {
    monitorSyncOperation('_updateRect', () {
      layout = _computeLayout();
      _cropStateManager.updateLayout(layout);
      transform.value = TransformData.fromController(_controller);
      _calculatePreferredCrop();
    });
  }

  /// Compute new [Rect] crop area depending of [_controller] data and layout size
  void _calculatePreferredCrop() {
    monitorSyncOperation('_calculatePreferredCrop', () {
      // set cached crop values to adjust it later
      Rect newRect = calculateCroppedRect(
        _controller,
        layout,
        min: _controller.cacheMinCrop,
        max: _controller.cacheMaxCrop,
      );
      if (_controller.preferredCropAspectRatio != null) {
        newRect = resizeCropToRatio(
          layout,
          newRect,
          widget.rotateCropArea == false && _controller.isRotated
              ? getOppositeRatio(_controller.preferredCropAspectRatio!)
              : _controller.preferredCropAspectRatio!,
        );
      }

      rect.value = newRect;
      _onPanEnd(force: true);
    });
  }

  void _scaleRect() {
    monitorSyncOperation('_scaleRect', () {
      layout = _computeLayout();
      _cropStateManager.updateLayout(layout);
      rect.value = calculateCroppedRect(_controller, layout);
      transform.value =
          TransformData.fromRect(rect.value, layout, viewerSize, _controller);
    });
  }

  /// Return [Rect] expanded position to improve touch detection
  Rect _expandedPosition(Offset position) =>
      Rect.fromCenter(center: position, width: 48, height: 48);

  /// Return expanded [Rect] to includes all corners [_expandedPosition]
  Rect _expandedRect() {
    final expandedPosition = _expandedPosition(rect.value.center);
    return Rect.fromCenter(
        center: rect.value.center,
        width: rect.value.width + expandedPosition.width,
        height: rect.value.height + expandedPosition.height);
  }

  /// Map visual boundary to actual crop boundary based on rotation
  /// This ensures that when user touches what appears to be "bottom" in rotated view,
  /// we apply the operation to the correct actual boundary
  // Returns the [Offset] to shift [rect] with to centered in the view
  Offset get gestureOffset => Offset(
        (viewerSize.width / 2) - (layout.width / 2),
        (viewerSize.height / 2) - (layout.height / 2),
      );

  void _onPanDown(DragDownDetails details) {
    monitorSyncOperation('_onPanDown', () {
      final Offset pos = details.localPosition - gestureOffset;
      _boundary = CropBoundaries.none;

      print('🎯 CropGrid Gesture Down:');
      print('   Raw touch: ${details.localPosition}');
      print('   Gesture offset: $gestureOffset');
      print('   Adjusted pos: $pos');
      print('   Video rotation: ${_controller.rotation}°');
      print('   Layout size: $layout');

      if (_expandedRect().contains(pos)) {
        _boundary = CropBoundaries.inside;

        // CORNERS - back to original boundary detection
        if (_expandedPosition(rect.value.topLeft).contains(pos)) {
          _boundary = CropBoundaries.topLeft;
        } else if (_expandedPosition(rect.value.topRight).contains(pos)) {
          _boundary = CropBoundaries.topRight;
        } else if (_expandedPosition(rect.value.bottomRight).contains(pos)) {
          _boundary = CropBoundaries.bottomRight;
        } else if (_expandedPosition(rect.value.bottomLeft).contains(pos)) {
          _boundary = CropBoundaries.bottomLeft;
        } else if (_controller.preferredCropAspectRatio == null) {
          // CENTERS
          if (_expandedPosition(rect.value.centerLeft).contains(pos)) {
            _boundary = CropBoundaries.centerLeft;
          } else if (_expandedPosition(rect.value.topCenter).contains(pos)) {
            _boundary = CropBoundaries.topCenter;
          } else if (_expandedPosition(rect.value.centerRight).contains(pos)) {
            _boundary = CropBoundaries.centerRight;
          } else if (_expandedPosition(rect.value.bottomCenter).contains(pos)) {
            _boundary = CropBoundaries.bottomCenter;
          }
        }

        print('   Detected boundary: $_boundary');
        print('   Crop rect: ${rect.value}');

        setState(() {}); // to update selected boundary color
        _controller.isCropping = true;
        _cropStateManager.setCropping(true);
      }
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_boundary == CropBoundaries.none) return;

    monitorSyncOperation('_onPanUpdate', () {
      final Offset delta = details
          .delta; // No transformation needed since GestureDetector is now rotated

      print('🎯 CropGrid Gesture Update:');
      print('   Boundary: $_boundary');
      print('   Delta: $delta');
      print('   Before rect: ${rect.value}');

      // Use detected boundary directly since gesture area now matches visual rotation
      switch (_boundary) {
        case CropBoundaries.inside:
          final Offset pos = rect.value.topLeft + delta;
          rect.value = Rect.fromLTWH(
              pos.dx.clamp(0, layout.width - rect.value.width),
              pos.dy.clamp(0, layout.height - rect.value.height),
              rect.value.width,
              rect.value.height);
          break;
        //CORNERS
        case CropBoundaries.topLeft:
          final Offset pos = rect.value.topLeft + delta;
          _changeRect(left: pos.dx, top: pos.dy);
          break;
        case CropBoundaries.topRight:
          final Offset pos = rect.value.topRight + delta;
          _changeRect(right: pos.dx, top: pos.dy);
          break;
        case CropBoundaries.bottomRight:
          final Offset pos = rect.value.bottomRight + delta;
          _changeRect(right: pos.dx, bottom: pos.dy);
          break;
        case CropBoundaries.bottomLeft:
          final Offset pos = rect.value.bottomLeft + delta;
          _changeRect(left: pos.dx, bottom: pos.dy);
          break;
        //CENTERS
        case CropBoundaries.topCenter:
          _changeRect(top: rect.value.top + delta.dy);
          break;
        case CropBoundaries.bottomCenter:
          _changeRect(bottom: rect.value.bottom + delta.dy);
          break;
        case CropBoundaries.centerLeft:
          _changeRect(left: rect.value.left + delta.dx);
          break;
        case CropBoundaries.centerRight:
          _changeRect(right: rect.value.right + delta.dx);
          break;
        case CropBoundaries.none:
          break;
      }

      print('   After rect: ${rect.value}');
    });
  }

  void _onPanEnd({bool force = false}) {
    if (_boundary != CropBoundaries.none || force) {
      monitorSyncOperation('_onPanEnd', () {
        final Rect r = rect.value;
        _controller.cacheMinCrop = Offset(
          r.left / layout.width,
          r.top / layout.height,
        );
        _controller.cacheMaxCrop = Offset(
          r.right / layout.width,
          r.bottom / layout.height,
        );
        _controller.isCropping = false;
        _cropStateManager.setCropping(false);
        // to update selected boundary color
        setState(() => _boundary = CropBoundaries.none);
      });
    }
  }

  //-----------//
  //RECT CHANGE//
  //-----------//

  /// Update [Rect] crop from incoming values, while respecting [_preferredCropAspectRatio]
  void _changeRect({double? left, double? top, double? right, double? bottom}) {
    top = max(0, top ?? rect.value.top);
    left = max(0, left ?? rect.value.left);
    right = min(layout.width, right ?? rect.value.right);
    bottom = min(layout.height, bottom ?? rect.value.bottom);

    // update crop height or width to adjust to the selected aspect ratio
    if (aspectRatio != null) {
      final width = right - left;
      final height = bottom - top;

      if (width / height > aspectRatio!) {
        switch (_boundary) {
          case CropBoundaries.topLeft:
          case CropBoundaries.bottomLeft:
            left = right - height * aspectRatio!;
            break;
          case CropBoundaries.topRight:
          case CropBoundaries.bottomRight:
            right = left + height * aspectRatio!;
            break;
          default:
            assert(false);
        }
      } else {
        switch (_boundary) {
          case CropBoundaries.topLeft:
          case CropBoundaries.topRight:
            top = bottom - width / aspectRatio!;
            break;
          case CropBoundaries.bottomLeft:
          case CropBoundaries.bottomRight:
            bottom = top + width / aspectRatio!;
            break;
          default:
            assert(false);
        }
      }
    }

    final newRect = Rect.fromLTRB(left, top, right, bottom);

    if (newRect.width < minRectSize ||
        newRect.height < minRectSize ||
        !isRectContained(layout, newRect)) {
      return;
    }

    rect.value = newRect;
    _cropStateManager.updateCropRect(newRect);
  }

  @override
  void updateRectFromBuild() {
    if (widget.showGrid) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateRect());
    } else {
      _scaleRect();
    }
  }

  @override
  Widget buildView(BuildContext context, TransformData transform) {
    if (widget.showGrid == false) {
      return RepaintBoundary(
        child: _buildCropView(transform, widget.overlayText),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        RepaintBoundary(
          child: _buildCropView(transform, widget.overlayText),
        ),
        // Apply the same rotation transform to GestureDetector to align with visual rotation
        Transform.rotate(
          angle: transform.rotation,
          child: GestureDetector(
            onPanDown: _onPanDown,
            onPanUpdate: _onPanUpdate,
            onPanEnd: (_) => _onPanEnd(),
            onTapUp: (_) => _onPanEnd(),
            child: const SizedBox.expand(
              child: DecoratedBox(
                decoration: BoxDecoration(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCropView(TransformData transform, String overlayText) {
    return Padding(
      padding: widget.margin,
      child: buildVideoView(
        _controller,
        transform,
        _boundary,
        overlayText: overlayText,
        showGrid: widget.showGrid,
      ),
    );
  }
}
