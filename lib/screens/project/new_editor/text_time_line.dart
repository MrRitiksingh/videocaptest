import 'package:ai_video_creator_editor/screens/project/new_editor/text_track.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/video_editor_provider.dart';
import 'package:ai_video_creator_editor/enums/track_type.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TextTimeline extends StatefulWidget {
  const TextTimeline({
    super.key,
    this.previewHeight,
  });

  final double? previewHeight;

  @override
  State<TextTimeline> createState() => _TextTimelineState();
}

class _TextTimelineState extends State<TextTimeline>
    with AutomaticKeepAliveClientMixin {

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final width = MediaQuery.of(context).size.width;
    return Consumer<VideoEditorProvider>(
      builder: (context, provider, child) {
        final timelineDuration = provider.videoDuration;
        final timelineWidth = timelineDuration * (width / 8);

        // Calculate lane height based on mode
        final isExpanded = provider.isEditingTrackType(TrackType.text);
        final activeLaneCount = provider.getActiveLaneCount(TrackType.text);
        final laneHeight = isExpanded
            ? 30.0                          // Edit mode: 30px per lane
            : 40.0 / activeLaneCount;      // Normal mode: divide 40px equally

        return Container(
          margin: EdgeInsets.only(right: width / 2), // Match video timeline margin
          width: timelineWidth,
          color: Color(0xFF1C1C1E), // Grey background makes gaps invisible
          // Multi-lane layout: only render active lanes
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: List.generate(activeLaneCount, (laneIndex) {
              final tracksInLane = provider.getTextTracksInLane(laneIndex);
              final isLastLane = laneIndex == activeLaneCount - 1;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLastLane ? 0 : 4), // 4px gap between lanes
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color(0xFF1C1C1E), // Match toolbar grey for better visibility
                    ),
                    child: Stack(
                      children: tracksInLane.map((textTrack) {
                    final index = provider.textTracks.indexOf(textTrack);
                    return TextTrack(
                      key: ValueKey(
                          '${textTrack.id}_${textTrack.lastModified.millisecondsSinceEpoch}'),
                      index: index,
                      textTrack: provider.textTracks[index],
                      isSelected: provider.selectedTextTrackIndex == index,
                      timelineWidth: timelineWidth,
                      timelineDuration: timelineDuration,
                      selectedTrackBorderColor: provider.selectedTrackBorderColor,
                      previewHeight: widget.previewHeight,
                      laneIndex: laneIndex, // Pass lane context to track
                      laneHeight: laneHeight, // Pass dynamic height to track
                    );
                  }).toList(),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
