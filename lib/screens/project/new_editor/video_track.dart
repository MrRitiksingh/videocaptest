import 'dart:async';
import 'dart:io';

import 'package:ai_video_creator_editor/screens/project/models/video_track_model.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/custom_trim_slider.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/video_editor_provider.dart';
import 'package:ai_video_creator_editor/enums/track_type.dart';
// TrackOptions import removed - handled by parent widget
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

// Trim overlay painter for visual feedback during dragging
class TrimOverlayPainter extends CustomPainter {
  final double visualTrimStart;
  final double visualTrimEnd;
  final double currentTrimStart;
  final double currentTrimEnd;
  final double originalDuration;
  final bool isDragging;
  final int thumbnailCount;

  TrimOverlayPainter({
    required this.visualTrimStart,
    required this.visualTrimEnd,
    required this.currentTrimStart,
    required this.currentTrimEnd,
    required this.originalDuration,
    required this.isDragging,
    required this.thumbnailCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isDragging || thumbnailCount <= 0) return;

    final maskPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    // Calculate current state duration (what's currently shown)
    final currentDuration = currentTrimEnd - currentTrimStart;
    if (currentDuration <= 0) return;

    // Map visual trim values relative to current state
    // Visual trim values are in original timeline coordinates
    // We need to convert them to current timeline coordinates

    // Calculate what portion of current thumbnails should be masked
    final visualStart = visualTrimStart;
    final visualEnd = visualTrimEnd;

    // Convert to ratios within current range (0.0 to 1.0)
    final startRatio =
        ((visualStart - currentTrimStart) / currentDuration).clamp(0.0, 1.0);
    final endRatio =
        ((visualEnd - currentTrimStart) / currentDuration).clamp(0.0, 1.0);

    print("=== Masking calculation ===");
    print(
        "Current trim range: $currentTrimStart - $currentTrimEnd (${currentDuration}s)");
    print("Visual trim range: $visualStart - $visualEnd");
    print("Mask ratios: $startRatio - $endRatio");

    // Left mask (area before visual trim start)
    if (startRatio > 0.0) {
      final leftMaskWidth = size.width * startRatio;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, leftMaskWidth, size.height),
        maskPaint,
      );
      print("Drawing left mask: width = $leftMaskWidth");
    }

    // Right mask (area after visual trim end)
    if (endRatio < 1.0) {
      final rightMaskStart = size.width * endRatio;
      final rightMaskWidth = size.width - rightMaskStart;
      canvas.drawRect(
        Rect.fromLTWH(rightMaskStart, 0, rightMaskWidth, size.height),
        maskPaint,
      );
      print(
          "Drawing right mask: start = $rightMaskStart, width = $rightMaskWidth");
    }
  }

  @override
  bool shouldRepaint(TrimOverlayPainter oldDelegate) {
    return oldDelegate.visualTrimStart != visualTrimStart ||
        oldDelegate.visualTrimEnd != visualTrimEnd ||
        oldDelegate.currentTrimStart != currentTrimStart ||
        oldDelegate.currentTrimEnd != currentTrimEnd ||
        oldDelegate.isDragging != isDragging ||
        oldDelegate.thumbnailCount != thumbnailCount;
  }
}

class VideoTrack extends StatefulWidget {
  const VideoTrack({
    super.key,
    required this.videoTrack,
    required this.index,
    required this.isSelected,
    required this.selectedTrackBorderColor,
    this.isCompactMode = false,
  });

  final VideoTrackModel videoTrack;
  final int index;
  final bool isSelected;
  final Color selectedTrackBorderColor;
  final bool isCompactMode;

  @override
  State<VideoTrack> createState() => _VideoTrackState();
}

