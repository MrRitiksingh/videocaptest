// text_overlay_manager.dart
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/material.dart';

class TextOverlay {
  String text;
  Offset position;
  double scale;
  Color color;
  TextStyle style;
  double rotation;

  TextOverlay({
    required this.text,
    required this.position,
    this.scale = 1.0,
    this.color = const Color.fromARGB(255, 189, 32, 21),
    required this.style,
    this.rotation = 0.0,
  });
}

// filters_manager.dart
class FilterManager {
  static const filters = {
    'none': [],
    'grayscale': ['-vf', 'colorchannelmixer=.3:.4:.3:0:.3:.4:.3:0:.3:.4:.3'],
    // 'sepia': [
    //   '-vf',
    //   'colorchannelmixer=.393:.769:.189:0:.349:.686:.168:0:.272:.534:.131'
    // ],
    'vintage': ['-vf', 'curves=vintage'],
    // 'sharpen': ['-vf', 'unsharp=5:5:1.0:5:5:0.0'],
    // 'brightness': ['-vf', 'brightness=0.2'],
    // 'contrast': ['-vf', 'contrast=1.5'],
    // 'saturation': ['-vf', 'saturation=2'],
  };

  static ColorFilter getColorFilter(String filter) {
    switch (filter) {
      case 'grayscale':
        return const ColorFilter.matrix([
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      // case 'sepia':
      //   return const ColorFilter.matrix([
      //     0.393,
      //     0.769,
      //     0.189,
      //     0,
      //     0,
      //     0.349,
      //     0.686,
      //     0.168,
      //     0,
      //     0,
      //     0.272,
      //     0.534,
      //     0.131,
      //     0,
      //     0,
      //     0,
      //     0,
      //     0,
      //     1,
      //     0,
      //   ]);
      case 'brightness':
        return const ColorFilter.matrix([
          1.5,
          0,
          0,
          0,
          0,
          0,
          1.5,
          0,
          0,
          0,
          0,
          0,
          1.5,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'contrast':
        return const ColorFilter.matrix([
          2,
          0,
          0,
          0,
          -255,
          0,
          2,
          0,
          0,
          -255,
          0,
          0,
          2,
          0,
          -255,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'saturation':
        return const ColorFilter.matrix([
          1.5,
          0,
          0,
          0,
          0,
          0,
          1.5,
          0,
          0,
          0,
          0,
          0,
          1.5,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case 'vintage':
        return const ColorFilter.matrix([
          0.9,
          0.5,
          0.1,
          0,
          0,
          0.3,
          0.8,
          0.1,
          0,
          0,
          0.2,
          0.3,
          0.5,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      default:
        return const ColorFilter.mode(
          Colors.transparent,
          BlendMode.srcOver,
        );
    }
  }

  static Future<bool> applyFilter(
      String inputPath, String outputPath, String filter) async {
    if (!filters.containsKey(filter)) return false;

    final command = [
      '-i',
      inputPath,
      ...filters[filter]!,
      '-c:a',
      'copy',
      outputPath
    ];

    final session = await FFmpegKit.execute(command.join(' '));
    final returnCode = await session.getReturnCode();
    if (ReturnCode.isSuccess(returnCode)) {
      return true;
    }
    return false;
  }
}
