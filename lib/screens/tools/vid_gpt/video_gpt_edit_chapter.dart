import 'dart:async';
import 'dart:io';

import 'package:ai_video_creator_editor/components/glowing_button.dart';
import 'package:ai_video_creator_editor/components/gradient_scaffold.dart';
import 'package:ai_video_creator_editor/components/sliding_up_scaffold.dart'
    show SlidingUpScaffold;
import 'package:ai_video_creator_editor/components/text_field.dart';
import 'package:ai_video_creator_editor/constants/extensions.dart';
import 'package:ai_video_creator_editor/database/models/generated_audio_meta.dart';
import 'package:ai_video_creator_editor/database/object_box_singleton.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/audio_trimmer.dart';
import 'package:ai_video_creator_editor/screens/tools/vid_gpt/setup_language.dart';
import 'package:ai_video_creator_editor/screens/tools/vid_gpt/video_gpt.dart';
import 'package:easy_audio_trimmer/easy_audio_trimmer.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:sliding_up_panel_custom/sliding_up_panel_custom.dart';

import '../../../components/file_image_viewer.dart';
import '../../../models/video_gpt_model.dart';

class VideoGptEditChapter extends StatefulWidget {
  final Data data;
  final File? audioFile;
  final bool generateAudio;
  final GptOrientation gptOrientation;

  const VideoGptEditChapter({
    super.key,
    required this.data,
    this.audioFile,
    required this.generateAudio,
    required this.gptOrientation,
  });

  @override
  State<VideoGptEditChapter> createState() => _VideoGptEditChapterState();
}

class _VideoGptEditChapterState extends State<VideoGptEditChapter> {
  late Data data;
  TextEditingController textEditingController = TextEditingController();
  PanelController panelController = PanelController();
  final Trimmer _trimmer = Trimmer();

  double _startValue = 0.0;
  double _endValue = 0.0;
  bool _isPlaying = false;
  bool isAudioVisible = false;
  int textFieldCharCount = 0;

  @override
  void initState() {
    _loadAudio();
    data = widget.data;
    textEditingController.text = data.prompt ?? "";
    textFieldCharCount = textEditingController.text.length;
    textEditingController.addListener(shouldAudioBeVisible);
    textEditingController.addListener(updateCharCount);
    super.initState();
  }

  void _loadAudio() async {
    if (!mounted) return;
    // Only load audio if audio file exists
    if (widget.audioFile == null) {
      setState(() {
        isAudioVisible = false;
      });
      return;
    }
    setState(() {
      isAudioVisible = false;
    });
    await _trimmer.loadAudio(audioFile: widget.audioFile!);
    setState(() {
      isAudioVisible = true;
    });
  }

  void updateCharCount() {
    textFieldCharCount = textEditingController.text.length;
    setState(() {});
  }

  void shouldAudioBeVisible() {
    textFieldCharCount = textEditingController.text.length;
    if (textEditingController.text == data.prompt) {
      if (!isAudioVisible && mounted) {
        setState(() {
          isAudioVisible = true;
        });
      }
    } else {
      if (isAudioVisible && mounted) {
        setState(() {
          isAudioVisible = false;
        });
      }
    }
  }

  Future<File?> _saveAudio() async {
    // Return null if no audio file exists
    if (widget.audioFile == null) {
      return null;
    }

    File? output;
    final Completer<File?> completer = Completer<File?>();
    await _trimmer.saveTrimmedAudio(
      startValue: _startValue,
      endValue: _endValue,
      audioFileName:
          "${getFileNameWithoutExtension(widget.audioFile!.path)}_${DateTime.now().millisecondsSinceEpoch.toString()}_trimmed",
      onSave: (outputPath) {
        if (outputPath != null) {
          output = File(outputPath);
          completer.complete(output);
        } else {
          completer.complete(null);
        }
      },
    );
    return await completer.future;
  }

  String estimateCharacterCount(int seconds) {
    const double charsPerSecond = 18;
    final estimateChar = (seconds * charsPerSecond).round();
    return "${textFieldCharCount}/${estimateChar}";
  }

