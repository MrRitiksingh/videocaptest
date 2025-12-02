import 'dart:io';

import 'package:ai_video_creator_editor/screens/project/new_editor/video_editor_page_updated.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/video_editor_provider.dart';
import 'package:ai_video_creator_editor/utils/uploads.dart';
import 'package:flutter/material.dart';

import 'custom_trim_slider.dart';

class AudioPicker extends StatefulWidget {
  final Function(String) onAudioSelected;
  final VideoEditorProvider videoEditorProvider;

  const AudioPicker({
    super.key,
    required this.onAudioSelected,
    required this.videoEditorProvider,
  });

  @override
  State<AudioPicker> createState() => _AudioPickerState();
}

class _AudioPickerState extends State<AudioPicker> {
  File? pickedAudioFile;

  @override
  Widget build(BuildContext context) {
    return BottomSheetWrapper(
      child: SizedBox(
        height: MediaQuery.of(context).size.height / 2,
        width: MediaQuery.of(context).size.width,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Select Audio',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            IconButton(
              onPressed: () async {
                pickedAudioFile =
                    await pickAudio(context, durationSeconds: 7200);
                setState(() {});
              },
              icon: const Icon(Icons.add),
            ),
            if (pickedAudioFile != null)
              CustomTrimSlider(
                value: widget.videoEditorProvider.trimStart,
                secondValue: widget.videoEditorProvider.trimEnd,
                position: widget.videoEditorProvider.playbackPosition,
                max: widget.videoEditorProvider.videoEditorController?.video
                        .value.duration.inSeconds
                        .toDouble() ??
                    0.0,
                onChanged: widget.videoEditorProvider.updateTrimValues,
                onPositionChanged: widget.videoEditorProvider.seekTo,
                // thumbnails: [],
                // thumbnails: _generateThumbnails(provider),
              ),
            // Expanded(
            //   child: FutureBuilder<List<String>>(
            //     future: _getAudioFiles(),
            //     builder: (context, snapshot) {
            //       if (!snapshot.hasData) {
            //         return const Center(child: CircularProgressIndicator());
            //       }
            //       if (snapshot.data?.isEmpty ?? false) {
            //         return Column(
            //           children: [
            //             IconButton(
            //               icon: const Icon(Icons.add),
            //               onPressed: () async {
            //                 File? pickedAudioFile = await pickAudio(context);
            //               },
            //             ),
            //           ],
            //         );
            //       }
            //       return ListView.builder(
            //         itemCount: snapshot.data!.length,
            //         itemBuilder: (context, index) {
            //           return ListTile(
            //             leading: const Icon(Icons.music_note),
            //             title: Text(basename(snapshot.data![index])),
            //             onTap: () {
            //               onAudioSelected(snapshot.data![index]);
            //               Navigator.pop(context);
            //             },
            //           );
            //         },
            //       );
            //     },
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}
