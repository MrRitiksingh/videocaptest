import 'package:ai_video_creator_editor/screens/project/new_editor/video_editor_provider.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/video_track.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/transition_button.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/transition_picker.dart';
import 'package:ai_video_creator_editor/screens/project/models/video_track_model.dart';
import 'package:ai_video_creator_editor/enums/track_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:reorderables/reorderables.dart';

class VideoTimeline extends StatefulWidget {
  final VideoPlayerController? controller;
  final ScrollController? videoScrollController;

  const VideoTimeline({
    super.key,
    required this.controller,
    required this.videoScrollController,
  });

  @override
  State<VideoTimeline> createState() => _VideoTimelineState();
}

const List<TransitionType> limitedTransitions = [
  TransitionType.none,
  TransitionType.fade,
  TransitionType.fadeblack,
  TransitionType.fadewhite,
  TransitionType.fadegrays,
  TransitionType.slideleft,
  TransitionType.slideright,
  TransitionType.slideup,
];


class _VideoTimelineState extends State<VideoTimeline>
    with AutomaticKeepAliveClientMixin {
  double? _lastTouchPositionX; // Store last touch X position for reorder mode
  ScrollController?
      _reorderScrollController; // Separate controller for ReorderableRow
  bool _scrollSyncListenerAttached =
      false; // Track if scroll sync listener is active

  @override
  void initState() {
    _reorderScrollController =
        ScrollController(); // Initialize separate controller
    // Set up scroll listener for manual timeline scrolling
    widget.videoScrollController
        ?.removeListener(_onScrollToUpdateVideoPosition);
    widget.videoScrollController?.addListener(() {
      if (widget.videoScrollController?.position.isScrollingNotifier.value ??
          false) {
        _onScrollToUpdateVideoPosition();
      }
    });

    // Set up position update listener for playback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupPlaybackListener();
    });

    super.initState();
  }

  void _setupPlaybackListener() {
    final provider = Provider.of<VideoEditorProvider>(context, listen: false);

    // Store the original callback to preserve provider's notifyListeners
    final originalCallback =
        provider.masterTimelineController.onPositionChanged;

    // Chain callbacks instead of overriding
    provider.masterTimelineController.onPositionChanged = () {
      // Call original callback first (triggers notifyListeners in provider)
      originalCallback?.call();

      // Then do our timeline-specific logic
      if (provider.masterTimelineController.isPlaying) {
        _onPlayScrollToCurrentVideoPosition();
      }
    };
  }

  Future<void> _onScrollToUpdateVideoPosition() async {
    if (!mounted || widget.videoScrollController?.hasClients != true) return;

    final provider = Provider.of<VideoEditorProvider>(context, listen: false);

    // Skip if currently editing video track - let parent pan gesture control scrolling
    if (provider.isEditingTrackType(TrackType.video)) return;

    final scrollController = widget.videoScrollController!;

    // Update master timeline position based on scroll
    provider.masterTimelineController.seekFromScroll(
      scrollController.offset,
      scrollController.position.maxScrollExtent,
    );
  }

  void _onPlayScrollToCurrentVideoPosition() {
    if (!mounted || widget.videoScrollController?.hasClients != true) return;

    final provider = Provider.of<VideoEditorProvider>(context, listen: false);
    final scrollController = widget.videoScrollController!;

    // Get target scroll position from master timeline
    final double targetOffset =
        provider.masterTimelineController.getScrollOffset(
      scrollController.position.maxScrollExtent,
    );

    // Only update if there's a significant difference to avoid jitter
    if ((targetOffset - scrollController.offset).abs() > 1) {
      scrollController.jumpTo(targetOffset);
    }
  }

  /// Setup scroll sync between main and reorder scroll controllers
  void _setupReorderScrollSync() {
    if (_scrollSyncListenerAttached) return;

    widget.videoScrollController?.addListener(_syncReorderScroll);
    _scrollSyncListenerAttached = true;
    print('✅ Reorder scroll sync listener attached');
  }

  /// Teardown scroll sync listener
  void _teardownReorderScrollSync() {
    if (!_scrollSyncListenerAttached) return;

    widget.videoScrollController?.removeListener(_syncReorderScroll);
    _scrollSyncListenerAttached = false;
    print('🔴 Reorder scroll sync listener removed');
  }

  /// Sync scroll position from main controller to reorder controller
  void _syncReorderScroll() {
    if (_reorderScrollController?.hasClients == true &&
        widget.videoScrollController?.hasClients == true) {
      final offset = widget.videoScrollController!.offset;
      if ((_reorderScrollController!.offset - offset).abs() > 0.1) {
        _reorderScrollController!.jumpTo(offset);
      }
    }
  }

  @override
  void dispose() {
    _teardownReorderScrollSync(); // Cleanup scroll sync listener
    widget.videoScrollController
        ?.removeListener(_onScrollToUpdateVideoPosition);
    _reorderScrollController?.dispose(); // Dispose separate controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final width = MediaQuery.of(context).size.width;
    return Consumer<VideoEditorProvider>(
      builder: (context, provider, child) {
        // Calculate timeline width based on mode
        double timelineWidth = 0.0;

        if (provider.isReorderMode) {
          // REORDER MODE: All tracks are compact boxes (1 second width each)
          final compactWidth = width / 8;
          timelineWidth = provider.videoTracks.length * compactWidth;
        } else {
          // NORMAL MODE: Sum of individual track widths based on duration
          for (int i = 0; i < provider.videoTracks.length; i++) {
            final track = provider.videoTracks[i];

            // Use visual stretch duration if this track is actively stretching
            final effectiveDuration = (provider.isAnyTrackStretching && provider.activeStretchTrackIndex == i)
                ? provider.activeStretchVisualDuration  // Use in-progress stretch
                : (track.isImageBased && track.customDuration != null)
                    ? track.customDuration!
                    : track.totalDuration.toDouble();

            timelineWidth += (width / 8) * effectiveDuration;
          }
        }

        // Fallback for empty tracks
        if (provider.videoTracks.isEmpty) {
          timelineWidth = 100.0; // Minimum width for empty timeline
        }

        // Debug logging (can be removed later)
        final providerDuration = provider.videoDuration;
        final providerWidth = providerDuration * (width / 8);
        final oldMargin = width * 0.1; // Previous margin
        final newMargin = width / 2; // Timeline margin for scrollability
        print('🎯 TIMELINE WIDTH & MARGIN FIX:');
        print(
            '   Provider videoDuration: ${providerDuration}s (width: ${providerWidth.toStringAsFixed(1)}px)');
        print(
            '   Fixed timeline width: ${timelineWidth.toStringAsFixed(1)}px (sum of tracks)');
        print(
            '   Old margin: ${oldMargin.toStringAsFixed(1)}px (10% of screen)');
        print(
            '   New margin: ${newMargin.toStringAsFixed(1)}px (fixed padding)');
        print(
            '   Total space saved: ${(providerWidth - timelineWidth + oldMargin - newMargin).toStringAsFixed(1)}px');

        // Auto-scroll to center compact boxes at touch point when entering reorder mode
        // DISABLED FOR TESTING - User wants to test without auto-scroll
        // if (provider.isReorderMode && provider.reorderTouchPositionX != null) {
        //   WidgetsBinding.instance.addPostFrameCallback((_) {
        //     _scrollToTouchPoint(provider.reorderTouchPositionX!, width);
        //   });
        // }

        // REORDERABLE ROW: Use reorderables package for smooth CapCut-style animations
        return Container(
          margin: EdgeInsets.only(right: newMargin),
          width: timelineWidth,
          child: provider.isReorderMode
              ? _buildReorderableRow(provider, width)
              : _buildNormalRow(provider, width),
        );
      },
    );
  }

  /// Build reorderable row for smooth CapCut-style drag animations
  Widget _buildReorderableRow(
      VideoEditorProvider provider, double screenWidth) {
    // ✅ Setup scroll sync listener once when entering reorder mode
    if (!_scrollSyncListenerAttached) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setupReorderScrollSync();
        // Initial sync to match current scroll position
        _syncReorderScroll();
      });
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // Tap outside items exits reorder mode
        print('🔚 Tap detected - exiting reorder mode');
        provider.finalizeReorder();
        provider.exitReorderMode();
      },
      child: ReorderableRow(
        scrollController: _reorderScrollController, // Use separate controller
        crossAxisAlignment: CrossAxisAlignment.center,
        onReorder: (int oldIndex, int newIndex) {
          print('🔄 Reordering: $oldIndex → $newIndex');
          provider.reorderVideoTracks(oldIndex, newIndex);
          HapticFeedback.mediumImpact();
          // Don't auto-exit - let user continue reordering or tap outside to exit
        },
        children: provider.videoTracks.asMap().entries.map((entry) {
          final videoTrack = entry.value;
          final index = entry.key;

          return VideoTrack(
            key: ValueKey(videoTrack.id), // REQUIRED for ReorderableRow
            videoTrack: videoTrack,
            index: index,
            isSelected: provider.selectedVideoTrackIndex == index,
            selectedTrackBorderColor: provider.selectedTrackBorderColor,
            isCompactMode: true, // Always compact in reorder mode
          );
        }).toList(),
      ),
    );
  }

  /// Build normal row with long-press gesture to enter reorder mode
  Widget _buildNormalRow(VideoEditorProvider provider, double screenWidth) {
    // ✅ Tear down scroll sync listener when exiting reorder mode
    if (_scrollSyncListenerAttached) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _teardownReorderScrollSync();
      });
    }

    return Stack(
      clipBehavior: Clip.none, // Allow transition buttons to overflow
      children: [
        // Row with video tracks (existing implementation)
        Row(
          children: provider.videoTracks.asMap().entries.map((entry) {
            final videoTrack = entry.value;
            final index = entry.key;

            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onLongPressStart: (details) {
                // ✅ Check if edit mode is active before attempting to enter reorder mode
                if (provider.isEditingTrack) {
                  print('⚠️ Long-press blocked: currently in edit mode');
                  HapticFeedback
                      .lightImpact(); // Lighter feedback for blocked action
                  return;
                }

                // Capture touch position and enter reorder mode
                _lastTouchPositionX = details.globalPosition.dx;
                print(
                    '📍 Long press at: $_lastTouchPositionX - entering reorder mode');
                provider.enterReorderMode(index,
                    touchPositionX: _lastTouchPositionX);
                HapticFeedback.heavyImpact();
              },
              child: VideoTrack(
                // ✅ Use consistent key strategy across both modes
                key: ValueKey(videoTrack.id),
                videoTrack: videoTrack,
                index: index,
                isSelected: provider.selectedVideoTrackIndex == index,
                selectedTrackBorderColor: provider.selectedTrackBorderColor,
                isCompactMode: false, // Full size in normal mode
              ),
            );
          }).toList(),
        ),

        // Overlay transition buttons at track boundaries
        ..._buildTransitionButtons(provider, screenWidth),
      ],
    );
  }

  /// Build transition buttons positioned at track boundaries
  /// Hides buttons when VIDEO track is in edit mode (trim sliders visible)
 List<Widget> _buildTransitionButtons(
    VideoEditorProvider provider, double screenWidth) {
  
  if (provider.videoTracks.isEmpty) return [];

  // Hide buttons during video edit & stretch
  if (provider.isEditingTrackType(TrackType.video)) return [];
  if (provider.isAnyVideoProcessing) return [];

  List<Widget> buttons = [];
  double cumulativeWidth = 0.0;

  /// -----------------------------------------------------------
  /// 1) ADD START TRANSITION BUTTON (trackIndex = -1)
  /// -----------------------------------------------------------
  buttons.add(
    Positioned(
      left: -16, // small negative offset so it appears at start
      top: 14,
      child: TransitionButton(
        trackIndex: -1,
        currentTransition: provider.getStartTransition(),
        onTap: () => _showTransitionPicker(context, provider, -1),
      ),
    ),
  );

  /// -----------------------------------------------------------
  /// 2) EXISTING MIDDLE TRANSITION BUTTONS
  /// -----------------------------------------------------------
  for (int i = 0; i < provider.videoTracks.length - 1; i++) {
    final track = provider.videoTracks[i];

    final effectiveDuration =
        track.isImageBased && track.customDuration != null
            ? track.customDuration!
            : track.totalDuration.toDouble();

    final trackWidth = (screenWidth / 8) * effectiveDuration;
    cumulativeWidth += trackWidth;

    buttons.add(
      Positioned(
        left: cumulativeWidth - 16,
        top: 14,
        child: TransitionButton(
          trackIndex: i,
          currentTransition: track.transitionToNext,
          onTap: () => _showTransitionPicker(context, provider, i),
        ),
      ),
    );
  }

  /// -----------------------------------------------------------
  /// 3) ADD END TRANSITION BUTTON (trackIndex = last index)
  /// -----------------------------------------------------------
  final lastIndex = provider.videoTracks.length - 1;

  buttons.add(
    Positioned(
      left: cumulativeWidth +
          ((screenWidth / 8) *
              (provider.videoTracks[lastIndex].isImageBased &&
                      provider.videoTracks[lastIndex].customDuration != null
                  ? provider.videoTracks[lastIndex].customDuration!
                  : provider.videoTracks[lastIndex].totalDuration.toDouble())) -
          16,
      top: 14,
      child: TransitionButton(
        trackIndex: lastIndex,
        currentTransition: provider.getEndTransition(),
       onTap: () => _showTransitionPicker(context, provider, lastIndex),
      ),
    ),
  );

  return buttons;
}

  /// Show transition picker modal for specific track gap
