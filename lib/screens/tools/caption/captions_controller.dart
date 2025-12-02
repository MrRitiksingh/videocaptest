import 'dart:io';

import 'package:ai_video_creator_editor/screens/tools/simple_video_result.dart';
import 'package:ai_video_creator_editor/utils/functions.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:video_player/video_player.dart';

import '../../../components/file_image_viewer.dart';
import '../../../controllers/srt_to_ass_converter.dart';
import '../../../main.dart';
import '../../../utils/uploads.dart';
import '../../project/editor_controller.dart';
import '../../project/new_editor/caption_editor.dart';
import '../../project/new_editor/frame_extractor.dart';

class CaptionsController extends ChangeNotifier {
  // getters
  VideoPlayerController? get controller => _controller;

  List<Map<String, dynamic>> get captions => _captions;

  File? get currentVideoFile => _currentVideoFile;

  File? get extractedAudioFile => _extractedAudioFile;

  String? get extractedAudioUrl => _extractedAudioUrl;

  bool get isPlaying => _isPlaying;

  double get playbackPosition => _playbackPosition;

  CaptionType? get currentCaptionType => _currentCaptionType;

  List<CaptionType> get listCaptionType => _listCaptionType;

  // Controllers
  VideoPlayerController? _controller;

  // List<VideoCaption> _captions = [];
  List<Map<String, dynamic>> _captions = [];
  File? _currentVideoFile;
  File? _extractedAudioFile;
  String? _extractedAudioUrl;
  double _trimStart = 0.0;
  double _trimEnd = 0.0;
  double _playbackPosition = 0.0;

  // UI state properties
  bool _isPlaying = false;
  bool _isExtractingFrames = false;
  List<String> _framePaths = [];

  // List<double> _waveformData = [];
  initialize({
    required BuildContext context,
  }) async {
    _currentVideoFile = await pickVideo(context, durationSeconds: 300);
    if (_currentVideoFile == null) return;
    _controller?.dispose();
    _controller = VideoPlayerController.file(_currentVideoFile!);
    await _controller?.initialize();
    _controller?.setLooping(true);
    _trimEnd = _controller?.value.duration.inSeconds.toDouble() ?? 0.0;
    // _controller?.addListener(() {
    //   _playbackPosition =
    //       _controller?.value.position.inSeconds.toDouble() ?? 0.0;
    //   notifyListeners();
    // });
    // Add position listener
    _controller?.addListener(_onVideoPositionChanged);
    // Extract initial frames
    extractFrames();
    extractCurrentAudioFile();

    notifyListeners();
  }

  // @override
  void deactivate({bool? notify = false}) {
    _controller?.dispose();
    _currentVideoFile = null;
    _extractedAudioFile = null;
    _extractedAudioUrl = null;
    _trimStart = 0.0;
    _trimEnd = 0.0;
    _playbackPosition = 0.0;
    _isPlaying = false;
    _isExtractingFrames = false;
    _framePaths = [];
    _captions = [];
    segmentCurrentSentence = '';
    segmentCurrentSpokenWord = '';
    segmentCurrentWords = [];
    textPositionX = 100.0;
    textPositionY = 100.0;
    if (notify == true) {
      notifyListeners();
    }
  }

  double textPositionX = 100.0;
  double textPositionY = 100.0;

  void updateTextPosition(
      DraggableDetails dragDetails, double maxWidth, double maxHeight) {
    final RenderBox renderBox =
        navigatorKey.currentContext!.findRenderObject() as RenderBox;
    final Offset localPosition = renderBox.globalToLocal(dragDetails.offset);

    // Calculate new positions while keeping text within bounds
    textPositionX = localPosition.dx
        .clamp(0, maxWidth - 100); // 100 is approximate text width
    textPositionY = (localPosition.dy - kToolbarHeight)
        .clamp(0, maxHeight - 50); // 50 is approximate text height

    notifyListeners();
  }

  // updateTextPosition(DraggableDetails dragDetails) {
  //   textPositionY = dragDetails.offset.dy - kToolbarHeight;
  //   textPositionX = dragDetails.offset.dx;
  //   notifyListeners();
  // }

  void _onVideoPositionChanged() {
    if (_controller == null) return;

    _playbackPosition = _controller!.value.position.inSeconds.toDouble();
    // Check if position is outside trim bounds
    if (_playbackPosition < _trimStart) {
      _controller?.seekTo(Duration(seconds: _trimStart.round()));
    } else if (_playbackPosition > _trimEnd) {
      segmentCurrentSentence = "";
      segmentCurrentSpokenWord = '';
      segmentCurrentWords = [];
      _controller?.seekTo(Duration(seconds: _trimStart.round()));
      _controller?.pause();
    }
    if (_captions.isNotEmpty) {
      getCurrentWords(_playbackPosition);
    }
    notifyListeners();
  }

