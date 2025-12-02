import 'dart:io';

import 'package:ai_video_creator_editor/components/gradient_scaffold.dart';
import 'package:ai_video_creator_editor/constants/extensions.dart';
import 'package:ai_video_creator_editor/models/locale_keys.g.dart';
import 'package:ai_video_creator_editor/utils/functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lazy_load_scrollview/lazy_load_scrollview.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../../controllers/assets_controller.dart';
import 'editor_controller.dart';
import 'new_editor/video_editor_page_updated.dart';
import 'new_editor/video_editor_provider.dart';

class Projects extends StatefulWidget {
  const Projects({super.key});

  @override
  State<Projects> createState() => _ProjectsState();
}

class _ProjectsState extends State<Projects>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    context.read<AssetController>().getAssets();
    super.initState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      final assetController = context.read<AssetController>();
      assetController.updateLoading(true);
      assetController.getAssets();
    }
  }

  @override
  void deactivate() {
    context.read<AssetController>().disposeController();
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool processingAssets = false;

  // Calculate optimal aspect ratio from media files

  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    bool processingAssets = context.watch<AssetController>().loading;
    return Consumer<AssetController>(builder: (context, provider, child) {
      return GradientScaffold(
        appBar: AppBar(
          centerTitle: true,
          title: processingAssets
              ? context.shrink()
              : SizedBox(
                  height: 40,
                  child: FittedBox(
                    child: DropdownMenu(
                      initialSelection: provider.requestType,
                      width: 300,
                      trailingIcon:
                          const Icon(Icons.keyboard_arrow_down, size: 50),
                      textStyle: const TextStyle(fontSize: 30.0),
                      inputDecorationTheme: const InputDecorationTheme(
                        enabledBorder:
                            OutlineInputBorder(borderSide: BorderSide.none),
                      ),
                      dropdownMenuEntries: const [
                        DropdownMenuEntry(
                            value: RequestType.common, label: 'All'),
                        DropdownMenuEntry(
                            value: RequestType.video, label: 'Videos'),
                        DropdownMenuEntry(
                            value: RequestType.image, label: 'Images'),
                        // DropdownMenuEntry(value: null, label: 'Images'),
                      ],
                      onSelected: (value) {
                        if (provider.requestType == value) return;
                        provider.updateLoading(true);
                        provider.updateRequestType(value ?? RequestType.common);
                        provider.getAssets();
                      },
                    ),
                  ),
                ),
        ),
        floatingActionButton:
            provider.selectedMediaFiles.isEmpty || processingAssets
                ? null
                : FloatingActionButton(
                    heroTag: null,
                    onPressed: () async {
                      setState(() {});
                      var output = await processSelectedMedia(
                          context: context, navigate: true);
                      setState(() {});
                      safePrint(output);
                      context.read<AssetController>().disposeController();
                      if (Navigator.of(context).canPop() && output != null) {
                        Navigator.pop(context);
                      }
                    },
                    backgroundColor: Colors.blueAccent,
                    shape: const CircleBorder(),
                    child: processingAssets
                        ? const Center(
                            child: CupertinoActivityIndicator(),
                          )
                        : const Icon(
                            Icons.check,
                            color: Colors.white,
                          ),
                  ),
        bottomNavigationBar: provider.selectedMediaFiles.isEmpty ||
                processingAssets
            ? context.shrink()
            : SafeArea(
                bottom: false,
                child: SizedBox(
                  height: 80.0,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Row(
                          children: provider.selectedMediaFiles.map(
                            (element) {
                              return Container(
                                height: 75,
                                width: 75.0,
                                margin: const EdgeInsets.all(4.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2.0),
                                  child: GalleryThumbnail(
                                    asset: element,
                                    thumbFuture:
                                        provider.thumbnailUint8List(element),
                                  ),
                                ),
                              );
                            },
                          ).toList(),
                        ),
                        const SizedBox(height: 10, width: 200),
                      ],
                    ),
                  ),
                ),
              ),
        body: provider.loading
            ? const Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        "Processing...",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20.0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator.adaptive(),
                    ),
                  ],
                ),
              )
            : (provider.allMediaFiles.isEmpty)
                ? Padding(
                    padding: EdgeInsets.symmetric(
                        vertical: MediaQuery.of(context).size.height / 2 - 100),
                    child: const Center(
                      child: Text("No Assets found!"),
                    ),
                  )
                : LazyLoadScrollView(
                    onEndOfPage: () async => await provider.loadMoreAssets(),
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        children: [
                          GridView.builder(
                            shrinkWrap: true,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisExtent: 150,
                                    childAspectRatio: 0.75),
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: provider.allMediaFiles.length,
                            itemBuilder: (context, index) {
                              final element = provider.allMediaFiles[index];
                              bool selected =
                                  provider.selectedMediaFiles.contains(element);
                              return GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTap: () {
                                  if (processingAssets) return;
                                  if (selected) {
                                    provider.selectedMediaFiles.remove(element);
                                  } else {
                                    provider.selectedMediaFiles.add(element);
                                  }
                                  setState(() {});
                                },
                                child: Stack(
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.all(4.0),
                                      decoration: !selected
                                          ? const BoxDecoration()
                                          : BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(15.0),
                                              border: Border.all(
                                                width: 4.0,
                                                color: Colors.blueAccent,
                                              ),
                                            ),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        alignment: Alignment.center,
                                        children: [
                                          Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(10.0),
                                                child: GalleryThumbnail(
                                                  asset: element,
                                                  thumbFuture: provider
                                                      .thumbnailUint8List(
                                                          element),
                                                ),
                                              ),
                                              element.type == AssetType.video
                                                  ? const Icon(
                                                      Icons.play_arrow_sharp,
                                                      size: 80.0,
                                                      color: Colors.white,
                                                    )
                                                  : context.shrink(),
                                            ],
                                          ),
                                         
                                        ],
                                      ),
                                    ),
                                 
                                    Center(
                                      child: !selected
                                          ? context.shrink()
                                          : const CircleAvatar(
                                              radius: 24.0,
                                              child: Center(
                                                child: Icon(
                                                  Icons.check_circle,
                                                  size: 40.0,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          if (!provider.isLastPage)
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else
                            context.shrink()
                        ],
                      ),
                    ),
                  ),
      );
    });
  }
}

