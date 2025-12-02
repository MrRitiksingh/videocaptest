import 'dart:io';

import 'package:ai_video_creator_editor/components/text_field.dart';
import 'package:ai_video_creator_editor/constants/colors.dart';
import 'package:ai_video_creator_editor/constants/extensions.dart';
import 'package:ai_video_creator_editor/generated/assets.dart';
import 'package:ai_video_creator_editor/screens/project/editor_controller.dart';
import 'package:ai_video_creator_editor/utils/picked_file_custom.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:video_editor/video_editor.dart';

import '../../components/file_image_viewer.dart';
import '../../components/thumb_slider.dart';
import '../../components/video_editor/cropPage.dart';
import '../../components/video_editor/exportService.dart';
import '../../constants/filters.dart';
import '../../controllers/assets_controller.dart';
import '../../utils/functions.dart';
import '../tools/caption/caption.dart';
import '../tools/simple_video_result.dart';
import 'models/add_text_model.dart';
import 'projects.dart';

Color bgColor = Colors.black;
Color lightColor = Colors.white;

class AdvancedVideoEditorPage extends StatefulWidget {
  final File videoFile;

  const AdvancedVideoEditorPage({super.key, required this.videoFile});

  @override
  State<AdvancedVideoEditorPage> createState() =>
      _AdvancedVideoEditorPageState();
}

class _AdvancedVideoEditorPageState extends State<AdvancedVideoEditorPage> {
  late VideoEditorController _controller = VideoEditorController.file(
    File(widget.videoFile.path),
    minDuration: const Duration(seconds: 1),
    maxDuration: const Duration(seconds: 10000),
  );
  final _exportingProgress = ValueNotifier<double>(0.0);
  final _isExporting = ValueNotifier<bool>(false);
  PickedFileCustom? audioFile;

  @override
  void initState() {
    super.initState();
    context.read<AssetController>().fetchAllSongs();
    selectedEditorTab = editorTabsList[0];
    _controller.initialize().then((_) => setState(() {})).catchError((error) {
      // handle minimum duration bigger than video duration error
      Navigator.pop(context);
    }, test: (e) => e is VideoMinDurationError);
    generateThumbs();
  }

  List<AddTextModel> listAddTextModel = [];
  List<File> currentVideoThumbnails = [];

  generateThumbs({
    int? thumbNailsCount,
  }) async {
    currentVideoThumbnails = await generateThumbnails(
        videoFile: _controller.file, n: thumbNailsCount ?? 10);
    setState(() {});
  }

  initializeVideoEditorController({
    required String newVideoFilePath,
  }) {
    _controller = VideoEditorController.file(
      File(newVideoFilePath),
      minDuration: const Duration(seconds: 1),
      maxDuration: const Duration(seconds: 10000),
    )..initialize().then(
        (_) => setState(() {}),
      );
    setState(() {});
    safePrint(_controller.file.path);
    generateThumbs();
  }

  Widget? featureWidget;
  AssetController assetController = AssetController();
  @override
  dispose() {
    _controller.dispose();
    _isExporting.dispose();
    ExportService.dispose();
    assetController.disposeController();
    super.dispose();
  }

