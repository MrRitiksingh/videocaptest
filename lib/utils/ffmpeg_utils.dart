import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/log.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:permission_handler/permission_handler.dart';

class FFmpegUtils {
  static Future<String> getExportPath() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        throw Exception('Storage permission is required');
      }
    }

    final directory = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${directory.path}/exports');

    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    return exportDir.path;
  }

  static Future<String?> exportVideo({
    required String inputPath,
    required String outputFileName,
    String? audioPath,
    double? startTime,
    double? endTime,
    double originalAudioVolume = 1.0,
    double addedAudioVolume = 1.0,
    Function(double)? onProgress,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final outputPath = '${directory.path}/$outputFileName';

      // Ensure input file exists
      final inputFile = File(inputPath);
      if (!await inputFile.exists()) {
        throw Exception('Input video file does not exist: $inputPath');
      }

      // Ensure audio file exists if provided
      if (audioPath != null) {
        final audioFile = File(audioPath);
        if (!await audioFile.exists()) {
          throw Exception('Audio file does not exist: $audioPath');
        }
      }

      // Build FFmpeg command with optimized settings
      String command = '-i "${inputFile.path}"';

      // Add audio if provided
      if (audioPath != null) {
        command += ' -i "${File(audioPath).path}"';

        // Create complex filter for audio mixing with volume control
        command +=
            ' -filter_complex "[0:a]volume=${originalAudioVolume}[a1];[1:a]volume=${addedAudioVolume}[a2];[a1][a2]amix=inputs=2:duration=first[aout]"';
        command += ' -map 0:v -map "[aout]"';
      } else {
        // If no audio is added, just control original audio volume
        command +=
            ' -filter_complex "[0:a]volume=${originalAudioVolume}[aout]"';
        command += ' -map 0:v -map "[aout]"';
      }

      // Add trim if time parameters are provided
      if (startTime != null && endTime != null) {
        command += ' -ss $startTime -t ${endTime - startTime}';
      }

      // Optimized output parameters with progress reporting
      command +=
          ' -c:v libx264 -preset ultrafast -crf 28 -c:a aac -b:a 128k -movflags +faststart -progress pipe:1 "${outputPath}"';

      print('Executing FFmpeg command: $command');

      // Create a completer to handle the async operation
      final completer = Completer<String?>();
      bool isCompleted = false;

      // Execute FFmpeg command with progress tracking
      await FFmpegKit.executeAsync(
        command,
        (FFmpegSession session) async {
          try {
            final returnCode = await session.getReturnCode();
            if (ReturnCode.isSuccess(returnCode)) {
              final outputFile = File(outputPath);
              if (await outputFile.exists() && await outputFile.length() > 0) {
                print('Successfully exported video to: $outputPath');
                completer.complete(outputPath);
              } else {
                completer.completeError(
                    'Output file was not created or is empty: $outputPath');
              }
            } else {
              final logs = await session.getLogs();
              final errorMessage =
                  logs.map((log) => log.getMessage()).join('\n');
              print('FFmpeg export failed: $errorMessage');
              completer.completeError('FFmpeg export failed: $errorMessage');
            }
          } catch (e) {
            completer.completeError(e);
          }
          isCompleted = true;
        },
        (Log log) {
          final message = log.getMessage();
          print('FFmpeg log: $message');

          // Parse progress from FFmpeg logs
          if (message.contains('time=')) {
            try {
              final timeStr = message.split('time=')[1].split(' ')[0];
              final timeParts = timeStr.split(':');
              final seconds = double.parse(timeParts[0]) * 3600 +
                  double.parse(timeParts[1]) * 60 +
                  double.parse(timeParts[2]);

              // Calculate progress percentage
              final duration = endTime != null ? endTime - (startTime ?? 0) : 0;
              if (duration > 0) {
                final progress = (seconds / duration).clamp(0.0, 1.0);
                onProgress?.call(progress);
              }
            } catch (e) {
              print('Error parsing progress: $e');
            }
          }
        },
        (Statistics statistics) {
          // Additional progress tracking if needed
          if (statistics.getTime() > 0) {
            final duration = endTime != null ? endTime - (startTime ?? 0) : 0;
            if (duration > 0) {
              final progress =
                  (statistics.getTime() / duration).clamp(0.0, 1.0);
              onProgress?.call(progress);
            }
          }
        },
      );

      // Set a timeout of 5 minutes
      final timeout = Future.delayed(const Duration(minutes: 5));
      await Future.any([
        completer.future,
        timeout.then((_) {
          if (!isCompleted) {
            throw Exception('Export timed out after 5 minutes');
          }
        }),
      ]);

      return await completer.future;
    } catch (e) {
      print('Error during video export: $e');
      return null;
    }
  }
}
