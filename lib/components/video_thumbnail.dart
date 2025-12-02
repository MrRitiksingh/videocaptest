import 'dart:io';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class VideoFileThumbnail extends StatefulWidget {
  final File videoPath;
  final int index;

  const VideoFileThumbnail({
    Key? key,
    required this.videoPath,
    required this.index,
  }) : super(key: key);

  @override
  _VideoFileThumbnailState createState() => _VideoFileThumbnailState();
}

class _VideoFileThumbnailState extends State<VideoFileThumbnail>
    with AutomaticKeepAliveClientMixin {
  final ValueNotifier<Uint8List?> _thumbnailFile =
      ValueNotifier<Uint8List?>(null);
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(true);

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  @override
  void dispose() {
    _thumbnailFile.dispose();
    _isLoading.dispose();
    super.dispose();
  }

  Future<void> _generateThumbnail() async {
    final file = await generateThumbnail(widget.videoPath.path, widget.index);
    if (mounted) {
      _thumbnailFile.value = file;
      _isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<bool>(
      valueListenable: _isLoading,
      builder: (context, isLoading, _) {
        if (isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        return ValueListenableBuilder<Uint8List?>(
          valueListenable: _thumbnailFile,
          builder: (context, thumbnailFile, _) {
            if (thumbnailFile != null) {
              return Image.memory(thumbnailFile, fit: BoxFit.cover);
            } else {
              return const Icon(Icons.broken_image);
            }
          },
        );
      },
    );
  }

  Future<Uint8List?> generateThumbnail(String videoPath, int index) async {
    final tmpDir = await getTemporaryDirectory();
    final thumbnailPath =
        '${tmpDir.path}/${DateTime.now().millisecondsSinceEpoch}_thumbnail$index.jpg';
    if (await File(thumbnailPath).exists()) await File(thumbnailPath).delete();

    final command = [
      '-ss',
      '00:00:01',
      '-i "$videoPath"',
      '-frames:v 1',
      '-q:v ${_mapQualityToFFmpegScale(75)}',
      '"$thumbnailPath"',
    ].join(' ');

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      return await File(thumbnailPath).readAsBytes();
    } else {
      return null;
    }
  }

  int _mapQualityToFFmpegScale(int quality) {
    if (quality < 1) return 1;
    if (quality > 100) return 31;
    return ((101 - quality) / 3.25).toInt().clamp(1, 31);
  }

  @override
  bool get wantKeepAlive => true;
}
