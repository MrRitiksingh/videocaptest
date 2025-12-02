import 'dart:io';

import 'package:ai_video_creator_editor/components/gradient_scaffold.dart';
import 'package:ai_video_creator_editor/components/progress_indicator.dart';
import 'package:ai_video_creator_editor/constants/extensions.dart';
import 'package:ai_video_creator_editor/utils/functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../../components/drop_down.dart';
import '../../../components/glowing_button.dart';
import '../../../components/selector_with_page.dart';
import '../../../components/upload_button.dart';
import '../../../models/locale_keys.g.dart';
import 'caption-editor.dart';
import 'captions_controller.dart';

class Caption extends StatefulWidget {
  const Caption({super.key});

  @override
  State<Caption> createState() => _CaptionState();
}

class _CaptionState extends State<Caption> {
  SelectorController languageSelectorController = SelectorController(
    list: languageList,
    selectedMap: languageList[0],
    title: "Language",
  );
  SelectorController captionsLanguageSelectorController = SelectorController(
    list: languageList,
    selectedMap: languageList[0],
    title: "Translate Captions",
  );
  @override
  void deactivate() {
    context.read<CaptionsController>().deactivate();
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CaptionsController>(builder: (context, provider, child) {
      return LoaderWidgetOverlay(
        child: GradientScaffold(
          appBar: AppBar(
            title: const Text("Caption Video"),
            actions: [
              provider.captions.isEmpty
                  ? context.shrink()
                  : IconButton(
                      icon: const Icon(Icons.check),
                      onPressed: () async {
                        await provider.generateCaptions(context: context);
                      },
                    ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(children: [
              provider.currentVideoFile == null
                  ? UploadButton(
                      title: LocaleKeys.uploadVideo.tr(),
                      onTap: () async {
                        await provider.initialize(context: context);
                        setState(() {});
                      },
                    )
                  : ListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        Column(
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height / 2,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                child: LayoutBuilder(
                                    builder: (context, constraints) {
                                  final aspectRatio =
                                      provider.controller?.value.aspectRatio ??
                                          16 / 9;
                                  final width =
                                      provider.controller!.value.size.width;
                                  final height =
                                      provider.controller!.value.size.height;
                                  return SizedBox(
                                    // width: width,
                                    // height: height,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      clipBehavior: Clip.none,
                                      children: [
                                        AspectRatio(
                                          aspectRatio: (provider.controller!
                                                  .value.aspectRatio ??
                                              16 / 9),
                                          child: VideoPlayer(
                                            provider.controller!,
                                          ),
                                        ),
                                        // Draggable text overlay
                                        provider.captions.isEmpty
                                            ? context.shrink()
                                            : Positioned(
                                                left: provider.textPositionX
                                                    .clamp(0, width - 100),
                                                top: provider.textPositionY
                                                    .clamp(0, height - 50),
                                                child: Draggable<String>(
                                                  maxSimultaneousDrags: 1,
                                                  childWhenDragging: Opacity(
                                                    opacity: 0.3,
                                                    child: Text(
                                                      provider
                                                          .segmentCurrentSentence,
                                                      style: TextStyle(
                                                          color: provider
                                                              .currentCaptionTypePrimaryTextColor,
                                                          fontSize: provider
                                                              .currentCaptionTypeDefaultFontSize),
                                                    ),
                                                  ),
                                                  onDragEnd: (details) =>
                                                      provider
                                                          .updateTextPosition(
                                                    details,
                                                    width,
                                                    height,
                                                  ),
                                                  feedback: Material(
                                                    color: Colors.transparent,
                                                    child: Text(
                                                      provider
                                                          .segmentCurrentSentence,
                                                      style: TextStyle(
                                                          color: provider
                                                              .currentCaptionTypePrimaryTextColor,
                                                          fontSize: provider
                                                              .currentCaptionTypeDefaultFontSize),
                                                    ),
                                                  ),
                                                  child: SizedBox(
                                                    // width: constraints.maxWidth,
                                                    // height: 30.0,
                                                    child: Container(
                                                      // width: width,
                                                      padding:
                                                          const EdgeInsets.all(
                                                              8),
                                                      decoration: BoxDecoration(
                                                        color: provider
                                                            .currentCaptionTypeBackGroundColor,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4),
                                                      ),
                                                      child: Text(
                                                        provider
                                                            .segmentCurrentSentence,
                                                        style: TextStyle(
                                                            color: provider
                                                                .currentCaptionTypePrimaryTextColor,
                                                            fontSize: provider
                                                                .currentCaptionTypeDefaultFontSize),
                                                        textAlign:
                                                            TextAlign.center,
                                                        maxLines: 1,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          onPressed: () =>
                                              provider.togglePlay(),
                                          icon: Icon(
                                            provider.isPlaying
                                                ? Icons.pause
                                                : Icons.play_arrow,
                                            size: 60.0,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Positioned(
                                          top: 5.0,
                                          right: 5.0,
                                          child: IconButton(
                                            onPressed: () => provider
                                                .deactivate(notify: true),
                                            icon: const Icon(Icons.delete),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Slider(
                                value: provider.playbackPosition,
                                min: 0,
                                max: provider
                                        .controller?.value.duration.inSeconds
                                        .toDouble() ??
                                    100,
                                onChanged: (position) =>
                                    provider.seekTo(position),
                              ),
                            ),
                          ],
                        ),
                        Builder(
                          builder: (context) {
                            if (provider.captions.isEmpty) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SelectorWithPage(
                                    title: "Video Language",
                                    leading: const Icon(Icons.closed_caption),
                                    selectorController:
                                        languageSelectorController,
                                  ),
                                  SelectorWithPage(
                                    title: "Translate Caption",
                                    leading: const Icon(Icons.language),
                                    selectorController:
                                        captionsLanguageSelectorController,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12.0,
                                      vertical: 30.0,
                                    ),
                                    child: GlowingGenerateButton(
                                      onTap: () async {
                                        await provider.controller?.pause();
                                        try {
                                          await Future.delayed(Duration.zero);
                                          if (!mounted) return;
                                          context.loaderOverlay.show();
                                          await provider
                                              .extractCurrentAudioFile();
                                          if (provider.extractedAudioFile ==
                                              null) {
                                            throw Exception(
                                                "audioFile is null");
                                          }
                                          // safePrint(audioFile.path);
                                          // upload audio to backend and await for subtitles
                                          await provider.uploadExtractedAudio();
                                          // add the captions in the backend
                                          await provider.makeCaptions(
                                            context: context,
                                            language: languageSelectorController
                                                .selectedMap!["id"],
                                          );
                                          setState(() {});
                                          context.loaderOverlay.hide();
                                        } catch (err) {
                                          safePrint(err.toString());
                                          context.loaderOverlay.hide();
                                          showToast(
                                            context: context,
                                            title: "",
                                            description:
                                                LocaleKeys.anError.tr(),
                                            toastType: ToastType.warning,
                                          );
                                          rethrow;
                                        }
                                      },
                                      string: "Generate",
                                    ),
                                  ),
                                ],
                              );
                            } else {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    onTap: () async {
                                      await showMaterialModalBottomSheet(
                                        context: context,
                                        builder: (context) {
                                          return SizedBox(
                                            height: MediaQuery.of(context)
                                                    .size
                                                    .height /
                                                2,
                                            child: const Card(
                                              margin: EdgeInsets.zero,
                                              child: Column(
                                                children: [
                                                  Text(""),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                    child: Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Center(
                                          child: Text(
                                            provider.segmentCurrentSentence,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Center(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Wrap(
                                        children: provider.segmentCurrentWords
                                            .asMap()
                                            .entries
                                            .map(
                                          (entry) {
                                            return Card(
                                              margin: const EdgeInsets.all(2.0),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: Text(
                                                  entry.value.text,
                                                  style: TextStyle(
                                                      color: provider
                                                                  .segmentCurrentSpokenWord ==
                                                              entry.value.text
                                                          ? Colors.green
                                                          : Colors.white),
                                                ),
                                              ),
                                            );
                                          },
                                        ).toList(),
                                      ),
                                    ),
                                  ),
                                  DropDownWidget(
                                    hint: "Caption Type",
                                    onChanged: (value) =>
                                        provider.selectCaptionType(provider
                                            .listCaptionType
                                            .where((element) =>
                                                element.modelID == value)
                                            .first),
                                    index: 0,
                                    list: provider.listCaptionType.toJsonList(),
                                  ),
                                  // Text(
                                  //     "${provider.currentCaptionType?.modelID}"),
                                  provider.currentCaptionType
                                              ?.hasDefaultFontSize ==
                                          true
                                      ? Row(
                                          children: [
                                            Text("Font size"),
                                            Slider(
                                              onChanged: (value) => provider
                                                  .updateCurrentCaptionTypeDefaultFontSize(
                                                      value),
                                              // title: 'Text FontSize',
                                              max: 72,
                                              min: 12,
                                              value: provider
                                                  .currentCaptionTypeDefaultFontSize,
                                              divisions: 60,
                                            ),
                                          ],
                                        )
                                      : context.shrink(),
                                  provider.currentCaptionType
                                              ?.hasBackgroundColor ==
                                          true
                                      ? ListTile(
                                          title: const Text(
                                              'Text Background Color'),
                                          trailing: ColorPickerButton(
                                            color: provider
                                                .currentCaptionTypeBackGroundColor,
                                            onColorChanged: (color) => provider
                                                .updateCurrentCaptionTypeBackGroundColor(
                                                    color),
                                          ),
                                        )
                                      : context.shrink(),
                                  provider.currentCaptionType
                                              ?.hasPrimaryTextColor ==
                                          true
                                      ? ListTile(
                                          title: const Text('Text Color'),
                                          trailing: ColorPickerButton(
                                            color: provider
                                                .currentCaptionTypePrimaryTextColor,
                                            onColorChanged: (color) => provider
                                                .updateCurrentCaptionTypePrimaryTextColor(
                                                    color),
                                          ),
                                        )
                                      : context.shrink(),
                                  provider.currentCaptionType
                                              ?.hasSecondaryTextColor ==
                                          true
                                      ? ListTile(
                                          title: const Text(
                                              'Secondary Text Color'),
                                          trailing: ColorPickerButton(
                                            color: provider
                                                .currentCaptionTypeSecondaryTextColor,
                                            onColorChanged: (color) => provider
                                                .updateCurrentCaptionTypeSecondaryTextColor(
                                                    color),
                                          ),
                                        )
                                      : context.shrink(),
                                ],
                              );
                            }
                          },
                        ),
                      ],
                    ),
            ]),
          ),

          // : videoFile == null
          //     ? context.shrink()
          //     : ListView(
          //         shrinkWrap: true,
          //         children: [
          //           // SelectableText("$srtText"),
          //           videoFile == null
          //               ? context.shrink()
          //               : Padding(
          //                   padding: const EdgeInsets.symmetric(
          //                       horizontal: 16.0),
          //                   child: FileVideoViewer(
          //                     videoFilePath: videoFile!.path,
          //                     onPressed: () => setState(() {
          //                       videoFile = null;
          //                       srtText = [];
          //                       finalSrtText = null;
          //                     }),
          //                     betterPlayerDataSourceType:
          //                         BetterPlayerDataSourceType.file,
          //                   ),
          //                 ),
          //           EnhancedSubtitleEditor(
          //             karaokeEffect: KaraokeEffect.follow,
          //             videoFilePath: videoFile!.path,
          //             captionData:
          //                 srtText, // Your JSON data from captionVideo()
          //             onSave: (String assSubtitles) async {
          //               // Handle the generated ASS subtitles
          //               // print(assSubtitles);
          //               try {
          //                 context.loaderOverlay.show();
          //                 await Future.delayed(
          //                     const Duration(milliseconds: 300));
          //                 context.loaderOverlay.show();
          //                 finalSrtText = assSubtitles;
          //                 setState(() {});
          //                 File? srtFile =
          //                     await SubtitleConverter.assStringToAssFile(
          //                         assSubtitles);
          //                 File? result = await EditorVideoController
          //                     .embedAssSubtitleFile(
          //                   videoFile: videoFile!,
          //                   subtitleFileASS: srtFile!,
          //                 );
          //                 if (result == null) {
          //                   setState(() {});
          //                   context.loaderOverlay.hide();
          //                   return;
          //                 }
          //                 context.loaderOverlay.hide();
          //                 Navigator.push(
          //                   context,
          //                   MaterialPageRoute(
          //                     builder: (context) => SimpleVideoResult(
          //                       videoFilePath: result.path,
          //                       betterPlayerDataSourceType:
          //                           BetterPlayerDataSourceType.file,
          //                     ),
          //                   ),
          //                 );
          //               } catch (err) {
          //                 context.loaderOverlay.hide();
          //                 //
          //               }
          //             },
          //           ),
          //           // SubtitleEditor(
          //           //   videoFilePath: videoFile!.path,
          //           //   initialSrtText: srtText!,
          //           //   onSave: (String editedSrt) async {
          //           //     try {
          //           //       // safePrint(editedSrt);
          //           //       await Future.delayed(
          //           //           const Duration(milliseconds: 300));
          //           //       context.loaderOverlay.show();
          //           //       finalSrtText = editedSrt;
          //           //       setState(() {});
          //           //       File? srtFile = await EditorVideoController
          //           //           .subtitleStringToSRTFile(finalSrtText ?? "");
          //           //       // File? srtFile = await SubtitleConverter.srtToAss(
          //           //       //     finalSrtText ?? "");
          //           //       // File? srtFile =
          //           //       //     await SubtitleConverter.assStringToAssFile("");
          //           //       if (srtFile == null) return;
          //           //       File? result =
          //           //           await EditorVideoController.embedSomeAss(
          //           //         videoFile: videoFile!,
          //           //         subtitleFileSRT: srtFile,
          //           //       );
          //           //       // File? result =
          //           //       //     await EditorVideoController.embedSubtitleFile(
          //           //       //   videoFile: videoFile!,
          //           //       //   subtitleFileSRT: srtFile,
          //           //       // );
          //           //       if (result == null) {
          //           //         setState(() {});
          //           //         context.loaderOverlay.hide();
          //           //         return;
          //           //       }
          //           //       // videoFile = result;
          //           //       // finalSrtText = null;
          //           //       // srtText = null;
          //           //       setState(() {});
          //           //       context.loaderOverlay.hide();
          //           //       Navigator.push(
          //           //         context,
          //           //         MaterialPageRoute(
          //           //           builder: (context) => SimpleVideoResult(
          //           //             videoFilePath: result.path,
          //           //             betterPlayerDataSourceType:
          //           //                 BetterPlayerDataSourceType.file,
          //           //           ),
          //           //         ),
          //           //       );
          //           //     } catch (err) {
          //           //       safePrint(err);
          //           //       context.loaderOverlay.hide();
          //           //       showToast(
          //           //         context: context,
          //           //         title: "",
          //           //         description: LocaleKeys.anError.tr(),
          //           //         toastType: ToastType.warning,
          //           //       );
          //           //     }
          //           //
          //           //     setState(() {});
          //           //   },
          //           // ),
          //         ],
          //       ),
        ),
      );
    });
  }
}

List<Map<String, dynamic>> languageList = [
  {"name": "English", "id": "en"},
  {"name": "Chinese", "id": "zh"},
  {"name": "Spanish", "id": "es"},
  {"name": "Hindi", "id": "hi"},
  {"name": "French", "id": "fr"},
  {"name": "Arabic", "id": "ar"},
  {"name": "Bengali", "id": "bn"},
  {"name": "Portuguese", "id": "pt"},
  {"name": "Russian", "id": "ru"},
  {"name": "Urdu", "id": "ur"},
  {"name": "Indonesian", "id": "id"},
  {"name": "German", "id": "de"},
  {"name": "Japanese", "id": "ja"},
  {"name": "Turkish", "id": "tr"},
  {"name": "Vietnamese", "id": "vi"},
  {"name": "Korean", "id": "ko"},
  {"name": "Tamil", "id": "ta"},
  {"name": "Italian", "id": "it"},
  {"name": "Thai", "id": "th"},
  {"name": "Polish", "id": "pl"},
  {"name": "Persian", "id": "fa"},
  {"name": "Punjabi", "id": "pa"},
  {"name": "Marathi", "id": "mr"},
  {"name": "Telugu", "id": "te"},
  {"name": "Ukrainian", "id": "uk"},
  {"name": "Gujarati", "id": "gu"},
  {"name": "Malayalam", "id": "ml"},
  {"name": "Dutch", "id": "nl"},
  {"name": "Tagalog", "id": "tl"},
  {"name": "Kannada", "id": "kn"},
  {"name": "Malay", "id": "ms"},
  {"name": "Greek", "id": "el"},
  {"name": "Burmese", "id": "my"},
  {"name": "Swedish", "id": "sv"},
  {"name": "Romanian", "id": "ro"},
  {"name": "Hungarian", "id": "hu"},
  {"name": "Hebrew", "id": "he"},
  {"name": "Czech", "id": "cs"},
  {"name": "Swahili", "id": "sw"},
  {"name": "Javanese", "id": "jw"},
  {"name": "Danish", "id": "da"},
  {"name": "Norwegian", "id": "no"},
  {"name": "Serbian", "id": "sr"},
  {"name": "Finnish", "id": "fi"},
  {"name": "Slovak", "id": "sk"},
  {"name": "Bulgarian", "id": "bg"},
  {"name": "Croatian", "id": "hr"},
  {"name": "Lithuanian", "id": "lt"},
  {"name": "Slovenian", "id": "sl"},
  {"name": "Estonian", "id": "et"},
  {"name": "Latvian", "id": "lv"},
  {"name": "Belarusian", "id": "be"},
  {"name": "Albanian", "id": "sq"},
  {"name": "Mongolian", "id": "mn"},
  {"name": "Armenian", "id": "hy"},
  {"name": "Icelandic", "id": "is"},
  {"name": "Kazakh", "id": "kk"},
  {"name": "Georgian", "id": "ka"},
  {"name": "Nepali", "id": "ne"},
  {"name": "Khmer", "id": "km"},
  {"name": "Turkmen", "id": "tk"},
  {"name": "Uzbek", "id": "uz"},
  {"name": "Azerbaijani", "id": "az"},
  {"name": "Tajik", "id": "tg"},
  {"name": "Macedonian", "id": "mk"},
  {"name": "Afrikaans", "id": "af"},
  {"name": "Yiddish", "id": "yi"},
  {"name": "Amharic", "id": "am"},
  {"name": "Catalan", "id": "ca"},
  {"name": "Assamese", "id": "as"},
  {"name": "Sindhi", "id": "sd"},
  {"name": "Somali", "id": "so"},
  {"name": "Pashto", "id": "ps"},
  {"name": "Yoruba", "id": "yo"},
  {"name": "Maori", "id": "mi"},
  {"name": "Sanskrit", "id": "sa"},
  {"name": "Tatar", "id": "tt"},
  {"name": "Sinhala", "id": "si"},
  {"name": "Welsh", "id": "cy"},
  {"name": "Basque", "id": "eu"},
  {"name": "Haitian Creole", "id": "ht"},
  {"name": "Norwegian Nynorsk", "id": "nn"},
  {"name": "Malagasy", "id": "mg"},
  {"name": "Latin", "id": "la"},
  {"name": "Hausa", "id": "ha"},
  {"name": "Galician", "id": "gl"},
  {"name": "Faroese", "id": "fo"},
  {"name": "Luxembourgish", "id": "lb"},
  {"name": "Lingala", "id": "ln"},
  {"name": "Lao", "id": "lo"},
  {"name": "Maltese", "id": "mt"},
  {"name": "Occitan", "id": "oc"},
  {"name": "Shona", "id": "sn"},
  {"name": "Sundanese", "id": "su"},
  {"name": "Tibetan", "id": "bo"},
  {"name": "Breton", "id": "br"},
  {"name": "Bosnian", "id": "bs"},
  {"name": "Hawaiian", "id": "haw"},
  {"name": "Bashkir", "id": "ba"}
];

class SubtitleEntry {
  int index;
  String timeRange;
  String text;
  TextEditingController controller;

  SubtitleEntry({
    required this.index,
    required this.timeRange,
    required this.text,
  }) : controller = TextEditingController(text: text);
}

// Function to parse SRT text into a list of maps
List<Map<String, dynamic>> parseSrtToList(String srtText) {
  List<Map<String, dynamic>> subtitles = [];
  final entries = srtText.trim().split('\n\n');

  for (var entry in entries) {
    final lines = entry.trim().split('\n');
    if (lines.length >= 3) {
      subtitles.add({
        'index': int.parse(lines[0]),
        'timeRange': lines[1],
        'text': lines.sublist(2).join('\n'),
      });
    }
  }
  return subtitles;
}

// Function to convert edited subtitles back to SRT format
String convertToSrt(List<Map<String, dynamic>> subtitles) {
  final StringBuffer buffer = StringBuffer();

  for (var i = 0; i < subtitles.length; i++) {
    if (i > 0) buffer.write('\n\n');
    buffer.write('${subtitles[i]['index']}\n');
    buffer.write('${subtitles[i]['timeRange']}\n');
    buffer.write(subtitles[i]['text']);
  }

  return buffer.toString();
}

class SubtitleEditor extends StatefulWidget {
  final String initialSrtText;
  final Function(String) onSave;
  final String videoFilePath;

  const SubtitleEditor({
    super.key,
    required this.initialSrtText,
    required this.onSave,
    required this.videoFilePath,
  });

  @override
  SubtitleEditorState createState() => SubtitleEditorState();
}

class SubtitleEditorState extends State<SubtitleEditor> {
  late List<Map<String, dynamic>> subtitles;
  late List<SubtitleEntry> subtitleEntries;

  @override
  void initState() {
    super.initState();
    // getThumbs();
    subtitles = parseSrtToList(widget.initialSrtText);
    subtitleEntries = subtitles
        .map((subtitle) => SubtitleEntry(
              index: subtitle['index'],
              timeRange: subtitle['timeRange'],
              text: subtitle['text'],
            ))
        .toList();
  }

  void saveChanges() {
    for (var i = 0; i < subtitles.length; i++) {
      subtitles[i]['text'] = subtitleEntries[i].controller.text;
    }
    widget.onSave(convertToSrt(subtitles));
  }

  @override
  void dispose() {
    for (var entry in subtitleEntries) {
      entry.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: subtitleEntries.length,
          itemBuilder: (context, index) {
            final entry = subtitleEntries[index];
            return GestureDetector(
              onTap: () =>
                  FocusScope.of(context).requestFocus(FocusScopeNode()),
              child: Card(
                elevation: 0,
                margin:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Index: ${entry.index}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Time: ${entry.timeRange}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: entry.controller,
                        maxLines: null,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Subtitle Text',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: saveChanges,
            child: const Text('Save Changes'),
          ),
        ),
      ],
    );
  }
}

Future<List<File>> generateThumbnails({
  required File videoFile,
  required int n,
}) async {
  // Ensure FFmpeg package is installed
  final List<File> thumbnails = [];

  // Check if the input file exists
  if (!videoFile.existsSync()) {
    throw Exception("Video file does not exist.");
  }

  // Get the video duration using FFmpeg
  final durationResult =
      await FFmpegKit.execute('-i ${videoFile.path} -hide_banner');
  final durationMatch = RegExp(r'Duration: (\d{2}):(\d{2}):(\d{2})\.\d+')
      .firstMatch((await durationResult.getOutput()) ?? '');

  if (durationMatch == null) {
    throw Exception('Unable to determine video duration.');
  }

  // Parse video duration (hours:minutes:seconds)
  final hours = int.parse(durationMatch.group(1)!);
  final minutes = int.parse(durationMatch.group(2)!);
  final seconds = int.parse(durationMatch.group(3)!);
  final totalSeconds = hours * 3600 + minutes * 60 + seconds;

  // Calculate the interval for thumbnails
  final interval = totalSeconds ~/ n;

  // Directory to save thumbnails
  final tempDir = await getTemporaryDirectory();

  for (int i = 0; i < n; i++) {
    final timestamp = interval * i; // Time in seconds for each thumbnail
    final thumbnailPath =
        '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_thumb_$i.jpg';

    // Run FFmpeg to extract thumbnail
    final result = await FFmpegKit.execute(
        '-i ${videoFile.path} -ss $timestamp -vframes 1 -q:v 2 $thumbnailPath');

    // if (await result.getReturnCode() == 0) {
    if (ReturnCode.isSuccess(await result.getReturnCode())) {
      thumbnails.add(File(thumbnailPath));
    } else {
      safePrint("Error generating thumbnail for timestamp $timestamp");
    }
  }

  return thumbnails;
}

// class Caption extends StatefulWidget {
//   const Caption({super.key});
//
//   @override
//   State<Caption> createState() => _CaptionState();
// }
//
// class _CaptionState extends State<Caption> {
//   File? videoFile;
//   SelectorController languageSelectorController = SelectorController(
//     list: languageList,
//     selectedMap: languageList[0],
//     title: "Language",
//   );
//   SelectorController captionsLanguageSelectorController = SelectorController(
//     list: languageList,
//     selectedMap: languageList[0],
//     title: "Translate Captions",
//   );
//   List<Map<String, dynamic>> srtText = [];
//   String? finalSrtText;
//   @override
//   Widget build(BuildContext context) {
//     return LoaderWidgetOverlay(
//       child: GradientScaffold(
//         appBar: AppBar(
//           title: const Text("Caption Video"),
//         ),
//         body: srtText.isEmpty
//             ? SingleChildScrollView(
//                 child: Column(children: [
//                   videoFile == null
//                       ? UploadButton(
//                           title: LocaleKeys.uploadVideo.tr(),
//                           onTap: () => pickVideo(context, durationSeconds: 300)
//                               .then(
//                                   (value) => setState(() => videoFile = value)),
//                         )
//                       : ListView(
//                           shrinkWrap: true,
//                           physics: const NeverScrollableScrollPhysics(),
//                           children: [
//                             Padding(
//                               padding:
//                                   const EdgeInsets.symmetric(horizontal: 16.0),
//                               child: FileVideoViewer(
//                                 videoFilePath: videoFile!.path,
//                                 onPressed: () => setState(() {
//                                   videoFile = null;
//                                   srtText = [];
//                                   finalSrtText = null;
//                                 }),
//                                 betterPlayerDataSourceType:
//                                     BetterPlayerDataSourceType.file,
//                               ),
//                             ),
//                             SelectorWithPage(
//                               title: "Video Language",
//                               leading: const Icon(Icons.closed_caption),
//                               selectorController: languageSelectorController,
//                             ),
//                             SelectorWithPage(
//                               title: "Translate Caption",
//                               leading: const Icon(Icons.language),
//                               selectorController:
//                                   captionsLanguageSelectorController,
//                             ),
//                             Padding(
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 12.0,
//                                 vertical: 30.0,
//                               ),
//                               child: GlowingButtonCircular(
//                                 onTap: () async {
//                                   try {
//                                     await Future.delayed(Duration.zero);
//                                     if (!mounted) return;
//                                     context.loaderOverlay.show();
//                                     // extract audio from video using ffmpeg
//                                     File? audioFile =
//                                         await EditorVideoController
//                                             .extractAudioFromVideo(
//                                                 videoFile: videoFile!);
//                                     if (audioFile == null) {
//                                       throw Exception("audioFile is null");
//                                     }
//                                     // safePrint(audioFile.path);
//                                     // upload audio to backend and await for subtitles
//                                     String? audioUrl =
//                                         await uploadIOFile(audioFile);
//                                     if (audioUrl == null)
//                                       throw Exception("audioUrl is null");
//                                     // add the captions in the backend
//                                     srtText = await context
//                                             .read<TemplatesNotifier>()
//                                             .captionVideo(
//                                               audioUrl: audioUrl,
//                                               translate: false,
//                                               language: 'en',
//                                             ) ??
//                                         [];
//                                     setState(() {});
//                                     context.loaderOverlay.hide();
//                                   } catch (err) {
//                                     safePrint(err.toString());
//                                     context.loaderOverlay.hide();
//                                     showToast(
//                                       context: context,
//                                       title: "",
//                                       description: LocaleKeys.anError.tr(),
//                                       toastType: ToastType.error,
//                                     );
//                                   }
//                                 },
//                                 string: "Generate",
//                               ),
//                             ),
//                           ],
//                         ),
//                 ]),
//               )
//             : videoFile == null
//                 ? context.shrink()
//                 : ListView(
//                     shrinkWrap: true,
//                     children: [
//                       // SelectableText("$srtText"),
//                       videoFile == null
//                           ? context.shrink()
//                           : Padding(
//                               padding:
//                                   const EdgeInsets.symmetric(horizontal: 16.0),
//                               child: FileVideoViewer(
//                                 videoFilePath: videoFile!.path,
//                                 onPressed: () => setState(() {
//                                   videoFile = null;
//                                   srtText = [];
//                                   finalSrtText = null;
//                                 }),
//                                 betterPlayerDataSourceType:
//                                     BetterPlayerDataSourceType.file,
//                               ),
//                             ),
//                       EnhancedSubtitleEditor(
//                         karaokeEffect: KaraokeEffect.follow,
//                         videoFilePath: videoFile!.path,
//                         captionData:
//                             srtText, // Your JSON data from captionVideo()
//                         onSave: (String assSubtitles) async {
//                           // Handle the generated ASS subtitles
//                           // print(assSubtitles);
//                           try {
//                             context.loaderOverlay.show();
//                             await Future.delayed(
//                                 const Duration(milliseconds: 300));
//                             context.loaderOverlay.show();
//                             finalSrtText = assSubtitles;
//                             setState(() {});
//                             File? srtFile =
//                                 await SubtitleConverter.assStringToAssFile(
//                                     assSubtitles);
//                             File? result = await EditorVideoController
//                                 .embedAssSubtitleFile(
//                               videoFile: videoFile!,
//                               subtitleFileASS: srtFile!,
//                             );
//                             if (result == null) {
//                               setState(() {});
//                               context.loaderOverlay.hide();
//                               return;
//                             }
//                             context.loaderOverlay.hide();
//                             Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                 builder: (context) => SimpleVideoResult(
//                                   videoFilePath: result.path,
//                                   betterPlayerDataSourceType:
//                                       BetterPlayerDataSourceType.file,
//                                 ),
//                               ),
//                             );
//                           } catch (err) {
//                             context.loaderOverlay.hide();
//                             //
//                           }
//                         },
//                       ),
//                       // SubtitleEditor(
//                       //   videoFilePath: videoFile!.path,
//                       //   initialSrtText: srtText!,
//                       //   onSave: (String editedSrt) async {
//                       //     try {
//                       //       // safePrint(editedSrt);
//                       //       await Future.delayed(
//                       //           const Duration(milliseconds: 300));
//                       //       context.loaderOverlay.show();
//                       //       finalSrtText = editedSrt;
//                       //       setState(() {});
//                       //       File? srtFile = await EditorVideoController
//                       //           .subtitleStringToSRTFile(finalSrtText ?? "");
//                       //       // File? srtFile = await SubtitleConverter.srtToAss(
//                       //       //     finalSrtText ?? "");
//                       //       // File? srtFile =
//                       //       //     await SubtitleConverter.assStringToAssFile("");
//                       //       if (srtFile == null) return;
//                       //       File? result =
//                       //           await EditorVideoController.embedSomeAss(
//                       //         videoFile: videoFile!,
//                       //         subtitleFileSRT: srtFile,
//                       //       );
//                       //       // File? result =
//                       //       //     await EditorVideoController.embedSubtitleFile(
//                       //       //   videoFile: videoFile!,
//                       //       //   subtitleFileSRT: srtFile,
//                       //       // );
//                       //       if (result == null) {
//                       //         setState(() {});
//                       //         context.loaderOverlay.hide();
//                       //         return;
//                       //       }
//                       //       // videoFile = result;
//                       //       // finalSrtText = null;
//                       //       // srtText = null;
//                       //       setState(() {});
//                       //       context.loaderOverlay.hide();
//                       //       Navigator.push(
//                       //         context,
//                       //         MaterialPageRoute(
//                       //           builder: (context) => SimpleVideoResult(
//                       //             videoFilePath: result.path,
//                       //             betterPlayerDataSourceType:
//                       //                 BetterPlayerDataSourceType.file,
//                       //           ),
//                       //         ),
//                       //       );
//                       //     } catch (err) {
//                       //       safePrint(err);
//                       //       context.loaderOverlay.hide();
//                       //       showToast(
//                       //         context: context,
//                       //         title: "",
//                       //         description: LocaleKeys.anError.tr(),
//                       //         toastType: ToastType.warning,
//                       //       );
//                       //     }
//                       //
//                       //     setState(() {});
//                       //   },
//                       // ),
//                     ],
//                   ),
//       ),
//     );
//   }
// }
