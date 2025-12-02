// speed_control.dart
import 'package:ai_video_creator_editor/screens/project/new_editor/video_editor_page_updated.dart';
import 'package:flutter/material.dart';

class SpeedControl extends StatelessWidget {
  final double currentSpeed;
  final Function(double) onSpeedChanged;

  const SpeedControl({
    super.key,
    required this.currentSpeed,
    required this.onSpeedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BottomSheetWrapper(
      child: Container(
        height: 150,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Playback Speed'),
            Slider(
              value: currentSpeed,
              min: 0.5,
              max: 2.0,
              divisions: 6,
              label: '${currentSpeed}x',
              onChanged: onSpeedChanged,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [0.5, 1.0, 1.5, 2.0].map((speed) {
                return TextButton(
                  onPressed: () => onSpeedChanged(speed),
                  child: Text('${speed}x'),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
