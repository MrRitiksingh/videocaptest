// asset_picker.dart
import 'dart:io';

import 'package:ai_video_creator_editor/screens/project/new_editor/video_editor_page_updated.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/video_editor_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../../controllers/assets_controller.dart';
import '../../../utils/functions.dart';
import '../projects.dart';

class AssetPicker extends StatefulWidget {
  final Function(List<String>)
      onAssetsReordered; // Changed to handle reordering
  final Function(String) onAddAsset; // For adding new assets
  final List<String> assets;

  const AssetPicker({
    super.key,
    required this.onAssetsReordered,
    required this.onAddAsset,
    required this.assets,
  });

  @override
  State<AssetPicker> createState() => _AssetPickerState();
}

class _AssetPickerState extends State<AssetPicker> {
  // Future<void> _pickAsset() async {
  //   try {
  //     final result = await FilePicker.platform.pickFiles(
  //       type: FileType.media,
  //       allowMultiple: false,
  //     );
  //
  //     setState(() {
  //       if (result != null) {
  //         widget.onAddAsset(result.files.single.path!);
  //       }
  //     });
  //   } catch (e) {
  //     safePrint('Error picking asset: $e');
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Consumer<AssetController>(builder: (context, provider, child) {
      return BottomSheetWrapper(
        child: Container(
          height: MediaQuery.of(context).size.height / 2,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Arrange Media', style: TextStyle(fontSize: 18)),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () async {
                      await provider.getAllMedia(context);
                      setState(() {});
                    },
                  ),
                ],
              ),
              Expanded(
                child: provider.selectedMediaFiles.isEmpty
                    ? const Center(child: Text('No assets added yet'))
                    : ReorderableListView.builder(
                        onReorder: (oldIndex, newIndex) {
                          final newAssets = List<String>.from(widget.assets);
                          if (newIndex > oldIndex) {
                            newIndex -= 1;
                          }
                          final item = newAssets.removeAt(oldIndex);
                          newAssets.insert(newIndex, item);
                          widget.onAssetsReordered(newAssets);
                        },
                        itemCount: provider.selectedMediaFiles.length,
                        itemBuilder: (context, index) {
                          final asset = provider.selectedMediaFiles[index];
                          // final isVideo = asset.id.endsWith('.mp4');

                          return Container(
                            key: ValueKey(asset),
                            height: 50,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 50,
                                  child: GalleryThumbnail(
                                    asset: asset,
                                    thumbFuture:
                                        provider.thumbnailUint8List(asset),
                                  ),
                                  // child: isVideo
                                  //     ? VideoThumbnail(path: asset.)
                                  //     : Image.file(
                                  //         File(asset),
                                  //         fit: BoxFit.cover,
                                  //       ),
                                ),
                                const SizedBox(width: 16),
                                // Expanded(
                                //   child: Text(
                                //     asset.title?.split('/').last ?? "",
                                //     maxLines: 1,
                                //     overflow: TextOverflow.ellipsis,
                                //   ),
                                // ),
                                Expanded(
                                  child: Container(
                                    alignment: Alignment.center,
                                    width: 100.0,
                                    decoration: BoxDecoration(
                                      color: Colors.black45,
                                      borderRadius: BorderRadius.circular(10.0),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          onPressed: () {},
                                          icon: const Icon(
                                            Icons.remove,
                                            color: Colors.red,
                                          ),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text("1"),
                                        ),
                                        IconButton(
                                          onPressed: () {},
                                          icon: const Icon(
                                            Icons.add,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle),
                                  onPressed: () {
                                    // final newAssets =
                                    //     List<String>.from(widget.assets)
                                    //       ..removeAt(index);
                                    // widget.onAssetsReordered(newAssets);
                                    provider.selectedMediaFiles.remove(asset);
                                    setState(() {});
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              ElevatedButton(
                onPressed: () {
                  // Combine videos in current order
                  Provider.of<VideoEditorProvider>(context, listen: false)
                      .combineVideos(widget.assets);
                  Navigator.pop(context);
                },
                child: const Text('Combine and Apply'),
              ),
            ],
          ),
        ),
      );
    });
  }
}

// Optional VideoThumbnail widget for video previews
class VideoThumbnail extends StatelessWidget {
  final String path;

  const VideoThumbnail({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _generateThumbnail(path),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.file(
            File(snapshot.data!),
            fit: BoxFit.cover,
          );
        }
        return Container(
          color: Colors.grey[900],
          child: const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  Future<String?> _generateThumbnail(String videoPath) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbnailPath =
          '${tempDir.path}/thumbnail_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final command = '-i $videoPath -vframes 1 -y $thumbnailPath';
      await FFmpegKit.execute(command);

      return thumbnailPath;
    } catch (e) {
      safePrint('Error generating thumbnail: $e');
      return null;
    }
  }
}
