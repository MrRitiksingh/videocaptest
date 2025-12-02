import 'dart:io';

import 'package:ai_video_creator_editor/components/glowing_button.dart';
import 'package:ai_video_creator_editor/components/gradient_scaffold.dart';
import 'package:ai_video_creator_editor/components/progress_indicator.dart';
import 'package:ai_video_creator_editor/components/sliding_up_scaffold.dart';
import 'package:ai_video_creator_editor/constants/extensions.dart';
import 'package:ai_video_creator_editor/controllers/azure_provider.dart';
import 'package:ai_video_creator_editor/database/models/generated_audio_meta.dart';
import 'package:ai_video_creator_editor/database/object_box_singleton.dart';
import 'package:ai_video_creator_editor/models/locale_keys.g.dart';
import 'package:ai_video_creator_editor/screens/tools/vid_gpt/setup_language.dart';
import 'package:ai_video_creator_editor/screens/tools/vid_gpt/vid_gpt_notifier.dart';
import 'package:ai_video_creator_editor/screens/tools/vid_gpt/video_gpt.dart';
import 'package:ai_video_creator_editor/screens/tools/vid_gpt/video_gpt_edit_chapter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:provider/provider.dart';
import 'package:sliding_up_panel_custom/sliding_up_panel_custom.dart';

import '../../../components/bool_list_tile.dart';
import '../../../models/video_gpt_model.dart';
import '../../../utils/functions.dart';
import '../../../utils/snack_bar_utils.dart';

// Subtitle Position Enum
enum SubtitlePosition {
  top,
  middle,
  bottom;

  String get displayName {
    switch (this) {
      case SubtitlePosition.top:
        return 'Top';
      case SubtitlePosition.middle:
        return 'Middle';
      case SubtitlePosition.bottom:
        return 'Bottom';
    }
  }

  // FFmpeg alignment values for subtitle positioning (ASS/SSA format)
  // Based on user testing: Middle(5) shows on top, Top(8) shows in middle
  // Swapping values to fix the positioning issue
  int get ffmpegAlignment {
    switch (this) {
      case SubtitlePosition.top:
        return 5; // Was 8, but 5 actually shows on top
      case SubtitlePosition.middle:
        return 8; // Was 5, but 8 actually shows in middle
      case SubtitlePosition.bottom:
        return 2; // Bottom center (should be correct)
    }
  }
}

// Subtitle Configuration Model
class SubtitleConfig {
  bool enabled;
  double fontSize;
  Color fontColor;
  Color backgroundColor;
  SubtitlePosition position;

  SubtitleConfig({
    this.enabled = true, // Default ON as requested
    this.fontSize = 16.0,
    this.fontColor = Colors.white,
    Color? backgroundColor,
    this.position = SubtitlePosition.bottom,
  }) : backgroundColor = backgroundColor ?? Colors.black.withValues(alpha: 0.7);

  SubtitleConfig copyWith({
    bool? enabled,
    double? fontSize,
    Color? fontColor,
    Color? backgroundColor,
    SubtitlePosition? position,
  }) {
    return SubtitleConfig(
      enabled: enabled ?? this.enabled,
      fontSize: fontSize ?? this.fontSize,
      fontColor: fontColor ?? this.fontColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      position: position ?? this.position,
    );
  }

  // Convert color to hex string for FFmpeg ASS/SSA format
  // ASS format: &HAABBGGRR (Alpha, Blue, Green, Red)
  // For subtitles filter, we need to use the correct format
  String colorToHex(Color color) {
    final alpha =
        (255 - (color.a * 255.0).round()) & 0xff; // Inverted alpha for ASS
    final blue = (color.b * 255.0).round() & 0xff;
    final green = (color.g * 255.0).round() & 0xff;
    final red = (color.r * 255.0).round() & 0xff;

    // For ASS format: &HAABBGGRR (Alpha inverted, Blue, Green, Red)
    return '&H${alpha.toRadixString(16).padLeft(2, '0').toUpperCase()}'
        '${blue.toRadixString(16).padLeft(2, '0').toUpperCase()}'
        '${green.toRadixString(16).padLeft(2, '0').toUpperCase()}'
        '${red.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  }

  // Get FFmpeg subtitle style string
  String get ffmpegStyle {
    return 'FontSize=${fontSize.toInt()},'
        'PrimaryColour=${colorToHex(fontColor)},'
        'BackColour=${colorToHex(backgroundColor)},'
        'Alignment=${position.ffmpegAlignment}';
  }
}

// UI Components for Subtitle Customization
class SubtitleFontSizeSlider extends StatelessWidget {
  final double fontSize;
  final ValueChanged<double> onChanged;

