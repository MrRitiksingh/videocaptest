import 'dart:async';

import 'package:ai_video_creator_editor/enums/track_type.dart';
import 'package:ai_video_creator_editor/enums/edit_operation.dart';
import 'package:ai_video_creator_editor/screens/project/models/text_track_model.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/custom_trim_slider.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/text_style_editor.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/video_editor_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

class TextTrack extends StatefulWidget {
  const TextTrack({
    super.key,
    required this.textTrack,
    required this.index,
    required this.isSelected,
    required this.timelineWidth,
    required this.timelineDuration,
    required this.selectedTrackBorderColor,
    this.previewHeight,
    required this.laneIndex, // NEW: Lane context
    required this.laneHeight, // NEW: Dynamic lane height
  });

  final TextTrackModel textTrack;
  final int index;
  final bool isSelected;
  final double timelineWidth;
  final double timelineDuration;
  final Color selectedTrackBorderColor;
  final double? previewHeight;
  final int laneIndex; // NEW: Lane index for multi-lane support
  final double laneHeight; // NEW: Dynamic lane height

  @override
  State<TextTrack> createState() => _TextTrackState();
}

class _TextTrackState extends State<TextTrack>
    with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _videoPlayerController;

  TrimBoundaries _boundary = TrimBoundaries.none;
  Rect _trimRect = Rect.zero;
  double _trimStart = 0.0;
  double _trimEnd = 0.0;

  // Hold and drag state for repositioning
  bool _isHoldDragging = false;
  double? _holdDragStartPosition;
  double? _originalTrackStartTime;
  Timer? _holdTimer;

  // Lane switching state
  double? _holdDragStartPositionY; // Track vertical position
  int? _originalLaneIndex; // Original lane before drag
  int? _targetLaneIndex; // Current hover lane during drag
  static const double laneSwitchThreshold = 20.0; // Vertical pixels to trigger lane switch

  // Auto-scroll during trim handle drag near edges
  Timer? _autoScrollTimer;
  static const double edgeScrollZone = 80.0;
  static const double maxScrollSpeed = 10.0;
  bool _isAutoScrolling = false;
  double _lastScrollOffset = 0.0;

  bool isVideoPositionOnTextTrack = false;

  @override
  void initState() {
    super.initState();
    _trimStart = widget.textTrack.trimStartTime;
    _trimEnd = widget.textTrack.trimEndTime;
    _videoPlayerController =
        context.read<VideoEditorProvider>().videoEditorController?.video;
    _videoPlayerController?.addListener(_syncTextWithVideo);
  }

  Future<void> _syncTextWithVideo() async {
    if (_videoPlayerController == null) return;

    final videoState = _videoPlayerController!.value;
    final videoPosition = videoState.position.inMilliseconds;
    final startTime = widget.textTrack.trimStartTime * 1000;
    final endTime = widget.textTrack.trimEndTime * 1000;
    final provider = context.read<VideoEditorProvider>();

    if (videoPosition >= startTime && videoPosition < endTime) {
      isVideoPositionOnTextTrack = true;
      await provider.updateDisplayText(widget.textTrack.text);
    } else if (isVideoPositionOnTextTrack) {
      isVideoPositionOnTextTrack = false;
      await provider.updateDisplayText("");
    }
  }

  Rect _getTrimRect() {
    double left = (_trimStart / widget.timelineDuration) * widget.timelineWidth;
    double right = (_trimEnd / widget.timelineDuration) * widget.timelineWidth;

    left = left.isNaN ? 0 : left;
    right = right.isNaN ? 0 : right;

    return Rect.fromLTRB(left, 0, right, widget.laneHeight);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_boundary == TrimBoundaries.none || !widget.isSelected) return;

    final provider = context.read<VideoEditorProvider>();
    // Get tracks in the same lane only (multi-lane support)
    final tracksInSameLane = provider.getTextTracksInLane(widget.laneIndex);
    final trackIndexInLane = tracksInSameLane.indexOf(widget.textTrack);
    final isFirstTrackInLane = trackIndexInLane == 0;
    final isLastTrackInLane = trackIndexInLane == tracksInSameLane.length - 1;

    // Collision boundaries within the same lane only
    final double lowerLimit = (tracksInSameLane.length == 1 || isFirstTrackInLane)
        ? 0
        : tracksInSameLane[trackIndexInLane - 1].trimEndTime;

    final double upperLimit = (tracksInSameLane.length == 1 || isLastTrackInLane)
        ? widget.timelineDuration.toDouble()
        : tracksInSameLane[trackIndexInLane + 1].trimStartTime;

    final delta =
        details.delta.dx / widget.timelineWidth * widget.timelineDuration;
    const double minTrimSize = 1;

    void updateTrim(double newStart, double newEnd) {
      _trimStart = newStart;
      _trimEnd = newEnd;
      provider.updateTextTrack(widget.index, _trimStart, _trimEnd);
    }

    switch (_boundary) {
      case TrimBoundaries.start:
        updateTrim(
            (_trimStart + delta).clamp(lowerLimit, _trimEnd - minTrimSize),
            _trimEnd);
        break;

      case TrimBoundaries.end:
        updateTrim(_trimStart,
            (_trimEnd + delta).clamp(_trimStart + minTrimSize, upperLimit));
        break;

      case TrimBoundaries.inside:
        final length = _trimEnd - _trimStart;
        var newStart =
            (_trimStart + delta).clamp(lowerLimit, upperLimit - length);
        updateTrim(newStart, newStart + length);
        break;

      case TrimBoundaries.none:
        break;
    }
  }

  void _onHoldDragUpdate(dynamic details) {
    if (!_isHoldDragging ||
        _holdDragStartPosition == null ||
        _originalTrackStartTime == null) return;

    final provider = context.read<VideoEditorProvider>();
    final screenWidth = MediaQuery.of(context).size.width;

    final deltaX = details.globalPosition.dx - _holdDragStartPosition!;
    final deltaTime = deltaX / (screenWidth / 8);

    final trackDuration =
        widget.textTrack.trimEndTime - widget.textTrack.trimStartTime;

    // Get collision boundaries from neighboring tracks IN THE SAME LANE
    final tracksInSameLane = provider.getTextTracksInLane(widget.laneIndex);
    final trackIndexInLane = tracksInSameLane.indexOf(widget.textTrack);
    final isFirstTrackInLane = trackIndexInLane == 0;
    final isLastTrackInLane = trackIndexInLane == tracksInSameLane.length - 1;

    final double lowerLimit = (tracksInSameLane.length == 1 || isFirstTrackInLane)
        ? 0
        : tracksInSameLane[trackIndexInLane - 1].trimEndTime;

    final double upperLimit = (tracksInSameLane.length == 1 || isLastTrackInLane)
        ? provider.videoDuration
        : tracksInSameLane[trackIndexInLane + 1].trimStartTime;

    final newStartTime = (_originalTrackStartTime! + deltaTime)
        .clamp(lowerLimit, upperLimit - trackDuration);
    final newEndTime = newStartTime + trackDuration;

    _trimStart = newStartTime;
    _trimEnd = newEndTime;

    provider.updateTextTrackTimelinePosition(
        widget.index, newStartTime, newEndTime);
  }

  void _onHoldDragEnd() {
    _stopAutoScroll();
    setState(() {
      _isHoldDragging = false;
      _holdDragStartPosition = null;
      _holdDragStartPositionY = null; // Clear Y position
      _originalTrackStartTime = null;
      _originalLaneIndex = null; // Clear lane tracking
      _targetLaneIndex = null; // Clear target lane
    });
    _holdTimer?.cancel();
    HapticFeedback.lightImpact();
  }

  void _checkAndTriggerAutoScroll(double globalX) {
    final screenWidth = MediaQuery.of(context).size.width;
    final provider = context.read<VideoEditorProvider>();
    final scrollController = provider.textScrollController;

    if (scrollController == null || !scrollController.hasClients) return;

    double scrollDelta = 0;

    // Left edge detection
    if (globalX < edgeScrollZone) {
      double distance = edgeScrollZone - globalX;
      scrollDelta = -(distance / edgeScrollZone) * maxScrollSpeed;
    }
    // Right edge detection
    else if (globalX > screenWidth - edgeScrollZone) {
      double distance = globalX - (screenWidth - edgeScrollZone);
      scrollDelta = (distance / edgeScrollZone) * maxScrollSpeed;
    }

    if (scrollDelta != 0) {
      _startAutoScroll(scrollController, scrollDelta);
    } else {
      _stopAutoScroll();
    }
  }

  void _startAutoScroll(ScrollController controller, double delta) {
    _autoScrollTimer?.cancel();
    _isAutoScrolling = true;
    _lastScrollOffset = controller.offset;

    _autoScrollTimer = Timer.periodic(Duration(milliseconds: 16), (timer) {
      if (!mounted || !controller.hasClients) {
        timer.cancel();
        _isAutoScrolling = false;
        return;
      }

      double newOffset = (controller.offset + delta).clamp(
        0.0,
        controller.position.maxScrollExtent,
      );

      controller.jumpTo(newOffset);

      // Calculate scroll delta and route to appropriate update
      double scrollDelta = newOffset - _lastScrollOffset;
      _lastScrollOffset = newOffset;

      if (scrollDelta != 0) {
        if (_isHoldDragging) {
          _applySyntheticPositionUpdate(scrollDelta);
        } else if (_boundary != TrimBoundaries.none) {
          _applySyntheticTrimUpdate(scrollDelta);
        }
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _isAutoScrolling = false;
    _lastScrollOffset = 0.0;
  }

  void _applySyntheticTrimUpdate(double scrollDelta) {
    if (_boundary == TrimBoundaries.none || !widget.isSelected) return;

    final provider = context.read<VideoEditorProvider>();
    // Get tracks in the same lane only
    final tracksInSameLane = provider.getTextTracksInLane(widget.laneIndex);
    final trackIndexInLane = tracksInSameLane.indexOf(widget.textTrack);
    final isFirstTrackInLane = trackIndexInLane == 0;
    final isLastTrackInLane = trackIndexInLane == tracksInSameLane.length - 1;

    final double lowerLimit = (tracksInSameLane.length == 1 || isFirstTrackInLane)
        ? 0
        : tracksInSameLane[trackIndexInLane - 1].trimEndTime;

    final double upperLimit = (tracksInSameLane.length == 1 || isLastTrackInLane)
        ? widget.timelineDuration.toDouble()
        : tracksInSameLane[trackIndexInLane + 1].trimStartTime;

    // Convert scroll pixels to timeline duration
    final delta = scrollDelta / widget.timelineWidth * widget.timelineDuration;
    const double minTrimSize = 1;

    void updateTrim(double newStart, double newEnd) {
      _trimStart = newStart;
      _trimEnd = newEnd;
      provider.updateTextTrack(widget.index, _trimStart, _trimEnd);
    }

    switch (_boundary) {
      case TrimBoundaries.start:
        updateTrim(
            (_trimStart + delta).clamp(lowerLimit, _trimEnd - minTrimSize),
            _trimEnd);
        break;

      case TrimBoundaries.end:
        updateTrim(_trimStart,
            (_trimEnd + delta).clamp(_trimStart + minTrimSize, upperLimit));
        break;

      case TrimBoundaries.inside:
        final length = _trimEnd - _trimStart;
        var newStart =
            (_trimStart + delta).clamp(lowerLimit, upperLimit - length);
        updateTrim(newStart, newStart + length);
        break;

      case TrimBoundaries.none:
        break;
    }
  }

  void _applySyntheticPositionUpdate(double scrollDelta) {
    if (!_isHoldDragging || _originalTrackStartTime == null) return;

    final provider = context.read<VideoEditorProvider>();
    final trackDuration =
        widget.textTrack.trimEndTime - widget.textTrack.trimStartTime;

    // Get collision boundaries IN THE SAME LANE
    final tracksInSameLane = provider.getTextTracksInLane(widget.laneIndex);
    final trackIndexInLane = tracksInSameLane.indexOf(widget.textTrack);
    final isFirstTrackInLane = trackIndexInLane == 0;
    final isLastTrackInLane = trackIndexInLane == tracksInSameLane.length - 1;

    final double lowerLimit = (tracksInSameLane.length == 1 || isFirstTrackInLane)
        ? 0
        : tracksInSameLane[trackIndexInLane - 1].trimEndTime;

    final double upperLimit = (tracksInSameLane.length == 1 || isLastTrackInLane)
        ? provider.videoDuration
        : tracksInSameLane[trackIndexInLane + 1].trimStartTime;

    // Convert scroll pixels to timeline duration and apply
    final deltaTime =
        scrollDelta / widget.timelineWidth * widget.timelineDuration;
    final newStartTime =
        (_trimStart + deltaTime).clamp(lowerLimit, upperLimit - trackDuration);
    final newEndTime = newStartTime + trackDuration;

    _trimStart = newStartTime;
    _trimEnd = newEndTime;

    provider.updateTextTrackTimelinePosition(
        widget.index, newStartTime, newEndTime);
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _videoPlayerController?.removeListener(_syncTextWithVideo);
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _trimRect = _getTrimRect();
    final provider = context.watch<VideoEditorProvider>();

    return SizedBox(
      width: widget.timelineWidth,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fromRect(
            rect: _trimRect,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: widget.isSelected
                      ? Colors.white
                      : widget.selectedTrackBorderColor,
                  width: widget.isSelected ? 3 : 2,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        final provider = context.read<VideoEditorProvider>();

                        // ✅ Exit reorder mode if active
                        if (provider.isReorderMode) {
                          provider.finalizeReorder();
                          provider.exitReorderMode();
                          HapticFeedback.lightImpact();
                          return;
                        }

                        if (provider.isEditingTrack) {
                          // Exit edit mode
                          provider.exitEditMode();
                          HapticFeedback.lightImpact();
                        } else {
                          // Enter edit mode and select this track
                          provider.setTextTrackIndex(widget.index);
                          HapticFeedback.mediumImpact();
                        }
                      },
                      onLongPressStart: (details) {
                        final provider = context.read<VideoEditorProvider>();

                        // Auto-enter position mode on long press
                        // provider.enterEditMode(TrackType.text, mode: TrackEditMode.position);

                        setState(() {
                          _isHoldDragging = true;
                          _holdDragStartPosition = details.globalPosition.dx;
                          _holdDragStartPositionY = details.globalPosition.dy; // Track Y position
                          _originalTrackStartTime = widget.textTrack.trimStartTime;
                          _originalLaneIndex = widget.laneIndex; // Track original lane
                          _targetLaneIndex = widget.laneIndex; // Initialize target lane
                        });

                        HapticFeedback.heavyImpact();
                      },
                      onLongPressMoveUpdate: (details) {
                        if (!_isHoldDragging) return;

                        // Calculate vertical delta for lane switching
                        if (_holdDragStartPositionY != null) {
                          final deltaY = details.globalPosition.dy - _holdDragStartPositionY!;
                          final laneOffset = (deltaY / widget.laneHeight).round();
                          final newTargetLane = (_originalLaneIndex! + laneOffset).clamp(0, 2);

                          if (newTargetLane != _targetLaneIndex) {
                            setState(() => _targetLaneIndex = newTargetLane);
                            HapticFeedback.selectionClick(); // Feedback on lane change
                          }
                        }

                        _checkAndTriggerAutoScroll(details.globalPosition.dx);

                        // Only update position manually when NOT auto-scrolling
                        // During auto-scroll, synthetic updates handle position changes
                        if (!_isAutoScrolling) {
                          _onHoldDragUpdate(details);
                        }
                      },
                      onLongPressEnd: (details) async {
                        if (_isHoldDragging) {
                          final provider = context.read<VideoEditorProvider>();

                          // Check if lane changed
                          if (_targetLaneIndex != null && _targetLaneIndex != _originalLaneIndex) {
                            // Attempt lane switch with auto-trim
                            final success = await provider.attemptTextLaneSwitch(
                              context,
                              widget.index,
                              _originalLaneIndex!,
                              _targetLaneIndex!,
                              autoTrim: true,
                            );

                            if (!success) {
                              // Lane switch failed - show feedback
                              HapticFeedback.heavyImpact();
                            }
                          }

                          _onHoldDragEnd();

                          // Return to trim mode
                          // provider.enterEditMode(TrackType.text,
                          // mode: TrackEditMode.trim);
                        }
                      },
                      // Only add drag callbacks when in edit mode to allow ScrollView to handle scrolling
                      onHorizontalDragStart:
                          provider.isEditingTrackType(TrackType.text)
                              ? (details) {
                                  // No special handling needed - edit mode controls behavior
                                }
                              : null,
                      onHorizontalDragUpdate:
                          provider.isEditingTrackType(TrackType.text)
                              ? (details) {
                                  if (_isHoldDragging) return;

                                  // Body drag does nothing - only handles can trim
                                  // This prevents accidental trim operations
                                  // Long press + drag is used for repositioning
                                }
                              : null,
                      onHorizontalDragEnd:
                          provider.isEditingTrackType(TrackType.text)
                              ? (details) {
                                  if (_isHoldDragging) {
                                    _onHoldDragEnd();
                                  } else if (_boundary != TrimBoundaries.none) {
                                    _boundary = TrimBoundaries.none;
                                  }
                                }
                              : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.centerLeft,
                        child: ClipRect(
                          child: Text(
                            "${(_trimEnd - _trimStart).toStringAsFixed(1)} | ${widget.textTrack.text}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: widget.laneHeight >= 30 ? 12 : (widget.laneHeight >= 20 ? 10 : 8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Start handle
          if (widget.isSelected &&
              provider.isEditMode(TrackEditMode.trim, TrackType.text))
            Positioned(
              left: _trimRect.left - 10,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) {
                  _boundary = TrimBoundaries.start;
                  _onPanUpdate(details);
                  _checkAndTriggerAutoScroll(details.globalPosition.dx);
                },
                onHorizontalDragEnd: (_) {
                  _stopAutoScroll();
                },
                child: Container(
                  width: 20,
                  height: widget.laneHeight,
                  decoration: BoxDecoration(
                    color: widget.selectedTrackBorderColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      bottomLeft: Radius.circular(4),
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 2,
                      height: 15,
                      decoration: const BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // End handle
          if (widget.isSelected &&
              provider.isEditMode(TrackEditMode.trim, TrackType.text))
            Positioned(
              left: _trimRect.right - 10,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) {
                  _boundary = TrimBoundaries.end;
                  _onPanUpdate(details);
                  _checkAndTriggerAutoScroll(details.globalPosition.dx);
                },
                onHorizontalDragEnd: (_) {
                  _stopAutoScroll();
                },
                child: Container(
                  width: 20,
                  height: widget.laneHeight,
                  decoration: BoxDecoration(
                    color: widget.selectedTrackBorderColor,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(4),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 2,
                      height: 15,
                      decoration: const BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Lane switch visual indicator
          if (_isHoldDragging && _targetLaneIndex != null && _targetLaneIndex != widget.laneIndex)
            Positioned.fromRect(
              rect: _trimRect,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue, width: 3),
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.blue.withOpacity(0.2),
                ),
                child: Center(
                  child: Icon(
                    _targetLaneIndex! > widget.laneIndex
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showStyleEditor(BuildContext context) {
    print('TextStyleEditor: _showStyleEditor called');

    // Use dynamic preview height or fallback to fixed height
    final deviceWidth = MediaQuery.of(context).size.width;
    final dynamicHeight =
        widget.previewHeight ?? 370.0; // Use passed height or fallback

    final previewSize = Size(deviceWidth, dynamicHeight);

    print(
        'TextStyleEditor: Using dynamic bounds - ${previewSize.width}x${previewSize.height}');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => TextStyleEditor(
        textTrack: widget.textTrack,
        previewSize: previewSize,
        onStyleUpdated: (updatedTrack) {
          context.read<VideoEditorProvider>().updateTextTrackModel(
                widget.index,
                updatedTrack,
              );
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