  // Frame extraction
  Future<void> extractFrames() async {
    if (_controller == null || _isExtractingFrames) return;

    _isExtractingFrames = true;
    notifyListeners();

    try {
      _framePaths = await FrameExtractor.extractFrames(
        videoPath: _controller!.dataSource,
        frameCount: 10,
        videoDuration: _controller!.value.duration,
      );
    } finally {
      _isExtractingFrames = false;
      notifyListeners();
    }
  }

  void togglePlay() {
    if (_controller == null) return;
    if (_isPlaying) {
      _controller?.pause();
    } else {
      _controller?.play();
    }
    _isPlaying = !_isPlaying;
    notifyListeners();
  }

  void seekTo(double position) {
    if (_controller == null) return;

    // Clamp position within trim bounds
    position = position.clamp(_trimStart, _trimEnd);
    _controller?.seekTo(Duration(seconds: position.round()));
    notifyListeners();
  }

  Future<void> fetchCaptions({required String videoLanguage}) async {}

  extractCurrentAudioFile() async {
    if (_extractedAudioFile != null || _currentVideoFile == null) {
      return _extractedAudioFile;
    }
    _extractedAudioFile = await EditorVideoController.extractAudioFromVideo(
        videoFile: _currentVideoFile!);
  }

  uploadExtractedAudio() async {
    if (_extractedAudioFile == null) throw Exception("Extracted audio is null");
    if (_extractedAudioUrl != null) {
      return _extractedAudioUrl;
    }
    _extractedAudioUrl = "";
    notifyListeners();
  }

  makeCaptions({
    required BuildContext context,
    required String language,
  }) async {
    if (_extractedAudioUrl == null) {
      throw Exception("Extracted audio url is null");
    }
    _captions = [];
    getCurrentWords(_playbackPosition);
  }

  String segmentCurrentSentence = '';
  String segmentCurrentSpokenWord = '';
  List<VideoCaption> segmentCurrentWords = [];

  void getCurrentWords(
    double durationInSeconds,
  ) {
    for (var segment in _captions) {
      num start = segment['start'];
      num end = segment['end'];

      // Check if the duration falls within this segment
      if (durationInSeconds >= start && durationInSeconds <= end) {
        // print('Text: ${segment['text']}');
        segmentCurrentSentence = segment["text"] ?? "";

        List<dynamic> words = segment['words'];
        // print(words[0]["end"].runtimeType);
        segmentCurrentWords = words
            .map(
              (word) => VideoCaption(
                text: word['word'] ?? "",
                startTime: double.parse((word['start'] ?? 0.0).toString()),
                endTime: double.parse((word['end'] ?? 0.0).toString()),
              ),
            )
            .toList();

        ///
        // print('All Words in Segment:');
        // for (var word in words) {
        //   print(
        //       '${word['word']} (Start: ${word['start']}, End: ${word['end']})');
        // }

        // Find the current spoken word if the time matches in integers
        int currentTime = durationInSeconds.toInt();
        for (var word in words) {
          int wordStart = word['start'].toInt();
          int wordEnd = word['end'].toInt();

          if (currentTime >= wordStart && currentTime <= wordEnd) {
            // print('Current Spoken Word: ${word['word']}');
            segmentCurrentSpokenWord = word['word'] ?? "";
            break;
          }
        }
        return; // Exit after processing the matching segment
      }
    }
    // print('No matching segment found for duration: $durationInSeconds seconds');
    notifyListeners();
  }

  void selectCaptionType(CaptionType value) {
    // print(value.modelID);
    _currentCaptionType = value;
    notifyListeners();
  }

  CaptionType? _currentCaptionType = CaptionType(
    name: 'Simple Captions',
    modelID: "simple_captions",
    hasBackgroundColor: true,
    hasDefaultFontSize: true,
    hasPrimaryTextColor: true,
    hasSecondaryTextColor: false,
  );
  double currentCaptionTypeDefaultFontSize = 12.0;
  Color currentCaptionTypeBackGroundColor = Colors.white;
  Color currentCaptionTypePrimaryTextColor = Colors.black;
  Color currentCaptionTypeSecondaryTextColor = Colors.yellow;

  updateCurrentCaptionTypeSecondaryTextColor(Color color) {
    currentCaptionTypeSecondaryTextColor = color;
    notifyListeners();
  }

