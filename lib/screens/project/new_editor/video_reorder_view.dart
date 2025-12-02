import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../models/video_track_model.dart';
import 'video_editor_provider.dart';

/// CapCut-style video reorder view with compact thumbnails
class VideoReorderView extends StatefulWidget {
  const VideoReorderView({Key? key}) : super(key: key);

  @override
  State<VideoReorderView> createState() => _VideoReorderViewState();
}

class _VideoReorderViewState extends State<VideoReorderView> {
  late final ScrollController _reorderScrollController;

  @override
  void initState() {
    super.initState();
    // Create independent scroll controller for reorder view
    _reorderScrollController = ScrollController();
  }

  @override
  void dispose() {
    _reorderScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Consumer<VideoEditorProvider>(
      builder: (context, provider, child) {
        return SizedBox(
          height: 80, // Compact height for reorder mode
          width: width, // Constrain to screen width
          child: SingleChildScrollView(
            controller: _reorderScrollController,
            scrollDirection: Axis.horizontal,
            child: Row(
              children: provider.videoTracks.asMap().entries.map((entry) {
                final index = entry.key;
                final track = entry.value;
                return _buildCompactThumbnail(context, track, index, provider);
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactThumbnail(
      BuildContext context, VideoTrackModel track, int index, VideoEditorProvider provider) {
    final isBeingDragged = provider.reorderingTrackIndex == index;

    // Show placeholder for the item being dragged
    if (isBeingDragged) {
      return Container(
        key: ValueKey('${track.id}_placeholder'),
        margin: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        width: 100,
        height: 64,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.blue.withValues(alpha: 0.4),
            width: 2,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(
            Icons.drag_indicator,
            color: Colors.blue.withValues(alpha: 0.6),
            size: 32,
          ),
        ),
      );
    }

    // Normal DragTarget for other items
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        // Accept if it's a different track AND we're in reorder mode
        return details.data != index && provider.isReorderMode;
      },

      onAcceptWithDetails: (details) {
        final fromIndex = details.data;
        final toIndex = index;
        provider.reorderVideoTracks(fromIndex, toIndex);
        HapticFeedback.mediumImpact();
      },

      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: Duration(milliseconds: 200),
          margin: EdgeInsets.symmetric(
            horizontal: isHovering ? 12 : 4,
            vertical: 8,
          ),
          width: 100, // Compact fixed width
          height: 64,
          decoration: BoxDecoration(
            border: Border.all(
              color: isHovering ? Colors.green : Colors.white,
              width: isHovering ? 3 : 2,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: isHovering
                ? [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              // Use FIRST thumbnail from existing generated thumbnails
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: _buildThumbnailFromExisting(track),
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
                    '${index + 1}',
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
                    '${track.totalDuration}s',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Reuse existing thumbnails from VideoTrack
  Widget _buildThumbnailFromExisting(VideoTrackModel track) {
    // Access thumbnail from track's existing thumbnail cache
    // The VideoTrack widget generates thumbnails at:
    // ${tempDir.path}/fullvideo_${trackId}_${fileHash}_${duration}_frame_*.jpg

    return FutureBuilder<File?>(
      future: _getFirstThumbnail(track),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Image.file(
            snapshot.data!,
            fit: BoxFit.cover,
            width: 100,
            height: 64,
          );
        }

        // Fallback: show placeholder while loading
        return Container(
          color: Colors.grey[800],
          child: Center(
            child: Icon(Icons.video_library, color: Colors.white54, size: 24),
          ),
        );
      },
    );
  }

  // Get first thumbnail from existing cache
  Future<File?> _getFirstThumbnail(VideoTrackModel track) async {
    final tempDir = await getTemporaryDirectory();

    // Generate stable ID (same logic as VideoTrack)
    final fileHash = track.processedFile.path.hashCode;
    final trackId = track.id;
    final stableId =
        'fullvideo_${trackId}_${fileHash}_${track.originalDuration.toInt()}';

    // Find first thumbnail matching pattern
    try {
      final files = await tempDir
          .list()
          .where((entity) =>
              entity.path.contains(stableId) &&
              entity.path.contains('_frame_'))
          .toList();

      if (files.isNotEmpty) {
        // Sort to get first frame
        files.sort((a, b) => a.path.compareTo(b.path));
        return File(files.first.path);
      }
    } catch (e) {
      print('Error finding thumbnail for reorder view: $e');
    }

    return null;
  }
}
