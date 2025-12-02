import 'dart:io';
import 'dart:ui';

import 'package:ai_video_creator_editor/screens/project/editor_controller.dart';
import 'package:ai_video_creator_editor/components/duration_selector.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/video_editor_provider.dart';
import 'package:ai_video_creator_editor/components/video_thumbnail.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/video_trim_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FileReordering extends StatefulWidget {
  const FileReordering({
    super.key,
    required this.reorderFiles,
    required this.totalDurations,
  });

  final List<File> reorderFiles;
  final List<int> totalDurations;

  @override
  State<FileReordering> createState() => _FileReorderingState();
}

class _FileReorderingState extends State<FileReordering> {
  List<File> reorderFiles = [];
  List<int> totalDurations = [];

  @override
  void initState() {
    reorderFiles = List<File>.from(widget.reorderFiles);
    totalDurations = List<int>.from(widget.totalDurations);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VideoEditorProvider>(
      builder: (context, provider, child) {
        return SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ReorderableListView.builder(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  proxyDecorator: proxyDecorator,
                  itemCount: reorderFiles.length,
                  onReorder: (int oldIndex, int newIndex) {
                    if (oldIndex < newIndex) newIndex -= 1;
                    final File fileItem = reorderFiles.removeAt(oldIndex);
                    reorderFiles.insert(newIndex, fileItem);
                    final int durationItem = totalDurations.removeAt(oldIndex);
                    totalDurations.insert(newIndex, durationItem);
                  },
                  itemBuilder: (context, index) {
                    final isVideo = isVideoFile(reorderFiles[index].path);
                    return Padding(
                      key: ValueKey('$index-${reorderFiles[index]}'),
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 100,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (!isVideo)
                                    Image.file(reorderFiles[index])
                                  else
                                    VideoFileThumbnail(
                                      key: ValueKey(index),
                                      index: index,
                                      videoPath: reorderFiles[index],
                                    ),
                                  if (isVideo)
                                    const Icon(
                                      Icons.play_arrow_sharp,
                                      size: 40.0,
                                    )
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: 15),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isVideo)
                                DurationSelector(
                                  key: ValueKey('$index-${totalDurations[index]}'),
                                  initialDuration: totalDurations[index],
                                  onSelect: (result) => totalDurations[index] = result,
                                ),
                              if (isVideo)
                                GestureDetector(
                                  child: const Icon(Icons.content_cut_sharp),
                                  onTap: () async {
                                    Navigator.push<String?>(context, MaterialPageRoute(builder: (context) {
                                      return VideoTrimView(videoFile: reorderFiles[index]);
                                    })).then((outputPath) {
                                      if (outputPath == null) return;
                                      reorderFiles[index] = File(outputPath);
                                    });
                                  },
                                ),
                              SizedBox(height: 15),
                              Icon(Icons.reorder, color: Colors.white),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      provider.combineMediaFiles(reorderFiles, totalDurations);
                    },
                    child: Text("Continue"),
                  ),
                ],
              ),
              SizedBox(height: 5),
            ],
          ),
        );
      },
    );
  }

  Widget proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double animValue = Curves.easeInOut.transform(animation.value);
        final double scale = lerpDouble(1, 1.02, animValue)!;
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: child,
    );
  }
}