  updateCurrentCaptionTypePrimaryTextColor(Color color) {
    currentCaptionTypePrimaryTextColor = color;
    notifyListeners();
  }

  updateCurrentCaptionTypeBackGroundColor(Color color) {
    currentCaptionTypeBackGroundColor = color;
    notifyListeners();
  }

  updateCurrentCaptionTypeDefaultFontSize(double dfs) {
    currentCaptionTypeDefaultFontSize = dfs;
    notifyListeners();
  }

  final List<CaptionType> _listCaptionType = [
    CaptionType(
      name: 'Simple Captions',
      modelID: "simple_captions",
      hasBackgroundColor: true,
      hasDefaultFontSize: true,
      hasPrimaryTextColor: true,
      hasSecondaryTextColor: false,
    ),
    CaptionType(
      name: 'Karaoke',
      modelID: "karaoke",
      hasBackgroundColor: false,
      hasDefaultFontSize: true,
      hasPrimaryTextColor: true,
      hasSecondaryTextColor: true,
    ),
  ];

  Future<void> generateCaptions({
    required BuildContext context,
  }) async {
    VideoPlayerValue videoInfo = controller!.value;
    if (_currentCaptionType?.modelID.toLowerCase() == "karaoke") {
      String assSubtitles = generateKaraokeASSSubtitles(
        videoInfo: videoInfo,
        defaultX: textPositionX,
        defaultY: textPositionY,
        mainTextColor: currentCaptionTypePrimaryTextColor,
        secondaryHighlightColor: currentCaptionTypeSecondaryTextColor,
        processedCaptions: captions,
        fontSize: currentCaptionTypeDefaultFontSize,
      );
      try {
        context.loaderOverlay.show();
        await Future.delayed(const Duration(milliseconds: 300));
        context.loaderOverlay.show();
        File? srtFile =
            await SubtitleConverter.assStringToAssFile(assSubtitles);
        safePrint(srtFile);
        File? result = await EditorVideoController.embedAssSubtitleFile(
          videoFile: currentVideoFile!,
          subtitleFileASS: srtFile!,
        );
        if (result == null) {
          context.loaderOverlay.hide();
          return;
        }
        context.loaderOverlay.hide();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SimpleVideoResult(
              videoFilePath: result.path,
              betterPlayerDataSourceType: FileDataSourceType.file,
            ),
          ),
        );
      } catch (err) {
        context.loaderOverlay.hide();
        rethrow;
      }
    } else if (_currentCaptionType?.modelID.toLowerCase() ==
        "simple_captions") {
      String assSubtitles = generateOnlyWordASSSubtitles(
        videoInfo: videoInfo,
        defaultX: textPositionX,
        defaultY: textPositionY,
        mainTextColor: currentCaptionTypePrimaryTextColor,
        secondaryHighlightColor: currentCaptionTypeSecondaryTextColor,
        processedCaptions: captions,
        fontSize: currentCaptionTypeDefaultFontSize,
      );
      try {
        context.loaderOverlay.show();
        await Future.delayed(const Duration(milliseconds: 300));
        context.loaderOverlay.show();
        File? srtFile =
            await SubtitleConverter.assStringToAssFile(assSubtitles);
        print(srtFile);
        File? result = await EditorVideoController.embedAssSubtitleFile(
          videoFile: currentVideoFile!,
          subtitleFileASS: srtFile!,
        );
        if (result == null) {
          context.loaderOverlay.hide();
          return;
        }
        context.loaderOverlay.hide();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SimpleVideoResult(
              videoFilePath: result.path,
              betterPlayerDataSourceType: FileDataSourceType.file,
            ),
          ),
        );
      } catch (err) {
        context.loaderOverlay.hide();
        rethrow;
      }
    }
  }
}

