import 'package:flutter/material.dart';
import 'package:ai_video_creator_editor/screens/project/models/video_track_model.dart';
import 'package:ai_video_creator_editor/screens/project/models/text_track_model.dart';
import 'package:ai_video_creator_editor/controllers/video_controller.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/master_timeline_controller.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/transition_preview_engine.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/canvas_configuration.dart';
import 'media_canvas_renderer.dart';

/// Wrapper for MediaCanvasRenderer that handles transition blending
///
/// This widget detects when playback is within a transition region and
/// automatically blends two video tracks using the TransitionPreviewEngine.
class TransitionAwareCanvasRenderer extends StatelessWidget {
  final List<VideoTrackModel> videoTracks;
  final Map<String, VideoEditorController> videoControllers;
  final TransitionPlaybackState transitionState;
  final Size fixedCanvasSize;
  final Size previewContainerSize;
  final List<TextTrackModel> textTracks;
  final double currentTime;
  final Function(int, TextTrackModel)? onTextTrackUpdate;
  final Function(VideoTrackModel)? onTrackUpdate;
  final VoidCallback? onTap;
  final CanvasConfiguration? canvasConfiguration;
  final int? selectedVideoTrackIndex;

  const TransitionAwareCanvasRenderer({
    Key? key,
    required this.videoTracks,
    required this.videoControllers,
    required this.transitionState,
    required this.fixedCanvasSize,
    required this.previewContainerSize,
    required this.textTracks,
    required this.currentTime,
    this.onTextTrackUpdate,
    this.onTrackUpdate,
    this.onTap,
    this.canvasConfiguration,
    this.selectedVideoTrackIndex,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Log transition state for debugging
    if (transitionState.isInTransition) {
      print('🎬 TransitionAwareCanvasRenderer state:');
      print('   isInTransition: ${transitionState.isInTransition}');
      print(
          '   transitionType: ${transitionState.transitionType?.name ?? "null"}');
      print(
          '   progress: ${(transitionState.progress * 100).toStringAsFixed(1)}%');
      print(
          '   fromTrack: ${transitionState.fromTrackIndex}, toTrack: ${transitionState.toTrackIndex}');
    }

    // START TRANSITION (START → first track)
    if (transitionState.isInTransition &&
        transitionState.fromTrackIndex == -1 &&
        transitionState.toTrackIndex == 0) {
      print("🎬 Rendering START transition (fade-in)");

      // Black screen as the 'from' layer
      final blackScreen = Container(color: Colors.black);

      final toTrack = videoTracks[0];
      final toController = videoControllers[toTrack.id];

      final toWidget = _buildCanvasRenderer(
        track: toTrack,
        controller: toController,
        key: ValueKey('start_to_${toTrack.id}'),
      );

      return TransitionPreviewEngine.applyTransition(
        fromWidget: blackScreen,
        toWidget: toWidget,
        transitionType: transitionState.transitionType!,
        progress: transitionState.progress,
      );
    }

// END TRANSITION (last track → END)
    if (transitionState.isInTransition &&
        transitionState.fromTrackIndex == videoTracks.length - 1 &&
        transitionState.toTrackIndex == -1) {
      print("🎬 Rendering END transition (fade-out)");

      final fromTrack = videoTracks.last;
      final fromController = videoControllers[fromTrack.id];

      final fromWidget = _buildCanvasRenderer(
        track: fromTrack,
        controller: fromController,
        key: ValueKey('end_from_${fromTrack.id}'),
      );

      // Black screen as the 'to' layer
      final blackScreen = Container(color: Colors.black);

      return TransitionPreviewEngine.applyTransition(
        fromWidget: fromWidget,
        toWidget: blackScreen,
        transitionType: transitionState.transitionType!,
        progress: transitionState.progress,
      );
    }

    // Check if we're in a transition
    if (transitionState.isInTransition &&
        transitionState.transitionType != null &&
        transitionState.fromTrackIndex >= 0 &&
        transitionState.toTrackIndex < videoTracks.length) {
      print(
          '🎬 Rendering TRANSITION: ${transitionState.transitionType!.name} (${(transitionState.progress * 100).toStringAsFixed(1)}%)');

      return _buildTransitionBlend(context);
    } else {
      // Normal rendering: just display the current video track
      final currentTrack = _getCurrentVideoTrack();

      if (currentTrack == null) {
        print('⚠️ No current video track found at time $currentTime');
        return _buildNoVideoPlaceholder();
      }

      final trackIndex = videoTracks.indexWhere((t) => t.id == currentTrack.id);
      print(
          '📹 Rendering normal (single track): Track $trackIndex at ${currentTime.toStringAsFixed(2)}s');

      return _buildSingleVideoRenderer(currentTrack);
    }
  }

  /// Build transition blend of two videos
  Widget _buildTransitionBlend(BuildContext context) {
    final fromTrack = videoTracks[transitionState.fromTrackIndex];
    final toTrack = videoTracks[transitionState.toTrackIndex];
    final fromController = videoControllers[fromTrack.id];
    final toController = videoControllers[toTrack.id];

    // Build widgets for both videos
    final fromWidget = _buildCanvasRenderer(
      track: fromTrack,
      controller: fromController,
      key: ValueKey('from_${fromTrack.id}'),
    );

    final toWidget = _buildCanvasRenderer(
      track: toTrack,
      controller: toController,
      key: ValueKey('to_${toTrack.id}'),
    );

    // Apply transition effect
    return TransitionPreviewEngine.applyTransition(
      fromWidget: fromWidget,
      toWidget: toWidget,
      transitionType: transitionState.transitionType!,
      progress: transitionState.progress,
    );
  }

  /// Build renderer for a single video (no transition)
  Widget _buildSingleVideoRenderer(VideoTrackModel track) {
    final controller = videoControllers[track.id];
    final trackIndex = videoTracks.indexWhere((t) => t.id == track.id);
    final isSelected = selectedVideoTrackIndex == trackIndex;

    return _buildCanvasRenderer(
      track: track,
      controller: controller,
      isSelected: isSelected,
      showHandles: isSelected,
    );
  }

  /// Build a MediaCanvasRenderer for a video track
  Widget _buildCanvasRenderer({
    required VideoTrackModel track,
    required VideoEditorController? controller,
    Key? key,
    bool isSelected = false,
    bool showHandles = false,
  }) {
    return MediaCanvasRenderer(
      key: key,
      track: track,
      controller: controller
          ?.video, // Extract VideoPlayerController from VideoEditorController
      fixedCanvasSize: fixedCanvasSize,
      previewContainerSize: previewContainerSize,
      isSelected: isSelected,
      showHandles: showHandles,
      onTrackUpdate: onTrackUpdate,
      textTracks: textTracks,
      currentTime: currentTime,
      onTextTrackUpdate: onTextTrackUpdate,
      onTap: onTap,
      canvasConfiguration: canvasConfiguration,
      filter: track.filter,
    );
  }

  /// Get the current video track based on timeline position
  VideoTrackModel? _getCurrentVideoTrack() {
    double cumulativeTime = 0.0;

    for (final track in videoTracks) {
      final trackEndTime = cumulativeTime + track.totalDuration;

      if (currentTime >= cumulativeTime && currentTime < trackEndTime) {
        return track;
      }

      cumulativeTime += track.totalDuration;
    }

    // If at the very end, return last track
    if (currentTime >= cumulativeTime - 0.1 && videoTracks.isNotEmpty) {
      return videoTracks.last;
    }

    return null;
  }

  /// Build placeholder when no video is available
  Widget _buildNoVideoPlaceholder() {
    return Container(
      width: previewContainerSize.width,
      height: previewContainerSize.height,
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, color: Colors.white54, size: 48),
            SizedBox(height: 8),
            Text(
              'No video',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