void _showTransitionPicker(
  BuildContext context,
  VideoEditorProvider provider,
  int trackIndex,
) {
  showModalBottomSheet(
    context: context,
    builder: (context) => TransitionPicker(
      trackIndex: trackIndex,
      currentTransition: trackIndex == -1
          ? provider.getStartTransition() ?? TransitionType.none
          : trackIndex == provider.videoTracks.length - 1
              ? provider.getEndTransition() ?? TransitionType.none
              : provider.videoTracks[trackIndex].transitionToNext ??
                  TransitionType.none,
      onTransitionSelected: (transition) {
        if (trackIndex == -1) {
          provider.setStartTransition(transition);
        } else if (trackIndex == provider.videoTracks.length - 1) {
          provider.setEndTransition(transition);
        } else {
          provider.setVideoTrackTransitionToNext(trackIndex, transition);
        }
      },
    ),
  );
}

void _showLimitedTransitionPicker(
  BuildContext context,
  VideoEditorProvider provider,
  int trackIndex,
) {
  showModalBottomSheet(
    context: context,
    builder: (context) => LimitedTransitionPicker(
      trackIndex: trackIndex,
      allowedTransitions: limitedTransitions,
      currentTransition: trackIndex == -1
          ? provider.getStartTransition() ?? TransitionType.none
          : trackIndex == provider.videoTracks.length - 1
              ? provider.getEndTransition() ?? TransitionType.none
              : provider.videoTracks[trackIndex].transitionToNext ??
                  TransitionType.none,
      onTransitionSelected: (transition) {
        if (trackIndex == -1) {
          provider.setStartTransition(transition);
        } else if (trackIndex == provider.videoTracks.length - 1) {
          provider.setEndTransition(transition);
        } else {
          provider.setVideoTrackTransitionToNext(trackIndex, transition);
        }
      },
    ),
  );
}



  /// Auto-scroll timeline to center compact boxes around touch point (CapCut-style)
  void _scrollToTouchPoint(double touchX, double screenWidth) {
    if (!mounted || widget.videoScrollController?.hasClients != true) return;

    final scrollController = widget.videoScrollController!;

    // touchX is global screen X position (distance from left edge of screen)
    // To center that screen position: scroll to (currentScroll + touchX - halfScreen)
    final targetOffset = scrollController.offset + touchX - (screenWidth / 2);

    // Clamp to valid scroll range
    final clampedOffset =
        targetOffset.clamp(0.0, scrollController.position.maxScrollExtent);

    print('📍 Auto-scroll:');
    print('   Touch at screen position: $touchX');
    print('   Current scroll: ${scrollController.offset}');
    print('   Target scroll: $clampedOffset');

    // Smooth scroll to position
    scrollController.animateTo(
      clampedOffset,
      duration: Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  bool get wantKeepAlive => true;
}