String generateOnlyWordASSSubtitles({
  required VideoPlayerValue videoInfo,
  required double defaultX,
  required double defaultY,
  required Color mainTextColor,
  required Color secondaryHighlightColor, // Background box color
  required List<Map<String, dynamic>> processedCaptions,
  required double fontSize,
  String fontFamily = "Arial",
}) {
  String colorToASSString(Color color) {
    String bb = color.blue.toRadixString(16).padLeft(2, '0');
    String gg = color.green.toRadixString(16).padLeft(2, '0');
    String rr = color.red.toRadixString(16).padLeft(2, '0');
    return '&H00$bb$gg$rr&'; // 00 for full opacity
  }

  final String assScript = '''[Script Info]
Title: Generated Subtitles
ScriptType: v4.00+
WrapStyle: 0
ScaledBorderAndShadow: yes
PlayResX: ${videoInfo.size.width}
PlayResY: ${videoInfo.size.height}

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,${fontFamily},${fontSize},${colorToASSString(mainTextColor)},${colorToASSString(mainTextColor)},&H00000000&,${colorToASSString(secondaryHighlightColor)},1,0,0,0,100,100,0,0,3,1,0,2,${defaultX.toInt()},${defaultX.toInt()},${defaultY.toInt()},1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
''' +
      processedCaptions.map((caption) {
        String startTime = _formatTime(caption['start']);
        String endTime = _formatTime(caption['end']);
        String text = caption['text'];
        String effect = caption['transition'] ?? '';

        // Using simple box style with border for better visibility
        return 'Dialogue: 0,$startTime,$endTime,Default,,0,0,0,$effect,$text\n';
      }).join();

  return assScript;
}

String generateKaraokeASSSubtitles({
  required VideoPlayerValue videoInfo,
  required double defaultX,
  required double defaultY,
  required Color mainTextColor,
  required Color secondaryHighlightColor,
  required List<Map<String, dynamic>> processedCaptions,
  required double fontSize,
  String fontFamily = "Arial",
}) {
  final videoWidth = videoInfo.size.width;
  final videoHeight = videoInfo.size.height;
  final buffer = StringBuffer();

  // final defaultX = videoWidth / 2;
  // final defaultY = videoHeight * 0.8;

  // Convert colors to ASS format with alpha channel
  final mainColor = '00${_colorToASSString(mainTextColor)}';
  final highlightColor = '00${_colorToASSString(secondaryHighlightColor)}';

  buffer.writeln('''[Script Info]
ScriptType: v4.00+
PlayResX: ${videoWidth.toInt()}
PlayResY: ${videoHeight.toInt()}
YCbCr Matrix: TV.709
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,${fontFamily},${fontSize},&H${mainColor},&H${highlightColor},&H000000,&H80000000,1,0,0,0,100,100,0,0,1,2,1,2,20,20,20,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text''');

  for (var caption in processedCaptions) {
    final startTime = _formatTime(double.parse(caption['start'].toString()));
    final endTime = _formatTime(double.parse(caption['end'].toString()));
    // final position = caption['position'] as Offset;
    // final x = position.dx > 0 ? position.dx : defaultX;
    // final y = position.dy > 0 ? position.dy : defaultY;
    final x = defaultX;
    final y = defaultY;

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

    buffer
        .writeln('Dialogue: 0,$startTime,$endTime,Default,,0,0,0,,$textBuffer');
  }

  return buffer.toString();
}

String _formatTime(num seconds) {
  seconds = double.parse(seconds.toString());
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

class CaptionType {
  String name;
  String modelID;
  bool hasBackgroundColor;

  // String primaryTextColor;
  bool hasPrimaryTextColor;
  bool hasSecondaryTextColor;
  bool hasDefaultFontSize;

  CaptionType({
    required this.name,
    required this.modelID,
    required this.hasBackgroundColor,
    required this.hasDefaultFontSize,
    required this.hasPrimaryTextColor,
    required this.hasSecondaryTextColor,
    // required this.primaryTextColor,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'model_id': modelID,
      'hasBackgroundColor': hasBackgroundColor,
      'hasPrimaryTextColor': hasPrimaryTextColor,
      'hasSecondaryTextColor': hasSecondaryTextColor,
      'hasDefaultFontSize': hasDefaultFontSize,
    };
  }

  // Optional: Add fromJson constructor if you need to create CaptionType from Map
  factory CaptionType.fromJson(Map<String, dynamic> json) {
    return CaptionType(
      name: json['name'],
      modelID: json['model_id'],
      hasBackgroundColor: json['hasBackgroundColor'],
      hasPrimaryTextColor: json['hasPrimaryTextColor'],
      hasSecondaryTextColor: json['hasSecondaryTextColor'],
      hasDefaultFontSize: json['hasDefaultFontSize'],
    );
  }
}

// Extension method to convert List<CaptionType> to List<Map<String, dynamic>>
extension CaptionTypeListExtension on List<CaptionType> {
  List<Map<String, dynamic>> toJsonList() {
    return map((captionType) => captionType.toJson()).toList();
  }
}

// Alternative: Standalone function to convert List<CaptionType> to List<Map<String, dynamic>>
List<Map<String, dynamic>> captionTypesToJson(List<CaptionType> captionTypes) {
  return captionTypes.map((captionType) => captionType.toJson()).toList();
}
