import 'package:ai_video_creator_editor/screens/project/new_editor/audio_track.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/video_editor_provider.dart';
import 'package:ai_video_creator_editor/enums/track_type.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AudioTimeline extends StatefulWidget {
  const AudioTimeline({super.key});

  @override
  State<AudioTimeline> createState() => _AudioTimelineState();
}

class _AudioTimelineState extends State<AudioTimeline>
    with AutomaticKeepAliveClientMixin {

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final width = MediaQuery.of(context).size.width;
    return Consumer<VideoEditorProvider>(
      builder: (context, provider, child) {
        final timelineDuration = provider.videoDuration;
        final timelineWidth = timelineDuration * (width / 8);
        // Ensure audio controllers are created and master timeline is updated
        // This happens automatically when audio tracks are added/removed through the provider

        // Calculate lane height based on mode
        final isExpanded = provider.isEditingTrackType(TrackType.audio);
        final activeLaneCount = provider.getActiveLaneCount(TrackType.audio);
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
              final tracksInLane = provider.getAudioTracksInLane(laneIndex);
              final isLastLane = laneIndex == activeLaneCount - 1;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLastLane ? 0 : 4), // 4px gap between lanes
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color(0xFF1C1C1E), // Match toolbar grey for better visibility
                    ),
                    child: Stack(
                      children: tracksInLane.map((audioTrack) {
                    final index = provider.audioTracks.indexOf(audioTrack);
                    return AudioTrack(
                      key: ValueKey(
                          '${audioTrack.id}_${audioTrack.lastModified.millisecondsSinceEpoch}'),
                      index: index,
                      audioTrack: audioTrack,
                      isSelected: provider.selectedAudioTrackIndex == index,
                      timelineWidth: timelineWidth,
                      timelineDuration: timelineDuration,
                      selectedTrackBorderColor: provider.selectedTrackBorderColor,
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
