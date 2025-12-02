// frame_extractor.dart
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';

class FrameExtractor {
  static Future<List<String>> extractFrames({
    required String videoPath,
    required int frameCount,
    required Duration videoDuration,
  }) async {
    final List<String> framePaths = [];
    final Directory tempDir = await getTemporaryDirectory();

    final interval = videoDuration.inSeconds ~/ frameCount;

    for (int i = 0; i < frameCount; i++) {
      final timeInSeconds = i * interval;
      final outputPath = '${tempDir.path}/frame_$i.jpg';

      final command =
          '-ss $timeInSeconds -i $videoPath -vframes 1 -q:v 2 $outputPath';
      await FFmpegKit.execute(command);

      framePaths.add(outputPath);
    }

    return framePaths;
  }
}
