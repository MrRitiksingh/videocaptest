import 'package:flutter/material.dart';
import 'package:ai_video_creator_editor/screens/project/models/video_track_model.dart';

/// AspectRatioAwareCropPreview: A new approach to crop preview that properly maintains aspect ratios
///
/// WHY: The existing CropPreviewWidget has scaling issues that cause distortion
/// WHERE: Used in MediaCanvasRenderer and crop preview scenarios
/// WHAT: Provides proper aspect ratio preservation with letterboxing/pillarboxing
class AspectRatioAwareCropPreview extends StatelessWidget {
  final Widget child;
  final CropModel? cropModel;
  final Size videoSize;
  final Size previewSize;
  final bool showCropOverlay;
  final Function(CropModel cropModel)? onCropChanged;
  final VoidCallback? onCropToggle;

  /// Preview mode determines how cropped content is displayed
  /// - fitCrop: Shows only cropped area, maintaining aspect ratio with letterboxing
  /// - fillPreview: Stretches crop to fill preview (legacy behavior)
  final CropPreviewMode previewMode;

  const AspectRatioAwareCropPreview({
    Key? key,
    required this.child,
    this.cropModel,
    required this.videoSize,
    required this.previewSize,
    this.showCropOverlay = false,
    this.onCropChanged,
    this.onCropToggle,
    this.previewMode = CropPreviewMode.fitCrop,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cropModel = this.cropModel;

    if (cropModel == null || !cropModel.enabled) {
      return _buildUncropped();
    }

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        // Cropped content with proper aspect ratio
        _buildAspectRatioAwareCroppedContent(cropModel),

        // Crop overlay (if enabled)
        if (showCropOverlay) _buildCropOverlay(cropModel),
      ],
    );
  }

  /// Build uncropped content (fallback)
  Widget _buildUncropped() {
    return SizedBox(
      width: previewSize.width,
      height: previewSize.height,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: videoSize.width,
          height: videoSize.height,
          child: child,
        ),
      ),
    );
  }

  /// Build cropped content with proper aspect ratio preservation
  ///
  /// APPROACH: Instead of complex scaling math, use Flutter's built-in FittedBox
  /// with proper clipping to maintain aspect ratios naturally
  Widget _buildAspectRatioAwareCroppedContent(CropModel cropModel) {
    print('🎬 AspectRatioAwareCropPreview building cropped content:');
    print('   Video size: ${videoSize.width} x ${videoSize.height}');
    print('   Preview size: ${previewSize.width} x ${previewSize.height}');
    print(
        '   Crop: x=${cropModel.x}, y=${cropModel.y}, w=${cropModel.width}, h=${cropModel.height}');

    // Calculate crop area aspect ratio
    final cropAspectRatio = cropModel.width / cropModel.height;
    final previewAspectRatio = previewSize.width / previewSize.height;

    print('   Crop aspect ratio: $cropAspectRatio');
    print('   Preview aspect ratio: $previewAspectRatio');

    if (previewMode == CropPreviewMode.fillPreview) {
      return _buildFillPreviewMode(cropModel);
    } else {
      return _buildFitCropMode(cropModel);
    }
  }

  /// Fit crop mode: Shows only cropped area with proper aspect ratio preservation
  /// This is the MAIN solution to the aspect ratio problem
  Widget _buildFitCropMode(CropModel cropModel) {
    print('   Using FIT CROP mode (maintains aspect ratio)');

    // Step 1: Calculate crop area aspect ratio and how it should fit in preview
    final cropAspectRatio = cropModel.width / cropModel.height;
    final previewAspectRatio = previewSize.width / previewSize.height;

    // Step 2: Calculate how the CROP AREA should be displayed in preview (maintaining aspect ratio)
    double cropDisplayWidth, cropDisplayHeight;
    double cropOffsetX = 0, cropOffsetY = 0;

    if (cropAspectRatio > previewAspectRatio) {
      // Crop is wider - fit width, letterbox top/bottom
      cropDisplayWidth = previewSize.width;
      cropDisplayHeight = previewSize.width / cropAspectRatio;
      cropOffsetY = (previewSize.height - cropDisplayHeight) / 2;
    } else {
      // Crop is taller - fit height, pillarbox left/right
      cropDisplayHeight = previewSize.height;
      cropDisplayWidth = previewSize.height * cropAspectRatio;
      cropOffsetX = (previewSize.width - cropDisplayWidth) / 2;
    }

    print(
        '   Crop will display as: ${cropDisplayWidth} x ${cropDisplayHeight} at offset ($cropOffsetX, $cropOffsetY)');

    // Step 3: Calculate scale factor needed to make crop area fit the calculated display size
    final cropToDisplayScale = cropDisplayWidth / cropModel.width;

    print('   Crop to display scale: $cropToDisplayScale');

    // Step 4: Calculate video position to show only the crop area
    final videoLeft = -cropModel.x * cropToDisplayScale;
    final videoTop = -cropModel.y * cropToDisplayScale;
    final videoWidth = videoSize.width * cropToDisplayScale;
    final videoHeight = videoSize.height * cropToDisplayScale;

    print(
        '   Video positioned at: left=$videoLeft, top=$videoTop, size=${videoWidth}x${videoHeight}');

    // Step 5: Create the properly cropped content
    return SizedBox(
      width: previewSize.width,
      height: previewSize.height,
      child: Stack(
        children: [
          // Black background for letterboxing/pillarboxing
          Container(
            width: previewSize.width,
            height: previewSize.height,
            color: Colors.black,
          ),

          // Positioned crop display area with clipped video
          Positioned(
            left: cropOffsetX,
            top: cropOffsetY,
            width: cropDisplayWidth,
            height: cropDisplayHeight,
            child: ClipRect(
              child: Stack(
                children: [
                  Positioned(
                    left: videoLeft,
                    top: videoTop,
                    width: videoWidth,
                    height: videoHeight,
                    child: child,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Fill preview mode: Stretches crop to fill entire preview (legacy behavior)
  Widget _buildFillPreviewMode(CropModel cropModel) {
    print('   Using FILL PREVIEW mode (may cause distortion)');

    // This is the old logic - kept for compatibility
    final videoScaleX = previewSize.width / videoSize.width;
    final videoScaleY = previewSize.height / videoSize.height;
    final videoScale = videoScaleX < videoScaleY ? videoScaleX : videoScaleY;

    final scaledCropX = cropModel.x * videoScale;
    final scaledCropY = cropModel.y * videoScale;
    final scaledCropWidth = cropModel.width * videoScale;
    final scaledCropHeight = cropModel.height * videoScale;

    final cropScaleX = previewSize.width / scaledCropWidth;
    final cropScaleY = previewSize.height / scaledCropHeight;
    final cropScale = cropScaleX < cropScaleY ? cropScaleX : cropScaleY;

    final finalScale = videoScale * cropScale;
    final offsetX = (previewSize.width - scaledCropWidth * cropScale) / 2 -
        scaledCropX * cropScale;
    final offsetY = (previewSize.height - scaledCropHeight * cropScale) / 2 -
        scaledCropY * cropScale;

    return ClipRect(
      child: SizedBox(
        width: previewSize.width,
        height: previewSize.height,
        child: Transform.translate(
          offset: Offset(offsetX, offsetY),
          child: Transform.scale(
            scale: finalScale,
            alignment: Alignment.topLeft,
            child: child,
          ),
        ),
      ),
    );
  }

  /// Build crop overlay (simplified version)
  Widget _buildCropOverlay(CropModel cropModel) {
    // For now, use a simple overlay - can be enhanced later
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.red, width: 2),
        ),
        child: const Center(
          child: Text(
            'CROP OVERLAY',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

/// Crop preview modes
enum CropPreviewMode {
  /// Fit crop: Shows only cropped area with proper aspect ratio (recommended)
  fitCrop,

  /// Fill preview: Stretches crop to fill preview area (legacy, may distort)
  fillPreview,
}
