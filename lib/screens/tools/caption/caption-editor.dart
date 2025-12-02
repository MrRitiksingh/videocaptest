import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:video_player/video_player.dart';

import '../../../components/file_image_viewer.dart';

class CaptionStyleConfig {
  Color mainTextColor;
  Color highlightColor;
  double fontSize;
  String fontFamily;
  TransitionEffect transition;
  Offset position;
  TextAlign alignment;

  static const defaultTransition = TransitionEffect(
    name: 'Word Highlight',
    assCommand: _defaultAssCommand,
  );

  static String _defaultAssCommand(int duration, String word,
      String highlightColor, String mainColor, double x, double y) {
    return '\\k$duration\\c&H$highlightColor&$word\\c&H$mainColor&';
  }

  CaptionStyleConfig({
    this.mainTextColor = Colors.white,
    this.highlightColor = Colors.yellow,
    this.fontSize = 48.0,
    this.fontFamily = 'Arial',
    this.transition = defaultTransition,
    this.position = const Offset(0.5, 0.8),
    this.alignment = TextAlign.center,
  });
}

class EnhancedSubtitleEditor extends StatefulWidget {
  final String videoFilePath;
  final List<dynamic> captionData;
  final Function(String) onSave;
  final KaraokeEffect karaokeEffect;

  const EnhancedSubtitleEditor({
    super.key,
    required this.videoFilePath,
    required this.captionData,
    required this.onSave,
    required this.karaokeEffect,
  });

  @override
  EnhancedSubtitleEditorState createState() => EnhancedSubtitleEditorState();
}

enum KaraokeEffect {
  follow,
  wordCaption,
}

