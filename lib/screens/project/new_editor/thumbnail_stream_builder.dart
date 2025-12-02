import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

class ThumbnailStreamBuilder extends StatefulWidget {
  final VideoPlayerController? controller;
  final ScrollController scrollController;

  const ThumbnailStreamBuilder({
    super.key,
    required this.controller,
    required this.scrollController,
  });

  @override
  State<ThumbnailStreamBuilder> createState() => _ThumbnailStreamBuilderState();
}

class _ThumbnailStreamBuilderState extends State<ThumbnailStreamBuilder> {
  final StreamController<List<Uint8List>> _streamController =
      StreamController<List<Uint8List>>();
  List<Uint8List> _thumbnails = [];
  int _thumbnailCount = 8;

  @override
  void initState() {
    super.initState();
    _generateThumbnails();
  }

  @override
  void dispose() {
    _streamController.close();
    super.dispose();
  }

  void _generateThumbnails() async {
    if (widget.controller == null) return;
    final Directory tempDir = await getTemporaryDirectory();
    for (int i = 1; i <= _thumbnailCount; i++) {
      try {
        final bytes = await _generateThumbnail(i, tempDir.path);
        if (bytes != null) {
          _thumbnails.add(bytes);
          _streamController.add(List.from(_thumbnails));
        }
      } catch (e) {
        debugPrint(e.toString());
      }
    }
  }

  Future<Uint8List?> _generateThumbnail(int seconds, String tempDirPath) async {
    if (widget.controller == null) return null;
    final String thumbnailPath =
        '${tempDirPath}/${DateTime.now().millisecondsSinceEpoch}_thumbnail$seconds.jpg';

    if (await File(thumbnailPath).exists()) await File(thumbnailPath).delete();

    final command =
        '-i ${widget.controller!.dataSource} -ss $seconds -vframes 1 -y $thumbnailPath';
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      return await File(thumbnailPath).readAsBytes();
    } else {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Uint8List>>(
      stream: _streamController.stream,
      builder: (context, snapshot) {
        return ListView.builder(
          controller: widget.scrollController,
          scrollDirection: Axis.horizontal,
          itemCount: _thumbnailCount,
          itemBuilder: (context, index) {
            if (!snapshot.hasData || index >= snapshot.data!.length) {
              return Container(
                height: 60,
                width: MediaQuery.of(context).size.width / 8,
                color: Colors.grey,
                child: Icon(Icons.image),
              );
            }
            return SizedBox(
              height: 60,
              width: MediaQuery.of(context).size.width / 8,
              child: Image.memory(snapshot.data![index], fit: BoxFit.cover),
            );
          },
        );
      },
    );
  }
}
