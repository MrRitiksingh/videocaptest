// volume_control.dart
import 'package:ai_video_creator_editor/screens/project/new_editor/video_editor_page_updated.dart';
import 'package:flutter/material.dart';

class VolumeControl extends StatelessWidget {
  final double videoVolume;
  final double audioVolume;
  final Function(double) onVideoVolumeChanged;
  final Function(double) onAudioVolumeChanged;

  const VolumeControl({
    super.key,
    required this.videoVolume,
    required this.audioVolume,
    required this.onVideoVolumeChanged,
    required this.onAudioVolumeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BottomSheetWrapper(
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Video Volume'),
            Slider(
              value: videoVolume,
              min: 0.0,
              max: 1.0,
              onChanged: onVideoVolumeChanged,
            ),
            const SizedBox(height: 16),
            const Text('Audio Track Volume'),
            Slider(
              value: audioVolume,
              min: 0.0,
              max: 1.0,
              onChanged: onAudioVolumeChanged,
            ),
          ],
        ),
      ),
    );
  }
}

enum TransitionType { none, fade, wipe, slide, zoom, dissolve }
