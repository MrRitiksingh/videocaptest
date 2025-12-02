import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../components/file_image_viewer.dart';
import 'functions.dart';

class PickedFileCustom {
  File? file;
  String? fileUrl;
  FileDataSourceType betterPlayerDataSourceType;

  PickedFileCustom({
    this.file,
    this.fileUrl,
    required this.betterPlayerDataSourceType,
  });

  Map<String, dynamic> toJson() {
    return {
      'file': file?.path, // Assuming you want to serialize file path
      'fileUrl': fileUrl,
      'betterPlayerDataSourceType':
          betterPlayerDataSourceType.toString().split('.').last,
    };
  }

  factory PickedFileCustom.fromJson(Map<String, dynamic> json) {
    return PickedFileCustom(
      file: json['file'] != null ? File(json['file']) : null,
      fileUrl: json['fileUrl'],
      betterPlayerDataSourceType: FileDataSourceType.values.firstWhere(
        (type) =>
            type.toString().split('.').last ==
            json['betterPlayerDataSourceType'],
      ),
    );
  }

  PickedFileCustom copyWith({
    File? file,
    String? fileUrl,
    FileDataSourceType? betterPlayerDataSourceType,
  }) {
    return PickedFileCustom(
      file: file ?? this.file,
      fileUrl: fileUrl ?? this.fileUrl,
      betterPlayerDataSourceType:
          betterPlayerDataSourceType ?? this.betterPlayerDataSourceType,
    );
  }

  Future<String?> returnFile({
    required String fileType,
    String? requestType,
  }) async {
    if (fileUrl != null) {
      return fileUrl;
    } else if (file != null) {
      String? downloadUrl = "";
      if (['video', 'image'].contains(fileType)) {
        Uint8List? uint8list;
        String? thumbBinary;
        if (fileType == "video") {
          uint8list = await generateThumbnailData(
              videoUrl: file!.path, passMacos: true);
          thumbBinary = base64Encode(uint8list ?? []);
        }
      }
      return downloadUrl;
    } else if (fileUrl != null && file != null) {
      return fileUrl;
    } else {
      throw Error;
    }
  }
}
