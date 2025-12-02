import 'package:flutter/material.dart';
import 'package:ai_video_creator_editor/controllers/video_controller.dart';
import 'package:ai_video_creator_editor/screens/project/models/transform_data.dart';
import 'package:ai_video_creator_editor/components/crop/crop_grid.dart';

/// Efficient state manager for crop operations with caching and performance optimization
class CropStateManager extends ChangeNotifier {
  final VideoEditorController controller;

  // Reactive state using ValueNotifier for minimal rebuilds
  final ValueNotifier<Rect> cropRect = ValueNotifier<Rect>(Rect.zero);
  final ValueNotifier<TransformData> transform =
      ValueNotifier<TransformData>(const TransformData());
  final ValueNotifier<bool> isCropping = ValueNotifier<bool>(false);
  final ValueNotifier<CropBoundaries> boundary =
      ValueNotifier<CropBoundaries>(CropBoundaries.none);

  // Cached calculations to avoid recalculations
  TransformData? _cachedTransform;
  Rect? _cachedCropRect;
  Size? _cachedLayout;
  Size? _cachedViewerSize;

  // Layout and viewer size tracking
  Size _layout = Size.zero;
  Size _viewerSize = Size.zero;

  CropStateManager(this.controller);

  // Getters for current state
  Size get layout => _layout;
  Size get viewerSize => _viewerSize;

  /// Update layout size with caching
  void updateLayout(Size newLayout) {
    if (_cachedLayout != newLayout) {
      _cachedLayout = newLayout;
      _layout = newLayout;
      _invalidateTransformCache();
    }
  }

  /// Update viewer size with caching
  void updateViewerSize(Size newViewerSize) {
    if (_cachedViewerSize != newViewerSize) {
      _cachedViewerSize = newViewerSize;
      _viewerSize = newViewerSize;
      _invalidateTransformCache();
    }
  }

  /// Update crop rectangle with caching and transform recalculation
  void updateCropRect(Rect newRect) {
    if (_cachedCropRect != newRect) {
      _cachedCropRect = newRect;
      cropRect.value = newRect;
      _updateTransform();
    }
  }

  /// Update cropping state
  void setCropping(bool cropping) {
    isCropping.value = cropping;
  }

  /// Update boundary state
  void setBoundary(CropBoundaries newBoundary) {
    boundary.value = newBoundary;
  }

  /// Calculate and cache transform data
  void _updateTransform() {
    if (_layout == Size.zero || _viewerSize == Size.zero) return;

    // Only recalculate if necessary
    if (_cachedTransform == null || _cachedCropRect != cropRect.value) {
      _cachedTransform = TransformData.fromRect(
        cropRect.value,
        _layout,
        _viewerSize,
        controller,
      );
      transform.value = _cachedTransform!;
    }
  }

  /// Invalidate transform cache when layout changes
  void _invalidateTransformCache() {
    _cachedTransform = null;
    _updateTransform();
  }

  /// Clear all caches (call when video changes)
  void clearCache() {
    _cachedTransform = null;
    _cachedCropRect = null;
    _cachedLayout = null;
    _cachedViewerSize = null;
  }

  /// Dispose resources
  @override
  void dispose() {
    cropRect.dispose();
    transform.dispose();
    isCropping.dispose();
    boundary.dispose();
    super.dispose();
  }
}

// Crop boundaries enum is defined in crop_grid.dart to avoid conflicts