class EnhancedSubtitleEditorState extends State<EnhancedSubtitleEditor> {
  late CaptionStyleConfig styleConfig;
  late List<Map<String, dynamic>> processedCaptions;
  int selectedCaptionIndex = -1;
  late VideoPlayerController videoPlayerController;
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    styleConfig = CaptionStyleConfig();
    processedCaptions = processCaptionData(widget.captionData);
    videoPlayerController =
        VideoPlayerController.file(File(widget.videoFilePath));
    initializeVideoPlayer();
  }

  Future<void> initializeVideoPlayer() async {
    await videoPlayerController.initialize();
    setState(() {});
  }

  List<Map<String, dynamic>> processCaptionData(List<dynamic> rawData) {
    return rawData.map((caption) {
      return {
        'id': caption['id'],
        'text': caption['text'],
        'start': caption['start'],
        'end': caption['end'],
        'words': caption['words'],
        'position': const Offset(0.0, 0.0),
        'style': CaptionStyleConfig(),
      };
    }).toList();
  }

  String generateKaraokeASSSubtitles() {
    final videoInfo = videoPlayerController.value;
    final videoWidth = videoInfo.size.width;
    final videoHeight = videoInfo.size.height;
    final buffer = StringBuffer();

    final defaultX = videoWidth / 2;
    final defaultY = videoHeight * 0.8;

    // Convert colors to ASS format with alpha channel
    final mainColor = '00${_colorToASSString(styleConfig.mainTextColor)}';
    final highlightColor = '00${_colorToASSString(styleConfig.highlightColor)}';

    buffer.writeln('''[Script Info]
ScriptType: v4.00+
PlayResX: ${videoWidth.toInt()}
PlayResY: ${videoHeight.toInt()}
YCbCr Matrix: TV.709
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,${styleConfig.fontFamily},${styleConfig.fontSize},&H${mainColor},&H${highlightColor},&H000000,&H80000000,1,0,0,0,100,100,0,0,1,2,1,2,20,20,20,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text''');

    for (var caption in processedCaptions) {
      final startTime = _formatTime(double.parse(caption['start'].toString()));
      final endTime = _formatTime(double.parse(caption['end'].toString()));
      final position = caption['position'] as Offset;

      final x = position.dx > 0 ? position.dx : defaultX;
      final y = position.dy > 0 ? position.dy : defaultY;

      final textBuffer = StringBuffer();

      // Position and base color setup
      textBuffer.write('{\\pos($x,$y)}');

      // Create karaoke effect for each word
      for (var word in caption['words']) {
        final duration = ((double.parse(word['end'].toString()) -
                    double.parse(word['start'].toString())) *
                100)
            .round();

        // Karaoke effect with color transformation
        textBuffer.write('{');
        // Start with main color
        textBuffer.write('\\c&H${mainColor}&');
        // Add timing for color change
        textBuffer.write('\\k$duration');
        // Add the word
        textBuffer.write('}${word['word']} ');

        // Reset to main color for next word
        textBuffer.write('{\\c&H${mainColor}&}');
      }

      buffer.writeln(
          'Dialogue: 0,$startTime,$endTime,Default,,0,0,0,,$textBuffer');
    }

    return buffer.toString();
  }

  String generateOnlyWordASSSubtitles() {
    final videoInfo = videoPlayerController.value;
    final videoWidth = videoInfo.size.width;
    final videoHeight = videoInfo.size.height;
    final buffer = StringBuffer();

    final defaultX = videoWidth / 2;
    final defaultY = videoHeight * 0.8;

    // Convert colors to ASS format with alpha channel
    final mainColor = '00${_colorToASSString(styleConfig.mainTextColor)}';
    final highlightColor = '00${_colorToASSString(styleConfig.highlightColor)}';

    buffer.writeln('''[Script Info]
ScriptType: v4.00+
PlayResX: ${videoWidth.toInt()}
PlayResY: ${videoHeight.toInt()}
YCbCr Matrix: TV.709
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,${styleConfig.fontFamily},${styleConfig.fontSize},&H${mainColor},&H${highlightColor},&H000000,&H80000000,1,0,0,0,100,100,0,0,1,2,1,2,20,20,20,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text''');

    for (var caption in processedCaptions) {
      final startTime = _formatTime(double.parse(caption['start'].toString()));
      final endTime = _formatTime(double.parse(caption['end'].toString()));
      final position = caption['position'] as Offset;

      final x = position.dx > 0 ? position.dx : defaultX;
      final y = position.dy > 0 ? position.dy : defaultY;

      final textBuffer = StringBuffer();
      textBuffer.write('{\\pos($x,$y)}');

      for (var word in caption['words']) {
        final duration = ((double.parse(word['end'].toString()) -
                    double.parse(word['start'].toString())) *
                100)
            .round();
        // Word starts with highlight color, then instantly changes to main color after duration
        textBuffer.write(
            '\\k$duration\\c&H${highlightColor}&${word['word']}\\c&H${mainColor}& ');
      }

      buffer.writeln(
          'Dialogue: 0,$startTime,$endTime,Default,,0,0,0,,$textBuffer');
    }

    return buffer.toString();
  }

  String _formatTime(double seconds) {
    final hours = (seconds ~/ 3600).toString().padLeft(1, '0');
    final minutes = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toStringAsFixed(2).padLeft(5, '0');
    return '$hours:$minutes:$secs';
  }

  String _colorToASSString(Color color) {
    // ASS uses BBGGRR format (without alpha)
    return '${color.blue.toRadixString(16).padLeft(2, '0')}'
        '${color.green.toRadixString(16).padLeft(2, '0')}'
        '${color.red.toRadixString(16).padLeft(2, '0')}';
  }

  final List<TransitionEffect> availableTransitions = [
    TransitionEffect(
      name: 'Word Highlight',
      assCommand: (duration, word, highlightColor, mainColor, x, y) =>
          '\\k$duration\\c&H$highlightColor&$word\\c&H$mainColor&',
    ),
    TransitionEffect(
      name: 'Fade In',
      assCommand: (duration, word, highlightColor, mainColor, x, y) =>
          '{\\pos($x,$y)\\fad(200,0)}\\k$duration$word',
    ),
    TransitionEffect(
      name: 'Slide Up',
      assCommand: (duration, word, highlightColor, mainColor, x, y) =>
          '{\\move($x,${y + 50},$x,$y,200)}\\k$duration$word',
    ),
    TransitionEffect(
      name: 'Pop',
      assCommand: (duration, word, highlightColor, mainColor, x, y) =>
          '{\\pos($x,$y)\\t(0,200,\\fscx120\\fscy120)\\t(200,400,\\fscx100\\fscy100)}\\k$duration$word',
    ),
  ];

  Widget buildStyleControls() {
    return Column(
      children: [
        ListTile(
          title: const Text('Main Text Color'),
          trailing: ColorPickerButton(
            color: styleConfig.mainTextColor,
            onColorChanged: (color) {
              setState(() => styleConfig.mainTextColor = color);
            },
          ),
        ),
        ListTile(
          title: const Text('Highlight Color'),
          trailing: ColorPickerButton(
            color: styleConfig.highlightColor,
            onColorChanged: (color) {
              setState(() => styleConfig.highlightColor = color);
            },
          ),
        ),
        Slider(
          value: styleConfig.fontSize,
          min: 12.0,
          max: 72.0,
          divisions: 60,
          label: '${styleConfig.fontSize.round()}',
          onChanged: (value) {
            setState(() => styleConfig.fontSize = value);
          },
        ),
        DropdownButton<TransitionEffect>(
          value: styleConfig.transition,
          items: availableTransitions
              .map((effect) => DropdownMenuItem(
                    value: effect,
                    child: Text(effect.name),
                  ))
              .toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => styleConfig.transition = value);
            }
          },
        ),
      ],
    );
  }

  Widget buildCaptionPreview() {
    return Stack(
      children: [
        FileVideoViewer(
          onPressed: () {},
          fileDataSourceType: FileDataSourceType.file,
          videoFilePath: widget.videoFilePath,
        ),
        ...processedCaptions
            .map((caption) => Positioned(
                  left: caption['position'].dx,
                  top: caption['position'].dy,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        final size = context.size!;
                        final videoInfo = videoPlayerController.value;
                        final videoWidth = videoInfo.size.width;
                        final videoHeight = videoInfo.size.height;

                        // Convert screen coordinates to video coordinates
                        final newX = (details.localPosition.dx / size.width) *
                            videoWidth;
                        final newY = (details.localPosition.dy / size.height) *
                            videoHeight;

                        final idx = processedCaptions.indexOf(caption);
                        processedCaptions[idx]['position'] = Offset(newX, newY);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      child: RichText(
                        text: TextSpan(
                          children: _buildWordSpans(caption['words']),
                          style: TextStyle(
                            fontSize: caption['style'].fontSize,
                            fontFamily: caption['style'].fontFamily,
                          ),
                        ),
                      ),
                    ),
                  ),
                ))
            .toList(),
      ],
    );
  }

  List<TextSpan> _buildWordSpans(List<dynamic> words) {
    return words.map((word) {
      return TextSpan(
        text: word['word'],
        style: TextStyle(
          color: (word['highlighted'] ?? false)
              ? styleConfig.highlightColor
              : styleConfig.mainTextColor,
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        buildStyleControls(),
        buildCaptionPreview(),
        ElevatedButton(
          onPressed: () {
            String assSubtitles = "";
            if (widget.karaokeEffect == KaraokeEffect.follow) {
              assSubtitles = generateKaraokeASSSubtitles();
            } else {
              assSubtitles = generateOnlyWordASSSubtitles();
            }
            widget.onSave(assSubtitles);
          },
          child: const Text('Save Captions'),
        ),
      ],
    );
  }
}

class ColorPickerButton extends StatelessWidget {
  final Color color;
  final ValueChanged<Color> onColorChanged;

  const ColorPickerButton({
    super.key,
    required this.color,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Pick a color'),
              content: SingleChildScrollView(
                child: ColorPicker(
                  pickerColor: color,
                  onColorChanged: onColorChanged,
                  portraitOnly: true, // Optional: makes it more compact
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Done'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            );
          },
        );
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

/// copy 2
class TransitionEffect {
  final String name;

  // final String Function(int duration, String word, String highlightColor, String mainColor) assCommand;
  final String Function(int duration, String word, String highlightColor,
      String mainColor, double x, double y) assCommand;

  const TransitionEffect({
    required this.name,
    required this.assCommand,
  });

  // Add equality operators
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransitionEffect && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;
}

class CaptionStyle {
  Color mainTextColor;
  Color highlightColor;
  double fontSize;
  String fontFamily;
  TransitionEffect transition;
  Offset position;
  TextAlign alignment;

  CaptionStyle({
    this.mainTextColor = Colors.white,
    this.highlightColor = Colors.yellow,
    this.fontSize = 48.0, // Increased default size for better visibility
    this.fontFamily = 'Arial',
    this.transition = defaultTransition, // Uses the constant defined above
    this.position = const Offset(0.5, 0.8), // Default to bottom-center
    this.alignment = TextAlign.center,
  });

  static const defaultTransition = TransitionEffect(
    name: 'Word Highlight',
    assCommand: _defaultAssCommand, // Reference to static function
  );

  // Separate static function for the ASS command
  static String _defaultAssCommand(int duration, String word,
      String highlightColor, String mainColor, double x, double y) {
    return '\\k$duration\\c&H$highlightColor&$word\\c&H$mainColor&';
  }

  String toASSStyle() {
    return '''Style: Default,${fontFamily},${fontSize},&H${mainTextColor.value.toRadixString(16)},&H${highlightColor.value.toRadixString(16)},&H000000,&H00000000,1,0,0,0,100,100,0,0,1,2,2,2,20,20,20,1''';
  }
}

// class EnhancedCaptionEditor extends StatefulWidget {
//   final String videoFilePath;
//   final List<dynamic> captionData;
//   final Function(String) onSave;
//
//   const EnhancedCaptionEditor({
//     Key? key,
//     required this.videoFilePath,
//     required this.captionData,
//     required this.onSave,
//   }) : super(key: key);
//
//   @override
//   _EnhancedCaptionEditorState createState() => _EnhancedCaptionEditorState();
// }
//
// class _EnhancedCaptionEditorState extends State<EnhancedCaptionEditor> {
//   late CaptionStyle style;
//   late List<CaptionEntry> captions;
//   int selectedCaptionIndex = -1;
//   late VideoPlayerController videoPlayerController; // declare as late
//
//   bool isPlaying = false;
//
//   final List<TransitionEffect> availableTransitions = [
//     TransitionEffect(
//       name: 'Word Highlight',
//       assCommand: (duration, word, highlightColor, mainColor, x, y) =>
//           '\\k$duration\\c&H$highlightColor&$word\\c&H$mainColor&',
//     ),
//     TransitionEffect(
//       name: 'Fade In',
//       assCommand: (duration, word, highlightColor, mainColor, x, y) =>
//           '{\\pos($x,$y)\\fad(200,0)}\\k$duration$word',
//     ),
//     TransitionEffect(
//       name: 'Slide Up',
//       assCommand: (duration, word, highlightColor, mainColor, x, y) =>
//           '{\\move($x,${y + 50},$x,$y,200)}\\k$duration$word',
//     ),
//     TransitionEffect(
//       name: 'Pop',
//       assCommand: (duration, word, highlightColor, mainColor, x, y) =>
//           '{\\pos($x,$y)\\t(0,200,\\fscx120\\fscy120)\\t(200,400,\\fscx100\\fscy100)}\\k$duration$word',
//     ),
//   ];
//
//   @override
//   void initState() {
//     super.initState();
//     style = CaptionStyle();
//     captions = processCaptionData(widget.captionData);
//     // Initialize video controller here
//     videoPlayerController =
//         VideoPlayerController.file(File(widget.videoFilePath));
//     initializeVideoPlayer();
//   }
//
//   Future<void> initializeVideoPlayer() async {
//     await videoPlayerController.initialize();
//     setState(() {});
//   }
//
//   List<CaptionEntry> processCaptionData(List<dynamic> rawData) {
//     return rawData.map((caption) {
//       return CaptionEntry(
//         id: caption['id'],
//         text: caption['text'],
//         startTime: caption['start'],
//         endTime: caption['end'],
//         words: (caption['words'] as List)
//             .map((word) => WordEntry(
//                   text: word['word'],
//                   startTime: word['start'],
//                   endTime: word['end'],
//                   probability: word['probability'],
//                 ))
//             .toList(),
//         style: CaptionStyle(),
//         position: style.position,
//       );
//     }).toList();
//   }
//
//   String generateASSSubtitles() {
//     final buffer = StringBuffer();
//
//     // Write ASS header
//     buffer.writeln('''[Script Info]
// ScriptType: v4.00+
// PlayResX: 1280
// PlayResY: 720
// WrapStyle: 0
//
// [V4+ Styles]
// Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
// ${style.toASSStyle()}
//
// [Events]
// Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text''');
//
//     // Generate events for each caption
//     for (var caption in captions) {
//       final startTime = _formatASSTime(caption.startTime);
//       final endTime = _formatASSTime(caption.endTime);
//       final position = _calculatePosition(caption.position);
//
//       var text = '';
//       var currentTime = caption.startTime;
//
//       // Apply word-by-word highlighting
//       for (var word in caption.words) {
//         final duration =
//             (word.endTime - word.startTime) * 100; // Convert to centiseconds
//         text += '{\\k$duration}${word.text}';
//       }
//
//       // Add positioning and transition effects
//       text = '${caption.style.transition.assCommand}{\\pos($position)}$text';
//
//       buffer.writeln('Dialogue: 0,$startTime,$endTime,Default,,0,0,0,,$text');
//     }
//
//     return buffer.toString();
//   }
//
//   String _formatASSTime(double seconds) {
//     final hours = (seconds ~/ 3600).toString().padLeft(1, '0');
//     final minutes = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
//     final secs = (seconds % 60).toStringAsFixed(2).padLeft(5, '0');
//     return '$hours:$minutes:$secs';
//   }
//
//   String _calculatePosition(Offset position) {
//     final x = (position.dx * 1280).round(); // Scale to PlayResX
//     final y = (position.dy * 720).round(); // Scale to PlayResY
//     return '$x,$y';
//   }
//
//   Widget buildPreviewArea() {
//     return Stack(
//       children: [
//         AspectRatio(
//           aspectRatio: videoPlayerController.value.aspectRatio,
//           child: VideoPlayer(videoPlayerController),
//         ),
//         if (selectedCaptionIndex >= 0)
//           Positioned.fill(
//             child: GestureDetector(
//               onPanUpdate: (details) {
//                 setState(() {
//                   final RenderBox box = context.findRenderObject() as RenderBox;
//                   final pos = box.globalToLocal(details.globalPosition);
//                   captions[selectedCaptionIndex].position = Offset(
//                     pos.dx / box.size.width,
//                     pos.dy / box.size.height,
//                   );
//                 });
//               },
//               child: CaptionPreview(
//                 caption: captions[selectedCaptionIndex],
//                 style: style,
//               ),
//             ),
//           ),
//       ],
//     );
//   }
//
//   Widget buildStyleControls() {
//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Style Settings',
//                 style: Theme.of(context).textTheme.titleLarge),
//             const SizedBox(height: 16),
//
//             // Color controls
//             Row(
//               children: [
//                 Expanded(
//                   child: ColorPickerField(
//                     label: 'Main Color',
//                     color: style.mainTextColor,
//                     onColorChanged: (color) =>
//                         setState(() => style.mainTextColor = color),
//                   ),
//                 ),
//                 const SizedBox(width: 16),
//                 Expanded(
//                   child: ColorPickerField(
//                     label: 'Highlight Color',
//                     color: style.highlightColor,
//                     onColorChanged: (color) =>
//                         setState(() => style.highlightColor = color),
//                   ),
//                 ),
//               ],
//             ),
//
//             const SizedBox(height: 16),
//
//             // Font size control
//             Row(
//               children: [
//                 const Text('Font Size'),
//                 Expanded(
//                   child: Slider(
//                     value: style.fontSize,
//                     min: 24.0,
//                     max: 72.0,
//                     divisions: 48,
//                     label: style.fontSize.round().toString(),
//                     onChanged: (value) =>
//                         setState(() => style.fontSize = value),
//                   ),
//                 ),
//               ],
//             ),
//
//             // Transition selector
//             DropdownButtonFormField<TransitionEffect>(
//               value: style.transition,
//               decoration: const InputDecoration(labelText: 'Transition Effect'),
//               items: availableTransitions
//                   .map((effect) => DropdownMenuItem(
//                         value: effect,
//                         child: Text(effect.name),
//                       ))
//                   .toList(),
//               onChanged: (value) => setState(() => style.transition = value!),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         // Video preview with captions
//         buildPreviewArea(),
//
//         // Style controls
//         buildStyleControls(),
//
//         // Caption list
//         Expanded(
//           child: ListView.builder(
//             itemCount: captions.length,
//             itemBuilder: (context, index) {
//               final caption = captions[index];
//               return ListTile(
//                 selected: selectedCaptionIndex == index,
//                 title: Text(caption.text),
//                 subtitle: Text(
//                     '${_formatASSTime(caption.startTime)} - ${_formatASSTime(caption.endTime)}'),
//                 onTap: () => setState(() => selectedCaptionIndex = index),
//               );
//             },
//           ),
//         ),
//
//         // Save button
//         Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: ElevatedButton(
//             onPressed: () => widget.onSave(generateASSSubtitles()),
//             child: const Text('Save Captions'),
//           ),
//         ),
//       ],
//     );
//   }
//
//   @override
//   void dispose() {
//     videoPlayerController.dispose();
//     super.dispose();
//   }
// }

class CaptionEntry {
  final int id;
  final String text;
  final double startTime;
  final double endTime;
  final List<WordEntry> words;
  CaptionStyle style;
  Offset position;

  CaptionEntry({
    required this.id,
    required this.text,
    required this.startTime,
    required this.endTime,
    required this.words,
    required this.style,
    required this.position,
  });
}

class WordEntry {
  final String text;
  final double startTime;
  final double endTime;
  final double probability;

  WordEntry({
    required this.text,
    required this.startTime,
    required this.endTime,
    required this.probability,
  });
}

class CaptionPreview extends StatelessWidget {
  final CaptionEntry caption;
  final CaptionStyle style;

  const CaptionPreview({
    super.key,
    required this.caption,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: caption.position.dx,
      top: caption.position.dy,
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          caption.text,
          style: TextStyle(
            color: style.mainTextColor,
            fontSize: style.fontSize,
            fontFamily: style.fontFamily,
          ),
          textAlign: style.alignment,
        ),
      ),
    );
  }
}

class ColorPickerField extends StatelessWidget {
  final String label;
  final Color color;
  final ValueChanged<Color> onColorChanged;

  const ColorPickerField({
    Key? key,
    required this.label,
    required this.color,
    required this.onColorChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label),
        const SizedBox(width: 8),
        InkWell(
          onTap: () => _showColorPicker(context),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    );
  }

  void _showColorPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(label),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: color,
              onColorChanged: onColorChanged,
              portraitOnly: true,
              colorPickerWidth: 300,
              pickerAreaHeightPercent: 0.7,
              enableAlpha: true,
              labelTypes: const [],
              displayThumbColor: true,
              hexInputBar: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }
}