  void _exportVideo() async {
    _exportingProgress.value = 0;
    _isExporting.value = true;

    final config = VideoFFmpegVideoEditorConfig(
      _controller,
      // format: VideoExportFormat.gif,
      // commandBuilder: (config, videoPath, outputPath) {
      //   final List<String> filters = config.getExportFilters();
      //   filters.add('hflip'); // add horizontal flip

      //   return '-i $videoPath ${config.filtersCmd(filters)} -preset ultrafast $outputPath';
      // },
    );

    await ExportService.runFFmpegCommand(
      await config.getExecuteConfig(),
      onProgress: (stats) {
        // _exportingProgress.value =
        //     config.getFFmpegProgress(stats?.getTime().toInt());
      },
      // onError: (e, s) => _showErrorSnackBar("Error on export video :("),
      onError: (e, s) => safePrint(e),
      onCompleted: (file) {
        _isExporting.value = false;
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SimpleVideoResult(
              videoFilePath: file.path,
              betterPlayerDataSourceType: FileDataSourceType.file,
            ),
          ),
        );
        // showDialog(
        //   context: context,
        //   builder: (_) => VideoResultPopup(video: file),
        // );
      },
    );
  }

  late EditorTab selectedEditorTab;
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        bool value = await showAdaptiveDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text("Close Project"),
                    content:
                        const Text("Are you sure you want to close project,"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text("Close"),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("Continue editing"),
                      ),
                    ],
                  );
                }) ??
            false;
        return value;
      },
      child: CupertinoScaffold(
        body: Scaffold(
            appBar: AppBar(
              backgroundColor: bgColor,
              title: Row(
                children: [
                  // Expanded(
                  //   child: IconButton(
                  //     onPressed: () => Navigator.of(context).pop(),
                  //     icon: const Icon(Icons.exit_to_app),
                  //     tooltip: 'Leave editor',
                  //   ),
                  // ),
                  const VerticalDivider(endIndent: 22, indent: 22),
                  Expanded(
                    child: IconButton(
                      // onPressed: () {},
                      onPressed: () =>
                          _controller.rotate90Degrees(RotateDirection.left),
                      icon: Icon(
                        Icons.rotate_left,
                        color: lightColor,
                      ),
                      tooltip: "Rotate unclockwise",
                    ),
                  ),
                  Expanded(
                    child: IconButton(
                      // onPressed: () {},
                      onPressed: () =>
                          _controller.rotate90Degrees(RotateDirection.right),
                      icon: Icon(
                        Icons.rotate_right,
                        color: lightColor,
                      ),
                      tooltip: 'Rotate clockwise',
                    ),
                  ),
                  Expanded(
                    child: IconButton(
                      // onPressed: () {},
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) =>
                              CropPage(controller: _controller),
                        ),
                      ),
                      icon: Icon(
                        Icons.crop,
                        color: lightColor,
                      ),
                      tooltip: 'Open crop screen',
                    ),
                  ),
                  const VerticalDivider(endIndent: 22, indent: 22),
                  // Expanded(
                  //   child: PopupMenuButton(
                  //     tooltip: 'Open export menu',
                  //     icon: const Icon(Icons.save),
                  //     itemBuilder: (context) => [
                  //       // PopupMenuItem(
                  //       //   onTap: _exportCover,
                  //       //   child: const Text('Export cover'),
                  //       // ),
                  //       PopupMenuItem(
                  //         onTap: _exportVideo,
                  //         child: const Text('Export video'),
                  //       ),
                  //     ],
                  //   ),
                  // ),
                ],
              ),
              actions: [
                IconButton(
                  onPressed: _exportVideo,
                  icon: Icon(
                    Icons.check,
                    color: lightColor,
                  ),
                  tooltip: "Save Video",
                )
              ],
            ),
            body: Flex(
              direction: Axis.vertical,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: featureWidget != null ? 5 : 4,
                  child: _controller.initialized
                      ? CropGridViewer.preview(controller: _controller)
                      : Builder(
                          builder: (context) {
                            return context.shrink();
                          },
                        ),
                ),
                Container(
                  // color: Theme.of(context).appBarTheme.backgroundColor,
                  color: bgColor,
                  width: MediaQuery.of(context).size.width,
                  height: kToolbarHeight,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: SizedBox(
                      // padding: const EdgeInsets.only(
                      //   bottom: 30.0,
                      //   left: 20.0,
                      // ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        mainAxisSize: MainAxisSize.max,
                        children: editorTabsList.map(
                          (element) {
                            return Center(
                              child: InkWell(
                                onTap: () {
                                  selectedEditorTab = element;
                                  setState(() {});
                                },
                                child: element.copyWith(
                                    selected: element == selectedEditorTab),
                              ),
                            );
                          },
                        ).toList(),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: MediaQuery.of(context).size.height / 3.1,
                  child: Flex(
                    direction: Axis.vertical,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        flex: 1,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: _trimSlider(),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: bottomBody(),
                      ),
                    ],
                  ),
                ),
                // CoverViewer(controller: _controller),
              ],
            )

            // :  const Center(child: CircularProgressIndicator()),
            ),
      ),
    );
  }

  Widget captionsTab() {
    return Column(
      children: [
        CupertinoButton(
          child: const Text(
            "Caption Video",
            style: TextStyle(color: Colors.white),
          ),
          onPressed: () async {
            File? srtFile = await EditorVideoController.subtitleStringToSRTFile(
                "1\n00:00:00,000 --> 00:00:07,000\nYou know what we should all do?\n\n2\n00:00:07,000 --> 00:00:09,000\nGo see a musical.\n\n3\n00:00:12,000 --> 00:00:14,000\nSure.\n\n4\n00:00:14,000 --> 00:00:17,000\nAnd you know which one we should see?\n\n5\n00:00:17,000 --> 00:00:20,000\nThe 1996 Tony Award winner.");
            if (srtFile == null) return;
            File currentVideo = _controller.file;
            File? result = await EditorVideoController.embedSubtitleFile(
                videoFile: currentVideo, subtitleFileSRT: srtFile);
            if (result == null) return;
            initializeVideoEditorController(newVideoFilePath: result.path);
            // safePrint(_controller.file.path);
          },
        ),
      ],
    );
  }

  Widget addText() {
    // return context.shrink();
    // double currentVideoDuration = (_controller.trimPosition *
    //     (_controller.video.value.position.inSeconds));
    double currentVideoDuration =
        _controller.video.value.position.inSeconds.toDouble();
    // return Text(
    //     "$currentVideoDuration ${_controller.video.value.position.inSeconds}");
    // int durationToShowText = 1;
    // bool editText = false;
    // int currentIndex = 0;
    // TextEditingController addTextEditingController = TextEditingController();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 16.0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            mainAxisSize: MainAxisSize.max,
            children: [
              InkWell(
                child: const Text(
                  "Add Text",
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  setState(() {});
                  var value = await addEditText(
                    addTextEditingController: TextEditingController(),
                    currentVideoDuration: currentVideoDuration,
                    durationToShowText: 2,
                    fromDuration: currentVideoDuration.toInt(),
                  );
                  if (value == null) return;
                  listAddTextModel.add(value);
                  setState(() {});
                },
              ),
              InkWell(
                child: const Text(
                  "Sync Text",
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  //
                  File? textVideo = await EditorVideoController
                      .addMultiTextsToVideoWithDuration(
                    videoFile: _controller.file,
                    textOptions: listAddTextModel,
                  );
                  safePrint(textVideo?.path);
                  if (textVideo != null) {
                    initializeVideoEditorController(
                        newVideoFilePath: textVideo.path);
                  }
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 50.0, left: 10.0),
            // mainAxisSize: MainAxisSize.min,
            children: listAddTextModel.asMap().entries.map((entry) {
              return GestureDetector(
                onTap: () async {
                  AddTextModel? val = await addEditText(
                    addTextEditingController:
                        TextEditingController(text: entry.value.text),
                    currentVideoDuration: entry.value.startFrom.toDouble(),
                    durationToShowText: entry.value.durationSeconds,
                    fromDuration: entry.value.startFrom,
                  );
                  if (val == null) return;
                  listAddTextModel[entry.key] = val;
                  setState(() {});
                },
                child: Card(
                  // margin: Ed,
                  child: Row(
                    children: [
                      Text("${entry.value.startFrom}"),
                      const Text("  -  "),
                      Text(
                          "${entry.value.startFrom + entry.value.durationSeconds}"),
                      const SizedBox(width: 10.0),
                      Text(
                        entry.value.text,
                        style: const TextStyle(
                          color: Colors.yellowAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Future<AddTextModel?> addEditText({
    required TextEditingController addTextEditingController,
    required double currentVideoDuration,
    required int fromDuration,
    required int durationToShowText,
    AddTextModel? editTextModel,
  }) async {
    if (editTextModel != null) {
      addTextEditingController.text = editTextModel.text;
      durationToShowText = editTextModel.durationSeconds;
      fromDuration = editTextModel.startFrom;
    }
    AddTextModel? addTextModel = await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Add Text"),
            content: StatefulBuilder(builder: (context, updateState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFieldWidget(
                    textEditingController: addTextEditingController,
                  ),
                  const SizedBox(height: 10.0),
                  Row(
                    children: [
                      Text(
                        "From: $currentVideoDuration",
                        style: const TextStyle(fontSize: 16.0),
                      ),
                    ],
                  ),
                  const Text(
                    "Duration (seconds):",
                    style: TextStyle(fontSize: 16.0),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FloatingActionButton.small(
                        onPressed: () {
                          if (durationToShowText > 1) {
                            durationToShowText -= 1;
                            setState(() {});
                            updateState(() {});
                          }
                        },
                        child: const Icon(Icons.exposure_minus_1),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          "  $durationToShowText  ",
                          style: const TextStyle(fontSize: 16.0),
                        ),
                      ),
                      FloatingActionButton.small(
                        onPressed: () {
                          durationToShowText += 1;
                          setState(() {});
                          updateState(() {});
                        },
                        child: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ],
              );
            }),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text("Close"),
              ),
              TextButton(
                onPressed: () async {
                  var newText = AddTextModel(
                    endAt: fromDuration + durationToShowText,
                    startFrom: fromDuration,
                    durationSeconds: durationToShowText,
                    x: 100,
                    y: 100,
                    text: addTextEditingController.text,
                  );
                  Navigator.pop(context, newText);
                },
                child: const Text("Add"),
              ),
            ],
          );
        });
    return addTextModel;
  }

  Widget bottomBody() {
    switch (selectedEditorTab.uniqueKey) {
      case "trim":
        return Column(children: _trimSlider());
      case "cover":
        return _coverSelection();
      case "assets":
        return allAssets();
      case "add_audio":
        return addAudio();
      case "add_captions":
        return captionsTab();
      case "text":
        return addText();
      case "filters":
        return addFilters();
      default:
        return Text(selectedEditorTab.uniqueKey);
    }
  }

  Widget addFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Center(
            child: TextButton(
              onPressed: () async {
                List<FFmpegFilter> selectedFilters =
                    videoFfmpegFilters.where((sl) => sl.isSelected).toList();
                if (selectedFilters.isEmpty) return;
                var newVideo = await EditorVideoController.addVideoFilter(
                  videoFile: _controller.file,
                  selectedFilters: selectedFilters,
                );
                // safePrint("newVideo: ${newVideo?.path}");
                if (newVideo != null) {
                  initializeVideoEditorController(
                      newVideoFilePath: newVideo.path);
                }
              },
              child: const Text("Apply filters"),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: videoFfmpegFilters.asMap().entries.toList().map((entry) {
              FFmpegFilter currentFilter = entry.value;
              return Padding(
                padding: const EdgeInsets.all(2.0),
                child: SizedBox(
                  height: 80,
                  width: 70,
                  child: GestureDetector(
                    onTap: () async {
                      videoFfmpegFilters[entry.key] = currentFilter.copyWith(
                          isSelected: !currentFilter.isSelected);
                      setState(() {});
                    },
                    child: Container(
                      decoration: BoxDecoration(
                          borderRadius: kBorderRadius,
                          border: !currentFilter.isSelected
                              ? null
                              : Border.all(
                                  color: ColorConstants.loadingWavesColor,
                                  width: 2)),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 50,
                            width: 70,
                            child: ClipRRect(
                              borderRadius: kBorderRadius,
                              child: Image.asset(
                                Assets.imagesLogo,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Flexible(
                              child: Text(
                            entry.value.name,
                            maxLines: 1,
                            softWrap: true,
                          )),
                        ],
                      ),
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

  Widget thumbNailsSlider() {
    // double widthThumb = 100;
    return ThumbnailsSlider(
      currentVideoThumbnails: currentVideoThumbnails,
      videoDuration: _controller.videoDuration,
      onVideoTrimChanged: (start, end) {
        // Handle video trim changes
      },
      onAudioTrimChanged: (start, end) {
        // Handle audio trim changes
      },
    );
  }

  Widget addAudio() {
    return Consumer<AssetController>(
      builder: (context, provider, child) {
        return Column(
          children: [
            thumbNailsSlider(),
            GestureDetector(
              onTap: () => generateThumbs(),
              child: const Text("generateThumbs"),
            )
            // Padding(
            //   padding: const EdgeInsets.all(8.0),
            //   child: Align(
            //     alignment: Alignment.topRight,
            //     child: FloatingActionButton(
            //       child: const Icon(Icons.audio_file),
            //       onPressed: () async {
            //         var pickedFile =
            //             await pickAudio(context, durationSeconds: 100000);
            //         if (pickedFile != null) {
            //           await CupertinoScaffold.showCupertinoModalBottomSheet(
            //             context: context,
            //             builder: (context) {
            //               return StatefulBuilder(
            //                 builder: (context, updateState) {
            //                   updateState(() {});
            //                   return MoreOptionsSheet(
            //                     children: [
            //                       Column(
            //                         children: _trimSlider(),
            //                       ),
            //                       thumbNailsSlider(),
            //                       // Slider
            //                     ],
            //                   );
            //                 },
            //               );
            //             },
            //           );
            //           // audioFile = PickedFileCustom(
            //           //   betterPlayerDataSourceType:
            //           //       BetterPlayerDataSourceType.file,
            //           //   file: pickedFile,
            //           //   fileUrl: null,
            //           // );
            //           // setState(() {});
            //           // //replace audio file
            //           // var currentVideoFile = _controller.file;
            //           // safePrint("currentVideoFile: ${currentVideoFile.path}");
            //           // var newVideo =
            //           //     await EditorVideoController.addAudioToVideo(
            //           //   videoFile: currentVideoFile,
            //           //   audioFile: audioFile!.file!,
            //           // );
            //           // safePrint("newVideo: ${newVideo?.path}");
            //           // if (newVideo != null) {
            //           //   initializeVideoEditorController(
            //           //       newVideoFilePath: newVideo.path);
            //           // }
            //         }
            //         // audioFile
            //       },
            //     ),
            //   ),
            // ),
          ],
        );
      },
    );
    // return context.shrink();
  }

  Widget allAssets() {
    List<AssetEntity> selectedMediaFiles =
        context.read<AssetController>().selectedMediaFiles;
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: selectedMediaFiles.map((element) {
              return Container(
                height: 75,
                width: 75.0,
                margin: const EdgeInsets.all(4.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2.0),
                  child: GalleryThumbnail(
                    asset: element,
                    thumbFuture: context
                        .read<AssetController>()
                        .thumbnailUint8List(element),
                  ),
                ),
              );
            }).toList(),
          ),
        )
      ],
    );
  }

  Widget getBody() {
    switch (selectedEditorTab.uniqueKey) {
      case "trim":
        return Stack(
          alignment: Alignment.center,
          children: [
            CropGridViewer.preview(controller: _controller),
            AnimatedBuilder(
              animation: _controller.video,
              builder: (_, __) => AnimatedOpacity(
                opacity: _controller.isPlaying ? 0 : 1,
                duration: kThemeAnimationDuration,
                child: GestureDetector(
                  onTap: _controller.video.play,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      case "cover":
        return CoverViewer(controller: _controller);
      default:
        return Text(selectedEditorTab.uniqueKey);
    }
  }

  List<EditorTab> editorTabsList = const [
    EditorTab(
      iconData: Icons.audiotrack,
      title: "Assets",
      uniqueKey: "assets",
    ),
    EditorTab(
      iconData: Icons.audiotrack,
      title: "Audio",
      uniqueKey: "add_audio",
    ),
    // EditorTab(
    //   iconData: Icons.cut,
    //   title: "Trim",
    //   uniqueKey: "trim",
    // ),
    // EditorTab(
    //   iconData: Icons.closed_caption_sharp,
    //   title: "Captions",
    //   uniqueKey: "add_captions",
    // ),
    // EditorTab(
    //   iconData: Icons.video_label,
    //   title: "Cover",
    //   uniqueKey: "cover",
    // ),
    // EditorTab(
    //   iconData: CupertinoIcons.pen,
    //   title: "Paint",
    //   uniqueKey: "paint",
    // ),
    EditorTab(
      iconData: Icons.text_fields,
      title: "Text",
      uniqueKey: "text",
    ),
    // EditorTab(
    //   iconData: Icons.crop_rotate,
    //   title: "Copy/Rotate",
    //   uniqueKey: "copy_rotate",
    // ),
    EditorTab(
      iconData: Icons.filter,
      title: "Filters",
      uniqueKey: "filters",
    ),
    // EditorTab(
    //   iconData: Icons.blur_on,
    //   title: "Blur",
    //   uniqueKey: "blur",
    // ),
    // EditorTab(
    //   iconData: Icons.emoji_emotions,
    //   title: "Emoji",
    //   uniqueKey: "emoji",
    // ),
    // EditorTab(
    //   iconData: Icons.image,
    //   title: "Image",
    //   uniqueKey: "add_image",
    // ),
  ];
  final double height = 60;

  List<Widget> _trimSlider() {
    return [
      AnimatedBuilder(
        animation: Listenable.merge([
          _controller,
          _controller.video,
        ]),
        builder: (_, __) {
          final int duration = _controller.videoDuration.inSeconds;
          final double pos = _controller.trimPosition * duration;

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: height / 4),
            child: Row(
              children: [
                pos.isNaN || pos.isInfinite
                    ? const Text("")
                    : Text(formatter(Duration(seconds: pos.toInt()))),
                // Text("POS: ${pos} Duration: ${duration}"),
                const Expanded(child: SizedBox()),
                AnimatedOpacity(
                  opacity: _controller.isTrimming ? 1 : 0,
                  duration: kThemeAnimationDuration,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(formatter(_controller.startTrim)),
                      const SizedBox(width: 10),
                      Text(formatter(_controller.endTrim)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      Container(
        width: MediaQuery.of(context).size.width,
        margin: EdgeInsets.symmetric(vertical: height / 4),
        child: TrimSlider(
          controller: _controller,
          height: height,
          horizontalMargin: height / 4,
          child: TrimTimeline(
            controller: _controller,
            padding: const EdgeInsets.only(top: 10),
          ),
        ),
      )
    ];
  }

  Widget _coverSelection() {
    return SingleChildScrollView(
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(4),
          child: CoverSelection(
            controller: _controller,
            // size: height + 10,
            quantity: 8,
            selectedCoverBuilder: (cover, size) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  cover,
                  Icon(
                    Icons.check_circle,
                    color: const CoverSelectionStyle().selectedBorderColor,
                  )
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // if (this.isNaN || this.isInfinite){
  // // default value
  // }else{
  // // your logic
  // }
  String formatter(Duration duration) =>
      duration.inSeconds.isNaN || duration.inSeconds.isInfinite
          ? ""
          : [
              duration.inMinutes.remainder(60).toString().padLeft(2, '0'),
              duration.inSeconds.remainder(60).toString().padLeft(2, '0')
            ].join(":");
}

class EditorTab extends StatelessWidget {
  final IconData iconData;
  final String title;
  final String uniqueKey;
  final bool? selected;

  const EditorTab({
    super.key,
    required this.iconData,
    required this.title,
    required this.uniqueKey,
    this.selected,
  });

  EditorTab copyWith({
    IconData? iconData,
    String? title,
    String? uniqueKey,
    bool? selected,
  }) {
    return EditorTab(
      iconData: iconData ?? this.iconData,
      title: title ?? this.title,
      uniqueKey: uniqueKey ?? this.uniqueKey,
      selected: selected ?? this.selected,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: SizedBox(
        height: 40.0,
        width: 50.0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Icon(
                iconData,
                color: selected == true
                    ? Colors.white
                    : Colors.grey, // Using selected to modify UI
              ),
            ),
            const SizedBox(height: 5.0),
            FittedBox(
              child: Text(
                title,
                style: TextStyle(
                  color: selected == true ? Colors.white : Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
