import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:ai_video_creator_editor/screens/project/models/video_track_model.dart';
import 'package:ai_video_creator_editor/screens/project/models/text_track_model.dart';
import 'package:ai_video_creator_editor/screens/project/models/canvas_transform.dart';
import 'package:ai_video_creator_editor/utils/text_auto_wrap_helper.dart';
import 'canvas_text_overlay_painter.dart';
import 'text_rotation_manager.dart';
import 'media_manipulation_handler.dart';
import 'canvas_zoom_controller.dart';
import '../canvas_configuration.dart';
import '../text_overlay_manager.dart'; // For FilterManager
import '../video_editor_provider.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;

/// Hit test types for unified gesture system
enum HitType {
  none,
  text,
  videoDrag,
  videoSelection,
  videoRotationHandle,
  videoResizeHandle,
}

/// Hit test result containing interaction details
class HitTestResult {
  final HitType type;
  final Offset position;
  final TextTrackModel? textTrack;
  final VideoTrackModel? videoTrack;
  final ResizeHandle? resizeHandle;

  const HitTestResult({
    required this.type,
    required this.position,
    this.textTrack,
    this.videoTrack,
    this.resizeHandle,
  });
}

/// Unified clipper for cropping both video and image content
/// Based on the working _VideoCropClipper from IndividualVideoCropDialog
class MediaCropClipper extends CustomClipper<Rect> {
  final Rect cropRect;
  
  MediaCropClipper(this.cropRect);
  
  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(
      cropRect.left * size.width,
      cropRect.top * size.height,
      cropRect.width * size.width,
      cropRect.height * size.height,
    );
  }
  
  @override
  bool shouldReclip(MediaCropClipper oldClipper) {
    return oldClipper.cropRect != cropRect;
  }
}

/// Unified renderer for media (video/image) with canvas transformations
/// Now supports fixed canvas dimensions with preview scaling
class MediaCanvasRenderer extends StatefulWidget {
  final VideoTrackModel track;
  final VideoPlayerController? controller;
  final Size fixedCanvasSize; // Fixed canvas size (e.g., 1080x720)
  final Size previewContainerSize; // Actual preview container size
  final bool isSelected;
  final bool showHandles;
  final Function(VideoTrackModel)? onTrackUpdate;
  final VoidCallback? onTap;
  
  // Text overlay support
  final List<TextTrackModel> textTracks;
  final double currentTime;
  final int? selectedTextIndex;
  final Function(int, TextTrackModel)? onTextTrackUpdate;
  
  // Canvas configuration for dual canvas system
  final CanvasConfiguration? canvasConfiguration;

  // Canvas zoom controller for zoom/pan functionality
  final CanvasZoomController? zoomController;

  // Filter for video/image content (not applied to text overlays)
  final String? filter;

  const MediaCanvasRenderer({
    super.key,
    required this.track,
    required this.controller,
    required this.fixedCanvasSize,
    required this.previewContainerSize,
    this.isSelected = false,
    this.showHandles = false,
    this.onTrackUpdate,
    this.onTap,
    this.textTracks = const [],
    required this.currentTime,
    this.selectedTextIndex,
    this.onTextTrackUpdate,
    this.canvasConfiguration,
    this.zoomController,
    this.filter,
  });

  // Legacy constructor for backward compatibility
  const MediaCanvasRenderer.legacy({
    super.key,
    required this.track,
    required this.controller,
    required Size canvasSize,
    this.isSelected = false,
    this.showHandles = false,
    this.onTrackUpdate,
    this.onTap,
    this.textTracks = const [],
    required this.currentTime,
    this.selectedTextIndex,
    this.onTextTrackUpdate,
  }) : fixedCanvasSize = canvasSize,
       previewContainerSize = canvasSize,
       canvasConfiguration = null,
       zoomController = null,
       filter = null;

  @override
  State<MediaCanvasRenderer> createState() => _MediaCanvasRendererState();
}

class _MediaCanvasRendererState extends State<MediaCanvasRenderer> {
  ui.Image? _imageCache;
  bool _isLoadingImage = false;
  
  // Text overlay interaction state
  final Map<String, Offset> _localDragPositions = {};
  TextTrackModel? _draggedTrack;
  TextTrackModel? _scalingTrack;
  double? _tempRotation;
  Timer? _throttleTimer;

  // Asset drag state variables (like text overlay pattern)
  VideoTrackModel? _draggedAsset;
  VideoTrackModel? _scalingAsset;
  
  // Video manipulation handler
  late MediaManipulationHandler _manipulationHandler;


  @override
  void initState() {
    super.initState();
    
    // Initialize manipulation handler with fixed canvas size
    _manipulationHandler = MediaManipulationHandler(
      canvasSize: widget.fixedCanvasSize,
      onTrackUpdate: (updatedTrack) {
        widget.onTrackUpdate?.call(updatedTrack);
      },
    );
    
    if (widget.track.isImageBased) {
      _loadImage();
    }
  }

  @override
  void didUpdateWidget(MediaCanvasRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update manipulation handler if canvas size changed
    if (widget.fixedCanvasSize != oldWidget.fixedCanvasSize) {
      _manipulationHandler = MediaManipulationHandler(
        canvasSize: widget.fixedCanvasSize,
        onTrackUpdate: (updatedTrack) {
          widget.onTrackUpdate?.call(updatedTrack);
        },
      );
    }
    
    if (widget.track.originalFile.path != oldWidget.track.originalFile.path) {
      _imageCache = null;
      if (widget.track.isImageBased) {
        _loadImage();
      }
    }
  }

  Future<void> _loadImage() async {
    if (_isLoadingImage || _imageCache != null) return;

    // Check global cache first
    final provider = context.read<VideoEditorProvider>();
    final cachedImage = provider.imageCache[widget.track.id];
    if (cachedImage != null) {
      print('✅ Using cached image for track ${widget.track.id}');
      if (mounted) {
        setState(() {
          _imageCache = cachedImage;
          _isLoadingImage = false;
        });
      }
      // Pre-cache next track after using cached image
      _preCacheNextTrack();
      return;
    }

    setState(() => _isLoadingImage = true);

    try {
      final bytes = await widget.track.originalFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();

      if (mounted) {
        setState(() {
          _imageCache = frame.image;
          _isLoadingImage = false;
        });

        // Store in global cache
        provider.cacheImage(widget.track.id, frame.image);
        print('💾 Cached image for track ${widget.track.id}');

        // Pre-cache next track
        _preCacheNextTrack();
      }
    } catch (e) {
      print('Error loading image: $e');
      if (mounted) {
        setState(() => _isLoadingImage = false);
      }
    }
  }

  void _preCacheNextTrack() {
    try {
      final provider = context.read<VideoEditorProvider>();
      final tracks = provider.videoTracks;

      // Find current track index
      final currentIndex = tracks.indexWhere((t) => t.id == widget.track.id);
      if (currentIndex == -1 || currentIndex >= tracks.length - 1) {
        return; // No next track
      }

      // Get next track
      final nextTrack = tracks[currentIndex + 1];

      // Only pre-cache if next track is image-based and not already cached
      if (nextTrack.isImageBased && !provider.imageCache.containsKey(nextTrack.id)) {
        print('🔄 Pre-caching next track: ${nextTrack.id}');

        // Load in background
        Future(() async {
          try {
            final bytes = await nextTrack.originalFile.readAsBytes();
            final codec = await ui.instantiateImageCodec(bytes);
            final frame = await codec.getNextFrame();
            provider.cacheImage(nextTrack.id, frame.image);
            print('✅ Pre-cached next track: ${nextTrack.id}');
          } catch (e) {
            print('⚠️ Error pre-caching next track: $e');
          }
        });
      }
    } catch (e) {
      print('⚠️ Error in _preCacheNextTrack: $e');
    }
  }

