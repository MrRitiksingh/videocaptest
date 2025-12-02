import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../utils/functions.dart';

class SubtitleConverter {
  static Future<File?> srtToAss(String srtContent) async {
    // Basic ASS header template
    final header = '''[Script Info]
Title: Converted from SRT
ScriptType: v4.00+
Collisions: Normal
PlayResX: 1920
PlayResY: 1080
Timer: 100.0000

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Arial,48,&H00FFFFFF,&H00FFFFFF,&H000F0F0F,&H00000000,-1,0,0,0,100,100,0,0,1,2,0,2,20,20,20,1
Style: Word,Arial,48,&H0000FFFF,&H00FFFFFF,&H000F0F0F,&H00000000,-1,0,0,0,100,100,0,0,1,2,0,2,20,20,20,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
''';

    // Split SRT content into subtitle blocks
    final blocks = srtContent.trim().split('\n\n');
    final StringBuffer assEvents = StringBuffer();

    for (String block in blocks) {
      final lines = block.trim().split('\n');
      if (lines.length < 3) continue;

      // Parse timecodes
      final timecodeLine = lines[1];
      final timecodes = _parseTimecode(timecodeLine);
      if (timecodes == null) continue;

      // Get subtitle text (may span multiple lines)
      final text = lines.sublist(2).join(' ').trim();

      // Convert text to word-by-word events
      final words = text.split(' ');
      final double totalDuration =
          timecodes.end.difference(timecodes.start).inMilliseconds / 1000.0;
      final double wordDuration = totalDuration / words.length;

      for (int i = 0; i < words.length; i++) {
        final startTime = timecodes.start
            .add(Duration(milliseconds: (i * wordDuration * 1000).round()));
        final endTime = timecodes.start.add(
            Duration(milliseconds: ((i + 1) * wordDuration * 1000).round()));

        // Add event for each word
        assEvents.writeln(
            'Dialogue: 0,${_formatAssTime(startTime)},${_formatAssTime(endTime)},Word,,0,0,0,,${words[i]}');
      }

      // Add event for the full line with default style
      assEvents.writeln(
          'Dialogue: 0,${_formatAssTime(timecodes.start)},${_formatAssTime(timecodes.end)},Default,,0,0,0,,${_escapeAssText(text)}');
    }
    final assString = header + assEvents.toString();
    // return header + assEvents.toString();
    try {
      final temp = await getApplicationCacheDirectory();
      String outputSubtitlePath =
          "${temp.path}/${DateTime.now().millisecondsSinceEpoch}.ass";
      // Create a File instance at the desired path
      File srtFile = File(outputSubtitlePath);

      // Write the subtitle content to the file
      await srtFile.writeAsString(assString);

      // Return the created file
      safePrint("ASS: ${srtFile.path}");
      return srtFile;
    } catch (err) {
      safePrint(err);
      rethrow;
    }
  }

  static Future<File?> assStringToAssFile(String srtContent) async {
    try {
      final temp = await getApplicationCacheDirectory();
      String outputSubtitlePath =
          "${temp.path}/${DateTime.now().millisecondsSinceEpoch}.ass";
      // Create a File instance at the desired path
      File srtFile = File(outputSubtitlePath);

      // Write the subtitle content to the file
      await srtFile.writeAsString(srtContent);

      // Return the created file
      safePrint("ASS: ${srtFile.path}");
      return srtFile;
    } catch (err) {
      safePrint(err);
      rethrow;
    }
  }

  static _TimecodePair? _parseTimecode(String timecodeLine) {
    final regex = RegExp(
        r'(\d{2}):(\d{2}):(\d{2}),(\d{3}) --> (\d{2}):(\d{2}):(\d{2}),(\d{3})');
    final match = regex.firstMatch(timecodeLine);

    if (match == null) return null;

    final startTime = DateTime(
      2024,
      1,
      1,
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
    );

    final endTime = DateTime(
      2024,
      1,
      1,
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
      int.parse(match.group(7)!),
      int.parse(match.group(8)!),
    );

    return _TimecodePair(startTime, endTime);
  }

  static String _formatAssTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}.${(time.millisecond / 10).round().toString().padLeft(2, '0')}';
  }

  static String _escapeAssText(String text) {
    return text
        .replaceAll(r'\', r'\\')
        .replaceAll('{', r'\{')
        .replaceAll('}', r'\}');
  }
}

class _TimecodePair {
  final DateTime start;
  final DateTime end;

  _TimecodePair(this.start, this.end);
}