  @override
  void dispose() {
    textEditingController.removeListener(shouldAudioBeVisible);
    textEditingController.removeListener(updateCharCount);
    _trimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (Navigator.of(context).userGestureInProgress) {
          return false;
        } else {
          Navigator.pop(context, data);
          return true;
        }
      },
      child: GradientScaffold(
        appBar: AppBar(
          title: Text(data.prompt ?? ""),
        ),
        body: SlidingUpScaffold(
          panelController: panelController,
          body: Column(
            children: [
              FileVideoViewer(
                onPressed: () {},
                hideDeleteIcon: true,
                videoFilePath: data.video?.videoFiles
                    ?.getVideoWithOrientation(widget.gptOrientation)
                    .link,
                thumbnailImagerUrl: data.video?.image ?? "",
                fileDataSourceType: FileDataSourceType.network,
              ),
              // Text(data.video?.videoFiles?[1].quality ?? ""),
              TextFieldWidget(
                textEditingController: textEditingController,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      estimateCharacterCount(
                          widget.data.video?.duration?.toInt() ?? 1),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
              if (isAudioVisible && widget.generateAudio)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TrimViewer(
                          trimmer: _trimmer,
                          viewerHeight: 100,
                          maxAudioLength: Duration(
                              seconds:
                                  widget.data.video?.duration?.toInt() ?? 1),
                          viewerWidth: MediaQuery.of(context).size.width,
                          durationStyle: DurationStyle.FORMAT_MM_SS,
                          backgroundColor: Theme.of(context).primaryColor,
                          barColor: Colors.blueAccent,
                          durationTextStyle:
                              const TextStyle(color: Colors.white),
                          allowAudioSelection: true,
                          editorProperties: const TrimEditorProperties(
                            circleSize: 10,
                            borderPaintColor: Colors.white,
                            borderWidth: 4,
                            borderRadius: 5,
                            circlePaintColor: Colors.white,
                          ),
                          areaProperties:
                              TrimAreaProperties.edgeBlur(blurEdges: true),
                          onChangeStart: (value) => _startValue = value,
                          onChangeEnd: (value) => _endValue = value,
                          onChangePlaybackState: (value) {
                            if (mounted) {
                              setState(() {
                                _isPlaying = value;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    TextButton(
                      child: _isPlaying
                          ? const Icon(Icons.pause,
                              size: 80.0, color: Colors.white)
                          : const Icon(Icons.play_arrow,
                              size: 80.0, color: Colors.white),
                      onPressed: () async {
                        bool playbackState =
                            await _trimmer.audioPlaybackControl(
                          startValue: _startValue,
                          endValue: _endValue,
                        );
                        setState(() {
                          _isPlaying = playbackState;
                        });
                      },
                    ),
                  ],
                ),
            ],
          ),
          panel: Column(
            children: [
              GlowingGenerateButton(
                onTap: () async {
                  context.loaderOverlay.show();
                  int? generatedAudioId = data.generatedAudioId;
                  if (isAudioVisible) {
                    final existingMeta = generatedAudioId == null
                        ? null
                        : await ObjectBoxSingleTon.instance
                            .getGeneratedAudioMeta(generatedAudioId);
                    final file = await _saveAudio();
                    if (file != null && existingMeta != null) {
                      final newMeta = GeneratedAudioMeta(
                        id: existingMeta.id,
                        prompt: existingMeta.prompt,
                        originalFilePath: existingMeta.originalFilePath,
                        trimmedFilePath: file.path,
                        voice: existingMeta.voice,
                        gender: existingMeta.gender,
                      );
                      generatedAudioId = await ObjectBoxSingleTon.instance
                          .putGeneratedAudioMeta(newMeta);
                    }
                  }
                  data = data.copyWith(
                      prompt: textEditingController.text,
                      generatedAudioId: generatedAudioId);
                  context.loaderOverlay.hide();
                  Navigator.pop(context, data);
                },
                string: "Save",
              ),
              !widget.generateAudio ? context.shrink() : const SetupLanguage(),
            ],
          ),
        ),
      ),
    );
  }
}

extension VideoFileOrientationExtension on List<VideoFiles>? {
  VideoFiles getVideoWithOrientation(GptOrientation orientation) {
    if (this == null || this!.isEmpty) {
      throw StateError("No video files available");
    }

    // Helper to determine orientation
    bool isMatchingOrientation(VideoFiles file) {
      if (file.width == null || file.height == null) return false;
      return orientation == GptOrientation.landscape
          ? file.width! >= file.height!
          : file.height! > file.width!;
    }

    // Try to find the best match based on orientation
    final matchingFiles = this!.where(isMatchingOrientation).toList();

    if (matchingFiles.isNotEmpty) {
      // Prefer highest quality (resolution or size), fall back to first
      matchingFiles.sort((a, b) {
        final aPixels = (a.width ?? 0) * (a.height ?? 0);
        final bPixels = (b.width ?? 0) * (b.height ?? 0);
        return bPixels.compareTo(aPixels);
      });
      return matchingFiles.first;
    }

    // If no match found, return largest available video as fallback
    this!.sort((a, b) {
      final aPixels = (a.width ?? 0) * (a.height ?? 0);
      final bPixels = (b.width ?? 0) * (b.height ?? 0);
      return bPixels.compareTo(aPixels);
    });
    return this!.first;
  }
}