  @override
  void dispose() {
    // Don't dispose _imageCache here - it's managed by the global cache in provider
    // The provider will handle disposal when needed
    _throttleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transform = _getCanvasTransform();
    
    // With dynamic canvas sizing, the canvas should fit optimally in the container
    // Calculate minimal scaling needed (should be close to 1.0)
    final scaleX = widget.previewContainerSize.width / widget.fixedCanvasSize.width;
    final scaleY = widget.previewContainerSize.height / widget.fixedCanvasSize.height;
    final previewScale = math.min(scaleX, scaleY);
    
    // Canvas size after minimal scaling
    final actualCanvasSize = Size(
      widget.fixedCanvasSize.width * previewScale,
      widget.fixedCanvasSize.height * previewScale,
    );
    
    // Calculate centering offset within container
    final offsetX = (widget.previewContainerSize.width - actualCanvasSize.width) / 2;
    final offsetY = (widget.previewContainerSize.height - actualCanvasSize.height) / 2;
    
    print('🎨 MediaCanvasRenderer.build() for track: ${widget.track.id}');
    print('   💡 SELECTION STATE: ${widget.isSelected ? "SELECTED ✅" : "NOT SELECTED ❌"}');
    print('   Dynamic canvas size: ${widget.fixedCanvasSize}');
    print('   Preview container size: ${widget.previewContainerSize}');
    print('   Preview scale: ${previewScale.toStringAsFixed(3)} (should be ~1.0 with dynamic sizing)');
    print('   Actual canvas size: ${actualCanvasSize}');
    print('   Center offset: (${offsetX.toStringAsFixed(1)}, ${offsetY.toStringAsFixed(1)})');
    print('   📦 Track canvas properties:');
    print('     Track canvas size: ${widget.track.canvasSize}');
    print('     Track canvas position: ${widget.track.canvasPosition}');
    print('   🔄 Transform result:');
    print('     Transform size: ${transform.size}');
    print('     Transform position: ${transform.position}');
    
    // Check if track still has tiny default canvas properties
    if (widget.track.canvasSize == const Size(100, 100)) {
      print('   ⚠️ Track still has default tiny canvas size - initializing');
      print('   Showing loading indicator');
      return Container(
        width: widget.previewContainerSize.width,
        height: widget.previewContainerSize.height,
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white54),
              SizedBox(height: 8),
              Text('Initializing...', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      );
    }
    
    // Build the base canvas content
    Widget canvasContent = Container(
      width: actualCanvasSize.width,
      height: actualCanvasSize.height,
      decoration: BoxDecoration(
        color: Color(0xFF1a1a1a), // Dark gray background for canvas
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRect(
        // Canvas-level clipping to prevent rotated content overflow
        child: Stack(
          children: [
            // Media content
            _buildMediaContent(),

            // Unified interaction system (text + video)
            _buildUnifiedInteractionSystem(),

            // Asset drag overlay - Show during asset drag (track-specific validation)
            if (_draggedAsset != null && _draggedAsset!.id == widget.track.id)
              _buildSelectionOverlay(),

            // Asset scaling overlay - Show during asset scaling (track-specific validation)
            if (_scalingAsset != null && _scalingAsset!.id == widget.track.id)
              _buildManipulationHandles(),

            // Debug overlay showing canvas and container info (commented out)
            // _buildDebugOverlay(),
          ],
        ),
      ),
    );

    // Apply zoom transformation if zoom controller is provided
    if (widget.zoomController != null) {
      widget.zoomController!.initialize(
        canvasSize: actualCanvasSize,
        containerSize: widget.previewContainerSize,
      );

      canvasContent = Transform(
        transform: widget.zoomController!.getTransformMatrix(),
        child: canvasContent,
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      // Add zoom/pan gesture detection
      // onScaleStart: widget.zoomController != null ? _handleScaleStart : null,
      // onScaleUpdate: widget.zoomController != null ? _handleScaleUpdate : null,
      // onScaleEnd: widget.zoomController != null ? _handleScaleEnd : null,
      child: Container(
        width: widget.previewContainerSize.width,
        height: widget.previewContainerSize.height,
        decoration: BoxDecoration(
          color: Colors.black,
        ),
        child: Center(
          child: canvasContent,
        ),
      ),
    );
  }

  Widget _buildMediaContent() {
    final transform = _getCanvasTransform();
    
    // Calculate preview scaling factor
    final scaleX = widget.previewContainerSize.width / widget.fixedCanvasSize.width;
    final scaleY = widget.previewContainerSize.height / widget.fixedCanvasSize.height;
    final previewScale = math.min(scaleX, scaleY);
    
    // Scale the transform coordinates and size for the preview
    final scaledPosition = Offset(
      transform.position.dx * previewScale,
      transform.position.dy * previewScale,
    );
    final scaledSize = Size(
      transform.size.width * previewScale,
      transform.size.height * previewScale,
    );
    
    return Positioned(
      left: scaledPosition.dx,
      top: scaledPosition.dy,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..scale(transform.scale)
          ..rotateZ(transform.rotation),
        child: Opacity(
          opacity: transform.opacity,
          child: ClipRect(
            child: Container(
              width: scaledSize.width,
              height: scaledSize.height,
              child: _buildMediaWidget(transform.copyWith(size: scaledSize)),
            ),
          ),
        ),
      ),
    );
  }

  /// Helper method to apply filter if needed
  Widget _applyFilterIfNeeded(Widget child) {
    if (widget.filter == null || widget.filter == 'none') {
      return child;
    }

    final colorFilter = FilterManager.getColorFilter(widget.filter!);
    return ColorFiltered(
      colorFilter: colorFilter,
      child: child,
    );
  }

  Widget _buildMediaWidget(CanvasTransform transform) {
    print('🔍 _buildMediaWidget() for track: ${widget.track.id}');
    print('   Transform size: ${transform.size}');
    print('   Is image based: ${widget.track.isImageBased}');

    // Safety check: Don't render if transform size is invalid or too small
    if (transform.size.width < 50 || transform.size.height < 50 ||
        !transform.size.width.isFinite || !transform.size.height.isFinite) {
      print('   ⚠️ SAFETY CHECK TRIGGERED - Invalid transform size');
      return Container(
        width: 50,
        height: 50,
        color: Colors.grey[800],
        child: Center(
          child: Icon(Icons.hourglass_empty, color: Colors.white54, size: 20),
        ),
      );
    }
    
    if (widget.track.isImageBased) {
      print('   → Taking IMAGE rendering path');
      // Render image
      if (_imageCache != null) {
        final imageSize = Size(_imageCache!.width.toDouble(), _imageCache!.height.toDouble());
        
        print('   🔍 IMAGE CROP INFO:');
        print('      Image size: ${imageSize.width.toStringAsFixed(2)} x ${imageSize.height.toStringAsFixed(2)}');
        print('      Transform size: ${transform.size.width.toStringAsFixed(2)} x ${transform.size.height.toStringAsFixed(2)}');
        print('      Crop model: ${widget.track.canvasCropModel}');
        
        // Use CropPreviewWidget approach with proper scaling
        Widget imageWidget = CustomPaint(
          size: transform.size,
          painter: _ImagePainter(
            image: _imageCache!,
            cropRect: const Rect.fromLTWH(0, 0, 1, 1), // Full image, crop handled by CropPreviewWidget
          ),
        );

        // Apply crop if enabled - treat as new asset with cropped dimensions
        if (widget.track.canvasCropModel?.enabled == true) {
          print('      🖼️ TREATING CROPPED IMAGE AS NEW ASSET');
          final cropModel = widget.track.canvasCropModel!;

          // Calculate the effective "new image size" from crop dimensions
          final croppedImageSize = Size(cropModel.width, cropModel.height);
          print('      📐 Original image size: ${imageSize.width} x ${imageSize.height}');
          print('      🎯 Cropped "asset" size: ${croppedImageSize.width} x ${croppedImageSize.height}');

          // Calculate crop area in normalized coordinates
          final cropRect = Rect.fromLTWH(
            cropModel.x / imageSize.width,
            cropModel.y / imageSize.height,
            cropModel.width / imageSize.width,
            cropModel.height / imageSize.height,
          );

          // Use CustomPaint with cropped area as new asset
          return _applyFilterIfNeeded(
            CustomPaint(
              size: transform.size,
              painter: _ImagePainter(
                image: _imageCache!,
                cropRect: cropRect, // Apply crop directly in painter
                treatAsNewAsset: true, // Flag to scale crop to fill entire transform area
              ),
            ),
          );
        }

        return _applyFilterIfNeeded(imageWidget);
      } else if (_isLoadingImage) {
        return Center(child: CircularProgressIndicator());
      } else {
        return Container(
          color: Colors.grey[800],
          child: Center(
            child: Icon(Icons.image, color: Colors.white54),
          ),
        );
      }
    } else {
      print('   → Taking VIDEO rendering path');
      // Render video
      if (widget.controller != null && widget.controller!.value.isInitialized) {
        print('   ✅ Video controller is initialized');
        print('   Video controller size: ${widget.controller!.value.size}');
        print('   Rendering video with transform size: ${transform.size}');
        
        final videoSize = widget.controller!.value.size;
        
        print('   🔲 Video crop info for track ${widget.track.id}:');
        print('      Crop model: ${widget.track.canvasCropModel}');
        print('      Original video size: ${videoSize.width} x ${videoSize.height}');
        
        final videoScale = _calculateVideoScale(transform, videoSize);
        
        // Create base video widget with scaling
        Widget videoWidget = SizedBox(
          width: videoSize.width * videoScale,
          height: videoSize.height * videoScale,
          child: VideoPlayer(widget.controller!),
        );

        // Apply crop if enabled - treat as new asset with cropped dimensions
        if (widget.track.canvasCropModel?.enabled == true) {
          print('      🎬 TREATING CROPPED VIDEO AS NEW ASSET');
          final cropModel = widget.track.canvasCropModel!;

          // Calculate the effective "new video size" from crop dimensions
          final croppedVideoSize = Size(cropModel.width, cropModel.height);
          print('      📐 Original video size: ${videoSize.width} x ${videoSize.height}');
          print('      🎯 Cropped "asset" size: ${croppedVideoSize.width} x ${croppedVideoSize.height}');

          // Calculate scale based on cropped dimensions (treating it as new upload)
          final cropScale = _calculateVideoScale(transform, croppedVideoSize);
          print('      📊 Scale for cropped asset: $cropScale');

          // Calculate crop area in original video coordinates
          final cropRect = Rect.fromLTWH(
            cropModel.x / videoSize.width,
            cropModel.y / videoSize.height,
            cropModel.width / videoSize.width,
            cropModel.height / videoSize.height,
          );

          print('      🎭 Crop rect (normalized): ${cropRect.left.toStringAsFixed(3)}, ${cropRect.top.toStringAsFixed(3)}, ${cropRect.width.toStringAsFixed(3)}, ${cropRect.height.toStringAsFixed(3)}');

          // SCALE CROP TO FILL ENTIRE TRANSFORM (like new asset behavior)
          // Calculate how much we need to scale to make crop fill transform completely
          final scaleToFillX = transform.size.width / cropModel.width;
          final scaleToFillY = transform.size.height / cropModel.height;
          final fillScale = math.max(scaleToFillX, scaleToFillY); // Use max to fill completely

          print('      🎯 FILL SCALE APPROACH:');
          print('         Transform size: ${transform.size.width} x ${transform.size.height}');
          print('         Crop area size: ${cropModel.width} x ${cropModel.height}');
          print('         Scale X: $scaleToFillX, Scale Y: $scaleToFillY');
          print('         Using fill scale: $fillScale');

          // Scale the entire video by the fill scale
          final scaledVideoWidth = videoSize.width * fillScale;
          final scaledVideoHeight = videoSize.height * fillScale;

          // Calculate where the crop area will be in the scaled video
          final scaledCropX = cropModel.x * fillScale;
          final scaledCropY = cropModel.y * fillScale;
          final scaledCropWidth = cropModel.width * fillScale;
          final scaledCropHeight = cropModel.height * fillScale;

          // Position video so crop area is centered in transform
          final videoX = (transform.size.width - scaledCropWidth) / 2 - scaledCropX;
          final videoY = (transform.size.height - scaledCropHeight) / 2 - scaledCropY;

          print('         Scaled video size: $scaledVideoWidth x $scaledVideoHeight');
          print('         Video position: ($videoX, $videoY)');
          print('         Crop will appear at: (${(transform.size.width - scaledCropWidth) / 2}, ${(transform.size.height - scaledCropHeight) / 2})');

          return _applyFilterIfNeeded(
            SizedBox(
              width: transform.size.width,
              height: transform.size.height,
              child: ClipRect(
                child: Stack(
                  children: [
                    Positioned(
                      left: videoX,
                      top: videoY,
                      child: SizedBox(
                        width: scaledVideoWidth,
                        height: scaledVideoHeight,
                        child: VideoPlayer(widget.controller!),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // For non-cropped video, center it in the transform area
        return _applyFilterIfNeeded(
          SizedBox(
            width: transform.size.width,
            height: transform.size.height,
            child: ClipRect(
              child: Center(
                child: videoWidget,
              ),
            ),
          ),
        );
      } else {
        print('   ❌ Video controller not initialized');
        print('   Controller null: ${widget.controller == null}');
        if (widget.controller != null) {
          print('   Controller initialized: ${widget.controller!.value.isInitialized}');
        }
        
        return Container(
          color: Colors.black,
          child: Center(
            child: Icon(Icons.videocam, color: Colors.white54),
          ),
        );
      }
    }
  }

  Widget _buildUnifiedInteractionSystem() {
    // Calculate preview scaling factor (should be minimal with dynamic canvas)
    final scaleX = widget.previewContainerSize.width / widget.fixedCanvasSize.width;
    final scaleY = widget.previewContainerSize.height / widget.fixedCanvasSize.height;
    final previewScale = math.min(scaleX, scaleY);
    
    // Calculate the actual canvas size in the preview container
    final actualCanvasSize = Size(
      widget.fixedCanvasSize.width * previewScale,
      widget.fixedCanvasSize.height * previewScale,
    );
    
    // Unified gesture detector for both text and video interactions
    return GestureDetector(
      onTapDown: _handleUnifiedTapDown,
      onScaleStart: _handleUnifiedScaleStart,
      onScaleUpdate: _handleUnifiedScaleUpdate,
      onScaleEnd: _handleUnifiedScaleEnd,
      child: CustomPaint(
        size: actualCanvasSize,
        painter: CanvasTextOverlayPainter(
          textTracks: _createTextTracksWithLocalPositions(),
          currentTime: widget.currentTime,
          canvasSize: actualCanvasSize,
          currentVideoTrack: widget.track,
          selectedTextIndex: widget.selectedTextIndex,
          isExportMode: false, // Always false for preview rendering
          rotatingTrack: _scalingTrack,
          tempRotation: _tempRotation,
          selectedTrackId: _scalingTrack?.id, // Pass selected track ID
          draggingTrackId: _draggedTrack?.id, // Pass dragging track ID
          canvasConfiguration: widget.canvasConfiguration,
        ),
      ),
    );
  }

  Widget _buildSelectionOverlay() {
    final transform = _getCanvasTransform();
    
    // Calculate preview scaling factor
    final scaleX = widget.previewContainerSize.width / widget.fixedCanvasSize.width;
    final scaleY = widget.previewContainerSize.height / widget.fixedCanvasSize.height;
    final previewScale = math.min(scaleX, scaleY);
    
    // Scale the transform coordinates and size for the preview
    final scaledPosition = Offset(
      transform.position.dx * previewScale,
      transform.position.dy * previewScale,
    );
    final scaledSize = Size(
      transform.size.width * previewScale,
      transform.size.height * previewScale,
    );
    
    return Positioned(
      left: scaledPosition.dx,
      top: scaledPosition.dy,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..scale(transform.scale)
          ..rotateZ(transform.rotation),
        child: Container(
          width: scaledSize.width,
          height: scaledSize.height,
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.blue,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildManipulationHandles() {
    final transform = _getCanvasTransform();

    // Calculate preview scaling factor
    final scaleX = widget.previewContainerSize.width / widget.fixedCanvasSize.width;
    final scaleY = widget.previewContainerSize.height / widget.fixedCanvasSize.height;
    final previewScale = math.min(scaleX, scaleY);

    // Scale the transform coordinates and size for the preview (like _buildSelectionOverlay)
    final scaledPosition = Offset(
      transform.position.dx * previewScale,
      transform.position.dy * previewScale,
    );
    final scaledSize = Size(
      transform.size.width * previewScale,
      transform.size.height * previewScale,
    );

    return Stack(
      children: [
        // Selection border with proper transform application (like _buildSelectionOverlay)
        Positioned(
          left: scaledPosition.dx,
          top: scaledPosition.dy,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..scale(transform.scale)
              ..rotateZ(transform.rotation),
            child: Container(
              width: scaledSize.width,
              height: scaledSize.height,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),

        // Corner resize handles - COMMENTED OUT (user wants only drag functionality)
        // ...corners.map((corner) => Positioned(
        //   left: corner.dx - 6,
        //   top: corner.dy - 6,
        //   child: Container(
        //     width: 12,
        //     height: 12,
        //     decoration: BoxDecoration(
        //       color: Colors.white,
        //       border: Border.all(color: Colors.blue, width: 2),
        //       borderRadius: BorderRadius.circular(6),
        //     ),
        //   ),
        // )),

        // Rotation handle - COMMENTED OUT (user wants only drag functionality)
        // Positioned(
        //   left: scaledTransform.rotationHandlePosition.dx - 8,
        //   top: scaledTransform.rotationHandlePosition.dy - 8,
        //   child: Container(
        //     width: 16,
        //     height: 16,
        //     decoration: BoxDecoration(
        //       color: Colors.orange,
        //       shape: BoxShape.circle,
        //       border: Border.all(color: Colors.white, width: 2),
        //     ),
        //     child: Icon(
        //       Icons.rotate_right,
        //       size: 10,
        //       color: Colors.white,
        //     ),
        //   ),
        // ),
      ],
    );
  }

  double _calculateVideoScale(CanvasTransform transform, Size videoSize) {
    if (videoSize.width <= 0 || videoSize.height <= 0 ||
        !videoSize.width.isFinite || !videoSize.height.isFinite) {
      return 1.0;
    }
    
    if (transform.size.width <= 0 || transform.size.height <= 0 ||
        !transform.size.width.isFinite || !transform.size.height.isFinite) {
      return 1.0;
    }
    
    // Calculate scale to fit the video into the transform size while maintaining aspect ratio
    final scaleX = transform.size.width / videoSize.width;
    final scaleY = transform.size.height / videoSize.height;
    final scale = math.min(scaleX, scaleY);
    
    // Safety check for the calculated scale
    if (!scale.isFinite || scale <= 0) {
      return 1.0;
    }
    
    print('   📐 Video scale calculation:');
    print('      Video size: ${videoSize.width} x ${videoSize.height}');
    print('      Transform size: ${transform.size.width} x ${transform.size.height}');
    print('      Scale X: $scaleX, Scale Y: $scaleY');
    print('      Final scale: $scale');
    
    return scale;
  }



  /// Check if track is currently visible
  bool _isTrackVisible(TextTrackModel track) {
    final startTime = track.trimStartTime;
    final endTime = track.trimEndTime;
    return widget.currentTime >= startTime && widget.currentTime <= endTime;
  }

  /// Calculate accurate text bounds for hit testing using TextPainter
  Rect _calculateTextBounds(TextTrackModel track) {
    // Use the same font size calculation as the painter for consistency
    final fontSize = _calculateCanvasFontSize(track.fontSize, widget.fixedCanvasSize);
    
    // Create text style matching the painter
    final textStyle = TextStyle(
      fontSize: fontSize,
      fontFamily: track.fontFamily,
      height: 1.0,
    );

    // Calculate available space for text wrapping
    final availableSize = _calculateAvailableSize(track);
    
    // Get wrapped text lines
    final wrappedLines = TextAutoWrapHelper.wrapTextToFit(
      track.text,
      availableSize.width,
      availableSize.height,
      textStyle,
    );

    // Calculate actual text dimensions using TextPainter
    final textWidth = _calculateMaxLineWidth(wrappedLines, textStyle);
    final textHeight = _calculateWrappedTextHeight(wrappedLines, textStyle);
    
    // Add touch padding for easier selection
    final touchPadding = 16.0;
    
    // Get effective position (from local drag or track position)
    final effectivePosition = _getEffectivePosition(track);
    
    // For rotated text, use adjusted position calculation like optimized_preview_container
    if (track.rotation != 0) {
      // Get canvas container fitting for coordinate mapping
      final containerFitting = _getCanvasContainerFitting();
      
      // Calculate adjusted position to match the actual visual position of rotated text
      final adjustedPosition = TextRotationManager.calculateRotatedPositionWithVideoBounds(
        basePosition: effectivePosition,
        textWidth: textWidth,
        textHeight: textHeight,
        rotation: track.rotation,
        containerSize: widget.fixedCanvasSize,
        videoSize: widget.fixedCanvasSize, // Use fixed canvas size for consistency
        containerFitting: containerFitting,
        cropRect: null, // No crop in canvas renderer context
      );
      
      // Use standard rectangular bounds at the adjusted position
      // This ensures hit testing works correctly for rotated text
      return Rect.fromLTWH(
        adjustedPosition.dx - touchPadding/2,
        adjustedPosition.dy - touchPadding/2,
        textWidth + touchPadding,
        textHeight + touchPadding,
      );
    } else {
      return Rect.fromLTWH(
        effectivePosition.dx - touchPadding/2,
        effectivePosition.dy - touchPadding/2,
        textWidth + touchPadding,
        textHeight + touchPadding,
      );
    }
  }
  
  /// Get effective position considering local drag positions and track position
  Offset _getEffectivePosition(TextTrackModel track) {
    // Check for local drag position first
    final localPosition = _localDragPositions[track.id];
    if (localPosition != null) {
      return localPosition;
    }
    // Fall back to track position
    return track.position;
  }

  /// Calculate available size for text wrapping
  Size _calculateAvailableSize(TextTrackModel track) {
    final boundaryBufferX = 10.0;
    final boundaryBufferY = 5.0;
    
    final availableWidth = widget.fixedCanvasSize.width - track.position.dx - boundaryBufferX;
    final availableHeight = widget.fixedCanvasSize.height - track.position.dy - boundaryBufferY;
    
    return Size(
      availableWidth.clamp(100.0, widget.fixedCanvasSize.width * 0.8),
      availableHeight.clamp(50.0, widget.fixedCanvasSize.height * 0.8),
    );
  }

  /// Calculate maximum line width using TextPainter
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

  /// Calculate wrapped text height
  double _calculateWrappedTextHeight(List<String> lines, TextStyle style) {
    if (lines.isEmpty) return 0;
    
    final textPainter = TextPainter(
      text: TextSpan(text: lines.first, style: style),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    final lineHeight = textPainter.height;
    textPainter.dispose();
    
    return lines.length * lineHeight;
  }

  CanvasTransform _getCanvasTransform() {
    // Calculate asset size and position relative to fixed canvas
    return _calculateFixedCanvasTransform();
  }

  /// Calculate transform for asset with overflow support on all sides
  CanvasTransform _calculateFixedCanvasTransform() {
    // Use the provider-calculated canvas properties, allowing overflow on all sides
    Size trackSize = widget.track.canvasSize;
    Offset trackPosition = widget.track.canvasPosition;

    // Allow asset size without constraints (overflow supported)
    Size boundedSize = _enforceCanvasBounds(trackSize, trackPosition);

    // Allow asset positioning anywhere (overflow supported)
    Offset boundedPosition = _enforcePositionBounds(trackPosition, boundedSize);
    
    // Safety checks for scale
    var safeScale = widget.track.canvasScale;
    if (!safeScale.isFinite || safeScale <= 0) {
      safeScale = 1.0;
    }

    // Allow overflow on all sides - no bounds enforcement needed
    final finalSize = boundedSize;  // No size validation (allows overflow)
    final finalPosition = boundedPosition;  // No position validation (allows overflow)

    // Log the final values
    print('   ✨ Final size: $finalSize (original: $trackSize) - overflow allowed');
    print('   ✨ Final position: $finalPosition (original: $trackPosition) - overflow allowed');
    print('   ✨ Visual clipping will handle any overflow via ClipRect');

    return CanvasTransform(
      position: finalPosition,
      size: finalSize,
      scale: safeScale,
      rotation: -widget.track.canvasRotation * (3.14159 / 180),
      cropRect: Rect.fromLTWH(
        widget.track.canvasCropRect.left,
        widget.track.canvasCropRect.top,
        widget.track.canvasCropRect.width,
        widget.track.canvasCropRect.height,
      ),
      opacity: widget.track.canvasOpacity,
    );
  }


  /// Allow asset size without canvas bounds restrictions (overflow allowed)
  Size _enforceCanvasBounds(Size requestedSize, Offset position) {
    // Allow any asset size - visual clipping will be handled by canvas renderer
    // Only enforce minimum size to prevent unusable assets
    final minSize = 10.0;
    return Size(
      math.max(requestedSize.width, minSize),
      math.max(requestedSize.height, minSize),
    );
  }

  /// Allow asset positioning anywhere (including outside canvas bounds)
  Offset _enforcePositionBounds(Offset requestedPosition, Size assetSize) {
    // Allow assets to be positioned anywhere - visual clipping handles bounds
    return requestedPosition;
  }

  // ============================================================================
  // SMOOTH DRAG SYSTEM - Advanced localDragPosition feedback
  // ============================================================================

  /// Create text tracks with both local drag positions and local rotation for smoother visual feedback
  /// This matches the pattern from optimized_preview_container.dart for smooth dragging
  List<TextTrackModel> _createTextTracksWithLocalPositions() {
    return widget.textTracks.map((track) {
      final localPosition = _localDragPositions[track.id];
      final isCurrentlyScaling = _scalingTrack?.id == track.id;
      final localRotation = isCurrentlyScaling ? _tempRotation : null;
      
      if (localPosition != null || localRotation != null) {
        // Return a copy with local changes for smooth visual feedback
        return track.copyWith(
          position: localPosition ?? track.position,
          rotation: localRotation ?? track.rotation,
        );
      }
      return track;
    }).toList();
  }

  /// Calculate accurate text dimensions for boundary validation - position-aware like rendering system
  Size _calculateTextDimensions(TextTrackModel track, {Offset? currentPosition}) {
    if (widget.fixedCanvasSize.isEmpty) return const Size(100.0, 30.0); // Safe fallback

    // Use canvas-aware font size calculation (same as rendering)
    final fontSize = _calculateCanvasFontSize(track.fontSize, widget.fixedCanvasSize);

    // Create text style for measurement (same as rendering)
    final textStyle = TextStyle(
      fontSize: fontSize,
      fontFamily: track.fontFamily,
      height: 1.0,
    );

    // ✅ FIX: Use position-aware available size calculation (same as CanvasTextOverlayPainter)
    final position = currentPosition ?? track.position;
    final availableSize = _calculateAvailableSizeForDrag(track, position, widget.fixedCanvasSize);

    // Use TextAutoWrapHelper.wrapTextToFit() with position-aware constraints (same as rendering)
    final wrappedLines = TextAutoWrapHelper.wrapTextToFit(
      track.text,
      availableSize.width,   // Dynamic width based on position
      availableSize.height,  // Dynamic height based on position
      textStyle,
    );
    
    // Calculate actual text dimensions
    double maxLineWidth = 0;
    double totalHeight = 0;
    
    for (final line in wrappedLines) {
      final textPainter = TextPainter(
        text: TextSpan(text: line, style: textStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      
      maxLineWidth = math.max(maxLineWidth, textPainter.width);
      totalHeight += textPainter.height;
      
      textPainter.dispose();
    }
    
    return Size(maxLineWidth, totalHeight);
  }

  /// Calculate available size for text wrapping - matches CanvasTextOverlayPainter logic
  Size _calculateAvailableSizeForDrag(TextTrackModel track, Offset position, Size canvasSize) {
    // Dynamic canvas-aware boundary calculation with proportional buffers (same as painter)
    final boundaryBufferX = canvasSize.width * 0.02; // 2% of canvas width
    final boundaryBufferY = canvasSize.height * 0.02; // 2% of canvas height

    // Calculate actual available space from text position to canvas edges (same as painter)
    final availableWidth = canvasSize.width - position.dx - boundaryBufferX;
    final availableHeight = canvasSize.height - position.dy - boundaryBufferY;

    // Dynamic minimum sizes based on canvas dimensions (same as painter)
    final minWidth = math.max(100.0, canvasSize.width * 0.15); // At least 15% of canvas width
    final minHeight = math.max(50.0, canvasSize.height * 0.1);  // At least 10% of canvas height

    // Use full available space instead of artificial constraint (same as painter)
    final finalWidth = math.max(availableWidth, minWidth);
    final finalHeight = math.max(availableHeight, minHeight);

    print('🔄 Dynamic available size calculation:');
    print('   Position: (${position.dx.toStringAsFixed(1)}, ${position.dy.toStringAsFixed(1)})');
    print('   Canvas size: ${canvasSize.width}x${canvasSize.height}');
    print('   Available space: ${availableWidth.toStringAsFixed(1)}x${availableHeight.toStringAsFixed(1)}');
    print('   Final size: ${finalWidth.toStringAsFixed(1)}x${finalHeight.toStringAsFixed(1)}');

    return Size(finalWidth, finalHeight);
  }

  /// Apply smooth boundary constraints to prevent text from leaving canvas
  Offset _applySmoothBoundaryConstraints(
    Offset newPosition,
    Offset currentPosition,
    Size textDimensions,
    double rotation,
  ) {
    // Canvas boundaries with padding
    const boundaryPadding = 5.0;
    final leftBound = boundaryPadding;
    final topBound = boundaryPadding;
    final rightBound = widget.fixedCanvasSize.width - textDimensions.width - boundaryPadding;
    final bottomBound = widget.fixedCanvasSize.height - textDimensions.height - boundaryPadding;
    
    // ✅ FIX: Handle rotation using accurate rotated bounds instead of conservative buffer
    if (rotation != 0) {
      // Calculate actual rotated bounds using TextRotationManager
      final rotatedBounds = TextRotationManager.calculateRotatedTextBounds(
        textWidth: textDimensions.width,
        textHeight: textDimensions.height,
        rotation: rotation,
      );

      // Use actual rotated dimensions for boundary calculation
      final rotatedWidth = rotatedBounds['width']!;
      final rotatedHeight = rotatedBounds['height']!;

      // Apply reasonable buffer (much smaller than before)
      final smartBuffer = 10.0; // Fixed 10px buffer instead of proportional

      // Calculate valid bounds using actual rotated dimensions
      final validLeftBound = leftBound + smartBuffer;
      final validTopBound = topBound + smartBuffer;
      final validRightBound = (widget.fixedCanvasSize.width - rotatedWidth - smartBuffer).clamp(validLeftBound, widget.fixedCanvasSize.width);
      final validBottomBound = (widget.fixedCanvasSize.height - rotatedHeight - smartBuffer).clamp(validTopBound, widget.fixedCanvasSize.height);

      print('🔄 Smart rotation boundary calculation:');
      print('   Text dimensions: ${textDimensions.width.toStringAsFixed(1)}x${textDimensions.height.toStringAsFixed(1)}');
      print('   Rotated bounds: ${rotatedWidth.toStringAsFixed(1)}x${rotatedHeight.toStringAsFixed(1)}');
      print('   Valid bounds: X(${validLeftBound.toStringAsFixed(1)} to ${validRightBound.toStringAsFixed(1)}), Y(${validTopBound.toStringAsFixed(1)} to ${validBottomBound.toStringAsFixed(1)})');

      return Offset(
        newPosition.dx.clamp(validLeftBound, validRightBound),
        newPosition.dy.clamp(validTopBound, validBottomBound),
      );
    }
    
    // Apply smooth clamping with easing at boundaries
    double constrainedX = newPosition.dx;
    double constrainedY = newPosition.dy;
    
    // X-axis boundary handling with smooth falloff
    if (newPosition.dx < leftBound) {
      final overshoot = leftBound - newPosition.dx;
      constrainedX = leftBound - overshoot * 0.1; // 10% of overshoot allowed
    } else if (newPosition.dx > rightBound) {
      final overshoot = newPosition.dx - rightBound;
      constrainedX = rightBound + overshoot * 0.1; // 10% of overshoot allowed
    }
    
    // Y-axis boundary handling with smooth falloff
    if (newPosition.dy < topBound) {
      final overshoot = topBound - newPosition.dy;
      constrainedY = topBound - overshoot * 0.1; // 10% of overshoot allowed
    } else if (newPosition.dy > bottomBound) {
      final overshoot = newPosition.dy - bottomBound;
      constrainedY = bottomBound + overshoot * 0.1; // 10% of overshoot allowed
    }
    
    // Final hard clamp to prevent text from completely leaving canvas
    constrainedX = constrainedX.clamp(leftBound - textDimensions.width * 0.5, rightBound + textDimensions.width * 0.5);
    constrainedY = constrainedY.clamp(topBound - textDimensions.height * 0.5, bottomBound + textDimensions.height * 0.5);
    
    return Offset(constrainedX, constrainedY);
  }

  /// Apply smooth easing for better visual feedback
  Offset _applySmoothEasing(Offset current, Offset target, double factor) {
    return Offset(
      current.dx + (target.dx - current.dx) * factor,
      current.dy + (target.dy - current.dy) * factor,
    );
  }

  /// Calculate canvas-aware font size using CanvasConfiguration
  double _calculateCanvasFontSize(double baseFontSize, Size canvasSize) {
    if (widget.canvasConfiguration != null) {
      // Use CanvasConfiguration for consistent dual canvas scaling
      // For preview, font size is based on preview canvas size
      final referenceWidth = 1920.0; // Reference width for scaling
      final previewCanvasSize = widget.canvasConfiguration!.previewCanvasSize;
      final scale = previewCanvasSize.width / referenceWidth;
      final scaledFontSize = baseFontSize * scale.clamp(0.5, 3.0);
      
      print('🔤 Font scaling with CanvasConfiguration:');
      print('   Base font size: $baseFontSize');
      print('   Preview canvas: ${previewCanvasSize.width}x${previewCanvasSize.height}');
      print('   Scale factor: ${scale.toStringAsFixed(3)} (${previewCanvasSize.width} / $referenceWidth)');
      print('   Scaled font size: $scaledFontSize');
      
      return scaledFontSize;
    } else {
      // Fallback to old method if no CanvasConfiguration provided
      final referenceWidth = 1920.0; // Reference width for scaling
      final scale = widget.fixedCanvasSize.width / referenceWidth;
      final scaledFontSize = baseFontSize * scale.clamp(0.5, 3.0);
      
      print('🔤 Font scaling (legacy fallback):');
      print('   Base font size: $baseFontSize');
      print('   Canvas size: ${widget.fixedCanvasSize.width}x${widget.fixedCanvasSize.height}');
      print('   Scale factor: ${scale.toStringAsFixed(3)}');
      print('   Scaled font size: $scaledFontSize');
      
      return scaledFontSize;
    }
  }

  /// Get canvas container fitting for coordinate mapping (similar to video container fitting)
  Map<String, double> _getCanvasContainerFitting() {
    return {
      'actualPreviewWidth': widget.fixedCanvasSize.width,
      'actualPreviewHeight': widget.fixedCanvasSize.height,
      'gapLeft': 0.0,
      'gapTop': 0.0,
    };
  }

  /// Convert preview coordinates to canvas coordinates
  Offset _previewToCanvasCoordinates(Offset previewOffset) {
    // Calculate preview scaling factor (minimal with dynamic canvas)
    final scaleX = widget.previewContainerSize.width / widget.fixedCanvasSize.width;
    final scaleY = widget.previewContainerSize.height / widget.fixedCanvasSize.height;
    final previewScale = math.min(scaleX, scaleY);
    
    // Calculate centering offset
    final actualCanvasSize = Size(
      widget.fixedCanvasSize.width * previewScale,
      widget.fixedCanvasSize.height * previewScale,
    );
    final offsetX = (widget.previewContainerSize.width - actualCanvasSize.width) / 2;
    final offsetY = (widget.previewContainerSize.height - actualCanvasSize.height) / 2;
    
    // Convert from preview space to canvas space
    final adjustedOffset = Offset(
      previewOffset.dx - offsetX,
      previewOffset.dy - offsetY,
    );
    
    return Offset(
      adjustedOffset.dx / previewScale,
      adjustedOffset.dy / previewScale,
    );
  }

  /// Convert canvas coordinates to preview coordinates
  Offset _canvasToPreviewCoordinates(Offset canvasOffset) {
    // Calculate preview scaling factor (minimal with dynamic canvas)
    final scaleX = widget.previewContainerSize.width / widget.fixedCanvasSize.width;
    final scaleY = widget.previewContainerSize.height / widget.fixedCanvasSize.height;
    final previewScale = math.min(scaleX, scaleY);
    
    // Calculate centering offset
    final actualCanvasSize = Size(
      widget.fixedCanvasSize.width * previewScale,
      widget.fixedCanvasSize.height * previewScale,
    );
    final offsetX = (widget.previewContainerSize.width - actualCanvasSize.width) / 2;
    final offsetY = (widget.previewContainerSize.height - actualCanvasSize.height) / 2;
    
    // Convert from canvas space to preview space
    final scaledOffset = Offset(
      canvasOffset.dx * previewScale,
      canvasOffset.dy * previewScale,
    );
    
    return Offset(
      scaledOffset.dx + offsetX,
      scaledOffset.dy + offsetY,
    );
  }

  // ============================================================================
  // UNIFIED GESTURE SYSTEM - Combines text and video interactions
  // ============================================================================

  /// Unified hit testing with priority system
  /// Priority: Text > Video Handles > Video Selection

  HitTestResult _unifiedHitTest(Offset position) {
    print('\n🔍 === HIT TEST START ===');
    print('🔍 Test position: (${position.dx.toStringAsFixed(2)}, ${position.dy.toStringAsFixed(2)})');
    print('🔍 Text tracks count: ${widget.textTracks.length}');

    // PRIORITY 1: Text tracks (highest priority)
    for (final track in widget.textTracks) {
      if (_isTrackVisible(track)) {
        final textBounds = _calculateTextBounds(track);
        print('🔍 Text track "${track.text.substring(0, math.min(20, track.text.length))}" bounds: ${textBounds}');
        if (textBounds.contains(position)) {
          print('🎯 Hit test: TEXT track "${track.text.substring(0, math.min(20, track.text.length))}"');
          return HitTestResult(
            type: HitType.text,
            textTrack: track,
            position: position,
          );
        }
      }
    }

    // PRIORITY 2: Video asset interaction (simplified - like text overlay pattern)
    final insideAsset = _manipulationHandler.isInsideTrack(widget.track, position);
    print('🔍 Inside asset check: $insideAsset');

    if (insideAsset) {
      print('🎯 Hit test: VIDEO DRAG (simplified - no selection state needed)');
      return HitTestResult(
        type: HitType.videoDrag,
        videoTrack: widget.track,
        position: position,
      );
    }

    // No hit detected
    print('🎯 Hit test: NO HIT - no valid interaction area found');
    return HitTestResult(type: HitType.none, position: position);
  }

  /// Unified tap down handler
  void _handleUnifiedTapDown(TapDownDetails details) {
    print('\n📟 === UNIFIED TAP DOWN ===');
    print('📟 Position: (${details.localPosition.dx.toStringAsFixed(2)}, ${details.localPosition.dy.toStringAsFixed(2)})');

    final hitResult = _unifiedHitTest(details.localPosition);
    print('📟 Hit result: ${hitResult.type}');

    // Asset selection on tap removed - handles only appear during drag like text overlays
    switch (hitResult.type) {
      case HitType.videoDrag:
        print('📱 Unified Tap: Asset drag area (tap only - no action needed)');
        break;
      default:
        print('📟 Tap not handled: ${hitResult.type}');
        break;
    }
  }

  /// Unified scale start handler
  void _handleUnifiedScaleStart(ScaleStartDetails details) {
    print('\n✋ ===== UNIFIED SCALE START CALLED =====');
    print('✋ THIS PROVES SCALE START IS BEING CALLED!');
    print('✋ Position: (${details.localFocalPoint.dx.toStringAsFixed(2)}, ${details.localFocalPoint.dy.toStringAsFixed(2)})');
    print('✋ Asset selected: ${widget.isSelected}');
    print('✋ Pointer count: ${details.pointerCount}');

    final hitResult = _unifiedHitTest(details.localFocalPoint);
    print('✋ Hit result: ${hitResult.type}');
    
    switch (hitResult.type) {
      case HitType.text:
        print('🖱️ Scale Start: Text track "${hitResult.textTrack?.text}"');
        _handleTextScaleStart(hitResult.textTrack!, details);
        break;

      case HitType.videoDrag:
        print('\n🚀 === ASSET DRAG START (TEXT OVERLAY PATTERN) ===');
        print('🚀 Position: (${details.localFocalPoint.dx.toStringAsFixed(2)}, ${details.localFocalPoint.dy.toStringAsFixed(2)})');
        print('🚀 Pointer count: ${details.pointerCount}');
        print('🚀 Asset ID: ${widget.track.id}');
        print('🚀 Current asset position: (${widget.track.canvasPosition.dx.toStringAsFixed(2)}, ${widget.track.canvasPosition.dy.toStringAsFixed(2)})');

        // Use internal state management like text overlays
        setState(() {
          _draggedAsset = widget.track; // Set drag state initially
          print('🚀 Asset manipulation state activated internally');
        });

        _manipulationHandler.startDrag(widget.track, details.localFocalPoint);

        // Initialize scale tracking for pinch gestures
        if (details.pointerCount > 1) {
          print('🚀 Multi-touch detected - initializing scale tracking');
          _manipulationHandler.startScale(widget.track, 1.0); // Initial scale is always 1.0
        }
        break;

      case HitType.videoRotationHandle:
        print('🖱️ Scale Start: Video rotation');
        _manipulationHandler.startRotation(widget.track, details.localFocalPoint);
        break;

      case HitType.videoResizeHandle:
        print('🖱️ Scale Start: Video resize (${hitResult.resizeHandle})');
        _manipulationHandler.startResize(widget.track, hitResult.resizeHandle!, details.localFocalPoint);
        break;

      default:
        print('❌ Scale Start: No valid target - hitResult.type: ${hitResult.type}');
        break;
    }
  }

  /// Unified scale update handler
  void _handleUnifiedScaleUpdate(ScaleUpdateDetails details) {
    print('\n🔄 === UNIFIED SCALE UPDATE === ${DateTime.now().millisecondsSinceEpoch}');
    print('🔄 Position: (${details.localFocalPoint.dx.toStringAsFixed(2)}, ${details.localFocalPoint.dy.toStringAsFixed(2)})');
    print('🔄 Scale: ${details.scale.toStringAsFixed(3)}');
    print('🔄 Text dragged: ${_draggedTrack?.id ?? "null"}');
    print('🔄 Text scaling: ${_scalingTrack?.id ?? "null"}');
    print('🔄 Asset dragged: ${_draggedAsset?.id ?? "null"}');
    print('🔄 Asset scaling: ${_scalingAsset?.id ?? "null"}');
    print('🔄 Current track ID: ${widget.track.id}');
    print('🔄 Track match (drag): ${_draggedAsset?.id == widget.track.id}');
    print('🔄 Track match (scale): ${_scalingAsset?.id == widget.track.id}');
    print('🔄 Manipulation handler manipulating: ${_manipulationHandler.isManipulating}');
    print('🔄 Manipulation mode: ${_manipulationHandler.currentMode}');

    // Handle text interactions (keep working)
    if (_draggedTrack != null || _scalingTrack != null) {
      print('🔄 Handling text interaction');
      _handleTextScaleUpdate(details);
      return;
    }

    // Handle asset manipulation (using internal state with track-specific validation)
    if ((_draggedAsset != null && _draggedAsset!.id == widget.track.id) ||
        (_scalingAsset != null && _scalingAsset!.id == widget.track.id)) {
      print('🔄 Handling asset manipulation (track-specific: ${widget.track.id})');

      // Detect if this is a scaling gesture vs drag gesture
      final isScaling = (details.scale - 1.0).abs() > 0.01 && details.scale != 1.0;
      final isDragging = details.focalPointDelta.distance > 1.0 && !isScaling;

      print('🔄 Gesture type: ${isScaling ? "SCALING" : isDragging ? "DRAGGING" : "UNKNOWN"}, scale: ${details.scale.toStringAsFixed(3)}');

      // Switch to scaling state if scaling is detected
      if (isScaling && _draggedAsset != null && _scalingAsset == null) {
        setState(() {
          _scalingAsset = _draggedAsset;
          _draggedAsset = null;
          print('🔄 Switched from drag to scale state');
        });
      }

      if (isScaling && _scalingAsset != null) {
        // Handle pinch scaling
        print('🔄 Asset pinch scaling - scale: ${details.scale.toStringAsFixed(3)}');
        _manipulationHandler.handlePinchScale(details.scale);
      } else if (isDragging || _manipulationHandler.currentMode == ManipulationMode.drag) {
        // Handle drag movement (existing logic)
        final position = details.localFocalPoint;
        switch (_manipulationHandler.currentMode) {
          case ManipulationMode.drag:
            print('🔄 Calling updateDrag (track-specific)');
            _manipulationHandler.updateDrag(position);
            break;
          case ManipulationMode.resize:
            print('🔄 Calling updateResize (track-specific)');
            _manipulationHandler.updateResize(position);
            break;
          case ManipulationMode.rotate:
            print('🔄 Calling updateRotation (track-specific)');
            _manipulationHandler.updateRotation(position);
            break;
          default:
            break;
        }
      }
      return;
    }

    // No manipulation active - ignore (internal state handles everything like text overlay)
    print('🔄 No active manipulation (internal state pattern - no fallback needed)');
  }

  /// Unified scale end handler
  void _handleUnifiedScaleEnd(ScaleEndDetails details) {
    print('\n🏁 === UNIFIED SCALE END ===');
    print('🏁 Text dragged: ${_draggedTrack?.id ?? "null"}');
    print('🏁 Text scaling: ${_scalingTrack?.id ?? "null"}');
    print('🏁 Asset dragged: ${_draggedAsset?.id ?? "null"}');
    print('🏁 Asset scaling: ${_scalingAsset?.id ?? "null"}');
    print('🏁 Manipulation handler manipulating: ${_manipulationHandler.isManipulating}');

    // Handle text interactions (keep working)
    if (_draggedTrack != null || _scalingTrack != null) {
      print('🏁 Ending text interaction');
      _handleTextScaleEnd();
      return;
    }

    // Handle asset manipulation state cleanup
    if (_draggedAsset != null || _scalingAsset != null) {
      print('🏁 Ending asset manipulation state');
      setState(() {
        _draggedAsset = null;
        _scalingAsset = null;
        print('🔚 Asset manipulation state deactivated internally');
      });
    }

    // Handle video manipulation cleanup
    if (_manipulationHandler.isManipulating) {
      print('🏁 Ending video manipulation');
      _manipulationHandler.endManipulation();
    } else {
      print('🏁 No manipulation to end');
    }
  }

  // Text-specific scale gesture handlers
  void _handleTextScaleStart(TextTrackModel track, ScaleStartDetails details) {
    print('=== Enhanced Text Scale Start ===');
    print('Starting scale for track: "${track.text.substring(0, math.min(20, track.text.length))}"');
    print('Scale center: (${details.localFocalPoint.dx}, ${details.localFocalPoint.dy})');
    print('Track position: (${track.position.dx}, ${track.position.dy})');
    print('Track rotation: ${track.rotation}°');
    
    setState(() {
      _draggedTrack = track;
      _scalingTrack = track;
      
      // ✅ FIX: Simplified position calculation - use stored visual position directly
      // Since we now store visual positions, no complex rotation adjustments needed
      final initialDragPosition = track.position; // Use stored position directly

      print('✅ Simplified position calculation:');
      print('   Using stored visual position: (${initialDragPosition.dx}, ${initialDragPosition.dy})');
      print('   Track rotation: ${track.rotation}°');

      // Initialize local drag position with the stored visual position
      _localDragPositions[track.id] = initialDragPosition;
      
      print('Local drag position initialized: (${initialDragPosition.dx}, ${initialDragPosition.dy})');
    });
  }

  void _handleTextScaleUpdate(ScaleUpdateDetails details) {
    if (_draggedTrack == null) return;
    
    final trackId = _draggedTrack!.id;
    final currentLocalPosition = _localDragPositions[trackId] ?? _draggedTrack!.position;
    
    print('=== Enhanced Scale Update Debug ===');
    print('Track: "${_draggedTrack!.text.substring(0, math.min(10, _draggedTrack!.text.length))}"');
    print('Focal point delta: (${details.focalPointDelta.dx}, ${details.focalPointDelta.dy})');
    print('Current local position: (${currentLocalPosition.dx}, ${currentLocalPosition.dy})');
    
    // Handle dragging (single finger or focal point movement) with smooth feedback
    if (details.focalPointDelta.distance > 0.1) {
      print('=== Handling Smooth Drag ===');
      
      // Calculate new position using focal point delta
      final newPosition = Offset(
        currentLocalPosition.dx + details.focalPointDelta.dx,
        currentLocalPosition.dy + details.focalPointDelta.dy,
      );
      
      // Get accurate text dimensions for boundary calculation using current position
      final textDimensions = _calculateTextDimensions(_draggedTrack!, currentPosition: newPosition);
      print('Text dimensions: ${textDimensions.width} x ${textDimensions.height}');
      
      // Apply smooth boundary constraints
      final validatedPosition = _applySmoothBoundaryConstraints(
        newPosition,
        currentLocalPosition,
        textDimensions,
        _draggedTrack!.rotation,
      );
      
      // Apply smooth easing for better visual feedback (80% interpolation)
      final smoothedPosition = _applySmoothEasing(
        currentLocalPosition,
        validatedPosition,
        0.8, // 80% of the way to target for smooth movement
      );
      
      print('New position: (${newPosition.dx}, ${newPosition.dy})');
      print('Validated position: (${validatedPosition.dx}, ${validatedPosition.dy})');
      print('Smoothed position: (${smoothedPosition.dx}, ${smoothedPosition.dy})');
      
      // Store local position for smooth dragging and trigger immediate repaint
      _localDragPositions[trackId] = smoothedPosition;
      setState(() {}); // Immediate smooth visual feedback
    }
    
    // Handle rotation (two finger gesture) with enhanced smoothing
    if (details.rotation.abs() > 0.01) {
      print('=== Handling Rotation ===');
      final currentRotation = _draggedTrack!.rotation;
      final rotationDelta = details.rotation * 180 / math.pi;
      final newRotation = (currentRotation + rotationDelta) % 360;
      
      print('Rotation delta: ${rotationDelta.toStringAsFixed(1)}°');
      print('New rotation: ${newRotation.toStringAsFixed(1)}°');
      
      // Apply smooth rotation with immediate visual feedback
      setState(() {
        _tempRotation = newRotation;
      });
      
      // Throttle provider updates to avoid overwhelming the system (60fps)
      _throttleTimer?.cancel();
      _throttleTimer = Timer(const Duration(milliseconds: 16), () {
        if (_draggedTrack != null) {
          final updatedTrack = _draggedTrack!.copyWith(rotation: newRotation);
          final trackIndex = widget.textTracks.indexWhere((track) => track.id == trackId);
          if (trackIndex >= 0 && widget.onTextTrackUpdate != null) {
            widget.onTextTrackUpdate!(trackIndex, updatedTrack);
            print('Rotation committed to provider: ${newRotation.toStringAsFixed(1)}°');
          }
        }
      });
    }
    
    print('=== End Enhanced Scale Update Debug ===');
  }

  void _handleTextScaleEnd() {
    if (_draggedTrack == null) {
      print('=== Scale End: No dragged track ===');
      return;
    }
    
    final trackId = _draggedTrack!.id;
    final finalPosition = _localDragPositions[trackId] ?? _draggedTrack!.position;
    
    // Get final rotation from tempRotation if available
    final finalRotation = _tempRotation ?? _draggedTrack!.rotation;
    
    print('=== Enhanced Text Scale End ===');
    print('Ending scale for track: "${_draggedTrack!.text.substring(0, math.min(20, _draggedTrack!.text.length))}"');
    print('Final local position: (${finalPosition.dx}, ${finalPosition.dy})');
    print('Original track position: (${_draggedTrack!.position.dx}, ${_draggedTrack!.position.dy})');
    print('Final rotation: ${finalRotation.toStringAsFixed(1)}°');
    print('Original track rotation: ${_draggedTrack!.rotation.toStringAsFixed(1)}°');
    print('Temp rotation during gesture: ${_tempRotation?.toStringAsFixed(1) ?? "null"}°');
    
    // Check if position or rotation changed
    final positionChanged = (finalPosition - _draggedTrack!.position).distance > 1.0; // 1px threshold
    final rotationChanged = (_tempRotation != null) && 
                           ((_tempRotation! - _draggedTrack!.rotation).abs() > 1.0); // 1 degree threshold
    
    // Commit BOTH position and rotation changes if either changed
    if ((positionChanged || rotationChanged) && widget.onTextTrackUpdate != null) {
      final trackIndex = widget.textTracks.indexWhere((track) => track.id == trackId);
      if (trackIndex >= 0) {
        // Calculate the visual position that should be stored
        Offset visualPosition = finalPosition;

        // If rotation changed, calculate the final visual position after rotation
        if (rotationChanged && finalRotation != 0) {
          // Get text dimensions for visual position calculation
          final fontSize = _calculateCanvasFontSize(_draggedTrack!.fontSize, widget.fixedCanvasSize);
          final textStyle = TextStyle(
            fontSize: fontSize,
            fontFamily: _draggedTrack!.fontFamily,
          );

          // Get wrapped lines and calculate dimensions
          final wrappedLines = TextAutoWrapHelper.wrapText(
            _draggedTrack!.text,
            widget.fixedCanvasSize.width * 0.8, // Max width
            textStyle,
          );

          final textWidth = _calculateMaxLineWidth(wrappedLines, textStyle);
          final textHeight = _calculateWrappedTextHeight(wrappedLines, textStyle);

          // Calculate drag offset from original position
          final dragOffset = finalPosition - _draggedTrack!.position;

          // Calculate the final visual position using TextRotationManager
          visualPosition = TextRotationManager.calculateFinalVisualPosition(
            basePosition: _draggedTrack!.position,
            dragOffset: dragOffset,
            textWidth: textWidth,
            textHeight: textHeight,
            rotation: finalRotation,
          );

          print('Visual position calculation:');
          print('  Original position: ${_draggedTrack!.position}');
          print('  Final position: $finalPosition');
          print('  Drag offset: $dragOffset');
          print('  Text dimensions: ${textWidth}x$textHeight');
          print('  Final rotation: ${finalRotation.toStringAsFixed(1)}°');
          print('  Calculated visual position: $visualPosition');
        }

        final updatedTrack = _draggedTrack!.copyWith(
          position: visualPosition, // Use visual position instead of raw final position
          rotation: finalRotation, // Include final rotation
          updateTimestamp: true, // Mark as modified
        );
        
        print('Committing changes to provider: index=$trackIndex');
        if (positionChanged) {
          print('Position changed by: (${(finalPosition - _draggedTrack!.position).dx}, ${(finalPosition - _draggedTrack!.position).dy})');
        }
        if (rotationChanged) {
          print('Rotation changed by: ${(finalRotation - _draggedTrack!.rotation).toStringAsFixed(1)}° (${_draggedTrack!.rotation.toStringAsFixed(1)}° → ${finalRotation.toStringAsFixed(1)}°)');
        }
        
        widget.onTextTrackUpdate!(trackIndex, updatedTrack);
      } else {
        print('Warning: Track not found in widget.textTracks list');
      }
    } else if (!positionChanged && !rotationChanged) {
      print('Neither position nor rotation changed, skipping provider update');
    } else {
      print('Warning: No onTextTrackUpdate callback provided');
    }
    
    // Clean up all timers and temporary state
    _throttleTimer?.cancel();
    _throttleTimer = null;
    
    // Clear local drag state for this track
    _localDragPositions.remove(trackId);
    
    // Reset all drag and scale state
    setState(() {
      _draggedTrack = null;
      _scalingTrack = null;
      _tempRotation = null;
    });
    
    print('Scale end cleanup complete');
  }

  /// Build debug overlay showing canvas and container dimensions
  Widget _buildDebugOverlay() {
    final scaleX = widget.previewContainerSize.width / widget.fixedCanvasSize.width;
    final scaleY = widget.previewContainerSize.height / widget.fixedCanvasSize.height;
    final previewScale = math.min(scaleX, scaleY);
    final actualCanvasSize = Size(
      widget.fixedCanvasSize.width * previewScale,
      widget.fixedCanvasSize.height * previewScale,
    );

    return Positioned(
      top: 10,
      left: 10,
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Canvas Debug Info',
              style: TextStyle(
                color: Colors.yellow,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Container: ${widget.previewContainerSize.width.toStringAsFixed(1)} x ${widget.previewContainerSize.height.toStringAsFixed(1)}',
              style: TextStyle(color: Colors.white, fontSize: 10),
            ),
            Text(
              'Fixed Canvas: ${widget.fixedCanvasSize.width} x ${widget.fixedCanvasSize.height}',
              style: TextStyle(color: Colors.white, fontSize: 10),
            ),
            Text(
              'Actual Canvas: ${actualCanvasSize.width.toStringAsFixed(1)} x ${actualCanvasSize.height.toStringAsFixed(1)}',
              style: TextStyle(color: Colors.white, fontSize: 10),
            ),
            Text(
              'Preview Scale: ${previewScale.toStringAsFixed(3)}',
              style: TextStyle(color: Colors.white, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // ZOOM AND PAN GESTURE HANDLERS
  // ============================================================================

  // Removed conflicting canvas zoom gesture handlers
  // These were interfering with asset manipulation gestures

  // void _handleScaleStart(ScaleStartDetails details) {
  //   if (widget.zoomController == null) return;

  //   print('🔍 Scale gesture started at ${details.focalPoint}');
  //   widget.zoomController!.startGesture(
  //     details.focalPoint,
  //     widget.zoomController!.zoomScale,
  //   );
  // }

  // void _handleScaleUpdate(ScaleUpdateDetails details) {
  //   if (widget.zoomController == null) return;

  //   final isZooming = (details.scale - 1.0).abs() > 0.01; // Zoom threshold
  //   final isPanning = details.focalPointDelta.distance > 1.0; // Pan threshold

  //   print('🔍 Scale gesture update - Scale: ${details.scale.toStringAsFixed(3)}, '
  //         'Pan Delta: ${details.focalPointDelta}, Zooming: $isZooming, Panning: $isPanning');

  //   widget.zoomController!.updateGesture(
  //     scaleChange: isZooming ? details.scale : null,
  //     panDelta: isPanning ? details.focalPointDelta : null,
  //     focalPoint: details.focalPoint,
  //   );
  // }

  // void _handleScaleEnd(ScaleEndDetails details) {
  //   if (widget.zoomController == null) return;

  //   print('🔍 Scale gesture ended');
  //   widget.zoomController!.endGesture();
  // }
}

/// Custom painter for rendering images with crop
class _ImagePainter extends CustomPainter {
  final ui.Image image;
  final Rect cropRect;
  final bool treatAsNewAsset;

  _ImagePainter({
    required this.image,
    required this.cropRect,
    this.treatAsNewAsset = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate source rect from crop
    final sourceRect = Rect.fromLTWH(
      image.width * cropRect.left,
      image.height * cropRect.top,
      image.width * cropRect.width,
      image.height * cropRect.height,
    );
    
    // Destination rect is the full size
    final destRect = Rect.fromLTWH(0, 0, size.width, size.height);
    
    // Draw the cropped image
    canvas.drawImageRect(
      image,
      sourceRect,
      destRect,
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(_ImagePainter oldDelegate) {
    return oldDelegate.image != image || oldDelegate.cropRect != cropRect;
  }
}


