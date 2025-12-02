import 'package:ai_video_creator_editor/components/crop/crop_grid.dart';
import 'package:ai_video_creator_editor/components/crop/crop_grid_painter.dart';
import 'package:ai_video_creator_editor/components/crop/optimized_transform.dart';
import 'package:ai_video_creator_editor/components/crop/video_viewer.dart';
import 'package:ai_video_creator_editor/controllers/video_controller.dart';
import 'package:ai_video_creator_editor/screens/project/models/transform_data.dart';
import 'package:ai_video_creator_editor/utils/helpers.dart';
import 'package:flutter/material.dart';

/// Optimized mixin for crop preview functionality with caching and performance improvements
mixin CropPreviewMixin<T extends StatefulWidget> on State<T> {
  final ValueNotifier<Rect> rect = ValueNotifier<Rect>(Rect.zero);
  final ValueNotifier<TransformData> transform =
      ValueNotifier<TransformData>(const TransformData());

  Size viewerSize = Size.zero;
  Size layout = Size.zero;

  // Cached layout calculations for performance
  Size? _cachedLayout;
  EdgeInsets? _cachedMargin;
  bool? _cachedShouldFlipped;
  double? _cachedVideoRatio;

  @override
  void dispose() {
    transform.dispose();
    rect.dispose();
    super.dispose();
  }

  /// Returns the size of the max crop dimension based on available space and
  /// original video aspect ratio with caching for performance
  Size computeLayout(
    VideoEditorController controller, {
    EdgeInsets margin = EdgeInsets.zero,
    bool shouldFlipped = false,
  }) {
    if (viewerSize == Size.zero) return Size.zero;

    final videoRatio = controller.video.value.aspectRatio;

    // Check if we can use cached layout
    if (_cachedLayout != null &&
        _cachedMargin == margin &&
        _cachedShouldFlipped == shouldFlipped &&
        _cachedVideoRatio == videoRatio) {
      return _cachedLayout!;
    }

    // Calculate new layout
    final size = Size(viewerSize.width - margin.horizontal,
        viewerSize.height - margin.vertical);

    Size computedLayout;
    if (shouldFlipped) {
      computedLayout = computeSizeWithRatio(
              videoRatio > 1 ? size.flipped : size,
              getOppositeRatio(videoRatio))
          .flipped;
    } else {
      computedLayout = computeSizeWithRatio(size, videoRatio);
    }

    // Cache the result
    _cachedLayout = computedLayout;
    _cachedMargin = margin;
    _cachedShouldFlipped = shouldFlipped;
    _cachedVideoRatio = videoRatio;

    return computedLayout;
  }

  /// Clear layout cache when needed
  void clearLayoutCache() {
    _cachedLayout = null;
    _cachedMargin = null;
    _cachedShouldFlipped = null;
    _cachedVideoRatio = null;
  }

  void updateRectFromBuild();

  Widget buildView(BuildContext context, TransformData transform);

  /// Returns the [VideoViewer] transformed with editing view
  /// Paint rect on top of the video area outside of the crop rect
  Widget buildVideoView(
    VideoEditorController controller,
    TransformData transform,
    CropBoundaries boundary, {
    String overlayText = '',
    bool showGrid = false,
  }) {
    return SizedBox.fromSize(
      size: layout,
      child: OptimizedCropTransformWithAnimation(
        shouldAnimate: false, // Disabled to prevent 0° to current rotation animation
        transform: transform,
        animationDuration:
            const Duration(milliseconds: 600), // Smoother rotation
        animationCurve: Curves.easeInOut, // Better easing for rotation
        child: VideoViewer(
          controller: controller,
          child: buildPaint(
            controller,
            boundary: boundary,
            showGrid: showGrid,
            showCenterRects: controller.preferredCropAspectRatio == null,
            overlayText: overlayText,
          ),
        ),
      ),
    );
  }

  /// Determine if transform should be animated based on actual changes
  bool _shouldAnimateTransform(TransformData transform) {
    // Only animate if there's actual rotation, scale, or translation
    // Use more precise thresholds to prevent unnecessary animations
    return transform.rotation.abs() > 0.01 || // > 0.57 degrees
        (transform.scale - 1.0).abs() > 0.01 || // > 1% scale change
        transform.translate.distance > 1.0; // > 1 pixel movement
  }

  // Note: ImageViewer functionality not implemented in current project
  // This can be added later if thumbnail generation is needed

  Widget buildPaint(
    VideoEditorController controller, {
    CropBoundaries? boundary,
    bool showGrid = false,
    bool showCenterRects = false,
    String overlayText = '',
  }) {
    return ValueListenableBuilder(
      valueListenable: rect,
      // Build a [Widget] that hides the cropped area and show the crop grid if widget.showGrid is true
      builder: (_, Rect value, __) => RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: CropGridPainter(
            value,
            style: controller.cropStyle,
            boundary: boundary,
            showGrid: showGrid,
            showCenterRects: showCenterRects,
            overlayText: overlayText,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final size = constraints.biggest;
      if (size != viewerSize) {
        viewerSize = size;
        // Clear layout cache when viewer size changes
        clearLayoutCache();
        updateRectFromBuild();
      }

      return ValueListenableBuilder(
        valueListenable: transform,
        builder: (_, TransformData transform, __) =>
            buildView(context, transform),
      );
    });
  }
}
