// video_editor_page.dart
import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;
import 'package:ai_video_creator_editor/utils/functions.dart';
import 'package:ai_video_creator_editor/components/crop/crop_grid.dart';
import 'package:ai_video_creator_editor/constants/colors.dart';
import 'package:ai_video_creator_editor/constants/extensions.dart';
import 'package:ai_video_creator_editor/controllers/video_controller.dart';
import 'package:ai_video_creator_editor/screens/project/models/video_track_model.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/audio_time_line.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/crop_page.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/file_reordering.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/speed_control.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/text_overlay.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/text_overlay_manager.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/text_time_line.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/text_style_editor.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/transition_picker.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/video_time_line.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/video_editor_provider.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/video_export_manager.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/canvas/media_canvas_renderer.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/canvas/transition_aware_canvas_renderer.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/canvas/media_manipulation_handler.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/canvas_configuration.dart';
import 'package:ai_video_creator_editor/enums/track_type.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/video_rotation_control.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/volume_control.dart';
import 'package:ai_video_creator_editor/screens/project/projects.dart';
import 'package:ai_video_creator_editor/utils/permissions.dart';
import 'package:ai_video_creator_editor/utils/helpers.dart';
import 'package:ai_video_creator_editor/utils/text_auto_wrap_helper.dart';
import 'package:ai_video_creator_editor/utils/unified_coordinate_system.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lazy_load_scrollview/lazy_load_scrollview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'dart:async';
import '../../../components/file_image_viewer.dart';
import '../../../controllers/assets_controller.dart';
import '../../tools/simple_video_result.dart';
import 'audio_pick.dart';
import 'caption_editor.dart';
import 'crop_view.dart';
import 'custom_trim_slider.dart';
import 'export_progress_dialog.dart';
import 'filter_picker.dart';
import 'package:ai_video_creator_editor/utils/uploads.dart';
import 'package:ai_video_creator_editor/screens/project/editor_controller.dart';
import 'package:ai_video_creator_editor/screens/project/models/text_track_model.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/canvas/optimized_preview_container.dart';

enum CanvasRatio {
  RATIO_16_9('16:9', 16.0 / 9.0),
  RATIO_9_16('9:16', 9.0 / 16.0),
  RATIO_4_3('4:3', 4.0 / 3.0),
  RATIO_3_4('3:4', 3.0 / 4.0),
  RATIO_1_1('1:1', 1.0 / 1.0);

  const CanvasRatio(this.displayName, this.aspectRatio);
  final String displayName;
  final double aspectRatio;

  /// Calculate optimal canvas size that fits within the container while maintaining aspect ratio
  Size getOptimalCanvasSize(Size containerSize) {
    return calculateOptimalCanvasSize(containerSize, aspectRatio);
  }

  /// Legacy compatibility for existing getSize calls - now uses dynamic calculation
  Size getSize(double baseWidth) {
    final baseHeight = baseWidth / aspectRatio;
    return Size(baseWidth, baseHeight);
  }

  /// Get fixed size for export (high resolution)
  Size get exportSize {
    switch (this) {
      case RATIO_16_9:
        return const Size(1920, 1080);
      case RATIO_9_16:
        return const Size(1080, 1920);
      case RATIO_4_3:
        return const Size(1440, 1080);
      case RATIO_3_4:
        return const Size(1080, 1440);
      case RATIO_1_1:
        return const Size(1080, 1080);
    }
  }
}

/// Calculate optimal canvas size that fits within container while maintaining aspect ratio
Size calculateOptimalCanvasSize(Size containerSize, double aspectRatio) {
  // Safety checks
  if (containerSize.width <= 0 ||
      containerSize.height <= 0 ||
      !aspectRatio.isFinite ||
      aspectRatio <= 0) {
    return const Size(400, 300); // Safe fallback
  }

  final containerAspect = containerSize.width / containerSize.height;

  if (aspectRatio > containerAspect) {
    // Canvas is wider than container - fit to container width
    final width = containerSize.width;
    final height = width / aspectRatio;
    return Size(width, height);
  } else {
    // Canvas is taller than container - fit to container height
    final height = containerSize.height;
    final width = height * aspectRatio;
    return Size(width, height);
  }
}

class VideoEditorPage extends StatefulWidget {
  const VideoEditorPage({super.key});

  @override
  State<VideoEditorPage> createState() => _VideoEditorPageState();
}

class _VideoEditorPageState extends State<VideoEditorPage> {
  bool isOriginalMuted = false;
  final GlobalKey _previewContainerKey = GlobalKey();
  final GlobalKey _canvasKey = GlobalKey();
  bool _isRotating = false;
  Size? _measuredContainerSize; // Store the actual measured container size

  // Timeline dragging state
  bool _isDraggingTimeline = false;
  double? _lastPanPosition;
  bool _isTrackBeingManipulated =
      false; // Track if individual track is being manipulated

  // Global key for timeline gesture detector to enable delegation
  final GlobalKey _timelineGestureKey = GlobalKey();

  @override
  void initState() {
    super.initState();
  }

  @override
  void deactivate() {
    Provider.of<AssetController>(context, listen: false).selectedMediaFiles =
        [];
    super.deactivate();
  }

  @override
  void dispose() {
    // Perform canvas cleanup if widget is disposed without going through WillPopScope
    // This handles cases like programmatic navigation or system-level disposal
    _performCanvasCleanup().catchError((e) {
      print('Error during dispose cleanup: $e');
      // Don't block disposal on cleanup errors
    });
    super.dispose();
  }

  /// Calculate total timeline container height based on current track states
  double _calculateTimelineContainerHeight(VideoEditorProvider provider) {
    const double basePadding = 8.0; // vertical padding (4px top + 4px bottom)
    const double videoTimelineHeight = 60.0;
    const double gapBetweenTimelines = 20.0;

    // Calculate audio timeline height
    final audioActiveLanes = provider.getActiveLaneCount(TrackType.audio);
    final audioHeight = provider.isEditingTrackType(TrackType.audio)
        ? audioActiveLanes * 30.0 // Edit mode: 30px per lane
        : 40.0; // Normal mode: fixed 40px

    // Calculate text timeline height
    final textActiveLanes = provider.getActiveLaneCount(TrackType.text);
    final textHeight = provider.isEditingTrackType(TrackType.text)
        ? textActiveLanes * 30.0 // Edit mode: 30px per lane
        : 40.0; // Normal mode: fixed 40px

    // Total: padding + video + gap + audio + gap + text
    return basePadding +
        videoTimelineHeight +
        gapBetweenTimelines +
        audioHeight +
        gapBetweenTimelines +
        textHeight;
  }

