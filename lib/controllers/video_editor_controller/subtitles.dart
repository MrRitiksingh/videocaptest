// class FFmpegSubtitleBurner {
//   static String generateBurnCommand({
//     required String inputVideoPath,
//     required String subtitlePath,
//     required String outputPath,
//     SubtitleStyle? subtitleStyle,
//     VideoQualitySettings? qualitySettings,
//   }) {
//     subtitleStyle ??= SubtitleStyle();
//     qualitySettings ??= VideoQualitySettings();
//
//     final List<String> command = [
//       '-y', // Overwrite output file if it exists
//       '-i', inputVideoPath,
//       '-vf', 'subtitles=${subtitlePath}:${subtitleStyle.ffmpegStyleString}',
//       '-c:v', qualitySettings.videoCodec,
//       '-preset', qualitySettings.preset,
//       '-crf', qualitySettings.crf,
//     ];
//
//     // Add bitrate settings if specified
//     if (qualitySettings.videoBitrate != null) {
//       command.addAll(['-b:v', qualitySettings.videoBitrate!]);
//     }
//     if (qualitySettings.maxBitrate != null) {
//       command.addAll(['-maxrate', qualitySettings.maxBitrate!]);
//     }
//     if (qualitySettings.bufsize != null) {
//       command.addAll(['-bufsize', qualitySettings.bufsize!]);
//     }
//
//     // Copy audio stream without re-encoding
//     command.addAll(['-c:a', 'copy']);
//
//     // Add output path
//     command.add(outputPath);
//
//     return command.join(' ');
//   }
// }
//
// class SubtitleStyle {
//   final String fontName;
//   final int fontSize;
//   final String primaryColor;
//   final String outlineColor;
//   final double outlineWidth;
//   final bool bold;
//   final String alignment; // Can be 'center', 'left', 'right'
//   final int marginV; // Vertical margin from bottom
//   final int marginH; // Horizontal margin
//
//   SubtitleStyle({
//     this.fontName = 'Arial',
//     this.fontSize = 24,
//     this.primaryColor = 'white',
//     this.outlineColor = 'black',
//     this.outlineWidth = 2,
//     this.bold = true,
//     this.alignment = 'center',
//     this.marginV = 20,
//     this.marginH = 20,
//   });
//
//   String get ffmpegStyleString {
//     final boldStr = bold ? ':bold=1' : '';
//     final alignStr = switch (alignment) {
//       'left' => '1',
//       'center' => '2',
//       'right' => '3',
//       _ => '2'
//     };
//
//     return 'force_style=\'Fontname=${fontName},'
//         'FontSize=${fontSize},'
//         'PrimaryColour=${_convertColor(primaryColor)},'
//         'OutlineColour=${_convertColor(outlineColor)},'
//         'Outline=${outlineWidth},'
//         'Alignment=${alignStr},'
//         'MarginV=${marginV},'
//         'MarginH=${marginH}'
//         '${boldStr}\'';
//   }
//
//   // Convert common color names or hex to ASS color format
//   String _convertColor(String color) {
//     final colorMap = {
//       'white': '&HFFFFFF',
//       'black': '&H000000',
//       'yellow': '&H00FFFF',
//       'red': '&H0000FF',
//       'green': '&H00FF00',
//       'blue': '&HFF0000',
//     };
//
//     if (colorMap.containsKey(color.toLowerCase())) {
//       return colorMap[color.toLowerCase()]!;
//     }
//
//     // If it's a hex color (e.g., #FF0000), convert it to ASS format
//     if (color.startsWith('#')) {
//       final hex = color.substring(1);
//       if (hex.length == 6) {
//         final r = hex.substring(0, 2);
//         final g = hex.substring(2, 4);
//         final b = hex.substring(4, 6);
//         return '&H${b}${g}${r}';
//       }
//     }
//
//     return '&HFFFFFF'; // Default to white if color format is not recognized
//   }
// }
//
// class VideoQualitySettings {
//   final String preset;
//   final String crf; // Constant Rate Factor (0-51, lower is better quality)
//   final String? videoBitrate;
//   final String? maxBitrate;
//   final String? bufsize;
//   final String videoCodec;
//
//   VideoQualitySettings({
//     this.preset =
//         'medium', // Options: ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow
//     this.crf = '18', // 18-28 is usually good. 18 is visually lossless
//     this.videoBitrate,
//     this.maxBitrate,
//     this.bufsize,
//     this.videoCodec = 'libx264', // or 'h264_nvenc' for NVIDIA GPU acceleration
//   });
// }