Future<File?> processSelectedMedia({
  required BuildContext context,
  required bool navigate,
}) async {
  AssetController provider = context.read<AssetController>();
  if (provider.loading) {
    showToast(
      context: context,
      title: '',
      description: 'Operation already in progress.',
      toastType: ToastType.warning,
    );
    return null;
  }

  List<File> files = [];
  List<File> processedFiles = [];
  File? resultVideo;

  try {
    provider.updateLoading(true);

    // Convert assets to files
    for (AssetEntity asset in provider.selectedMediaFiles) {
      File? temp = await asset.file;
      if (temp != null) {
        files.add(temp);
      }
    }

    if (files.isEmpty) {
      throw Exception('No media files found to process.');
    }

    // Calculate optimal aspect ratio
    Size recommendedSize =
        await calculateOptimalAspectRatio(provider.selectedMediaFiles);

    // Handle single image
    if (files.length == 1 && !isVideoFile(files.first.path)) {
      resultVideo = await EditorVideoController.imagesToVideo(
        imageFiles: [files.first],
        eachImageDuration: const Duration(seconds: 3),
      );

      // Fix: Add the converted video to processedFiles
      if (resultVideo != null) {
        processedFiles = [resultVideo];
      }
    }
    // Handle single video
    else if (files.length == 1 && isVideoFile(files.first.path)) {
      resultVideo = files.first;
      processedFiles = [files.first];
    }
    // Handle multiple files - Convert images to videos, keep videos as-is
    else {
      print('🔄 PROCESSING MULTIPLE FILES - Converting images to videos');
      print('Original files: ${files.map((f) => f.path).toList()}');
      
      // Process each file individually
      for (File file in files) {
        if (isVideoFile(file.path)) {
          // Keep video files as-is
          processedFiles.add(file);
          print('✅ Video file kept: ${file.path}');
        } else {
          // Convert image to 3-second video
          print('🖼️ Converting image to video: ${file.path}');
          File? convertedVideo = await EditorVideoController.imagesToVideo(
            imageFiles: [file],
            eachImageDuration: const Duration(seconds: 3),
          );
          
          if (convertedVideo != null) {
            processedFiles.add(convertedVideo);
            print('✅ Image converted to video: ${convertedVideo.path}');
          } else {
            print('❌ Failed to convert image: ${file.path}');
            throw Exception('Failed to convert image to video: ${file.path}');
          }
        }
      }
      
      // Use first processed file as "primary" for legacy compatibility
      resultVideo = processedFiles.isNotEmpty ? processedFiles.first : null;
      
      print('Processed files: ${processedFiles.map((f) => f.path).toList()}');
    }

    if (resultVideo == null) {
      throw Exception('Failed to create video from selected media.');
    }

    await context.read<VideoEditorProvider>().reset(
          resultVideo.path,
          originalFile: files,
          processedFile: processedFiles,
          recommendedSize: recommendedSize,
        );

    if (navigate) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const VideoEditorPage(),
        ),
      );
    } else {
      Navigator.of(context).pop();
    }

    return resultVideo;
  } catch (err, stackTrace) {
    debugPrint('Error in processSelectedMedia: $err\n$stackTrace');

    rethrow;
  } finally {
    provider.updateLoading(false);
  }
}

Size calculateOptimalAspectRatio(List<AssetEntity> assets) {
  List<Size> dimensions = [];

  for (AssetEntity asset in assets) {
    dimensions.add(asset.size!);
  }

  if (dimensions.isEmpty) {
    return const Size(16, 9); // Default aspect ratio
  }

  // Calculate average dimensions
  double avgWidth = dimensions.map((d) => d.width).reduce((a, b) => a + b) /
      dimensions.length;
  double avgHeight = dimensions.map((d) => d.height).reduce((a, b) => a + b) /
      dimensions.length;

  return Size(avgWidth, avgHeight);
}

class GalleryThumbnail extends StatelessWidget {
  final AssetEntity asset;
  final Future<Uint8List?> thumbFuture;

  const GalleryThumbnail({
    super.key,
    required this.asset,
    required this.thumbFuture,
  });

  @override
  Widget build(BuildContext context) {
    // return Image.memory(asset.thumbnailUint8List(), fit: BoxFit.cover);
    return FutureBuilder<Uint8List?>(

      future: thumbFuture,
      builder: (_, snapshot) {
        // return Center(
        //   child: Text("${snapshot.connectionState}"),
        // );
        final bytes = snapshot.data;
        if (snapshot.hasError) {
          return Container();
        }
        if (bytes == null) return Container();
        return Image.memory(bytes, fit: BoxFit.cover);
      },
    );
  }
}