  @override
  Widget build(BuildContext context_) {
    final buildContext = context_; // Capture the build context

    return WillPopScope(
      onWillPop: () async {
        bool value = await showAdaptiveDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: const Text("Close Project"),
                  content: const Text(
                    "Are you sure you want to close project,",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("Close"),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Continue editing"),
                    ),
                  ],
                );
              },
            ) ??
            false;

        // If user chose to close, perform canvas cleanup
        if (value) {
          try {
            // Show brief loading indicator during cleanup
            if (context.mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            // Perform lightweight canvas cleanup
            await _performCanvasCleanup();

            // Close loading indicator
            if (context.mounted) {
              Navigator.pop(context);
            }
          } catch (e) {
            // Close loading indicator on error
            if (context.mounted) {
              Navigator.pop(context);
            }
            print('Cleanup error during project close: $e');
            // Continue with navigation even if cleanup fails
          }
        }

        return value;
      },
      child: Consumer<VideoEditorProvider>(
        builder: (ctx, provider, child) => Stack(
          children: [
            Scaffold(
              resizeToAvoidBottomInset: false,
              backgroundColor: Colors.black,
              appBar: provider.isEditingTrack
                  ? null
                  : AppBar(
                      backgroundColor: Colors.black,
                      leading: BackButton(),
                      actions: [
                        Consumer<VideoEditorProvider>(
                          builder: (context, provider, child) {
                            if (provider.selectedMediaId != null) {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Reset transformation - Hidden as requested
                                  // IconButton(
                                  //   icon: const Icon(Icons.restore,
                                  //       color: Colors.white),
                                  //   tooltip: 'Reset Transform',
                                  //   onPressed: () =>
                                  //       provider.resetTrackCanvasTransform(
                                  //           provider.selectedMediaId!),
                                  // ),
                                  // Deselect media - Removed as requested
                                  // IconButton(
                                  //   icon: const Icon(Icons.clear,
                                  //       color: Colors.white),
                                  //   tooltip: 'Exit Canvas Mode',
                                  //   onPressed: () => provider
                                  //       .selectMediaForManipulation(null),
                                  // ),
                                ],
                              );
                            }
                            return SizedBox.shrink();
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                              right: 16.0, top: 4.0, bottom: 4.0),
                          child: ElevatedButton(
                            onPressed: () => _exportVideo(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              // const Color.fromARGB(255, 46, 151, 158),
                              foregroundColor:
                                  const Color.fromARGB(255, 0, 0, 0),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            child: const Text('Done'),
                          ),
                        ),
                      ],
                    ),
              body: Material(
                color: Colors.transparent,
                child: Stack(
                  children: [
                    ImageFiltered(
                      imageFilter: provider.loading
                          ? ImageFilter.blur(sigmaX: 3, sigmaY: 3)
                          : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                      child: SafeArea(
                        child: Column(
                          children: [
                            Expanded(child: _buildVideoPreview()),
                            Container(
                              margin: EdgeInsets.all(5),
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(8),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatDuration(provider.videoPosition),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    " | ",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(provider.videoDuration),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Consumer<VideoEditorProvider>(
                              builder: (context, provider, child) {
                                final timelineHeight =
                                    _calculateTimelineContainerHeight(provider);

                                return Container(
                                  margin: EdgeInsets.symmetric(vertical: 30),
                                  height: timelineHeight,
                                  child: child,
                                );
                              },
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Draggable timeline container with improved gesture detection
                                  Positioned.fill(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior
                                          .opaque, // Changed to opaque for better capture
                                      onTap: () {
                                        // Tap anywhere on timeline to exit edit mode
                                        final provider =
                                            context.read<VideoEditorProvider>();
                                        if (provider.isEditingTrack) {
                                          provider.exitEditMode();
                                          HapticFeedback.lightImpact();
                                        }
                                      },
                                      onPanStart: _onTimelinePanStart,
                                      onPanUpdate: _onTimelinePanUpdate,
                                      onPanEnd: _onTimelinePanEnd,
                                      child: Container(
                                        color: Colors
                                            .transparent, // Ensure it captures all gestures
                                      ),
                                    ),
                                  ),
                                  // Timeline content - intercept taps for exit, allow drags for trim
                                  Consumer<VideoEditorProvider>(
                                    builder: (context, provider, child) {
                                      return GestureDetector(
                                        // ✅ Intercept taps to exit edit/reorder mode, let drags pass through to children
                                        behavior: HitTestBehavior.translucent,
                                        onTap: () {
                                          if (provider.isEditingTrack) {
                                            provider.exitEditMode();
                                            HapticFeedback.lightImpact();
                                          } else if (provider.isReorderMode) {
                                            provider.finalizeReorder();
                                            provider.exitReorderMode();
                                            HapticFeedback.lightImpact();
                                          }
                                        },
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                              vertical: 4.0),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              _buildVideoTimelineEditor(),
                                              SizedBox(height: 10),
                                              _buildAudioTimelineEditor(),
                                              SizedBox(height: 10),
                                              _buildTextTimelineEditor(),
                                              // SizedBox(height: 10),
                                              // _buildScrollableSpaceBelow(),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                  Align(
                                    alignment: Alignment.center,
                                    child: Container(
                                      width: 2,
                                      height: double.maxFinite,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildToolbar(),
                          ],
                        ),
                      ),
                    ),
                    if (provider.textFieldVisibility)
                      Positioned(
                        right: 5,
                        left: 5,
                        bottom: MediaQuery.of(context).viewInsets.bottom + 5,
                        child: Row(
                          spacing: 10,
                          children: [
                            Expanded(
                              child: TextField(
                                autofocus: true,
                                controller: provider.textEditingController,
                                onChanged: (value) =>
                                    provider.toggleSendButtonVisibility(
                                  value.isNotEmpty,
                                ),
                                style: TextStyle(color: Colors.black),
                                decoration: InputDecoration(
                                  hintText: "Type here...",
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      width: 2,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      width: 2,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                provider.addText(context);
                              },
                              child: CircleAvatar(
                                backgroundColor: Colors.white,
                                child: Icon(
                                  provider.sendButtonVisibility
                                      ? Icons.check_rounded
                                      : Icons.close,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (provider.loading)
                      const Center(
                        child: CupertinoActivityIndicator(radius: 30.0),
                      ),
                  ],
                ),
              ),
            ),
            if (provider.loading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: CupertinoActivityIndicator(radius: 30.0),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(double? seconds) {
    final duration = Duration(seconds: seconds?.round() ?? 0);
    return '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  List<Widget> _buildFixedBoundsTextOverlays(
    VideoEditorProvider provider,
    double containerWidth,
    double containerHeight,
  ) {
    print('=== _buildFixedBoundsTextOverlays START ===');
    print('Container dimensions: ${containerWidth}x${containerHeight}');

    // Define preview dimensions for font scaling
    final videoSize = provider.videoEditorController?.video.value.size;
    double videoHeight = videoSize?.height ?? 1080.0;
    double videoWidth = videoSize?.width ?? 1920.0;
    double previewHeight = provider.previewHeight ?? 400.0;
    double previewWidth = MediaQuery.of(context).size.width;

    if (provider.videoEditorController?.video.value.isInitialized != true) {
      print('Video not initialized, returning empty list');
      return [];
    }

    final currentPosition =
        provider.videoEditorController!.video.value.position.inMilliseconds;
    print('Current video position: ${currentPosition}ms');
// not working anymore
    final visibleTracks = provider.textTracks.where((track) {
      final startTime = track.trimStartTime * 1000;
      final endTime = track.trimEndTime * 1000;
      final isVisible =
          currentPosition >= startTime && currentPosition < endTime;
      print(
          'Track "${track.text}": start=${startTime}ms, end=${endTime}ms, visible=$isVisible');
      return isVisible;
    });

    print(
        'Total text tracks: ${provider.textTracks.length}, Visible tracks: ${visibleTracks.length}');

    final cropRect = provider.cropRect;

    print(
        'Crop rect: ${cropRect != null ? '(${cropRect.left}, ${cropRect.top}, ${cropRect.right}, ${cropRect.bottom})' : 'null'}');
    print(
        'Video size: ${videoSize != null ? '${videoSize.width}x${videoSize.height}' : 'null'}');

    if (cropRect != null && videoSize != null) {
      print('--- CROP APPLIED ---');
      // --- Crop is applied ---

      // First, calculate how the original video is displayed (same as no-crop)
      final videoAspectRatio = videoSize.width / videoSize.height;
      final containerAspectRatio = containerWidth / containerHeight;

      double actualPreviewWidth,
          actualPreviewHeight,
          gapLeft = 0.0,
          gapTop = 0.0;
      if (videoAspectRatio > containerAspectRatio) {
        // Original video is wider - fit width, letterbox top/bottom
        actualPreviewWidth = containerWidth;
        actualPreviewHeight = containerWidth / videoAspectRatio;
        gapTop = (containerHeight - actualPreviewHeight) / 2.0;
        print('Original video wider: fit width, letterbox top/bottom');
      } else {
        // Original video is taller - fit height, letterbox left/right
        actualPreviewHeight = containerHeight;
        actualPreviewWidth = containerHeight * videoAspectRatio;
        gapLeft = (containerWidth - actualPreviewWidth) / 2.0;
        print('Original video taller: fit height, letterbox left/right');
      }

      print(
          'Original video display area: ${actualPreviewWidth}x${actualPreviewHeight}');
      print('Original gap offsets: gapLeft=$gapLeft, gapTop=$gapTop');

      // Now use ONLY the original video display area as the container for the cropped video
      // This means the cropped video is constrained to the same area where original video was shown
      final cropAspectRatio = cropRect.width / cropRect.height;
      final videoDisplayAspectRatio = actualPreviewWidth / actualPreviewHeight;

      double croppedPreviewWidth,
          croppedPreviewHeight,
          croppedGapLeft = 0.0,
          croppedGapTop = 0.0;
      if (cropAspectRatio > videoDisplayAspectRatio) {
        // Crop is wider than video display area: fit width, letterbox top/bottom within video area
        croppedPreviewWidth = actualPreviewWidth;
        croppedPreviewHeight = actualPreviewWidth / cropAspectRatio;
        croppedGapTop = (actualPreviewHeight - croppedPreviewHeight) / 2.0;
        print(
            'Crop wider than video display: fit width, letterbox top/bottom within video area');
      } else {
        // Crop is taller than video display area: fit height, letterbox left/right within video area
        croppedPreviewHeight = actualPreviewHeight;
        croppedPreviewWidth = actualPreviewHeight * cropAspectRatio;
        croppedGapLeft = (actualPreviewWidth - croppedPreviewWidth) / 2.0;
        print(
            'Crop taller than video display: fit height, letterbox left/right within video area');
      }

      // Final position within the original video display area (not the full container)
      final finalGapLeft = gapLeft + croppedGapLeft;
      final finalGapTop = gapTop + croppedGapTop;

      print(
          'Cropped video display area: ${croppedPreviewWidth}x${croppedPreviewHeight}');
      print(
          'Final gap offsets: finalGapLeft=$finalGapLeft, finalGapTop=$finalGapTop');
      print('Cropped video is constrained to original video display area only');

      // Step 4: Map overlay positions
      return visibleTracks
          .map((track) {
            print('--- Processing track: "${track.text}" ---');
            print(
                'Original position: (${track.position.dx}, ${track.position.dy})');

            // track.position is in preview coordinates, map to cropped video area
            // First, convert from preview coordinates to original video display area
            final originalVideoX = (track.position.dx - gapLeft) *
                (videoSize.width / actualPreviewWidth);
            final originalVideoY = (track.position.dy - gapTop) *
                (videoSize.height / actualPreviewHeight);

            // Then, convert from original video space to crop space
            final cropSpaceX = originalVideoX - cropRect.left;
            final cropSpaceY = originalVideoY - cropRect.top;
            print(
                'Original video position: (${originalVideoX}, ${originalVideoY})');
            print('Crop space position: (${cropSpaceX}, ${cropSpaceY})');

            // Map to container space
            final xInContainer = finalGapLeft +
                (cropSpaceX * (croppedPreviewWidth / cropRect.width));
            final yInContainer = finalGapTop +
                (cropSpaceY * (croppedPreviewHeight / cropRect.height));
            print(
                'Container space position: (${xInContainer}, ${yInContainer})');

            // Clamp to visible crop area in container
            final minX = finalGapLeft;
            final maxX = finalGapLeft + croppedPreviewWidth;
            final minY = finalGapTop;
            final maxY = finalGapTop + croppedPreviewHeight;
            print('Clamp bounds: X(${minX} to ${maxX}), Y(${minY} to ${maxY})');

            final displayX = xInContainer.clamp(minX, maxX);
            final displayY = yInContainer.clamp(minY, maxY);
            print('Final display position: (${displayX}, ${displayY})');

            // Use the display position directly
            final remappedPosition = Offset(displayX, displayY);

            // Calculate text dimensions to determine proper boundaries

            // Use the new FontScalingHelper for consistent scaling
            final previewFontSize = FontScalingHelper.calculatePreviewFontSize(
              baseFontSize: track.fontSize,
              videoWidth: videoSize!.width,
              videoHeight: videoSize!.height,
              containerWidth: previewWidth,
              containerHeight: previewHeight,
            );

            // Dummy scale variable for compatibility
            final scale = previewFontSize / track.fontSize;

            print('=== Main Method Font Scaling (Preview Dimensions) ===');
            print(
                'Original video dimensions: ${videoSize!.width}x${videoSize!.height}');
            print('Preview dimensions: ${previewWidth}x${previewHeight}');
            print(
                'Actual preview area: ${actualPreviewWidth}x${actualPreviewHeight}');
            print('Gap offsets: gapLeft=$gapLeft, gapTop=$gapTop');
            print('Calculated preview font size: $previewFontSize');

            TextStyle textStyle = TextStyle(
              color: track.textColor,
              fontSize: previewFontSize,
              fontFamily: track.fontFamily,
              height: 1, // Ensure consistent line height
            );

            // Calculate single-line text width to determine if wrapping is needed
            final TextPainter singleLinePainter = TextPainter(
              text: TextSpan(text: track.text, style: textStyle),
              textDirection: TextDirection.ltr,
              maxLines: 1,
            );
            singleLinePainter.layout();
            final singleLineWidth = singleLinePainter.width;
            final singleLineHeight = singleLinePainter.height;
            singleLinePainter.dispose(); // Dispose TextPainter to free memory

            // Calculate available space using FontScalingHelper
            final boundaryBuffer =
                2.5; // Buffer to prevent text from touching boundary
            final boundaryBufferY = 5.0;

            final availableWidth =
                FontScalingHelper.calculatePreviewAvailableWidth(
              maxX: maxX,
              positionX: remappedPosition.dx,
              buffer: boundaryBuffer,
            );
            final availableHeight =
                maxY - remappedPosition.dy - boundaryBufferY;

            print('=== Text Wrapping Debug (Crop Applied) ===');
            print('Track: "${track.text}"');
            print('Single line width: $singleLineWidth');
            print('Available width: $availableWidth');
            print('Font size: $previewFontSize');
            print('Scale: $scale');

            // Calculate wrapped text to determine actual width needed
            List<String> wrappedLines;
            if (singleLineWidth <= availableWidth) {
              wrappedLines = [track.text];
              print('Single line fits - no wrapping needed');
            } else {
              wrappedLines = TextAutoWrapHelper.wrapTextToFit(
                track.text,
                availableWidth,
                availableHeight,
                textStyle,
              );
              print('Text wrapped into ${wrappedLines.length} lines');
            }
            print('=== End Text Wrapping Debug ===');
            print('Preview wrapped lines: ${wrappedLines.join(' | ')}');

            // Test: Verify wrapping logic by recalculating with same parameters
            final testWrappedLines = TextAutoWrapHelper.wrapTextToFit(
              track.text,
              availableWidth,
              availableHeight,
              textStyle,
            );
            print('=== Test Wrapping Verification ===');
            print('Test wrapped lines: ${testWrappedLines.join(' | ')}');
            print(
                'Original vs Test match: ${wrappedLines.join(' | ')} == ${testWrappedLines.join(' | ')}');
            print('=== End Test Verification ===');

            print('=== Detailed Wrapping Debug ===');
            print(
                'Text style used for wrapping: fontSize=${textStyle.fontSize}, fontFamily=${textStyle.fontFamily}');
            print(
                'Available width: $availableWidth, Available height: $availableHeight');
            print('Single line width: $singleLineWidth');
            for (int i = 0; i < wrappedLines.length; i++) {
              final line = wrappedLines[i];
              final TextPainter linePainter = TextPainter(
                text: TextSpan(text: line, style: textStyle),
                textDirection: TextDirection.ltr,
                maxLines: 1,
              );
              linePainter.layout();
              print('Line $i: "$line" (width: ${linePainter.width})');
              linePainter.dispose(); // Dispose TextPainter to free memory
            }
            print('=== End Detailed Wrapping Debug ===');

            // Calculate the width of the longest line after wrapping
            double maxLineWidth = 0;
            for (String line in wrappedLines) {
              final TextPainter linePainter = TextPainter(
                text: TextSpan(text: line, style: textStyle),
                textDirection: TextDirection.ltr,
                maxLines: 1,
              );
              linePainter.layout();
              maxLineWidth = math.max(maxLineWidth, linePainter.width);
              linePainter.dispose(); // Dispose TextPainter to free memory
            }

            // If single line fits, use it; otherwise calculate wrapped dimensions
            final effectiveWidth =
                availableWidth; // Always use original available width
            final effectiveHeight = availableHeight;

            // Calculate valid position boundaries using the same logic as text wrapping
            // The maximum valid X position should be where the text can still fit within the boundary
            final maxValidX = maxX - maxLineWidth - boundaryBuffer;
            final clampedMaxX = math.max(minX, maxValidX);

            // Calculate wrapped text height for Y boundary
            final totalTextHeight =
                TextAutoWrapHelper.calculateWrappedTextHeight(
              wrappedLines,
              textStyle,
            );
            final maxValidY = maxY - totalTextHeight - boundaryBufferY;
            final clampedMaxY = math.max(minY, maxValidY);

            // Ensure the text position is properly clamped to prevent overflow
            final clampedX = remappedPosition.dx.clamp(minX, clampedMaxX);
            final clampedY = remappedPosition.dy.clamp(minY, clampedMaxY);

            print('=== Boundary Enforcement Debug (Crop) ===');
            print(
                'Original position: (${remappedPosition.dx}, ${remappedPosition.dy})');
            print('Max line width: $maxLineWidth');
            print('Total text height: $totalTextHeight');
            print('Boundary buffer: $boundaryBuffer');
            print('Max valid X: $maxValidX, Clamped max X: $clampedMaxX');
            print('Max valid Y: $maxValidY, Clamped max Y: $clampedMaxY');
            print('Final clamped position: ($clampedX, $clampedY)');
            print('Available width for text: $availableWidth');
            print('Available height for text: $availableHeight');
            print('=== End Boundary Enforcement Debug ===');

            return Positioned(
              left: clampedX,
              top: clampedY,
              child: GestureDetector(
                behavior: HitTestBehavior
                    .deferToChild, // Let child (handle) claim gestures first
                onPanUpdate: (details) {
                  if (_isRotating) return; // Prevent drag if rotating

                  // Calculate text dimensions for boundary checking
                  final videoSize =
                      provider.videoEditorController?.video.value.size;

                  final previewFontSize =
                      FontScalingHelper.calculatePreviewFontSize(
                    baseFontSize: track.fontSize,
                    videoWidth: videoSize!.width,
                    videoHeight: videoSize!.height,
                    containerWidth: previewWidth,
                    containerHeight: previewHeight,
                  );

                  TextStyle textStyle = TextStyle(
                    color: track.textColor,
                    fontSize: previewFontSize,
                    fontFamily: track.fontFamily,
                  );

                  // Calculate single-line text width
                  final TextPainter singleLinePainter = TextPainter(
                    text: TextSpan(text: track.text, style: textStyle),
                    textDirection: TextDirection.ltr,
                    maxLines: 1,
                  );
                  singleLinePainter.layout();
                  final singleLineWidth = singleLinePainter.width;

                  // Calculate new position after drag in container space
                  final newXInContainer = displayX + details.delta.dx;
                  final newYInContainer = displayY + details.delta.dy;

                  // Calculate wrapping based on the new position and current text style with buffer
                  final boundaryBuffer =
                      2.5; // Buffer to prevent text from touching boundary
                  final boundaryBufferY = 5.0; // Buffer for Y boundary

                  // First calculate available width and height without rotation
                  final baseAvailableWidth =
                      maxX - newXInContainer - boundaryBuffer;
                  final baseAvailableHeight =
                      maxY - newYInContainer - boundaryBufferY;

                  // Use auto-wrap helper to get wrapped lines
                  final wrappedLines = singleLineWidth <= baseAvailableWidth
                      ? [track.text]
                      : TextAutoWrapHelper.wrapTextToFit(
                          track.text,
                          baseAvailableWidth,
                          baseAvailableHeight,
                          textStyle,
                        );

                  // Calculate the width of the longest line after wrapping
                  double maxLineWidth = 0;
                  for (String line in wrappedLines) {
                    final TextPainter linePainter = TextPainter(
                      text: TextSpan(text: line, style: textStyle),
                      textDirection: TextDirection.ltr,
                      maxLines: 1,
                    );
                    linePainter.layout();
                    maxLineWidth = math.max(maxLineWidth, linePainter.width);
                  }

                  final totalTextHeight =
                      TextAutoWrapHelper.calculateWrappedTextHeight(
                    wrappedLines,
                    textStyle,
                  );

                  // Now calculate rotated text bounds with final dimensions
                  final rotation = track.rotation ?? 0;
                  final rotatedBounds =
                      _SmoothRotatableTextState.calculateRotatedTextBounds(
                    textWidth: maxLineWidth,
                    textHeight: totalTextHeight,
                    rotation: rotation,
                  );

                  final rotatedWidth = rotatedBounds['width']!;
                  final rotatedHeight = rotatedBounds['height']!;
                  final offsetX = rotatedBounds['offsetX']!;
                  final offsetY = rotatedBounds['offsetY']!;

                  // Adjust available width and height for rotated text
                  final availableWidth = baseAvailableWidth - offsetX;
                  final availableHeight = baseAvailableHeight - offsetY;

                  // Recalculate wrapped lines with adjusted bounds if needed
                  List<String> finalWrappedLines = wrappedLines;
                  if (rotation != 0) {
                    finalWrappedLines = singleLineWidth <= availableWidth
                        ? [track.text]
                        : TextAutoWrapHelper.wrapTextToFit(
                            track.text,
                            availableWidth,
                            availableHeight,
                            textStyle,
                          );
                  }

                  // Recalculate final dimensions with adjusted wrapping
                  double finalMaxLineWidth = maxLineWidth;
                  double finalTotalTextHeight = totalTextHeight;

                  if (rotation != 0) {
                    finalMaxLineWidth = 0;
                    for (String line in finalWrappedLines) {
                      final TextPainter linePainter = TextPainter(
                        text: TextSpan(text: line, style: textStyle),
                        textDirection: TextDirection.ltr,
                        maxLines: 1,
                      );
                      linePainter.layout();
                      finalMaxLineWidth =
                          math.max(finalMaxLineWidth, linePainter.width);
                    }

                    finalTotalTextHeight =
                        TextAutoWrapHelper.calculateWrappedTextHeight(
                      finalWrappedLines,
                      textStyle,
                    );
                  }

                  // Recalculate rotated bounds with final text dimensions
                  final finalRotatedBounds =
                      _SmoothRotatableTextState.calculateRotatedTextBounds(
                    textWidth: finalMaxLineWidth,
                    textHeight: finalTotalTextHeight,
                    rotation: rotation,
                  );

                  final finalRotatedWidth = finalRotatedBounds['width']!;
                  final finalRotatedHeight = finalRotatedBounds['height']!;

                  // Calculate X boundary using the rotated text width with proper buffer
                  final maxValidX = maxX - finalRotatedWidth - boundaryBuffer;
                  final clampedMaxX = math.max(minX, maxValidX);

                  // Calculate Y boundary considering rotated text height
                  final maxValidY = maxY - finalRotatedHeight - boundaryBufferY;
                  final clampedMaxY = math.max(minY, maxValidY);

                  // Clamp to container bounds with text-aware boundaries
                  final clampedXInContainer =
                      newXInContainer.clamp(minX, clampedMaxX);
                  final clampedYInContainer =
                      newYInContainer.clamp(minY, clampedMaxY);

                  // Convert back to crop space
                  final newCropSpaceX = (clampedXInContainer - finalGapLeft) *
                      (cropRect.width / croppedPreviewWidth);
                  final newCropSpaceY = (clampedYInContainer - finalGapTop) *
                      (cropRect.height / croppedPreviewHeight);

                  // Convert back to original video space
                  final newVideoX = newCropSpaceX + cropRect.left;
                  final newVideoY = newCropSpaceY + cropRect.top;

                  // Convert back to preview coordinates
                  final newPreviewX = gapLeft +
                      (newVideoX * (actualPreviewWidth / videoSize!.width));
                  final newPreviewY = gapTop +
                      (newVideoY * (actualPreviewHeight / videoSize!.height));

                  print(
                      'Current container position: (${displayX}, ${displayY})');
                  print(
                      'New container position: (${clampedXInContainer}, ${clampedYInContainer})');
                  print(
                      'Single line width: $singleLineWidth, Max line width: $maxLineWidth, Total text height: $totalTextHeight');
                  print('Max valid X: $clampedMaxX, Max valid Y: $clampedMaxY');
                  print(
                      'New crop space position: (${newCropSpaceX}, ${newCropSpaceY})');
                  print('New video position: (${newVideoX}, ${newVideoY})');
                  print(
                      'New preview position: (${newPreviewX}, ${newPreviewY})');

                  final newPosition = Offset(newPreviewX, newPreviewY);
                  final updatedTrack = track.copyWith(position: newPosition);
                  final index = provider.textTracks.indexOf(track);
                  provider.updateTextTrackModel(index, updatedTrack);
                },
                child: _SmoothRotatableText(
                  track: track,
                  provider: provider,
                  isRotating: _isRotating, // pass down the flag
                  onSetRotating: (val) =>
                      setState(() => _isRotating = val), // pass down setter
                  availableWidth: effectiveWidth,
                  availableHeight: effectiveHeight,
                  previewFontSize:
                      previewFontSize, // Use track's font size directly
                ),
              ),
            );
          })
          .where((widget) => widget != null)
          .cast<Widget>()
          .toList();
    } else if (videoSize != null) {
      print('--- NO CROP APPLIED ---');
      // --- No crop: fit entire video in container (with possible letterboxing) ---
      final videoAspectRatio = videoSize.width / videoSize.height;
      final containerAspectRatio = containerWidth / containerHeight;
      print(
          'Aspect ratios: video=$videoAspectRatio, container=$containerAspectRatio');

      double actualPreviewWidth,
          actualPreviewHeight,
          gapLeft = 0.0,
          gapTop = 0.0;
      if (videoAspectRatio > containerAspectRatio) {
        actualPreviewWidth = containerWidth;
        actualPreviewHeight = containerWidth / videoAspectRatio;
        gapTop = (containerHeight - actualPreviewHeight) / 2.0;
        print('Video wider: fit width, letterbox top/bottom');
      } else {
        actualPreviewHeight = containerHeight;
        actualPreviewWidth = containerHeight * videoAspectRatio;
        gapLeft = (containerWidth - actualPreviewWidth) / 2.0;
        print('Video taller: fit height, letterbox left/right');
      }

      print('Preview dimensions: ${actualPreviewWidth}x${actualPreviewHeight}');
      print('Gap offsets: gapLeft=$gapLeft, gapTop=$gapTop');

      return visibleTracks
          .map((track) {
            print('--- Processing track (no crop): "${track.text}" ---');
            print(
                'Original position: (${track.position.dx}, ${track.position.dy})');

            // track.position is in preview coordinates (same as crop case)
            // Convert from preview coordinates to display coordinates
            final xInContainer = track.position.dx;
            final yInContainer = track.position.dy;
            print(
                'Container space position: (${xInContainer}, ${yInContainer})');

            final minX = gapLeft;
            final maxX = gapLeft + actualPreviewWidth;
            final minY = gapTop;
            final maxY = gapTop + actualPreviewHeight;
            print('Clamp bounds: X(${minX} to ${maxX}), Y(${minY} to ${maxY})');

            final displayX = xInContainer.clamp(minX, maxX);
            final displayY = yInContainer.clamp(minY, maxY);
            print('Final display position: (${displayX}, ${displayY})');

            // Calculate text dimensions to determine proper boundaries
            // Use the new FontScalingHelper for consistent scaling
            final previewFontSize = FontScalingHelper.calculatePreviewFontSize(
              baseFontSize: track.fontSize,
              videoWidth: videoSize!.width,
              videoHeight: videoSize!.height,
              containerWidth: previewWidth,
              containerHeight: previewHeight,
            );

            // Dummy scale variable for compatibility
            final scale = previewFontSize / track.fontSize;

            TextStyle textStyle = TextStyle(
              color: track.textColor,
              fontSize: previewFontSize,
              fontFamily: track.fontFamily,
              height: 1, // Ensure consistent line height
            );

            // Calculate single-line text width to determine if wrapping is needed
            final TextPainter singleLinePainter = TextPainter(
              text: TextSpan(text: track.text, style: textStyle),
              textDirection: TextDirection.ltr,
              maxLines: 1,
            );
            singleLinePainter.layout();
            final singleLineWidth = singleLinePainter.width;

            // Calculate available space considering text dimensions with buffer
            final boundaryBuffer =
                2.5; // Buffer to prevent text from touching boundary
            final boundaryBufferY = 5.0;
            final availableWidth =
                FontScalingHelper.calculatePreviewAvailableWidth(
              maxX: maxX,
              positionX: displayX,
              buffer: boundaryBuffer,
            );
            final availableHeight = maxY - displayY - boundaryBufferY;

            print('=== Text Wrapping Debug (No Crop) ===');
            print('Track: "${track.text}"');
            print('Single line width: $singleLineWidth');
            print('Available width: $availableWidth');
            print('Font size: $previewFontSize');
            print('Scale: $scale');

            // Calculate wrapped text to determine actual width needed
            List<String> wrappedLines;
            if (singleLineWidth <= availableWidth) {
              wrappedLines = [track.text];
              print('Single line fits - no wrapping needed');
            } else {
              wrappedLines = TextAutoWrapHelper.wrapTextToFit(
                track.text,
                availableWidth,
                availableHeight,
                textStyle,
              );
              print('Text wrapped into ${wrappedLines.length} lines');
            }
            print('=== End Text Wrapping Debug ===');
            print('Preview wrapped lines: ${wrappedLines.join(' | ')}');

            // Test: Verify wrapping logic by recalculating with same parameters
            final testWrappedLines = TextAutoWrapHelper.wrapTextToFit(
              track.text,
              availableWidth,
              availableHeight,
              textStyle,
            );
            print('=== Test Wrapping Verification (No Crop) ===');
            print('Test wrapped lines: ${testWrappedLines.join(' | ')}');
            print(
                'Original vs Test match: ${wrappedLines.join(' | ')} == ${testWrappedLines.join(' | ')}');
            print('=== End Test Verification ===');

            print('=== Detailed Wrapping Debug (No Crop) ===');
            print(
                'Text style used for wrapping: fontSize=${textStyle.fontSize}, fontFamily=${textStyle.fontFamily}');
            print(
                'Available width: $availableWidth, Available height: $availableHeight');
            print('Single line width: $singleLineWidth');
            for (int i = 0; i < wrappedLines.length; i++) {
              final line = wrappedLines[i];
              final TextPainter linePainter = TextPainter(
                text: TextSpan(text: line, style: textStyle),
                textDirection: TextDirection.ltr,
                maxLines: 1,
              );
              linePainter.layout();
              print('Line $i: "$line" (width: ${linePainter.width})');
              linePainter.dispose(); // Dispose TextPainter to free memory
            }
            print('=== End Detailed Wrapping Debug ===');

            // Calculate the width of the longest line after wrapping
            double maxLineWidth = 0;
            for (String line in wrappedLines) {
              final TextPainter linePainter = TextPainter(
                text: TextSpan(text: line, style: textStyle),
                textDirection: TextDirection.ltr,
                maxLines: 1,
              );
              linePainter.layout();
              maxLineWidth = math.max(maxLineWidth, linePainter.width);
              linePainter.dispose(); // Dispose TextPainter to free memory
            }

            // If single line fits, use it; otherwise calculate wrapped dimensions
            final effectiveWidth =
                availableWidth; // Always use original available width
            final effectiveHeight = availableHeight;

            // Calculate valid position boundaries using the same logic as text wrapping
            // The maximum valid X position should be where the text can still fit within the boundary
            final maxValidX = maxX - maxLineWidth - boundaryBuffer;
            final clampedMaxX = math.max(minX, maxValidX);

            // Calculate wrapped text height for Y boundary
            final totalTextHeight =
                TextAutoWrapHelper.calculateWrappedTextHeight(
              wrappedLines,
              textStyle,
            );
            final maxValidY = maxY - totalTextHeight - boundaryBufferY;
            final clampedMaxY = math.max(minY, maxValidY);

            // Ensure the text position is properly clamped to prevent overflow
            final clampedX = xInContainer.clamp(minX, clampedMaxX);
            final clampedY = yInContainer.clamp(minY, clampedMaxY);

            print('=== Boundary Enforcement Debug ===');
            print('Original position: (${xInContainer}, ${yInContainer})');
            print('Max line width: $maxLineWidth');
            print('Total text height: $totalTextHeight');
            print('Boundary buffer: $boundaryBuffer');
            print('Max valid X: $maxValidX, Clamped max X: $clampedMaxX');
            print('Max valid Y: $maxValidY, Clamped max Y: $clampedMaxY');
            print('Final clamped position: ($clampedX, $clampedY)');
            print('Available width for text: $availableWidth');
            print('Available height for text: $availableHeight');
            print('=== End Boundary Enforcement Debug ===');

            return Positioned(
              left: clampedX,
              top: clampedY,
              child: GestureDetector(
                behavior: HitTestBehavior.deferToChild,
                onPanUpdate: (details) {
                  if (_isRotating) return;

                  // Calculate text dimensions for boundary checking
                  final previewFontSize =
                      FontScalingHelper.calculatePreviewFontSize(
                    baseFontSize: track.fontSize,
                    videoWidth: videoSize!.width,
                    videoHeight: videoSize!.height,
                    containerWidth: previewWidth,
                    containerHeight: previewHeight,
                  );

                  TextStyle textStyle = TextStyle(
                    color: track.textColor,
                    fontSize: previewFontSize,
                    fontFamily: track.fontFamily,
                  );

                  // Calculate single-line text width
                  final TextPainter singleLinePainter = TextPainter(
                    text: TextSpan(text: track.text, style: textStyle),
                    textDirection: TextDirection.ltr,
                    maxLines: 1,
                  );
                  singleLinePainter.layout();
                  final singleLineWidth = singleLinePainter.width;
                  singleLinePainter
                      .dispose(); // Dispose TextPainter to free memory

                  // track.position is in preview coordinates (same as crop case)
                  // Calculate new preview position after drag
                  final newPreviewX = track.position.dx + details.delta.dx;
                  final newPreviewY = track.position.dy + details.delta.dy;

                  // Calculate wrapping based on the new preview position and current text style with buffer
                  final boundaryBuffer =
                      2.5; // Buffer to prevent text from touching boundary
                  final boundaryBufferY = 5.0;

                  // First calculate available width and height without rotation
                  final baseAvailableWidth =
                      maxX - newPreviewX - boundaryBuffer;
                  final baseAvailableHeight =
                      maxY - newPreviewY - boundaryBufferY;

                  // Use auto-wrap helper to get wrapped lines
                  final wrappedLines = singleLineWidth <= baseAvailableWidth
                      ? [track.text]
                      : TextAutoWrapHelper.wrapTextToFit(
                          track.text,
                          baseAvailableWidth,
                          baseAvailableHeight,
                          textStyle,
                        );

                  // Calculate the width of the longest line after wrapping
                  double maxLineWidth = 0;
                  for (String line in wrappedLines) {
                    final TextPainter linePainter = TextPainter(
                      text: TextSpan(text: line, style: textStyle),
                      textDirection: TextDirection.ltr,
                      maxLines: 1,
                    );
                    linePainter.layout();
                    maxLineWidth = math.max(maxLineWidth, linePainter.width);
                    linePainter.dispose(); // Dispose TextPainter to free memory
                  }

                  final totalTextHeight =
                      TextAutoWrapHelper.calculateWrappedTextHeight(
                    wrappedLines,
                    textStyle,
                  );

                  // Now calculate rotated text bounds with final dimensions
                  final rotation = track.rotation ?? 0;
                  final rotatedBounds =
                      _SmoothRotatableTextState.calculateRotatedTextBounds(
                    textWidth: maxLineWidth,
                    textHeight: totalTextHeight,
                    rotation: rotation,
                  );

                  final rotatedWidth = rotatedBounds['width']!;
                  final rotatedHeight = rotatedBounds['height']!;
                  final offsetX = rotatedBounds['offsetX']!;
                  final offsetY = rotatedBounds['offsetY']!;

                  // Adjust available width and height for rotated text
                  final availableWidth = baseAvailableWidth - offsetX;
                  final availableHeight = baseAvailableHeight - offsetY;

                  // Recalculate wrapped lines with adjusted bounds if needed
                  List<String> finalWrappedLines = wrappedLines;
                  if (rotation != 0) {
                    finalWrappedLines = singleLineWidth <= availableWidth
                        ? [track.text]
                        : TextAutoWrapHelper.wrapTextToFit(
                            track.text,
                            availableWidth,
                            availableHeight,
                            textStyle,
                          );
                  }

                  // Recalculate final dimensions with adjusted wrapping
                  double finalMaxLineWidth = maxLineWidth;
                  double finalTotalTextHeight = totalTextHeight;

                  if (rotation != 0) {
                    finalMaxLineWidth = 0;
                    for (String line in finalWrappedLines) {
                      final TextPainter linePainter = TextPainter(
                        text: TextSpan(text: line, style: textStyle),
                        textDirection: TextDirection.ltr,
                        maxLines: 1,
                      );
                      linePainter.layout();
                      finalMaxLineWidth =
                          math.max(finalMaxLineWidth, linePainter.width);
                      linePainter
                          .dispose(); // Dispose TextPainter to free memory
                    }

                    finalTotalTextHeight =
                        TextAutoWrapHelper.calculateWrappedTextHeight(
                      finalWrappedLines,
                      textStyle,
                    );
                  }

                  // Recalculate rotated bounds with final text dimensions
                  final finalRotatedBounds =
                      _SmoothRotatableTextState.calculateRotatedTextBounds(
                    textWidth: finalMaxLineWidth,
                    textHeight: finalTotalTextHeight,
                    rotation: rotation,
                  );

                  final finalRotatedWidth = finalRotatedBounds['width']!;
                  final finalRotatedHeight = finalRotatedBounds['height']!;

                  // Calculate X boundary using the rotated text width with proper buffer
                  final maxValidX = maxX - finalRotatedWidth - boundaryBuffer;
                  final clampedMaxX = math.max(minX, maxValidX);

                  // Clamp preview position with the correct boundary
                  final finalPreviewX = newPreviewX.clamp(minX, clampedMaxX);

                  // Calculate valid position boundaries considering rotated text height
                  final maxValidY = maxY - finalRotatedHeight - boundaryBufferY;
                  final clampedMaxY = math.max(minY, maxValidY);

                  final finalPreviewY = newPreviewY.clamp(minY, clampedMaxY);

                  print(
                      'Current preview position: (${track.position.dx}, ${track.position.dy})');
                  print(
                      'New preview position: (${finalPreviewX}, ${finalPreviewY})');
                  print(
                      'Single line width: $singleLineWidth, Max line width: $maxLineWidth, Total text height: $totalTextHeight');
                  print('Max valid X: $clampedMaxX, Max valid Y: $clampedMaxY');

                  final newPosition = Offset(finalPreviewX, finalPreviewY);
                  final updatedTrack = track.copyWith(position: newPosition);
                  final index = provider.textTracks.indexOf(track);
                  provider.updateTextTrackModel(index, updatedTrack);
                },
                child: _SmoothRotatableText(
                  track: track,
                  provider: provider,
                  isRotating: _isRotating,
                  onSetRotating: (val) => setState(() => _isRotating = val),
                  availableWidth: effectiveWidth,
                  availableHeight: effectiveHeight,
                  previewFontSize: previewFontSize,
                ),
              ),
            );
          })
          .where((widget) => widget != null)
          .cast<Widget>()
          .toList();
    } else {
      print('No video size available, returning empty list');
      return [];
    }

    print('=== _buildFixedBoundsTextOverlays END ===');
  }

  Widget _buildTopBar(BuildContext context) {
    return Consumer<VideoEditorProvider>(
      builder: (ctx, provider, child) => Row(
        children: [
          const BackButton(),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () => _exportVideo(context),
          ),
        ],
      ),
    );
  }

  void openBottomSheet(BuildContext context, List<VideoTrackModel> tracks) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Colors.black,
      isScrollControlled: true,
      isDismissible: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height / 1.4,
      ),
      builder: (BuildContext context) {
        if (tracks.length > 1) {
          return FileReordering(
            reorderFiles: tracks.map((e) => e.originalFile).toList(),
            totalDurations: tracks.map((e) => e.totalDuration).toList(),
          );
        } else {
          return Center(
            child: Text("Choose at least two files to be reordered."),
          );
        }
      },
    );
  }

  Widget _buildVideoPreview() {
    return Consumer<VideoEditorProvider>(
      builder: (context, provider, child) {
        if (provider.videoTracks.isEmpty) {
          return const Center(child: Text("No File added. Please add a file"));
        }
        if (provider.videoEditorController == null ||
            provider.isInitializingVideo) {
          return const Center(child: CupertinoActivityIndicator(radius: 20));
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final context = _previewContainerKey.currentContext;
          if (context != null) {
            final size = context.size;
            print('ACTUAL PREVIEW CONTAINER SIZE: '
                '\u001b[36m$size\u001b[0m');
            // Only measure container size when NOT in edit mode to avoid feedback loop
            // When editing, the container is reduced, and measuring it would store the reduced size
            if (size != null &&
                _measuredContainerSize != size &&
                !provider.isEditingTrack) {
              setState(() {
                _measuredContainerSize = size;
              });
              // Update the provider with the actual measured height and canvas size
              provider.setPreviewHeight(size.height);
              provider.setCanvasSize(size); // This is the missing call!
            }
          }
        });
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.hardEdge, // Add clipping to prevent text overflow
          children: [
            GestureDetector(
              onTap: provider.togglePlay,
              child: AnimatedBuilder(
                animation: provider.videoEditorController!.video,
                builder: (context, child) {
                  final deviceWidth = MediaQuery.of(context).size.width;
                  // Use measured container size or fallback to a reasonable default
                  // No height reduction needed - AppBar hiding provides space
                  final containerHeight =
                      _measuredContainerSize?.height ?? 400.0;

                  return Container(
                    key: _previewContainerKey,
                    width: deviceWidth,
                    height: containerHeight,
                    color: Colors.black, // Background for video
                    child: Stack(
                      clipBehavior: Clip
                          .hardEdge, // Add clipping to prevent text overflow
                      children: [
                        // Video preview - constrained to original video display area
                        _buildConstrainedVideoPreview(
                            provider, deviceWidth, containerHeight),

                        // Sequential video playback - show only current video based on timeline
                        _buildSequentialVideoPlayer(
                            provider, deviceWidth, containerHeight),
                      ],
                    ),
                  );
                },
              ),
            ),
            AnimatedBuilder(
              animation: provider.videoEditorController!.video,
              builder: (_, __) => AnimatedOpacity(
                opacity: provider.isPlaying ? 0 : 1,
                duration: kThemeAnimationDuration,
                child: GestureDetector(
                  onTap: () {
                    // Use provider's togglePlay which now uses master controller
                    provider.togglePlay();
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      provider.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConstrainedVideoPreview(
    VideoEditorProvider provider,
    double containerWidth,
    double containerHeight,
  ) {
    final videoSize = provider.videoEditorController?.video.value.size;
    if (videoSize == null) return const SizedBox.shrink();

    final videoAspectRatio = videoSize.width / videoSize.height;
    final containerAspectRatio = containerWidth / containerHeight;

    double actualPreviewWidth, actualPreviewHeight, gapLeft = 0.0, gapTop = 0.0;
    if (videoAspectRatio > containerAspectRatio) {
      actualPreviewWidth = containerWidth;
      actualPreviewHeight = containerWidth / videoAspectRatio;
      gapTop = (containerHeight - actualPreviewHeight) / 2.0;
    } else {
      actualPreviewHeight = containerHeight;
      actualPreviewWidth = containerHeight * videoAspectRatio;
      gapLeft = (containerWidth - actualPreviewWidth) / 2.0;
    }

    return Positioned(
      left: gapLeft,
      top: gapTop,
      width: actualPreviewWidth,
      height: actualPreviewHeight,
      child: CropGridViewer.preview(
        key: ValueKey(provider.textTracks.length),
        controller: provider.videoEditorController!,
        overlayText: "", // Remove old text display
      ),
    );
  }

  Widget _buildVideoTimelineEditor() {
    return SizedBox(
      height: 60,
      width: MediaQuery.of(context).size.width,
      child: Consumer<VideoEditorProvider>(
        builder: (context, provider, child) => SingleChildScrollView(
          physics: provider.masterTimelineController.isPlaying
              ? NeverScrollableScrollPhysics()
              : ClampingScrollPhysics(),
          controller: provider.videoScrollController,
          padding: EdgeInsets.zero,
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width / 2,
                child: GestureDetector(
                  onTap: () async {
                    context.loaderOverlay.show();
                    try {
                      final pickedFile = await pickVideo(context);
                      if (pickedFile == null) {
                        context.loaderOverlay.hide();
                        return;
                      }
                      final provider = context.read<VideoEditorProvider>();

                      final duration =
                          await provider.getMediaDuration(pickedFile.path);
                      await provider.addVideoTrack(
                        pickedFile,
                        pickedFile,
                        duration,
                      );
                    } finally {
                      context.loaderOverlay.hide();
                    }
                  },
                  child: Image.asset(
                    "assets/icons/add-video.png",
                    color: Colors.white,
                    height: 35,
                    width: 35,
                  ),
                ),
              ),
              VideoTimeline(
                key: ValueKey(provider.videoEditorController.hashCode),
                controller: provider.videoEditorController?.video,
                videoScrollController: provider.videoScrollController,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioTimelineEditor() {
    return Consumer<VideoEditorProvider>(builder: (context, provider, child) {
      // Calculate height: 40px normal, or 30px per lane in edit mode
      final isExpanded = provider.isEditingTrackType(TrackType.audio);
      final activeLaneCount = provider.getActiveLaneCount(TrackType.audio);
      final height = isExpanded
          ? activeLaneCount * 30.0 // Edit mode: 30px per lane
          : 40.0; // Normal mode: fixed 40px

      return Container(
        height: height,
        width: MediaQuery.of(context).size.width,
        child: SingleChildScrollView(
          physics: provider.masterTimelineController.isPlaying
              ? NeverScrollableScrollPhysics()
              : ClampingScrollPhysics(),
          controller: provider.audioScrollController,
          padding: EdgeInsets.zero,
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width / 2,
                child: GestureDetector(
                  onTap: () => provider.pickAudioFile(context),
                  child: Image.asset(
                    "assets/icons/add-audio.png",
                    color: Colors.white,
                    height: 25,
                    width: 25,
                  ),
                ),
              ),
              AudioTimeline(
                key: ValueKey(provider.videoEditorController.hashCode),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildTextTimelineEditor() {
    return Consumer<VideoEditorProvider>(builder: (context, provider, child) {
      // Calculate height: 40px normal, or 30px per lane in edit mode
      final isExpanded = provider.isEditingTrackType(TrackType.text);
      final activeLaneCount = provider.getActiveLaneCount(TrackType.text);
      final height = isExpanded
          ? activeLaneCount * 30.0 // Edit mode: 30px per lane
          : 40.0; // Normal mode: fixed 40px

      return Container(
        height: height,
        width: MediaQuery.of(context).size.width,
        child: SingleChildScrollView(
          physics: provider.masterTimelineController.isPlaying
              ? NeverScrollableScrollPhysics()
              : ClampingScrollPhysics(),
          controller: provider.textScrollController,
          padding: EdgeInsets.zero,
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width / 2,
                child: GestureDetector(
                  onTap: () => provider.toggleTextFieldVisibility(true),
                  child: Image.asset(
                    "assets/icons/add-text.png",
                    color: Colors.white,
                    height: 20,
                    width: 20,
                  ),
                ),
              ),
              TextTimeline(
                key: ValueKey(provider.videoEditorController.hashCode),
                previewHeight: provider.previewHeight,
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildScrollableSpaceBelow() {
    return SizedBox(
      height: 30,
      width: MediaQuery.of(context).size.width,
      child: Consumer<VideoEditorProvider>(
        builder: (context, provider, child) {
          final screenWidth = MediaQuery.of(context).size.width;
          final buttonWidth = screenWidth * 0.2;

          return Stack(
            children: [
              // Base scrollable space
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  // border: Border(
                  //   bottom:
                  //       BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
                  // ),
                ),
                child: Row(
                  children: [
                    // Fixed button area (20%) - empty space matching timeline structure
                    Container(
                      width: buttonWidth,
                      color: Colors.black,
                    ),
                    // Scrollable timeline area (80%)
                    Expanded(
                      child: Container(
                        color: Colors.black.withOpacity(0.3),
                        child: SingleChildScrollView(
                          physics: ClampingScrollPhysics(),
                          controller: provider.bottomScrollController,
                          scrollDirection: Axis.horizontal,
                          child: Container(
                            margin: EdgeInsets.only(
                                right: 1.0), // Match timeline margin
                            width: math.max(
                                provider.videoDuration * (screenWidth / 8),
                                screenWidth *
                                    2), // Ensure minimum scrollable width
                            height: 20,
                            color: Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVideoTrimSlider(VideoEditorProvider provider) {
    return Container(
      height: 60,
      child: CustomTrimSlider(
        value: provider.trimStart,
        secondValue: provider.trimEnd,
        position: provider.playbackPosition,
        onPositionChanged: provider.seekTo,
        max: provider.videoEditorController?.video.value.duration.inSeconds
                .toDouble() ??
            0.0,
        onChanged: (start, end) => provider.updateTrimValues(start, end),
        controller: provider.videoEditorController?.video,
      ),
    );
  }

  Widget _buildToolbar() {
    return Consumer<VideoEditorProvider>(
      builder: (context, provider, child) {
        if (provider.isEditingTrack) {
          return _buildEditModeToolbar(provider);
        }
        return _buildNormalModeToolbar(provider);
      },
    );
  }

  Widget _buildNormalModeToolbar(VideoEditorProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Color(0xFF1C1C1E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildToolbarItem(Icons.cut, 'Edit', onTap: _handleEditButton),
            const SizedBox(width: 16),
            _buildToolbarItem(Icons.videocam, 'Video',
                onTap: _handleVideoButton),
            const SizedBox(width: 16),
            _buildToolbarItem(Icons.music_note, 'Audio',
                onTap: _handleAudioButton),
            const SizedBox(width: 16),
            _buildToolbarItem(Icons.text_fields, 'Text',
                onTap: _handleTextButton),
            const SizedBox(width: 16),
            _buildToolbarItem(Icons.aspect_ratio, 'Ratio',
                onTap: _showCanvasRatioDialog),
          ],
        ),
      ),
    );
  }

  Widget _buildEditModeToolbar(VideoEditorProvider provider) {
    switch (provider.editingTrackType) {
      case TrackType.video:
        return _buildVideoEditToolbar(provider);
      case TrackType.audio:
        return _buildAudioEditToolbar(provider);
      case TrackType.text:
        return _buildTextEditToolbar(provider);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildVideoEditToolbar(VideoEditorProvider provider) {
    final selectedIndex = provider.selectedVideoTrackIndex;
    final isMuted =
        selectedIndex >= 0 && selectedIndex < provider.videoTracks.length
            ? provider.isVideoMuted(provider.videoTracks[selectedIndex].id)
            : false;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildBackButton(),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildToolbarItem(Icons.crop, 'Crop', onTap: _showCropView),
                  const SizedBox(width: 16),

                  // ---------------------------------------------------------
                  // NEW: ROTATION BUTTONS (Same Logic Used in _showCropView)
                  // ---------------------------------------------------------
                  _buildToolbarItem(Icons.rotate_left, 'Rotate Left',
                      onTap: () => _rotateTrack(RotateDirection.left)),
                  const SizedBox(width: 16),

                  _buildToolbarItem(Icons.rotate_right, 'Rotate Right',
                      onTap: () => _rotateTrack(RotateDirection.right)),
                  const SizedBox(width: 16),

                  // ---------------------------------------------------------

                  _buildToolbarItem(Icons.filter, 'Filter',
                      onTap: _showFilterPicker),
                  const SizedBox(width: 16),

                  _buildToolbarItem(Icons.delete, 'Delete',
                      onTap: _deleteSelectedVideoTrack),
                  const SizedBox(width: 16),

                  _buildToolbarItem(
                    isMuted ? Icons.volume_off : Icons.volume_up,
                    isMuted ? 'Unmute' : 'Mute',
                    onTap: _toggleSelectedVideoMute,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioEditToolbar(VideoEditorProvider provider) {
    final selectedIndex = provider.selectedAudioTrackIndex;
    final isMuted =
        selectedIndex >= 0 && selectedIndex < provider.audioTracks.length
            ? provider.isAudioMuted(provider.audioTracks[selectedIndex].id)
            : false;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Color(0xFF1C1C1E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildBackButton(),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // _buildToolbarItem(Icons.cut, 'Trim', onTap: () {}),
                  // const SizedBox(width: 16),
                  _buildToolbarItem(Icons.delete, 'Delete',
                      onTap: _deleteSelectedAudioTrack),
                  const SizedBox(width: 16),
                  _buildToolbarItem(
                    isMuted ? Icons.volume_off : Icons.volume_up,
                    isMuted ? 'Unmute' : 'Mute',
                    onTap: _toggleSelectedAudioMute,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextEditToolbar(VideoEditorProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Color(0xFF1C1C1E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildBackButton(),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildToolbarItem(Icons.delete, 'Delete',
                      onTap: _deleteSelectedTextTrack),
                  const SizedBox(width: 16),
                  _buildToolbarItem(Icons.rotate_right, 'Rotation',
                      onTap: () => _editSelectedTextTrack(initialTab: 1)),
                  const SizedBox(width: 16),
                  _buildToolbarItem(Icons.font_download, 'Font',
                      onTap: () => _editSelectedTextTrack(initialTab: 2)),
                  const SizedBox(width: 16),
                  _buildToolbarItem(Icons.format_size, 'Size',
                      onTap: () => _editSelectedTextTrack(initialTab: 3)),
                  const SizedBox(width: 16),
                  _buildToolbarItem(Icons.color_lens, 'Color',
                      onTap: () => _editSelectedTextTrack(initialTab: 4)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarItem(IconData icon, String label, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 65,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return InkWell(
      onTap: () {
        final provider = context.read<VideoEditorProvider>();
        provider.exitEditMode();
        HapticFeedback.lightImpact();
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          Icons.chevron_left,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }

  // Normal mode toolbar handlers
  void _handleEditButton() {
    final provider = context.read<VideoEditorProvider>();
    provider.selectTrackAtPosition(TrackType.video);
  }

  void _handleVideoButton() async {
    context.loaderOverlay.show();
    try {
      final pickedFile = await pickVideo(context);
      if (pickedFile == null) {
        context.loaderOverlay.hide();
        return;
      }
      final provider = context.read<VideoEditorProvider>();
      final duration = await provider.getMediaDuration(pickedFile.path);
      await provider.addVideoTrack(pickedFile, pickedFile, duration);
    } finally {
      context.loaderOverlay.hide();
    }
  }

  void _handleAudioButton() {
    final provider = context.read<VideoEditorProvider>();
    provider.pickAudioFile(context);
  }

  void _handleTextButton() {
    final provider = context.read<VideoEditorProvider>();
    provider.toggleTextFieldVisibility(true);
  }

  // Edit mode toolbar handlers - Video
  void _deleteSelectedVideoTrack() async {
    final provider = context.read<VideoEditorProvider>();
    final selectedIndex = provider.selectedVideoTrackIndex;
    if (selectedIndex >= 0) {
      context.loaderOverlay.show();
      try {
        await provider.removeVideoTrack(selectedIndex);
        provider.exitEditMode();
      } finally {
        context.loaderOverlay.hide();
      }
    }
  }

  void _toggleSelectedVideoMute() {
    final provider = context.read<VideoEditorProvider>();
    final selectedIndex = provider.selectedVideoTrackIndex;
    if (selectedIndex >= 0 && selectedIndex < provider.videoTracks.length) {
      provider.toggleVideoMute(provider.videoTracks[selectedIndex].id);
    }
  }

  // Edit mode toolbar handlers - Audio
  void _deleteSelectedAudioTrack() async {
    final provider = context.read<VideoEditorProvider>();
    final selectedIndex = provider.selectedAudioTrackIndex;
    if (selectedIndex >= 0) {
      context.loaderOverlay.show();
      try {
        await provider.removeAudioTrack(selectedIndex);
        provider.exitEditMode();
      } finally {
        context.loaderOverlay.hide();
      }
    }
  }

  void _toggleSelectedAudioMute() {
    final provider = context.read<VideoEditorProvider>();
    final selectedIndex = provider.selectedAudioTrackIndex;
    if (selectedIndex >= 0 && selectedIndex < provider.audioTracks.length) {
      provider.toggleAudioMute(provider.audioTracks[selectedIndex].id);
    }
  }

  // Edit mode toolbar handlers - Text
  void _deleteSelectedTextTrack() async {
    final provider = context.read<VideoEditorProvider>();
    final selectedIndex = provider.selectedTextTrackIndex;
    if (selectedIndex >= 0) {
      await provider.removeTextTrack(selectedIndex);
      provider.exitEditMode();
    }
  }

  void _editSelectedTextTrack({int initialTab = 0}) {
    final provider = context.read<VideoEditorProvider>();
    final selectedIndex = provider.selectedTextTrackIndex;
    if (selectedIndex >= 0 && selectedIndex < provider.textTracks.length) {
      final textTrack = provider.textTracks[selectedIndex];
      final deviceWidth = MediaQuery.of(context).size.width;
      final dynamicHeight = provider.previewHeight ?? 370.0;
      final previewSize = Size(deviceWidth, dynamicHeight);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => TextStyleEditor(
          textTrack: textTrack,
          previewSize: previewSize,
          initialTab: initialTab,
          onStyleUpdated: (updatedTrack) {
            provider.updateTextTrackModel(selectedIndex, updatedTrack);
          },
        ),
      );
    }
  }

  void _handleToolbarItemTap(String label) {
    final provider = Provider.of<VideoEditorProvider>(context, listen: false);
    switch (label) {
      case 'Assets':
        _showAssetPicker();
        break;
      case 'Audio':
        _showAudioPicker();
        break;
      case 'Trim':
        _showTrimVideo(provider);
        break;
      case 'Captions':
        _showCaptionEditor();
        break;
      case 'Text':
        _showTextEditor();
        break;
      case 'Filters':
        _showFilterPicker();
        break;
      case 'Rotate':
        _showRotationControls();
        break;
      // Transitions are now per-asset via timeline buttons
      // case 'Transitions':
      //   _showTransitionPicker();
      //   break;
      case 'Speed':
        _showSpeedControls();
        break;
      case 'Volume':
        _showVolumeControls();
        break;
      case 'Crop':
        _showCropView();
        break;
      case 'Ratio':
        _showCanvasRatioDialog();
        break;
      case 'Rotate Left':
        _rotateLeft();
        break;
      case 'Rotate Right':
        _rotateRight();
        break;
    }
  }

  void _applyCropToTrack(String trackId, VideoEditorController controller) {
    final provider = context.read<VideoEditorProvider>();

    // Get crop rectangle from the video editor controller
    final cropRect = controller.cropRect;
    final rotation = controller.rotation;

    if (cropRect == null) {
      print('🔲 No crop applied, keeping original crop rect');
      return;
    }

    print('🔲 Applying crop and rotation to track $trackId');
    print('   Crop rect from controller: $cropRect');
    print('   Rotation from controller: $rotation°');

    // Convert controller crop rect to normalized rect (0-1)
    // The controller crop rect is usually in video pixel coordinates
    final videoSize = controller.video.value.size;
    if (videoSize.width <= 0 || videoSize.height <= 0) {
      print('🔲 Invalid video size, cannot apply crop');
      return;
    }

    final normalizedCrop = Rect.fromLTWH(
      cropRect.left / videoSize.width,
      cropRect.top / videoSize.height,
      cropRect.width / videoSize.width,
      cropRect.height / videoSize.height,
    );

    print('   Normalized crop rect: $normalizedCrop');

    // Update the specific track's crop rectangle and rotation
    provider.updateVideoTrackCanvasProperties(
      trackId,
      cropRect: normalizedCrop,
      rotation: rotation,
    );

    print('✅ Crop and rotation applied to track $trackId');
    print(
        '📐 Crop rect applied: left=${normalizedCrop.left.toStringAsFixed(4)}, '
        'top=${normalizedCrop.top.toStringAsFixed(4)}, '
        'width=${normalizedCrop.width.toStringAsFixed(4)}, '
        'height=${normalizedCrop.height.toStringAsFixed(4)}');
    print('🔄 Rotation applied: $rotation°');

    // 🎯 IMPORTANT: Reapply the current canvas ratio to refresh the display
    // This ensures the cropped video displays properly without manual ratio selection
    final currentRatio = provider.selectedCanvasRatio;
    print('🔄 Refreshing canvas with current ratio: $currentRatio');

    // Force canvas refresh by reapplying the current ratio
    // This triggers all the recalculation logic that happens when ratio is selected
    Future.delayed(Duration.zero, () {
      provider.setSelectedCanvasRatio(currentRatio);
      print('✅ Canvas ratio refreshed - cropped video should display properly');
    });
  }

  void _rotateTrack(RotateDirection direction) {
    final provider = context.read<VideoEditorProvider>();

    // 1. Find active track (same logic as _showCropView)
    VideoTrackModel? targetTrack;
    final currentPosition = provider.videoPosition;

    for (final track in provider.videoTracks) {
      if (currentPosition >= track.startTime &&
          currentPosition < track.endTime) {
        targetTrack = track;
        break;
      }
    }

    // Fallback to selected track
    if (targetTrack == null && provider.selectedMediaId != null) {
      targetTrack = provider.videoTracks
          .where((t) => t.id == provider.selectedMediaId)
          .firstOrNull;
    }

    // Fallback to first track
    if (targetTrack == null && provider.videoTracks.isNotEmpty) {
      targetTrack = provider.videoTracks.first;
    }

    if (targetTrack == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No video available to rotate')),
      );
      return;
    }

    // 2. Get controller for selected track
    final controller = provider.getVideoControllerForTrack(targetTrack.id);
    if (controller == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video not ready to rotate')),
      );
      return;
    }

    // 3. Rotate the controller (same logic as CropPage)
    controller.rotate90Degrees(direction);

    // 4. Update rotation into VideoTrackModel (important!)
    provider.updateVideoTrackCanvasProperties(
      targetTrack.id,
      rotation: controller.rotation,
    );

    provider.notifyListeners();
  }

  void _showCropView() {
    final provider = context.read<VideoEditorProvider>();

    // Determine which video track to crop based on timeline position
    VideoTrackModel? targetTrack;

    // Get current timeline position
    final currentPosition = provider.videoPosition;

    print('🎯 Finding track at timeline position: ${currentPosition}s');

    // Find the track that's active at current timeline position
    for (final track in provider.videoTracks) {
      print(
          '   Checking track ${track.id}: start=${track.startTime}s, end=${track.endTime}s');
      if (currentPosition >= track.startTime &&
          currentPosition < track.endTime) {
        targetTrack = track;
        print('   ✅ Found active track: ${track.id}');
        break;
      }
    }

    // Fallback: If no track found at current position, try selected track
    if (targetTrack == null && provider.selectedMediaId != null) {
      targetTrack = provider.videoTracks
          .where((track) => track.id == provider.selectedMediaId)
          .firstOrNull;
      print('   📋 Using selected track fallback: ${targetTrack?.id}');
    }

    // Final fallback: Use first video track
    if (targetTrack == null && provider.videoTracks.isNotEmpty) {
      targetTrack = provider.videoTracks.first;
      print('   🔄 Using first track fallback: ${targetTrack.id}');
    }

    // Select this track for visual feedback
    if (targetTrack != null) {
      provider.selectMediaForManipulation(targetTrack.id);
    }

    if (targetTrack == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No video available for cropping')),
      );
      return;
    }

    // Get video controller for the target track
    final controller = provider.getVideoControllerForTrack(targetTrack.id);
    if (controller == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video not ready for cropping')),
      );
      return;
    }

    print('🎯 Opening CropPage for track: ${targetTrack.id}');
    print('   Track rotation: ${targetTrack.canvasRotation}°');
    print('   Current crop rect: ${targetTrack.canvasCropRect}');

    // Store current timeline position before entering crop mode
    final savedTimelinePosition = provider.videoPosition;
    print('💾 Saving timeline position: ${savedTimelinePosition}s');

    // Removed: "Cropping video" message as requested by user

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return CropPage(
            controller: controller,
            initialRotation: targetTrack?.canvasRotation ?? 0,
          );
        },
      ),
    ).then((_) {
      // When returning from crop page, get the updated crop from controller
      // and apply it to the specific track
      print('🔲 Returned from crop page');
      _applyCropToTrack(targetTrack!.id, controller);

      // Restore timeline position to maintain correct time display
      print('🔄 Restoring timeline position to: ${savedTimelinePosition}s');

      final provider = context.read<VideoEditorProvider>();

      // Method 1: Use master timeline controller to seek to the saved position
      if (provider.masterTimelineController != null) {
        provider.masterTimelineController!.seekToTime(savedTimelinePosition);
        print(
            '   ✅ Master timeline controller seeked to: ${savedTimelinePosition}s');
      }

      // Method 2: Seek the actual video controller to correct position
      if (provider.videoEditorController != null) {
        final targetDuration =
            Duration(milliseconds: (savedTimelinePosition * 1000).round());
        provider.videoEditorController!.video.seekTo(targetDuration);
        print('   ✅ Video controller seeked to: ${targetDuration.inSeconds}s');
      }

      // Force UI update to reflect the correct timeline position
      setState(() {});
      print('   ✅ Timeline position restoration completed');
    });
  }

  void _rotateLeft() {
    final videoEditorController =
        context.read<VideoEditorProvider>().videoEditorController;
    if (videoEditorController == null) return;
    videoEditorController.rotate90Degrees(RotateDirection.left);
  }

  void _rotateRight() {
    final videoEditorController =
        context.read<VideoEditorProvider>().videoEditorController;
    if (videoEditorController == null) return;
    videoEditorController.rotate90Degrees(RotateDirection.right);
  }

  _showTrimVideo(VideoEditorProvider provider) {
    provider.setEditMode(EditMode.trim);
    provider.videoEditorController?.video.pause(); // Pause video first
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Trim Video', style: TextStyle(fontSize: 18)),
            Expanded(
              child: CustomTrimSlider(
                value: provider.trimStart,
                secondValue: provider.trimEnd,
                position: provider.playbackPosition,
                max: provider
                        .videoEditorController?.video.value.duration.inSeconds
                        .toDouble() ??
                    0.0,
                onChanged: provider.updateTrimValues,
                onPositionChanged: provider.seekTo,
                controller: provider.videoEditorController?.video,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRotationControls() {
    showModalBottomSheet(
      context: context,
      builder: (context) => VideoRotationControl(
        currentRotation: Provider.of<VideoEditorProvider>(context).rotation,
        onRotationChanged: (rotation) => Provider.of<VideoEditorProvider>(
          context,
          listen: false,
        ).setRotation(rotation),
      ),
    );
  }

  // Global transition picker deprecated - transitions are now per-asset via timeline buttons
  // void _showTransitionPicker() {
  //   showModalBottomSheet(
  //     context: context,
  //     builder: (context) => TransitionPicker(
  //       trackIndex: 0, // Would need to determine which gap
  //       onTransitionSelected: (transition) => {}, // Handled per-asset now
  //       currentTransition: TransitionType.none,
  //     ),
  //   );
  // }

  void _showSpeedControls() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SpeedControl(
        currentSpeed: Provider.of<VideoEditorProvider>(context).playbackSpeed,
        onSpeedChanged: (speed) => Provider.of<VideoEditorProvider>(
          context,
          listen: false,
        ).setPlaybackSpeed(speed),
      ),
    );
  }

  void _showVolumeControls() {
    showModalBottomSheet(
      context: context,
      builder: (context) => VolumeControl(
        videoVolume: Provider.of<VideoEditorProvider>(context).videoVolume,
        audioVolume: Provider.of<VideoEditorProvider>(context).audioVolume,
        onVideoVolumeChanged: (volume) => Provider.of<VideoEditorProvider>(
          context,
          listen: false,
        ).setVideoVolume(volume),
        onAudioVolumeChanged: (volume) => Provider.of<VideoEditorProvider>(
          context,
          listen: false,
        ).setAudioVolume(volume),
      ),
    );
  }

  void _showAssetPicker() {
    context.read<AssetController>().getAllMedia(context);
  }

  void _showAudioPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => AudioPicker(
        onAudioSelected: (audio) => Provider.of<VideoEditorProvider>(
          context,
          listen: false,
        ).setAudio(audio),
        videoEditorProvider: Provider.of<VideoEditorProvider>(
          context,
          listen: false,
        ),
      ),
    );
  }

  void _showTextEditor() {
    showModalBottomSheet(
      context: context,
      builder: (context) => TextOverlayEditor(
        onTextAdded: (text) => Provider.of<VideoEditorProvider>(
          context,
          listen: false,
        ).addTextOverlay(text),
      ),
    );
  }

  void _showFilterPicker() {
    final provider = Provider.of<VideoEditorProvider>(context, listen: false);

    // Only allow filter selection when a video track is selected
    if (provider.selectedVideoTrackIndex < 0) {
      print('⚠️ No video track selected for filter application');
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => FilterPicker(
        onFilterSelected: (filter) {
          final provider = Provider.of<VideoEditorProvider>(
            context,
            listen: false,
          );
          // Apply filter to the currently selected video track
          provider.setVideoTrackFilter(
            provider.selectedVideoTrackIndex,
            filter,
          );
        },
        filters: FilterManager.filters.keys.toList(),
        currentFilter:
            provider.videoTracks[provider.selectedVideoTrackIndex].filter,
      ),
    );
  }

  void _showCanvasRatioDialog() {
    final provider = Provider.of<VideoEditorProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            'Select Canvas Ratio',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: CanvasRatio.values.map((ratio) {
              final isSelected = provider.selectedCanvasRatio == ratio;
              return ListTile(
                leading: Icon(
                  Icons.aspect_ratio,
                  color: isSelected ? Colors.blue : Colors.white70,
                ),
                title: Text(
                  ratio.displayName,
                  style: TextStyle(
                    color: isSelected ? Colors.blue : Colors.white,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing:
                    isSelected ? Icon(Icons.check, color: Colors.blue) : null,
                onTap: () {
                  provider.setSelectedCanvasRatio(ratio);
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showCaptionEditor() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CaptionEditor(
        onCaptionAdded: (VideoCaption caption) =>
            Provider.of<VideoEditorProvider>(
          context,
          listen: false,
        ).addCaption(caption),
      ),
    );
  }

  void _showCropDialog(BuildContext context) {
    final provider = Provider.of<VideoEditorProvider>(context, listen: false);

    if (provider.videoEditorController == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video not ready for cropping')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Center(
        child: Dialog(
          child: Container(
            width: 300,
            height: 400,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: ClipRect(
                    child: CropView(
                      controller: provider.videoEditorController!.video,
                      onCropChanged: provider.updateCropRect,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        await provider.applyCrop();
                        // provider.applyCrop();
                        Navigator.pop(context);
                      },
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> getAllMedia(BuildContext context) async {
    PermissionStatus permissionStatus = await getGalleryPermission();
    if (permissionStatus.isGranted) {
      permissionStatus = await Permission.photos.request();
    }

    int? selectedMediaFileIndex;
    AssetEntity? selectedMediaFile;

    await showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      builder: (context) {
        return Consumer<AssetController>(
          builder: (context, provider, _) {
            return StatefulBuilder(
              builder: (context, setState) {
                return Container(
                  margin: EdgeInsets.only(top: kToolbarHeight),
                  height:
                      MediaQuery.of(context).size.height - (kToolbarHeight * 0),
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(10.0),
                    ),
                  ),
                  child: Scaffold(
                    appBar: AppBar(
                      automaticallyImplyLeading: false,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(10.0),
                        ),
                      ),
                      centerTitle: false,
                      title: SizedBox(
                        height: 40,
                        child: FittedBox(
                          child: DropdownMenu(
                            initialSelection: provider.requestType,
                            width: 300,
                            trailingIcon: const Icon(
                              Icons.keyboard_arrow_down,
                              size: 50,
                            ),
                            textStyle: const TextStyle(fontSize: 30.0),
                            inputDecorationTheme: const InputDecorationTheme(
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide.none,
                              ),
                            ),
                            dropdownMenuEntries: const [
                              DropdownMenuEntry(
                                value: RequestType.common,
                                label: 'All',
                              ),
                              DropdownMenuEntry(
                                value: RequestType.video,
                                label: 'Videos',
                              ),
                              DropdownMenuEntry(
                                value: RequestType.image,
                                label: 'Images',
                              ),
                            ],
                            onSelected: (value) {
                              if (provider.requestType == value) return;
                              provider.updateLoading(true);
                              provider.updateRequestType(
                                value ?? RequestType.common,
                              );
                              provider.getAssets();
                            },
                          ),
                        ),
                      ),
                      actions: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    body: LazyLoadScrollView(
                      onEndOfPage: () async => await provider.loadMoreAssets(),
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          children: [
                            GridView.builder(
                              shrinkWrap: true,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisExtent: 150,
                                childAspectRatio: 0.75,
                              ),
                              itemCount: provider.allMediaFiles.length,
                              physics: const ScrollPhysics(),
                              itemBuilder: (context, index) {
                                final element = provider.allMediaFiles[index];
                                return GestureDetector(
                                  onTap: () async {
                                    selectedMediaFileIndex = index;
                                    selectedMediaFile = element;
                                    setState(() {});
                                  },
                                  child: Stack(
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.all(4.0),
                                        decoration: selectedMediaFileIndex ==
                                                index
                                            ? BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(4.0),
                                                border: Border.all(
                                                  width: 4.0,
                                                  color: Colors.blueAccent,
                                                ),
                                              )
                                            : const BoxDecoration(),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          alignment: Alignment.center,
                                          children: [
                                            Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    1.0,
                                                  ),
                                                  child: GalleryThumbnail(
                                                    asset: element,
                                                    thumbFuture: provider
                                                        .thumbnailUint8List(
                                                      element,
                                                    ),
                                                  ),
                                                ),
                                                element.type == AssetType.video
                                                    ? const Icon(
                                                        Icons.play_arrow_sharp,
                                                        size: 80.0,
                                                      )
                                                    : context.shrink(),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Center(
                                        child: selectedMediaFileIndex == index
                                            ? const CircleAvatar(
                                                radius: 24.0,
                                                child: Center(
                                                  child: Icon(
                                                    Icons.check_circle,
                                                    size: 40.0,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              )
                                            : context.shrink(),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            if (!provider.isLastPage)
                              Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else
                              SizedBox.shrink(),
                          ],
                        ),
                      ),
                    ),
                    floatingActionButton: selectedMediaFile == null
                        ? SizedBox()
                        : FloatingActionButton(
                            onPressed: () async {
                              File? tempFile = await selectedMediaFile?.file;
                              if (tempFile != null) {
                                final provider =
                                    context.read<VideoEditorProvider>();
                                final duration = await provider
                                    .getMediaDuration(tempFile.path);
                                provider.addVideoTrack(
                                    tempFile, tempFile, duration);
                                Navigator.pop(context);
                              }
                            },
                            backgroundColor: Colors.blueAccent,
                            shape: const CircleBorder(),
                            child: const Icon(Icons.check, color: Colors.white),
                          ),
                  ),
                );
              },
            );
          },
        );
      },
    );
    return;
  }

  Future<void> _exportVideo(BuildContext context) async {
    final provider = context.read<VideoEditorProvider>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ExportProgressDialog(),
    );

    try {
      String outputPath = await _getOutputPath();
      String? exportedPath;

      // Calculate the same container size used in UI rendering
      final deviceWidth = MediaQuery.of(context).size.width;
      final containerHeight = _measuredContainerSize?.height ?? 400.0;
      final previewContainerSize = Size(deviceWidth, containerHeight);
      final expectedPreviewCanvas = provider.selectedCanvasRatio
          .getOptimalCanvasSize(previewContainerSize);
      final exportCanvas = provider.selectedCanvasRatio.exportSize;
      final expectedScaleFactor =
          exportCanvas.width / expectedPreviewCanvas.width;

      print('🎬 Export - Container size calculation:');
      print('   Device width: $deviceWidth');
      print('   Container height: $containerHeight');
      print(
          '   Preview container: ${previewContainerSize.width}x${previewContainerSize.height}');
      print(
          '   Expected preview canvas: ${expectedPreviewCanvas.width}x${expectedPreviewCanvas.height}');
      print('   Export canvas: ${exportCanvas.width}x${exportCanvas.height}');
      print(
          '   Expected scale factor: ${expectedScaleFactor.toStringAsFixed(3)}x');

      // Always use sequential canvas export for all scenarios
      // Transitions are now asset-wise (stored in VideoTrackModel.transitionToNext)
      exportedPath = await VideoExportManager.exportSequentialCanvas(
        context,
        outputPath: outputPath,
        videoTracks: provider.videoTracks,
        textTracks: provider.textTracks,
        canvasSize:
            previewContainerSize, // ← Changed from exportSize to previewContainerSize
        canvasRatio: provider.selectedCanvasRatio,
        editorProvider: provider,
      );

      Navigator.pop(context); // Close progress dialog

      // Navigate directly to video result page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SimpleVideoResult(
            videoFilePath: exportedPath ?? outputPath,
            betterPlayerDataSourceType: FileDataSourceType.file,
          ),
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      _showExportErrorDialog(context, e.toString());
    }
  }

  /// Focused cleanup for canvas-based preview system
  Future<void> _performCanvasCleanup() async {
    try {
      print('🧹 Starting canvas-based resource cleanup...');

      // 1. Cancel active FFmpeg sessions (critical for memory and CPU)
      final sessions = await FFmpegKit.listSessions();
      if (sessions.isNotEmpty) {
        await FFmpegKit.cancel();
        print('✅ Canceled ${sessions.length} FFmpeg sessions');
      } else {
        print('✅ No active FFmpeg sessions found');
      }

      // 2. Clear memory cache systems
      TextPainterManager.clearCache();
      UnifiedCoordinateSystem.clearCache();
      print('✅ Cleared text and coordinate caches');

      // 3. Clean thumbnail files if any were generated
      await _cleanupThumbnailFiles();
      print('✅ Cleaned thumbnail files');

      print('🧹 Canvas cleanup completed successfully');
    } catch (e) {
      print('❌ Canvas cleanup error: $e');
      // Don't rethrow - cleanup errors shouldn't block navigation
    }
  }

  /// Clean up thumbnail files generated during timeline scrubbing
  Future<void> _cleanupThumbnailFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();
      int cleanedCount = 0;

      for (var file in files) {
        if (file is File) {
          final fileName = file.path.split('/').last;
          // Clean video editor related thumbnail files
          if (fileName.contains('_thumbnail') && fileName.endsWith('.jpg')) {
            await file.delete();
            cleanedCount++;
          }
        }
      }

      if (cleanedCount > 0) {
        print('🗑️ Cleaned $cleanedCount thumbnail files');
      }
    } catch (e) {
      print('⚠️ Thumbnail cleanup error: $e');
      // Non-critical error, continue cleanup
    }
  }

  /// Build sequential video player - shows only current video based on timeline
  Widget _buildSequentialVideoPlayer(VideoEditorProvider provider,
      double deviceWidth, double containerHeight) {
    // Get current video and position from master timeline controller
    final (currentTrack, positionInVideo) =
        provider.masterTimelineController.getCurrentVideoAndPosition();

    if (currentTrack == null) {
      // No video at current position
      return Container(
        width: deviceWidth,
        height: containerHeight,
        color: Colors.black,
        child: const Center(
          child: Text('No video at current time',
              style: TextStyle(color: Colors.white)),
        ),
      );
    }

    // Get video controller for current track
    final controller = provider.getVideoControllerForTrack(currentTrack.id);

    if (controller == null || !controller.video.value.isInitialized) {
      final currentTrackIndex = provider.videoTracks.indexOf(currentTrack);
      return Container(
        width: deviceWidth,
        height: containerHeight,
        color: Colors.black,
        child: Center(
          child: Text('Loading video ${currentTrackIndex + 1}...',
              style: const TextStyle(color: Colors.white)),
        ),
      );
    }

    // Get the dynamic canvas size that fits optimally in the container
    final previewContainerSize = Size(deviceWidth, containerHeight);
    final dynamicCanvasSize =
        provider.selectedCanvasRatio.getOptimalCanvasSize(previewContainerSize);
    final isSelected = provider.selectedMediaId == currentTrack.id;

    // Create CanvasConfiguration for dual canvas system
    final canvasConfig = CanvasConfiguration.fromContainer(
      containerSize: previewContainerSize,
      canvasRatio: provider.selectedCanvasRatio,
    );

    print('🎯 Created CanvasConfiguration in video_editor_page_updated:');
    print(
        '   Preview canvas: ${canvasConfig.previewCanvasSize.width}x${canvasConfig.previewCanvasSize.height}');
    print(
        '   Export canvas: ${canvasConfig.exportCanvasSize.width}x${canvasConfig.exportCanvasSize.height}');
    print('   Scale factor: ${canvasConfig.scaleFactor.toStringAsFixed(3)}x');

    // Use TransitionAwareCanvasRenderer with transition support (wraps MediaCanvasRenderer)
    return Container(
      width: deviceWidth,
      height: containerHeight,
      color: Colors.black,
      child: TransitionAwareCanvasRenderer(
        videoTracks: provider.videoTracks,
        videoControllers: provider.videoControllers,
        transitionState:
            provider.masterTimelineController.currentTransitionState,
        fixedCanvasSize: dynamicCanvasSize,
        previewContainerSize: previewContainerSize,
        textTracks: provider.textTracks,
        currentTime: provider.videoPosition,
        onTextTrackUpdate: (index, updatedTrack) {
          print('🔄 Updating text track $index via provider');
          provider.updateTextTrackModel(index, updatedTrack);
        },
        onTrackUpdate: (updatedTrack) =>
            provider.updateVideoTrackFromModel(updatedTrack),
        onTap: () {
          // Handle video selection when tapped (works on current visible track)
          if (!isSelected) {
            provider.selectMediaForManipulation(currentTrack.id);
          }
        },
        canvasConfiguration: canvasConfig,
        selectedVideoTrackIndex: provider.selectedVideoTrackIndex,
      ),
    );
  }

  // Timeline dragging gesture handlers with conflict detection
  void _onTimelinePanStart(DragStartDetails details) {
    _isDraggingTimeline = true;
    _lastPanPosition = details.globalPosition.dx;
  }

  void _onTimelinePanUpdate(DragUpdateDetails details) {
    if (!_isDraggingTimeline || _lastPanPosition == null) return;

    final provider = Provider.of<VideoEditorProvider>(context, listen: false);

    // Calculate the delta movement
    final currentPosition = details.globalPosition.dx;
    final deltaX = currentPosition - _lastPanPosition!;
    _lastPanPosition = currentPosition;

    // Convert delta to scroll offset change with sensitivity adjustment
    // Negative deltaX means dragging left (should scroll right)
    // Positive deltaX means dragging right (should scroll left)
    // Apply sensitivity multiplier to reduce timeline indicator speed
    const double sensitivity = 0.3; // Reduce to 50% of original speed
    final scrollDelta = -deltaX * sensitivity;

    // Apply scroll to all linked controllers with proper boundary checking
    final controllers = [
      provider.videoScrollController,
      provider.audioScrollController,
      provider.textScrollController,
      provider.bottomScrollController,
    ];

    for (final controller in controllers) {
      if (controller?.hasClients == true) {
        final currentOffset = controller!.offset;
        final maxScrollExtent = controller.position.maxScrollExtent;

        // Calculate new offset with proper clamping
        final newOffset =
            (currentOffset + scrollDelta).clamp(0.0, maxScrollExtent);

        // Additional check: prevent scrolling beyond 95% of max extent to keep indicator visible
        final safeMaxExtent = maxScrollExtent * 0.95;
        final safeOffset = newOffset.clamp(0.0, safeMaxExtent);

        // Use jumpTo for immediate response during dragging
        controller.jumpTo(safeOffset);
      }
    }

    // Update the master timeline position based on the new scroll position
    if (provider.videoScrollController?.hasClients == true) {
      final scrollController = provider.videoScrollController!;
      provider.masterTimelineController.seekFromScroll(
        scrollController.offset,
        scrollController.position.maxScrollExtent,
      );
      // The provider will be notified through the master timeline controller's callback
    }
  }

  void _onTimelinePanEnd(DragEndDetails details) {
    _isDraggingTimeline = false;
    _lastPanPosition = null;
  }
}

Future<String> _getOutputPath() async {
  final dir = await getApplicationDocumentsDirectory();
  return '${dir.path}/export_${DateTime.now().millisecondsSinceEpoch}.mp4';
}

void _showExportErrorDialog(BuildContext context, String error) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Export Failed'),
      content: const Text('Export failed, try again'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

class BottomSheetWrapper extends StatelessWidget {
  final Widget child;

  const BottomSheetWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: ColorConstants.primaryColor,
      margin: EdgeInsets.zero,
      child: child,
    );
  }
}

class _StackedVideoPreview extends StatefulWidget {
  final List<VideoTrackModel> videoTracks;
  const _StackedVideoPreview({required this.videoTracks});
  @override
  State<_StackedVideoPreview> createState() => _StackedVideoPreviewState();
}

class _StackedVideoPreviewState extends State<_StackedVideoPreview> {
  int _currentIndex = 0;
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(covariant _StackedVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoTracks[_currentIndex].processedFile.path !=
        widget.videoTracks[_currentIndex].processedFile.path) {
      _initController();
    }
  }

  Future<void> _initController() async {
    _controller?.dispose();
    _controller = VideoPlayerController.file(
      widget.videoTracks[_currentIndex].processedFile,
    );
    await _controller!.initialize();
    setState(() {
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CupertinoActivityIndicator(radius: 20));
    }
    return Column(
      children: [
        AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous, color: Colors.white),
              onPressed: _currentIndex > 0
                  ? () {
                      setState(() {
                        _currentIndex--;
                        _isInitialized = false;
                      });
                      _initController();
                    }
                  : null,
            ),
            IconButton(
              icon: Icon(
                _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  if (_controller!.value.isPlaying) {
                    _controller!.pause();
                  } else {
                    _controller!.play();
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.skip_next, color: Colors.white),
              onPressed: _currentIndex < widget.videoTracks.length - 1
                  ? () {
                      setState(() {
                        _currentIndex++;
                        _isInitialized = false;
                      });
                      _initController();
                    }
                  : null,
            ),
          ],
        ),
        Text(
          'Video ${_currentIndex + 1} of ${widget.videoTracks.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }
}

class _SmoothRotatableText extends StatefulWidget {
  final TextTrackModel track;
  final VideoEditorProvider provider;
  final bool? isRotating;
  final Function(bool)? onSetRotating;
  final double? availableWidth;
  final double? availableHeight;
  final double previewFontSize; // NEW: required font size from parent

  const _SmoothRotatableText({
    required this.track,
    required this.provider,
    this.isRotating,
    this.onSetRotating,
    this.availableWidth,
    this.availableHeight,
    required this.previewFontSize, // NEW: required
    Key? key,
  }) : super(key: key);
  @override
  State<_SmoothRotatableText> createState() => _SmoothRotatableTextState();
}

class _SmoothRotatableTextState extends State<_SmoothRotatableText>
    with SingleTickerProviderStateMixin {
  Offset? _cachedCenter;
  double? _tempRotation;
  Timer? _throttleTimer;
  late AnimationController _animController;
  late Animation<double> _rotationAnim;
  double? _animStart;
  double? _animEnd;
  bool _isRotating = false;

  @override
  void initState() {
    super.initState();
    _animController =
        AnimationController(vsync: this, duration: Duration(milliseconds: 150));
    _rotationAnim = Tween<double>(begin: 0, end: 0).animate(_animController);
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  /// Calculate the bounding box dimensions for rotated text
  static Map<String, double> calculateRotatedTextBounds({
    required double textWidth,
    required double textHeight,
    required double rotation,
  }) {
    if (rotation == 0) {
      return {
        'width': textWidth,
        'height': textHeight,
        'offsetX': 0.0,
        'offsetY': 0.0,
      };
    }

    final angleRad = rotation * math.pi / 180.0;
    final cosAngle = math.cos(angleRad);
    final sinAngle = math.sin(angleRad);

    // Calculate the corners of the original rectangle
    final corners = [
      [0.0, 0.0], // top-left
      [textWidth, 0.0], // top-right
      [textWidth, textHeight], // bottom-right
      [0.0, textHeight], // bottom-left
    ];

    // Rotate each corner and find the bounding box
    double minX = double.infinity;
    double maxX = -double.infinity;
    double minY = double.infinity;
    double maxY = -double.infinity;

    for (final corner in corners) {
      final x = corner[0];
      final y = corner[1];

      // Rotate the point
      final rotatedX = x * cosAngle - y * sinAngle;
      final rotatedY = x * sinAngle + y * cosAngle;

      minX = math.min(minX, rotatedX);
      maxX = math.max(maxX, rotatedX);
      minY = math.min(minY, rotatedY);
      maxY = math.max(maxY, rotatedY);
    }

    // Calculate the dimensions of the bounding box
    final rotatedWidth = (maxX - minX).ceil().toDouble();
    final rotatedHeight = (maxY - minY).ceil().toDouble();

    // Calculate the offset needed to position the rotated text correctly
    final offsetX = (rotatedWidth - textWidth) / 2.0;
    final offsetY = (rotatedHeight - textHeight) / 2.0;

    return {
      'width': rotatedWidth,
      'height': rotatedHeight,
      'offsetX': offsetX,
      'offsetY': offsetY,
    };
  }

  void _cacheCenter(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final size = box.size;
    final center = box.localToGlobal(Offset(size.width / 2, size.height / 2));
    _cachedCenter = center;
  }

  void _throttledUpdate(double angle) {
    _throttleTimer?.cancel();
    setState(() {
      _tempRotation = angle;
    });
    _throttleTimer = Timer(Duration(milliseconds: 16), () {
      final updatedTrack = widget.track.copyWith(rotation: angle);
      final index = widget.provider.textTracks.indexOf(widget.track);
      widget.provider.updateTextTrackModel(index, updatedTrack);
    });
  }

  void _animateToFinal(double from, double to) {
    _rotationAnim = Tween<double>(begin: from, end: to).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final rotation = _tempRotation ?? widget.track.rotation;
    // Use only the passed previewFontSize for TextStyle
    final previewFontSize = widget.previewFontSize;
    final textStyle = TextStyle(
      color: widget.track.textColor,
      fontSize: previewFontSize,
      fontFamily: widget.track.fontFamily,
      height: 1, // Ensure consistent line height
    );

    // Use the available width and height for constraints
    double availableWidth = widget.availableWidth ?? 200;
    double availableHeight = widget.availableHeight ?? 100;

    // Debug: Print what's being rendered
    print('=== _SmoothRotatableText Rendering Debug ===');
    print('Track text: "${widget.track.text}"');
    print(
        'Available width: $availableWidth, Available height: $availableHeight');
    print('Font size: $previewFontSize');
    print(
        'Text style for rendering: fontSize=${textStyle.fontSize}, fontFamily=${textStyle.fontFamily}');
    print('Text color: ${widget.track.textColor}');
    print(
        'Container constraints: maxWidth=$availableWidth, maxHeight=$availableHeight');
    print('=== End Rendering Debug ===');

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final angle =
            _animController.isAnimating ? _rotationAnim.value : rotation;
        return Transform.rotate(
          angle: angle * math.pi / 180,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none, // Allow rotation handle to be visible
            children: [
              // 1. The auto-wrapped text at (0,0), constrained by available width
              ClipRect(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: availableWidth,
                    maxHeight: availableHeight,
                  ),
                  child: Text(
                    widget.track
                        .text, // Use the original text, let it wrap naturally
                    style: textStyle.copyWith(
                      height: 1,
                      shadows: [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 2,
                          color: Colors.black.withOpacity(0.7),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.left, // Ensure left alignment
                    softWrap: true, // Enable natural text wrapping
                    overflow: TextOverflow.clip, // Clip text that overflows
                  ),
                ),
              ),
              // 2. The border box, constrained by available width
              Positioned(
                left: -4,
                top: -4,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: availableWidth + 8, // Add padding
                    maxHeight: availableHeight + 8,
                  ),
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: _isRotating
                            ? Colors.red
                            : Colors.white.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.track.text, // Use the original text for sizing
                    style: textStyle.copyWith(
                      color: Colors.transparent, // Only for sizing
                      height: 1,
                    ),
                    textAlign: TextAlign.left, // Ensure left alignment
                    softWrap: true, // Enable natural text wrapping
                    overflow: TextOverflow.clip, // Clip text that overflows
                  ),
                ),
              ),
              // 3. Rotation handle, positioned above the box
              Positioned(
                top: -22,
                child: GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      _isRotating = true;
                    });
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _cacheCenter(context));
                    _tempRotation = widget.track.rotation;
                  },
                  onPanUpdate: (details) {
                    if (_cachedCenter == null) return;
                    final touch = details.globalPosition;
                    final delta = touch - _cachedCenter!;
                    final angleRad = math.atan2(delta.dy, delta.dx);
                    final angleDeg = angleRad * 180 / math.pi;
                    final normalized = angleDeg < 0 ? angleDeg + 360 : angleDeg;
                    _throttledUpdate(normalized);
                  },
                  onPanEnd: (details) {
                    _throttleTimer?.cancel();
                    final finalRot =
                        _tempRotation ?? widget.track.rotation ?? 0;
                    final modelRot = widget.track.rotation ?? 0;
                    _animateToFinal(finalRot, modelRot);
                    _tempRotation = null;
                    _cachedCenter = null;
                    setState(() {
                      _isRotating = false;
                    });
                  },
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: _isRotating ? Colors.red : Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 0),
                    ),
                    child:
                        Icon(Icons.rotate_right, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