  const SubtitleFontSizeSlider({
    super.key,
    required this.fontSize,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Font Size: ${fontSize.toInt()}px',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          Slider(
            value: fontSize,
            min: 12.0,
            max: 32.0,
            divisions: 20,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class SubtitleColorPicker extends StatelessWidget {
  final String title;
  final Color selectedColor;
  final ValueChanged<Color> onChanged;

  const SubtitleColorPicker({
    super.key,
    required this.title,
    required this.selectedColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          GestureDetector(
            onTap: () => _showColorPicker(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selectedColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select $title'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Predefined colors
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Colors.white,
                  Colors.black,
                  Colors.red,
                  Colors.blue,
                  Colors.green,
                  Colors.yellow,
                  Colors.orange,
                  Colors.purple,
                  Colors.grey,
                ]
                    .map((color) => GestureDetector(
                          onTap: () {
                            onChanged(color);
                            Navigator.pop(context);
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selectedColor == color
                                    ? Colors.blue
                                    : Colors.grey,
                                width: selectedColor == color ? 3 : 1,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class SubtitlePositionSelector extends StatelessWidget {
  final SubtitlePosition selectedPosition;
  final ValueChanged<SubtitlePosition> onChanged;

  const SubtitlePositionSelector({
    super.key,
    required this.selectedPosition,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Position',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: SubtitlePosition.values.map((position) {
              final isSelected = selectedPosition == position;
              return GestureDetector(
                onTap: () {
                  print(
                      "DEBUG: UI Button tapped: ${position.displayName} (alignment: ${position.ffmpegAlignment})");
                  onChanged(position);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.blue
                        : Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.grey,
                    ),
                  ),
                  child: Text(
                    position.displayName,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class VideoGptComplete extends StatefulWidget {
  final VideoGptModel videoGptModel;
  final GptOrientation gptOrientation;

  const VideoGptComplete({
    super.key,
    required this.videoGptModel,
    required this.gptOrientation,
  });

  @override
  State<VideoGptComplete> createState() => _VideoGptCompleteState();
}

class _VideoGptCompleteState extends State<VideoGptComplete> {
  late VideoGptModel videoGptModel;
  bool generateAudio = true;
  bool generateText = true;
  bool enableSubtitle = true;
  late SubtitleConfig subtitleConfig;

  init() {
    videoGptModel = widget.videoGptModel;
    subtitleConfig = SubtitleConfig(); // Initialize with defaults
    setState(() {});
    // remove md
  }

  @override
  void initState() {
    init();
    super.initState();
  }

  PanelController panelController = PanelController();

  @override
  Widget build(BuildContext context) {
    return LoaderWidgetOverlay(
      child: GradientScaffold(
        appBar: AppBar(
          title: Text(videoGptModel.input ?? ""),
        ),
        body: SlidingUpScaffold(
          panelController: panelController,
          body: Column(
            children: [
              ListView.builder(
                shrinkWrap: true,
                controller: ScrollController(),
                physics: const NeverScrollableScrollPhysics(),
                itemCount: videoGptModel.data?.length ?? 0,
                itemBuilder: (context, index) {
                  Data data = videoGptModel.data![index];
                  return Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Dismissible(
                      key: Key("${data.video?.id}"),
                      background: Container(
                          color: Colors.redAccent.withValues(alpha: 0.5)),
                      onDismissed: (DismissDirection direction) {
                        setState(() {
                          videoGptModel.data?.removeAt(index);
                        });
                        showSnackBar(context, '${data.prompt} dismissed');
                      },
                      child: SizedBox(
                        height: 120.0,
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: Flex(
                            direction: Axis.horizontal,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 1,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    ClipRRect(
                                      borderRadius:
                                          const BorderRadius.horizontal(
                                              left: Radius.circular(10.0)),
                                      child: CachedNetworkImage(
                                        imageUrl: data.video?.image ?? "",
                                        fit: BoxFit.cover,
                                        height: 150.0,
                                        width: 150.0,
                                      ),
                                    ),
                                    const Icon(Icons.play_arrow,
                                        color: Colors.white, size: 50.0)
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10.0),
                              // Expanded(
                              //     flex: 2,
                              //     child: SelectableText(
                              //         "${(data?.video?.videoFiles?.getVideoWithOrientation(widget.gptOrientation).width ?? 0) >= (data?.video?.videoFiles?.getVideoWithOrientation(widget.gptOrientation).height ?? 0) ? "Landscape" : "Portrait"}")),
                              Expanded(
                                  flex: 2,
                                  child: SelectableText(data.prompt
                                          ?.remo7veMarkdownSymbols()
                                          .replaceAll("\"", "'") ??
                                      "")),
                              IconButton(
                                onPressed: () async {
                                  context.loaderOverlay.show();
                                  await updateData(
                                    data: data,
                                    index: index,
                                    gptOrientation: widget.gptOrientation,
                                  );
                                  context.loaderOverlay.hide();
                                },
                                icon:
                                    const Icon(Icons.edit, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          initialMaxHeight: MediaQuery.of(context).size.height * 0.65,
          panel: Column(
            children: [
              GlowingGenerateButton(
                string: LocaleKeys.generateVideoEM.tr(),
                onTap: () async {
                  try {
                    context.loaderOverlay.show();
                    await context
                        .read<SetupLanguageController>()
                        .generateAudioFileAndVideoFile(
                          context: context,
                          data: videoGptModel.data ?? [],
                          generateText: videoGptModel.generateText,
                          generateAudio: videoGptModel.generateAudio,
                          orientation: widget.gptOrientation,
                          subtitleConfig: subtitleConfig,
                        );
                    // processingToast(
                    //   context,
                    //   routeName: RouteNames.videoGpt,
                    //   isPremium: true,
                    //   skipNavigation: true,
                    // );
                    context.loaderOverlay.hide();
                  } catch (err) {
                    showToast(
                        context: context,
                        title: "",
                        description: LocaleKeys.anError.tr(),
                        toastType: ToastType.warning);
                    context.loaderOverlay.hide();
                  }
                },
              ),
              !videoGptModel.generateAudio
                  ? context.shrink()
                  : const SetupLanguage(),
              // Subtitle toggle - only available when audio is enabled
              if (videoGptModel.generateAudio)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: BooleanListTile(
                      enabled: subtitleConfig.enabled,
                      title: "Subtitle",
                      onChanged: (val) => setState(() {
                            subtitleConfig =
                                subtitleConfig.copyWith(enabled: val);
                          })),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: Icon(Icons.subtitles_off, color: Colors.grey),
                    title: Text("Subtitles",
                        style: TextStyle(color: Colors.grey)),
                    subtitle: Text("Requires voice narration",
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                    enabled: false,
                  ),
                ),
              // Subtitle customization UI - only show when enabled and audio exists
              if (subtitleConfig.enabled && videoGptModel.generateAudio) ...[
                SubtitleFontSizeSlider(
                  fontSize: subtitleConfig.fontSize,
                  onChanged: (value) => setState(() {
                    subtitleConfig = subtitleConfig.copyWith(fontSize: value);
                  }),
                ),
                SubtitleColorPicker(
                  title: "Font Color",
                  selectedColor: subtitleConfig.fontColor,
                  onChanged: (color) => setState(() {
                    subtitleConfig = subtitleConfig.copyWith(fontColor: color);
                  }),
                ),
                SubtitleColorPicker(
                  title: "Background Color",
                  selectedColor: subtitleConfig.backgroundColor,
                  onChanged: (color) => setState(() {
                    subtitleConfig =
                        subtitleConfig.copyWith(backgroundColor: color);
                  }),
                ),
                SubtitlePositionSelector(
                  selectedPosition: subtitleConfig.position,
                  onChanged: (position) => setState(() {
                    print(
                        "DEBUG: Position selected: ${position.displayName} (alignment: ${position.ffmpegAlignment})");
                    subtitleConfig =
                        subtitleConfig.copyWith(position: position);
                  }),
                ),
              ],
              // Padding(
              //   padding: const EdgeInsets.all(8.0),
              //   child: BooleanListTile(
              //     enabled: generateText,
              //     title: "Video Script",
              //     onChanged: (val) => setState(() => generateText = val),
              //   ),
              // ),
              // !generateText
              //     ? context.shrink()
              //     : Padding(
              //         padding: const EdgeInsets.all(8.0),
              //         child: BooleanListTile(
              //           enabled: generateAudio,
              //           title: "Generate Audio from text",
              //           onChanged: (val) => setState(() => generateAudio = val),
              //         ),
              //       ),
              // Text("font editing ui here if enabled"),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> updateData({
    required Data data,
    required int index,
    required GptOrientation gptOrientation,
  }) async {
    final azureProvider = context.read<AzureProvider>();
    final setupLanguageController = context.read<SetupLanguageController>();
    final voice = setupLanguageController.gptVoice.voiceValue;
    final gender = setupLanguageController.gptVoice.genderValue;
    safePrint("voice ${voice}");
    safePrint("gender ${gender}");
    // return;
    int? generatedAudioId;
    File? audioFile;
    if (videoGptModel.generateAudio) {
      GeneratedAudioMeta? existingMeta = data.generatedAudioId == null
          ? null
          : await ObjectBoxSingleTon.instance
              .getGeneratedAudioMeta(data.generatedAudioId!);

      if (data.prompt != existingMeta?.prompt &&
          voice != existingMeta?.voice &&
          gender != existingMeta?.gender) {
        audioFile = await azureProvider.azureTTS(
          context,
          gender: setupLanguageController.gptVoice.genderValue,
          voice: setupLanguageController.gptVoice.voiceValue,
          script: data.prompt ?? "",
          returnTempPath: true,
        );
      }

      if (audioFile != null) {
        final newMeta = GeneratedAudioMeta(
          id: existingMeta == null ? 0 : existingMeta.id,
          prompt: data.prompt ?? "",
          originalFilePath: audioFile.path,
          trimmedFilePath: audioFile.path,
          gender: gender,
          voice: voice,
        );
        generatedAudioId =
            await ObjectBoxSingleTon.instance.putGeneratedAudioMeta(newMeta);
      }
    }

    final updatedData = (generatedAudioId != null)
        ? data.copyWith(generatedAudioId: generatedAudioId)
        : data;

    // Only fetch audio metadata if audio generation is enabled
    GeneratedAudioMeta? existingMeta;
    if (videoGptModel.generateAudio) {
      if (updatedData.generatedAudioId != null) {
        existingMeta = await ObjectBoxSingleTon.instance
            .getGeneratedAudioMeta(updatedData.generatedAudioId!);
      }

      context.loaderOverlay.hide();

      // Only show error if audio was enabled but generation failed
      if (existingMeta == null) {
        showSnackBar(context, "Audio generating failed");
        return;
      }
    } else {
      // Audio is muted, no metadata needed
      context.loaderOverlay.hide();
    }

    var newData =
        await Navigator.push(context, MaterialPageRoute(builder: (context) {
      return VideoGptEditChapter(
        data: updatedData,
        audioFile: existingMeta != null
            ? File(existingMeta.trimmedFilePath!)
            : null,
        generateAudio: videoGptModel.generateAudio,
        gptOrientation: widget.gptOrientation,
      );
    }));

    if (newData is Data) {
      videoGptModel.data?[index] = newData;
      setState(() {});
      safePrint(videoGptModel.data?[index].prompt);
    }
  }
}
