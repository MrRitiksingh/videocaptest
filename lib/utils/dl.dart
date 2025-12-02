import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

import 'functions.dart';

Future<int?> getAudioLength({required File audio}) async {
  final AudioPlayer player = AudioPlayer();
  player.setVolume(0);
  await player.play(DeviceFileSource(audio.path));
  // safePrint(player.playerId);
  var duration = await player.getDuration();
  player.dispose();
  return duration?.inSeconds;
}

Future<File?> saveFileToTemp({required String urlPath}) async {
  try {
    String? extension = getFileExtension(urlPath);
    try {
      Uint8List? imageBytes;
      File? cachedFile;
      final cacheManager = DefaultCacheManager();
      final fileInfo = await cacheManager.getFileFromCache(urlPath);
      if (fileInfo != null) {
        imageBytes = fileInfo.file.readAsBytesSync();
        cachedFile = await uint8ListToFile(imageBytes, extension ?? "png");
      } else {
        final cachedFile = await cacheManager.getSingleFile(urlPath);
        imageBytes = cachedFile.readAsBytesSync();
      }
      if (cachedFile == null) throw Error;
      safePrint(cachedFile.path);
      return File(cachedFile.path);
    } catch (err) {
      final path =
          '${Directory.systemTemp.path}/Videocap_${DateTime.now().microsecondsSinceEpoch}${getRandom().toString().replaceAll(".", "")}.mp4';
      await Dio().download(
        urlPath,
        path,
      );
      return File(path);
    }
  } catch (e) {
    rethrow;
  }
}

String? getFileExtension(String url) {
  try {
    final uri = Uri.parse(url);
    final path = uri.path;
    final extension = path.split('.').last;
    if (extension.contains('/') || extension.isEmpty) {
      return null; // No valid file extension found
    }
    return extension;
  } catch (e) {
    // Handle invalid URLs or other errors
    safePrint("Error parsing URL: $e");
    return null;
  }
}

Future<File?> uint8ListToFile(Uint8List uint8list, String extension) async {
  final tempDir = await getTemporaryDirectory();
  File file = await File(
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_file.$extension')
      .create();
  file.writeAsBytesSync(uint8list);
  return file;
}
