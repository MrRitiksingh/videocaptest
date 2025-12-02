import 'dart:io';

import 'package:ai_video_creator_editor/components/file_image_viewer.dart';
import 'package:ai_video_creator_editor/components/glowing_button.dart';
import 'package:ai_video_creator_editor/components/gradient_scaffold.dart';
import 'package:ai_video_creator_editor/models/locale_keys.g.dart';
import 'package:ai_video_creator_editor/utils/download_file.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/video_export_manager.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class SimpleVideoResult extends StatefulWidget {
  final String videoFilePath;
  final FileDataSourceType betterPlayerDataSourceType;

  const SimpleVideoResult({
    super.key,
    required this.videoFilePath,
    required this.betterPlayerDataSourceType,
  });

  @override
  State<SimpleVideoResult> createState() => _SimpleVideoResultState();
}

class _SimpleVideoResultState extends State<SimpleVideoResult> {
  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(),
      body: ListView(
        children: [
          Container(
            margin: const EdgeInsets.all(6.0),
            child: FileVideoViewer(
              hideDeleteIcon: true,
              onPressed: () {},
              fileDataSourceType: widget.betterPlayerDataSourceType,
              videoFilePath: widget.videoFilePath,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: GlowingGenerateButton(
                    onTap: () async {
                      if (widget.betterPlayerDataSourceType ==
                          FileDataSourceType.file) {
                        saveVideoBytesToGallery(
                            videoFile: File(widget.videoFilePath),
                            context: context);
                      } else if (widget.betterPlayerDataSourceType ==
                          FileDataSourceType.network) {
                        saveVideoToGallery(
                            urlPath: widget.videoFilePath, context: context);
                      } else if (widget.betterPlayerDataSourceType ==
                          FileDataSourceType.memory) {
                        //
                      }
                    },
                    string: LocaleKeys.download.tr(),
                  ),
                ),
                // const SizedBox(width: 12),
                // ElevatedButton.icon(
                //   onPressed: () {
                //     // Show export logs dialog
                //     VideoExportManager.showExportLogs(context);
                //   },
                //   icon: const Icon(Icons.bug_report),
                //   label: const Text('Debug'),
                //   style: ElevatedButton.styleFrom(
                //     backgroundColor: Colors.deepPurple,
                //     foregroundColor: Colors.white,
                //   ),
                // ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