class _VideoTrackState extends State<VideoTrack>
    with AutomaticKeepAliveClientMixin {
  // Static memory cache for instant thumbnail access across widget rebuilds
  static final Map<String, List<File>> _thumbnailCache = {};

  final ValueNotifier<List<File>> _thumbnailNotifier =
      ValueNotifier<List<File>>([]);
  bool _isGeneratingThumbnails = false;

  // Trim functionality - Data layer (actual trim values)
  TrimBoundaries _boundary = TrimBoundaries.none;
  double _trimStart = 0.0;
  double _trimEnd = 0.0;
  Timer? _debounceTimer;

  // Visual layer (for immediate feedback)
  double _visualTrimStart = 0.0;
  double _visualTrimEnd = 0.0;
  bool _isDragging = false;

  // Hold and drag state for repositioning
  bool _isHoldDragging = false;
  double? _holdDragStartPosition;
  double? _originalTrackStartTime;
  Timer? _holdTimer;

  // Stretch functionality (for image-based videos)
  double _visualStretchDuration = 0.0;
  bool _isStretching = false;
  bool _isAwaitingStretchUpdate = false; // Preserves visual width after release until model updates

  // Check if we're in stretch mode (image-based) vs trim mode (regular video)
  bool get _isStretchMode => widget.videoTrack.isImageBased;

  @override
  void initState() {
    super.initState();
    _trimStart = widget.videoTrack.videoTrimStart;
    _trimEnd = widget.videoTrack.videoTrimEnd;
    _visualTrimStart = _trimStart;
    _visualTrimEnd = _trimEnd;

    // Initialize stretch duration
    _visualStretchDuration = widget.videoTrack.totalDuration.toDouble();

    // ✅ Don't eagerly set loading state - let _generateThumbnailAtTime handle it
    // This prevents flicker when thumbnails are already cached
    _generateThumbnailAtTime(widget.videoTrack.processedFile.path);
  }

  @override
  void didUpdateWidget(VideoTrack oldWidget) {
    super.didUpdateWidget(oldWidget);

    print("=== VideoTrack didUpdateWidget called ===");
    print("Old file: ${oldWidget.videoTrack.processedFile.path}");
    print("New file: ${widget.videoTrack.processedFile.path}");
    print("Old isCompactMode: ${oldWidget.isCompactMode}");
    print("New isCompactMode: ${widget.isCompactMode}");
    print("Old trim start: ${oldWidget.videoTrack.videoTrimStart}");
    print("New trim start: ${widget.videoTrack.videoTrimStart}");
    print("Old trim end: ${oldWidget.videoTrack.videoTrimEnd}");
    print("New trim end: ${widget.videoTrack.videoTrimEnd}");

    // Update data layer trim values when provider updates
    if (oldWidget.videoTrack.videoTrimStart !=
            widget.videoTrack.videoTrimStart ||
        oldWidget.videoTrack.videoTrimEnd != widget.videoTrack.videoTrimEnd) {
      _trimStart = widget.videoTrack.videoTrimStart;
      _trimEnd = widget.videoTrack.videoTrimEnd;
      // If not dragging, sync visual values
      if (!_isDragging) {
        _visualTrimStart = _trimStart;
        _visualTrimEnd = _trimEnd;
      }
    }

    // Detect when duration changes (stretch completed)
    if (oldWidget.videoTrack.totalDuration !=
        widget.videoTrack.totalDuration) {
      print("⏱️ Duration changed: ${oldWidget.videoTrack.totalDuration}s → ${widget.videoTrack.totalDuration}s");
      // Update visual stretch duration to match new duration and clear awaiting flag
      setState(() {
        _visualStretchDuration = widget.videoTrack.totalDuration.toDouble();
        _isAwaitingStretchUpdate = false; // Model updated successfully
      });
    }

    // ✅ GUARD: Only regenerate thumbnails if the file itself actually changed
    // Skip regeneration if only mode or other properties changed
    if (oldWidget.videoTrack.processedFile.path !=
        widget.videoTrack.processedFile.path) {
      print("📁 File path changed, regenerating thumbnails...");
      // Don't set loading state here - let _generateThumbnailAtTime handle it
      _generateThumbnailAtTime(widget.videoTrack.processedFile.path);
    } else if (oldWidget.isCompactMode != widget.isCompactMode) {
      print("🔄 Mode changed (compact: ${widget.isCompactMode}), keeping cached thumbnails");
      // Mode changed but file is same - thumbnails already loaded from cache
      // No action needed - existing thumbnails will be reused
    } else {
      print("✅ No relevant changes, keeping existing thumbnails");
    }
  }

  /// Generate stable identifier for thumbnails based on file path and creation time
  String _generateStableThumbnailId(String filePath) {
    // Use file path hash combined with original file stats for stability
    // This ensures thumbnails are only regenerated when the actual file changes
    final fileHash = filePath.hashCode;
    final trackId = widget.videoTrack.id;
    return 'fullvideo_${trackId}_${fileHash}_${widget.videoTrack.originalDuration.toInt()}';
  }

  Future<void> _generateThumbnailAtTime(String filePath) async {
    try {
      // Use stable identifier for both memory and disk cache
      final stableId = _generateStableThumbnailId(filePath);

      // ✅ CHECK MEMORY CACHE FIRST (synchronous, instant)
      if (_thumbnailCache.containsKey(stableId)) {
        print("✅ Using memory-cached thumbnails for: $stableId");
        if (mounted) {
          _thumbnailNotifier.value = _thumbnailCache[stableId]!;
          // No loading state needed - instant from memory
        }
        return;
      }

      // Check disk cache (async)
      final Directory tempDir = await getTemporaryDirectory();

      print(
          "=== Generating full-video thumbnails for track ${widget.videoTrack.id} ===");
      print("File path: $filePath");
      print("Original duration: ${widget.videoTrack.originalDuration}");
      print(
          "Current trim: ${widget.videoTrack.videoTrimStart} - ${widget.videoTrack.videoTrimEnd}");

      // Check if thumbnails already exist on disk for this stable ID
      final existingFiles = await tempDir.list().where((entity) {
        return entity.path.contains(stableId);
      }).toList();

      if (existingFiles.isNotEmpty) {
        print("📁 Using disk-cached thumbnails for stable ID: $stableId");
        final thumbnailFiles = existingFiles.map((e) => File(e.path)).toList()
          ..sort((a, b) {
            int extractNumber(String path) {
              String fileName = p.basename(path);
              final match = RegExp(r'frame_(\d+)\.jpg').firstMatch(fileName);
              return int.tryParse(match?.group(1) ?? '0') ?? 0;
            }

            return extractNumber(a.path).compareTo(extractNumber(b.path));
          });

        if (mounted) {
          // ✅ Store in memory cache for instant future access
          _thumbnailCache[stableId] = thumbnailFiles;
          _thumbnailNotifier.value = thumbnailFiles;
          setState(() {
            _isGeneratingThumbnails = false;
          });
        }
        return;
      }

      // ⚠️ No cache found - need to actually generate
      // ONLY NOW set loading state
      if (mounted) {
        setState(() {
          _isGeneratingThumbnails = true;
        });
      }

      // Clear old thumbnails for this track (different naming patterns)
      await _clearOldThumbnails(tempDir);

      final String outputPattern = '${tempDir.path}/${stableId}_frame_%d.jpg';

      // Generate thumbnails from FULL original video (not trimmed range)
      // This provides a complete thumbnail library that we can mask visually
      final originalDuration = widget.videoTrack.originalDuration;

      final command =
          '-i "$filePath" -vf "fps=1,scale=160:90" -t $originalDuration -q:v 2 "$outputPattern"';

      print("Generating full-video thumbnails with command: $command");

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      print("Full-video thumbnail generation return code: $returnCode");

      if (!ReturnCode.isSuccess(returnCode)) {
        print("Failed to generate thumbnails for ${widget.videoTrack.id}");
        if (mounted) _thumbnailNotifier.value = [];
        return;
      }

      final List<File> files = (await tempDir.list().where((entity) {
        return entity.path.contains(stableId);
      }).map((entity) {
        return File(entity.path);
      }).toList())
        ..sort((a, b) {
          int extractNumber(String path) {
            String fileName = p.basename(path);
            final match = RegExp(r'frame_(\d+)\.jpg').firstMatch(fileName);
            return int.tryParse(match?.group(1) ?? '0') ?? 0;
          }

          return extractNumber(a.path).compareTo(extractNumber(b.path));
        });

      print(
          "Generated ${files.length} thumbnails for track ${widget.videoTrack.id}");
      if (mounted) {
        // ✅ Store in memory cache after generation
        _thumbnailCache[stableId] = files;
        _thumbnailNotifier.value = files;
        setState(() {
          _isGeneratingThumbnails = false;
        });
      }
    } catch (e) {
      print("Error generating thumbnails: $e");
      if (mounted) {
        _thumbnailNotifier.value = [];
        setState(() {
          _isGeneratingThumbnails = false;
        });
      }
    }
  }

  Future<void> _clearOldThumbnails(Directory tempDir) async {
    try {
      // Clear old thumbnails with different naming patterns (legacy and current)
      final trackId = widget.videoTrack.id;
      final currentStableId =
          _generateStableThumbnailId(widget.videoTrack.processedFile.path);
      final oldFiles = await tempDir.list().where((entity) {
        final path = entity.path;
        // Clear old timestamp-based thumbnails and any other patterns for this track
        return (path.contains("video_track${widget.index}_${trackId}_") ||
                path.contains("fullvideo_${trackId}_")) &&
            path.contains("_frame_") &&
            !path.contains(
                currentStableId); // Don't clear current stable thumbnails
      }).toList();

      for (final file in oldFiles) {
        if (file is File) {
          await file.delete();
        }
      }
      print(
          "Cleared ${oldFiles.length} old thumbnails for track ${widget.videoTrack.id}");
    } catch (e) {
      print("Error clearing old thumbnails: $e");
    }
  }

  void _onPanStart() {
    setState(() {
      _isDragging = true;
    });
  }

  void _onPanEnd() {
    if (_isStretchMode) {
      // STRETCH MODE: Apply stretch via provider (instant, no FFmpeg during preview)
      final newDuration = _visualStretchDuration;
      final currentDuration = widget.videoTrack.totalDuration.toDouble();

      setState(() {
        _isDragging = false;
        _isStretching = false;
        // Preserve visual width until model updates
        _isAwaitingStretchUpdate = true;
      });

      // Note: Don't clear stretch progress here - it will be cleared after model updates
      // This prevents overflow during the async update period

      // Only update if duration changed significantly
      if ((newDuration - currentDuration).abs() > 0.1) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
          try {
            await context.read<VideoEditorProvider>().stretchImageVideo(
                  widget.index,
                  newDuration,
                );
            HapticFeedback.heavyImpact();
          } catch (e) {
            print("Stretch failed: $e");
            HapticFeedback.lightImpact();
            // Reset to original duration and clear awaiting flag on failure
            if (mounted) {
              setState(() {
                _visualStretchDuration =
                    widget.videoTrack.totalDuration.toDouble();
                _isAwaitingStretchUpdate = false; // Clear flag on error
              });
              // Note: Provider will clear stretch progress in its error handler
            }
          }
        });
      }
    } else {
      // TRIM MODE: Original trim logic
      _trimStart = _visualTrimStart;
      _trimEnd = _visualTrimEnd;

      setState(() {
        _isDragging = false;
      });

      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        context
            .read<VideoEditorProvider>()
            .updateVideoTrack(widget.index, _trimStart, _trimEnd);
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details, double trackWidth) {
    if (_boundary == TrimBoundaries.none || !widget.isSelected) return;

    // Calculate delta based on drag movement (1/8 screen = 1 second)
    final delta =
        details.delta.dx / (MediaQuery.of(context).size.width / 8) * 1.0;

    if (_isStretchMode) {
      // STRETCH MODE: Change duration by dragging handles
      const double minDuration = 1.0;
      const double maxDuration = 30.0;

      setState(() {
        switch (_boundary) {
          case TrimBoundaries.start:
            // Stretch from start: dragging left = shorter, right = longer
            _visualStretchDuration = (_visualStretchDuration - delta)
                .clamp(minDuration, maxDuration);
            _isStretching = true;
            break;

          case TrimBoundaries.end:
            // Stretch from end: dragging right = longer, left = shorter
            _visualStretchDuration = (_visualStretchDuration + delta)
                .clamp(minDuration, maxDuration);
            _isStretching = true;
            break;

          case TrimBoundaries.inside:
            // Middle drag: reposition track (handled elsewhere)
            break;

          case TrimBoundaries.none:
            break;
        }
      });

      // Report stretch progress to provider for timeline width adjustment
      if (_isStretching) {
        context.read<VideoEditorProvider>().updateStretchProgress(
          widget.index,
          _visualStretchDuration,
        );
      }
    } else {
      // TRIM MODE: Original trim logic for regular videos
      final originalDuration = widget.videoTrack.originalDuration;
      if (originalDuration <= 0) return;

      const double minTrimSize = 0.5;
      final double lowerLimit = 0;
      final double upperLimit = originalDuration;

      setState(() {
        switch (_boundary) {
          case TrimBoundaries.start:
            _visualTrimStart = (_visualTrimStart + delta)
                .clamp(lowerLimit, _visualTrimEnd - minTrimSize);
            break;

          case TrimBoundaries.end:
            _visualTrimEnd = (_visualTrimEnd + delta)
                .clamp(_visualTrimStart + minTrimSize, upperLimit);
            break;

          case TrimBoundaries.inside:
            final length = _visualTrimEnd - _visualTrimStart;
            var newStart = (_visualTrimStart + delta)
                .clamp(lowerLimit, upperLimit - length);
            _visualTrimStart = newStart;
            _visualTrimEnd = newStart + length;
            break;

          case TrimBoundaries.none:
            break;
        }
      });
    }
  }

  // Hold and drag methods for repositioning
  void _onHoldDragUpdate(DragUpdateDetails details) {
    if (!_isHoldDragging ||
        _holdDragStartPosition == null ||
        _originalTrackStartTime == null) return;

    final provider = context.read<VideoEditorProvider>();
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate the movement delta in pixels
    final deltaX = details.globalPosition.dx - _holdDragStartPosition!;

    // Convert pixel movement to time (using same scale as timeline: width/8 per second)
    final deltaTime = deltaX / (screenWidth / 8);

    // Calculate new start time
    final newStartTime = (_originalTrackStartTime! + deltaTime)
        .clamp(0.0, provider.videoDuration - widget.videoTrack.totalDuration);

    // Update the track position using the provider method
    provider.updateVideoTrackPosition(widget.index, newStartTime.toInt());
  }

  void _onHoldDragEnd() {
    setState(() {
      _isHoldDragging = false;
      _holdDragStartPosition = null;
      _originalTrackStartTime = null;
    });
    _holdTimer?.cancel();

    // Provide feedback that repositioning is complete
    HapticFeedback.lightImpact();
  }


  @override
  void dispose() {
    _thumbnailNotifier.dispose();
    _debounceTimer?.cancel();
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Calculate track width using the same approach as provider (use customDuration for image-based tracks)
    // For stretch mode during drag, use visual stretch duration for immediate feedback
    final width = MediaQuery.of(context).size.width;
    final displayDuration = (_isStretchMode && (_isStretching || _isAwaitingStretchUpdate))
        ? _visualStretchDuration
        : (widget.videoTrack.isImageBased && widget.videoTrack.customDuration != null)
            ? widget.videoTrack.customDuration!
            : widget.videoTrack.totalDuration.toDouble();
    final trackWidth = (width / 8) * displayDuration;
    final provider = context.watch<VideoEditorProvider>();

    // COMPACT MODE: Show single box thumbnail for reorder mode
    if (widget.isCompactMode) {
      return _buildCompactView(width);
    }

    // NORMAL MODE: Full timeline view
    return Container(
      width: trackWidth,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main track container (no absolute positioning)
          Container(
            width: trackWidth,
            height: 60,
            decoration: BoxDecoration(
              border: Border.all(
                color: widget.isSelected
                    ? Colors.white
                    : widget.selectedTrackBorderColor,
                width: widget.isSelected ? 3 : 2,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
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
                  provider.setVideoTrackIndex(widget.index);
                  HapticFeedback.mediumImpact();
                }
              },
              // Long-press handlers removed to allow LongPressDraggable to work
              // Edit mode drag repositioning still available via horizontal drag
              onHorizontalDragStart: provider.isEditingTrackType(TrackType.video) ? (details) {
                if (_isHoldDragging) {
                  _holdDragStartPosition = details.globalPosition.dx;
                }
              } : null,
              onHorizontalDragUpdate: provider.isEditingTrackType(TrackType.video) ? (details) {
                // Priority 1: Hold-drag repositioning (edit mode only)
                if (_isHoldDragging) {
                  _onHoldDragUpdate(details);
                  return;
                }

                // Priority 2: Edit mode - trim functionality
                if (_boundary == TrimBoundaries.none) {
                  _boundary = TrimBoundaries.inside;
                  _onPanStart();
                }
                _onPanUpdate(details, trackWidth);
              } : null,
              onHorizontalDragEnd: provider.isEditingTrackType(TrackType.video) ? (details) {
                if (_isHoldDragging) {
                  _onHoldDragEnd();
                } else if (_boundary != TrimBoundaries.none) {
                  _onPanEnd();
                }
              } : null,
              child: ValueListenableBuilder<List<File>>(
                valueListenable: _thumbnailNotifier,
                builder: (context, thumbnails, _) {
                  // Calculate visible thumbnail range based on trim values for normal display
                  List<File> visibleThumbnails = [];
                  List<File> displayThumbnails =
                      []; // What to actually show (switches based on dragging state)

                  if (thumbnails.isNotEmpty &&
                      widget.videoTrack.originalDuration > 0) {
                    final originalDuration = widget.videoTrack.originalDuration;
                    final trimStart = widget.videoTrack.videoTrimStart;
                    final trimEnd = widget.videoTrack.videoTrimEnd;

                    // Handle edge cases for filtered thumbnails
                    if (trimStart >= trimEnd) {
                      // Invalid trim range - show empty
                      visibleThumbnails = [];
                    } else if (trimStart <= 0 && trimEnd >= originalDuration) {
                      // No trim applied - show all thumbnails
                      visibleThumbnails = thumbnails;
                    } else {
                      // Calculate which thumbnails correspond to the trimmed duration
                      final startIndex =
                          ((trimStart / originalDuration) * thumbnails.length)
                              .floor()
                              .clamp(0, thumbnails.length);
                      final endIndex =
                          ((trimEnd / originalDuration) * thumbnails.length)
                              .ceil()
                              .clamp(0, thumbnails.length);

                      // Ensure we have at least one thumbnail if trim range is valid
                      final safeStartIndex =
                          startIndex.clamp(0, thumbnails.length - 1);
                      final safeEndIndex = (endIndex <= safeStartIndex)
                          ? safeStartIndex + 1
                          : endIndex.clamp(
                              safeStartIndex + 1, thumbnails.length);

                      print("=== Thumbnail filtering ===");
                      print("Original duration: $originalDuration");
                      print("Trim: $trimStart - $trimEnd");
                      print("Total thumbnails: ${thumbnails.length}");
                      print("Calculated indices: $startIndex to $endIndex");
                      print("Safe indices: $safeStartIndex to $safeEndIndex");

                      visibleThumbnails =
                          thumbnails.sublist(safeStartIndex, safeEndIndex);
                    }

                    // Choose which thumbnails to display based on dragging state
                    if (_isDragging) {
                      // During dragging: show current state thumbnails (what's currently visible) for context
                      displayThumbnails = visibleThumbnails.isNotEmpty
                          ? visibleThumbnails
                          : thumbnails;
                      print(
                          "=== Dragging mode: showing current state thumbnails ===");
                      print(
                          "Display thumbnails count: ${displayThumbnails.length}");
                    } else {
                      // Normal state: show filtered thumbnails
                      displayThumbnails = visibleThumbnails;
                    }
                  }

                  return Stack(
                    children: [
                      // Show loading indicator or thumbnails
                      _isGeneratingThumbnails
                          ? Container(
                              height: 60, // Match thumbnail height
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.white.withValues(alpha: 0.9),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Loading...',
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.9),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              height: 60,
                              child: displayThumbnails.isNotEmpty
                                  ? ListView.builder(
                                      shrinkWrap: true,
                                      padding: EdgeInsets.zero,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      scrollDirection: Axis.horizontal,
                                      itemCount: displayThumbnails.length,
                                      itemBuilder: (context, index) {
                                        return SizedBox(
                                          width: trackWidth /
                                              displayThumbnails.length,
                                          child: Image.file(
                                            displayThumbnails[index],
                                            fit: BoxFit.cover,
                                          ),
                                        );
                                      },
                                    )
                                  : const Center(
                                      child: Icon(Icons.broken_image_outlined)),
                            ),

                      // Visual feedback overlay during dragging
                      if (_isDragging)
                        if (_isStretchMode && _isStretching)
                          // STRETCH FEEDBACK
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.blue, width: 3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Align(
                                alignment: Alignment.center,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Show icon only for tracks >= 3 seconds
                                      if (_visualStretchDuration >= 3.0) ...[
                                        Icon(Icons.photo_size_select_large,
                                            color: Colors.white, size: 14),
                                        SizedBox(width: 6),
                                      ],
                                      // Adaptive text based on 3 second threshold
                                      Text(
                                        _visualStretchDuration < 3.0
                                            ? '${_visualStretchDuration.toStringAsFixed(1)}s'  // Short: "2.5s"
                                            : 'Stretch to ${_visualStretchDuration.toStringAsFixed(1)}s',  // Full: "Stretch to 3.5s"
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,  // Safety fallback
                                        maxLines: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          // TRIM FEEDBACK (existing overlay)
                          CustomPaint(
                            size: Size(trackWidth, 60),
                            painter: TrimOverlayPainter(
                              visualTrimStart: _visualTrimStart,
                              visualTrimEnd: _visualTrimEnd,
                              currentTrimStart: widget.videoTrack.videoTrimStart,
                              currentTrimEnd: widget.videoTrack.videoTrimEnd,
                              originalDuration:
                                  widget.videoTrack.originalDuration,
                              isDragging: _isDragging,
                              thumbnailCount: displayThumbnails.length,
                            ),
                          ),

                      // Duration label - positioned in center to avoid handle overlap
                      Positioned(
                        bottom: 2,
                        left: trackWidth / 2 - 15, // Center horizontally
                        child: Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "${widget.videoTrack.totalDuration}s",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // Start handle - positioned at track start (left boundary)
          if (widget.isSelected)
            Positioned(
              left:
                  0, // Always at track start since track width represents trimmed content
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) {
                  _boundary = TrimBoundaries.start;
                  _onPanStart();
                },
                onHorizontalDragUpdate: (details) {
                  _onPanUpdate(details, trackWidth);
                },
                onHorizontalDragEnd: (_) {
                  _onPanEnd();
                },
                child: Container(
                  width: 20,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _isStretchMode
                        ? Colors.blue
                        : widget.selectedTrackBorderColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(4),
                      bottomLeft: Radius.circular(4),
                    ),
                  ),
                  child: Center(
                    child: _isStretchMode
                        ? Icon(Icons.unfold_more,
                            color: Colors.white, size: 14)
                        : Container(
                            width: 2,
                            height: 15,
                            decoration: BoxDecoration(
                              color: Colors.grey,
                              borderRadius: BorderRadius.all(
                                Radius.circular(double.maxFinite),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),

          // End handle - positioned at track end (right boundary)
          if (widget.isSelected)
            Positioned(
              right:
                  0, // Always at track end since track width represents trimmed content
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) {
                  _boundary = TrimBoundaries.end;
                  _onPanStart();
                },
                onHorizontalDragUpdate: (details) {
                  _onPanUpdate(details, trackWidth);
                },
                onHorizontalDragEnd: (_) {
                  _onPanEnd();
                },
                child: Container(
                  width: 20,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _isStretchMode
                        ? Colors.blue
                        : widget.selectedTrackBorderColor,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(4),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                  child: Center(
                    child: _isStretchMode
                        ? Icon(Icons.unfold_more,
                            color: Colors.white, size: 14)
                        : Container(
                            width: 2,
                            height: 15,
                            decoration: BoxDecoration(
                              color: Colors.grey,
                              borderRadius: BorderRadius.all(
                                Radius.circular(double.maxFinite),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build compact single-box view for reorder mode
  Widget _buildCompactView(double screenWidth) {
    // Compact box width = 1 second equivalent in timeline scale
    final compactWidth = screenWidth / 8;

    return Container(
      width: compactWidth,
      height: 64,
      decoration: BoxDecoration(
        border: Border.all(
          color: widget.isSelected ? Colors.white : Colors.grey,
          width: widget.isSelected ? 3 : 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ValueListenableBuilder<List<File>>(
        valueListenable: _thumbnailNotifier,
        builder: (context, thumbnails, _) {
          return Stack(
            children: [
              // Show first thumbnail only
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: thumbnails.isNotEmpty
                    ? Image.file(
                        thumbnails.first,
                        fit: BoxFit.cover,
                        width: compactWidth,
                        height: 64,
                      )
                    : Container(
                        color: Colors.grey[800],
                        child: Center(
                          child: Icon(
                            Icons.video_library,
                            color: Colors.white54,
                            size: 24,
                          ),
                        ),
                      ),
              ),

              // Track number badge (top-left)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${widget.index + 1}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Duration badge (bottom-right)
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${widget.videoTrack.totalDuration.toStringAsFixed(1)}s',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
