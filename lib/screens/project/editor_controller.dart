import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/level.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/session.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../constants/filters.dart';
import '../../utils/functions.dart';
import 'models/add_text_model.dart';

class MediaInput {
  final File file;
  final Duration? duration; // Only used for images
  final bool isVideo;

  MediaInput({
    required this.file,
    this.duration,
    required this.isVideo,
  }) : assert(isVideo || duration != null, 'Images must have a duration');

  static bool isVideoFile(String filePath) {
    final videoExtensions = ['.mp4', '.mov', '.avi', '.mkv', '.webm'];
    return videoExtensions.contains(path.extension(filePath).toLowerCase());
  }
}

bool isVideoFile(String filePath) {
  final videoExtensions = ['.mp4', '.mov', '.avi', '.mkv', '.webm'];
  return videoExtensions.contains(path.extension(filePath).toLowerCase());
}

void ffprint(String text) {
  final pattern = new RegExp('.{1,900}');
  var nowString = DateTime.now();
  pattern
      .allMatches(text)
      .forEach((match) => safePrint("$nowString - " + match.group(0)!));
}

String notNull(String? string, [String valuePrefix = ""]) {
  return (string == null) ? "" : valuePrefix + string;
}

void listAllLogs(Session session) async {
  ffprint("Listing log entries for session: ${session.getSessionId()}");
  var allLogs = await session.getAllLogs();
  allLogs.forEach((element) {
    ffprint(
        "${Level.levelToString(element.getLevel())}:${element.getMessage()}");
  });
  // ffprint("Listed log entries for session: ${session.getSessionId()}");
}

class EditorVideoController {
  // Helper method to check if a video file has audio stream
  static Future<bool> _hasAudioStream(String videoPath) async {
    try {
      final session = await FFmpegKit.execute(
          '-v quiet -show_streams -select_streams a -of csv=p=0 "$videoPath"');
      final output = await session.getOutput();
      return output != null && output.trim().isNotEmpty;
    } catch (e) {
      safePrint("Error checking audio stream for $videoPath: $e");
      return false;
    }
  }

  // Helper method to get video duration
  static Future<(File?, List<(File original, File processed)>?)>
      combineMediaFiles(
    List<File> files, {
    List<int>? totalDuration,
    required int outputHeight,
    required int outputWidth,
  }) async {
    try {
      if (files.isEmpty) return (null, null);

      // Ensure dimensions are even numbers (required for H.264 encoding)
      // Use a more conservative approach to avoid aspect ratio issues
      final evenWidth = (outputWidth % 2 == 0) ? outputWidth : outputWidth - 1;
      final evenHeight =
          (outputHeight % 2 == 0) ? outputHeight : outputHeight - 1;

      safePrint("Original dimensions: ${outputWidth}x${outputHeight}");
      safePrint("Adjusted dimensions: ${evenWidth}x${evenHeight}");

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${tempDir.path}/${timestamp}_combined_output.mp4';
      final inputListPath = '${tempDir.path}/${timestamp}_input_list.txt';
      final inputListFile = File(inputListPath);

      List<String> processedFilePaths = [];

      // Use indexed mapping for parallel processing
      final List<Future<(int, File, File?, bool)>> futures = [];
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        futures.add(Future<(int, File, File?, bool)>(() async {
          final ext = file.path.split('.').last.toLowerCase();
          final isImage = ['jpg', 'jpeg', 'png', 'webp'].contains(ext);
          final isVideo = ['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext);
          String finalPath = '';
          bool success = false;

          if (isImage) {
            final imageVideoPath = '${tempDir.path}/${timestamp}_image_$i.mp4';
            final duration = totalDuration?[i] ?? 3;

            // Improved image-to-video conversion with better settings for thumbnails and preview
            final imgCommand = '-y -loop 1 -t $duration -i "${file.path}" '
                '-f lavfi -i anullsrc=r=44100:cl=stereo '
                '-vf "scale=$evenWidth:$evenHeight:force_original_aspect_ratio=decrease,'
                'pad=$evenWidth:$evenHeight:(ow-iw)/2:(oh-ih)/2:color=black" '
                '-r 30 -c:v libx264 -preset medium -crf 23 -pix_fmt yuv420p '
                '-c:a aac -b:a 128k -shortest -movflags +faststart "$imageVideoPath"';
            safePrint("Improved Image to Video Command #$i:\n$imgCommand");
            final session = await FFmpegKit.execute(imgCommand);
            final returnCode = await session.getReturnCode();
            final logs = await session.getLogsAsString();
            if (ReturnCode.isSuccess(returnCode)) {
              // Verify the output file exists and has content
              final outputFile = File(imageVideoPath);
              if (await outputFile.exists() && await outputFile.length() > 0) {
                finalPath = imageVideoPath;
                success = true;
                // DEBUG: Check audio stream in processed image video
                final probeSession = await FFmpegKit.execute(
                    '-hide_banner -i "$imageVideoPath"');
                final probeLogs = await probeSession.getOutput();
                safePrint('Audio debug (image video $i):\n$probeLogs');
              } else {
                safePrint(
                    "Error: Image processing output file is empty or missing for #$i");
                success = false;
              }
            } else {
              safePrint("Error in image file #$i: $logs");
              success = false;
            }
          } else if (isVideo) {
            final standardizedPath =
                '${tempDir.path}/${timestamp}_video_$i.mp4';
            final vidCommand = '-y -i "${file.path}" '
                '-vf "scale=$evenWidth:$evenHeight" '
                '-r 10 -map 0 -c:v libx264 -preset ultrafast -c:a aac -ar 48000 -ac 2 -b:a 128k '
                '-b:v 800k -threads 0 "$standardizedPath"';
            safePrint("Video Standardize Command #$i:\n$vidCommand");
            final session = await FFmpegKit.execute(vidCommand);
            final returnCode = await session.getReturnCode();
            final logs = await session.getLogsAsString();
            if (ReturnCode.isSuccess(returnCode)) {
              // Verify the output file exists and has content
              final outputFile = File(standardizedPath);
              if (await outputFile.exists() && await outputFile.length() > 0) {
                finalPath = standardizedPath;
                success = true;

                // Check if the video has audio using our helper method
                final hasAudio = await _hasAudioStream(standardizedPath);
                safePrint('Video $i has audio: $hasAudio');

                if (!hasAudio) {
                  final withAudioPath =
                      '${tempDir.path}/${timestamp}_video_${i}_withaudio.mp4';
                  final addAudioCmd =
                      '-y -i "$standardizedPath" -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=48000 -shortest -c:v copy -c:a aac "$withAudioPath"';

                  safePrint(
                      'Adding silent audio to $standardizedPath: $addAudioCmd');
                  final addAudioSession = await FFmpegKit.execute(addAudioCmd);
                  final addAudioReturnCode =
                      await addAudioSession.getReturnCode();
                  if (ReturnCode.isSuccess(addAudioReturnCode)) {
                    final audioFile = File(withAudioPath);
                    if (await audioFile.exists() &&
                        await audioFile.length() > 0) {
                      finalPath = withAudioPath;
                    } else {
                      safePrint('Failed to create audio file: $withAudioPath');
                    }
                  } else {
                    safePrint(
                        'Failed to add silent audio to $standardizedPath');
                  }
                }
              } else {
                safePrint(
                    "Error: Video processing output file is empty or missing for #$i");
                success = false;
              }
            } else {
              safePrint("Error in video file #$i: $logs");
              success = false;
            }
          } else {
            safePrint("Unsupported file type: ${file.path}");
            success = false;
          }

          // Return the result with success flag
          return (i, file, success ? File(finalPath) : null, success);
        }));
      }

      final results = await Future.wait(futures);
      results.sort((a, b) => a.$1.compareTo(b.$1));

      // Filter out failed processing results and build successful pairs
      final successfulResults = results.where((result) => result.$4).toList();
      if (successfulResults.isEmpty) {
        safePrint("All media files failed to process");
        return (null, null);
      }

      final processedPairs =
          successfulResults.map((e) => (e.$2, e.$3!)).toList();
      processedFilePaths =
          processedPairs.map((e) => "file '${e.$2.path}'").toList();

      safePrint(
          "Successfully processed ${successfulResults.length} out of ${files.length} files");

      if (processedFilePaths.isEmpty) return (null, null);

      // Validate all files exist before writing the list
      for (final path in processedFilePaths) {
        final filePath = path.replaceAll("file '", "").replaceAll("'", "");
        final file = File(filePath);
        if (!await file.exists()) {
          safePrint("Warning: File does not exist: $filePath");
        }
      }

      await inputListFile.writeAsString(processedFilePaths.join('\n'));
      safePrint(
          "Created input list file with ${processedFilePaths.length} entries");

      // Use more robust concatenation command with proper audio handling
      final finalCommand = '-y -f concat -safe 0 -i "$inputListPath" '
          '-map 0:v -map 0:a? -c:v libx264 -preset ultrafast -c:a aac -b:v 800k -b:a 128k '
          '"$outputPath"';

      safePrint("Final Concatenation Command:\n$finalCommand");

      final finalSession = await FFmpegKit.execute(finalCommand);
      final returnCode = await finalSession.getReturnCode();
      final logs = await finalSession.getLogsAsString();
      final stack = await finalSession.getFailStackTrace();

      if (ReturnCode.isSuccess(returnCode)) {
        // Verify the output file was created successfully
        final outputFile = File(outputPath);
        if (await outputFile.exists() && await outputFile.length() > 0) {
          safePrint("Video combined successfully: $outputPath");
          return (File(outputPath), processedPairs);
        } else {
          safePrint("Output file was not created or is empty: $outputPath");
          return (null, null);
        }
      } else {
        safePrint(
            "FFmpeg failed to combine files.\nLogs:\n$logs\nStack:\n$stack");

        // Try a fallback approach with simpler concatenation
        safePrint("Attempting fallback concatenation method...");
        final fallbackCommand = '-y -f concat -safe 0 -i "$inputListPath" '
            '-c copy "$outputPath"';

        final fallbackSession = await FFmpegKit.execute(fallbackCommand);
        final fallbackReturnCode = await fallbackSession.getReturnCode();

        if (ReturnCode.isSuccess(fallbackReturnCode)) {
          final outputFile = File(outputPath);
          if (await outputFile.exists() && await outputFile.length() > 0) {
            safePrint("Fallback concatenation successful: $outputPath");
            return (File(outputPath), processedPairs);
          }
        }

        final fallbackLogs = await fallbackSession.getLogsAsString();
        safePrint("Fallback also failed: $fallbackLogs");
        return (null, null);
      }
    } catch (e, stack) {
      safePrint("Exception occurred during media combination: $e");
      safePrint("Stack trace:\n$stack");
      rethrow;
      // return (null, null);
    }
  }

  // Helper method to get image dimensions using FFmpeg probe
  static Future<Map<String, int>> _getImageDimensions(String imagePath) async {
    try {
      final session = await FFmpegKit.execute('-hide_banner -i "$imagePath"');
      final logs = await session.getLogsAsString();

      // Parse dimensions from FFmpeg output
      final dimensionRegex = RegExp(r'(\d+)x(\d+)');
      final match = dimensionRegex.firstMatch(logs);

      if (match != null) {
        final width = int.parse(match.group(1)!);
        final height = int.parse(match.group(2)!);
        return {'width': width, 'height': height};
      }

      // Fallback to reasonable defaults if parsing fails
      return {'width': 1280, 'height': 720};
    } catch (e) {
      safePrint("Error getting image dimensions: $e");
      return {'width': 1280, 'height': 720};
    }
  }

  // Calculate optimal width preserving aspect ratio with reasonable limits
  static int _calculateOptimalWidth(int originalWidth, int originalHeight) {
    const int maxWidth = 1920;
    const int minWidth = 480;

    if (originalWidth <= maxWidth && originalWidth >= minWidth) {
      return originalWidth;
    }

    // Scale down if too large, up if too small
    if (originalWidth > maxWidth) {
      return maxWidth;
    } else {
      return minWidth;
    }
  }

  // Calculate optimal height preserving aspect ratio
  static int _calculateOptimalHeight(int originalWidth, int originalHeight) {
    final targetWidth = _calculateOptimalWidth(originalWidth, originalHeight);
    final aspectRatio = originalHeight / originalWidth;
    return (targetWidth * aspectRatio).round();
  }

  static Future<File?> imagesToVideo({
    required List<File> imageFiles,
    required Duration eachImageDuration,
    int? width,
    int? height,
    int bitrate = 2000,
  }) async {
    if (imageFiles.isEmpty) return null;
    try {
      Directory temp = await getApplicationCacheDirectory();
      String outputVideoPath =
          "${temp.path}/${DateTime.now().millisecondsSinceEpoch}.mp4";

      final imageFilesPaths = imageFiles.map((file) => file.path).toList();

      // Get dimensions from first image to preserve aspect ratio
      final dimensions = await _getImageDimensions(imageFiles.first.path);
      final targetWidth = width ??
          _calculateOptimalWidth(dimensions['width']!, dimensions['height']!);
      final targetHeight = height ??
          _calculateOptimalHeight(dimensions['width']!, dimensions['height']!);

      safePrint(
          "Original image dimensions: ${dimensions['width']}x${dimensions['height']}");
      safePrint("Target video dimensions: ${targetWidth}x${targetHeight}");

      // Build a filter chain that preserves aspect ratio, ensures even dimensions
      // and guarantees encoder-friendly sizes using ceil/2*2 and padding.
      final String vf =
          "scale='min(${targetWidth},iw)':'-2':force_original_aspect_ratio=decrease,pad='ceil(iw/2)*2':'ceil(ih/2)*2':(ow-iw)/2:(oh-ih)/2";

      String command;

      if (imageFiles.length == 1) {
        // Single image: Use loop method
        final imagePath = imageFiles.first.path;
        final duration = eachImageDuration.inSeconds;

        command = '-y -loop 1 -t $duration -i "$imagePath" '
            '-f lavfi -i anullsrc=r=44100:cl=stereo '
            '-vf "$vf" '
            '-r 30 -c:v libx264 -preset medium -crf 23 -pix_fmt yuv420p '
            '-c:a aac -b:a 128k -shortest -movflags +faststart "$outputVideoPath"';
      } else {
        // Multiple images: Use framerate method
        final framerate = 1 / eachImageDuration.inSeconds;

        command =
            '-y -framerate $framerate ${imageFilesPaths.map((path) => '-i "$path"').join(' ')} '
            '-vf "$vf" '
            '-r 30 -c:v libx264 -preset medium -crf 23 -pix_fmt yuv420p '
            '-movflags +faststart "$outputVideoPath"';
      }

      safePrint("Improved Image to Video Command:\n$command");
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final outputFile = File(outputVideoPath);
        if (await outputFile.exists() && await outputFile.length() > 0) {
          safePrint("Image to video conversion successful: ${outputFile.path}");
          return outputFile;
        }
        throw Exception('Output file not found or empty');
      } else {
        final logs = await session.getLogsAsString();
        final failStackTrace = await session.getFailStackTrace();
        safePrint(
            "Image to video conversion failed: ${failStackTrace ?? logs}");
        throw Exception('FFmpeg failed: ${failStackTrace ?? logs}');
      }
    } catch (err) {
      safePrint('Error combining media: $err');
      rethrow;
    }
  }

  // static Future<File?> addAudioToVideo({
  //   required File videoFile,
  //   required File audioFile,
  // }) async {
  //   try {
  //     Directory temp = await getApplicationDocumentsDirectory();
  //     String outputVideoPath =
  //         "${temp.path}/${DateTime.now().millisecondsSinceEpoch}.mp4";
  //     String command =
  //         '-i ${videoFile.path} -i ${audioFile.path} -map 0:v -map 1:a -c:v copy -shortest $outputVideoPath';
  //     safePrint(command);
  //     // copy(command2);
  //     final session = await FFmpegKit.execute(command);
  //     final returnCode = await session.getReturnCode();
  //     if (ReturnCode.isSuccess(returnCode)) {
  //       final outputFile = File(outputVideoPath);
  //       if (await outputFile.exists()) {
  //         return outputFile;
  //       }
  //       throw Exception('Output file not found');
  //     } else {
  //       final logs = await session.getLogsAsString();
  //       final failStackTrace = await session.getFailStackTrace();
  //       safePrint(failStackTrace ?? logs);
  //       throw Exception();
  //     }
  //   } catch (err) {
  //     safePrint('Error combining media');
  //     rethrow;
  //   }
  // }

  static Future<File?> addAudioToVideo({
    required File videoFile,
    required File audioFile,
    bool muteOriginalAudio = true,
    double inputAudioVolume = 1.0, // 1.0 = 100%, 0.5 = 50%, etc.
  }) async {
    try {
      // Validate input files
      if (!await videoFile.exists()) {
        // return FFmpegResult(
        //   success: false,
        //   error: 'Video file does not exist: ${videoFile.path}',
        // );
        return null;
      }
      if (!await audioFile.exists()) {
        // return FFmpegResult(
        //   success: false,
        //   error: 'Audio file does not exist: ${audioFile.path}',
        // );
        return null;
      }

      Directory temp = await getApplicationDocumentsDirectory();
      String outputVideoPath =
          "${temp.path}/processed_${DateTime.now().millisecondsSinceEpoch}.mp4";

      // Build FFmpeg command with volume control
      List<String> commandParts = [
        // Input files
        '-i ${videoFile.path}',
        '-i ${audioFile.path}',

        // Audio filters
        '-filter_complex',
      ];

      if (muteOriginalAudio) {
        // If muting original audio, we only need the new audio
        commandParts.add('"[1:a]volume=${inputAudioVolume}[a]"');
        commandParts.addAll([
          // Map video from first input and processed audio
          '-map 0:v',
          '-map "[a]"',
        ]);
      } else {
        // Mix both audio streams - use duration=first to match video duration
        commandParts.add(
          '"[0:a]volume=0.0[va];[1:a]volume=${inputAudioVolume}[na];[va][na]amix=inputs=2:duration=first[a]"',
        );
        commandParts.addAll([
          // Map video from first input and processed audio
          '-map 0:v',
          '-map "[a]"',
        ]);
      }

      // Add output options
      commandParts.addAll([
        // Copy video codec to avoid re-encoding
        '-c:v copy',

        // Set audio codec and quality
        '-c:a aac',
        '-b:a 192k',

        // Ensure output duration matches the shortest input
        '-shortest',

        // Output file
        outputVideoPath,
      ]);

      // Join command parts
      String command = commandParts.join(' ');
      safePrint('Executing FFmpeg command: $command');

      // Execute FFmpeg command
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      // final logs = await session.getLogsAsString();

      if (ReturnCode.isSuccess(returnCode)) {
        final outputFile = File(outputVideoPath);
        if (await outputFile.exists()) {
          // return FFmpegResult(
          //   success: true,
          //   outputFile: outputFile,
          //   logs: logs,
          // );
          return outputFile;
        } else {
          // return FFmpegResult(
          //   success: false,
          //   error: 'Output file not found after successful processing',
          //   logs: logs,
          // );
          return null;
        }
      } else {
        // final failStackTrace = await session.getFailStackTrace();
        // return FFmpegResult(
        //   success: false,
        //   error: failStackTrace ?? 'Unknown error occurred',
        //   logs: logs,
        // );
        return null;
      }
    } catch (err) {
      // return FFmpegResult(
      //   success: false,
      //   error: 'Error processing media: ${err.toString()}',
      // );
      rethrow;
    }
  }

  static Future<File?> addTextsToVideo({
    required File videoFile,
    required String fontPath,
    required List<VideoTextOverlayOptions> textOptions,
  }) async {
    try {
      // Validate input file
      if (!await videoFile.exists()) {
        safePrint('Video file does not exist: ${videoFile.path}');
        return null;
      }

      // Get video metadata
      final metadataResult = await _getVideoMetadata(videoFile);
      if (metadataResult == null) {
        safePrint('Could not retrieve video metadata');
        return null;
      }

      // Prepare output file
      Directory temp = await getApplicationDocumentsDirectory();
      String outputVideoPath =
          "${temp.path}/multi_text_overlay_${DateTime.now().millisecondsSinceEpoch}.mp4";

      // Build complex filter parts
      List<String> filterParts = [];

      // Determine video dimensions
      int width = metadataResult['width'] ?? 0;
      int height = metadataResult['height'] ?? 0;

      // Process each text overlay
      textOptions.asMap().forEach((index, options) {
        // Calculate absolute coordinates
        int xPos = (options.x * width).round();
        int yPos = (options.y * height).round();

        // Prepare font settings
        String fontPath =
            options.fontFile ?? '/system/fonts/Roboto-Regular.ttf';

        // Base text filter
        String textFilter = "drawtext=fontfile=$fontPath:" +
            "text='${_escapeFFmpegText(options.text)}':" +
            "fontcolor=${options.fontColor}:" +
            "fontsize=${options.fontSize}:" +
            "x=$xPos:y=$yPos";

        // Optional background box
        if (options.boxColor != null) {
          textFilter += ":" +
              "box=1:" +
              "boxcolor=${options.boxColor}:" +
              "boxopacity=${(options.boxOpacity ?? 0.5)}:" +
              "padding=${options.boxPadding ?? 10}";
        }

        // Time-based visibility
        if (options.startTime >= 0) {
          textFilter +=
              ":enable='between(t,${options.startTime},${options.startTime + (options.duration ?? 5)}))'";
        }

        // Add transition effect
        if (options.transitionEffect != null) {
          switch (options.transitionEffect) {
            case 'fade':
              textFilter += ",fade=in=0.5:out=0.5:st=${options.startTime}";
              break;
            case 'slideLeft':
              textFilter = "format=rgba,/" +
                  "drawtext=fontfile=$fontPath:" +
                  "text='${_escapeFFmpegText(options.text)}':" +
                  "fontcolor=${options.fontColor}:" +
                  "fontsize=${options.fontSize}:" +
                  "x=w-t/0.5*(w+tw):y=$yPos:" +
                  "enable='between(t,${options.startTime},${options.startTime + (options.duration ?? 5)})'";
              break;
            case 'slideRight':
              textFilter = "format=rgba,/" +
                  "drawtext=fontfile=$fontPath:" +
                  "text='${_escapeFFmpegText(options.text)}':" +
                  "fontcolor=${options.fontColor}:" +
                  "fontsize=${options.fontSize}:" +
                  "x=-tw+t/0.5*(w+tw):y=$yPos:" +
                  "enable='between(t,${options.startTime},${options.startTime + (options.duration ?? 5)})'";
              break;
          }
        }

        filterParts.add(textFilter);
      });

      // Construct FFmpeg command
      String command = '-i ${videoFile.path} ' +
          '-vf "' +
          filterParts.join(',') +
          '" ' +
          '-c:a copy ' + // Copy audio without re-encoding
          '-c:v libx264 ' + // Re-encode video to apply filter
          '-preset medium ' + // Balanced encoding speed and quality
          '-crf 23 ' + // Constant Rate Factor for good quality
          '$outputVideoPath';

      // Execute FFmpeg command
      safePrint('FFmpeg Command: $command');
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final outputFile = File(outputVideoPath);
        if (await outputFile.exists()) {
          return outputFile;
        }
      }

      // Log error if processing failed
      // final logs = await session.getLogsAsString();
      // safePrint('FFmpeg Logs: $logs');
      listAllLogs(session);
      return null;
    } catch (e) {
      safePrint('Error adding texts to video: $e');
      return null;
    }
  }

  static Future<File?> addMultiTextsToVideoWithDuration({
    required File videoFile,
    required List<AddTextModel> textOptions,
  }) async {
    try {
      Directory temp = await getApplicationDocumentsDirectory();
      String outputVideoPath =
          "${temp.path}/multi_text_overlay_${DateTime.now().millisecondsSinceEpoch}.mp4";
      List<String> multiTextCommands = textOptions.map((addTextModel) {
        return "drawtext=text='${addTextModel.text}':"
            "fontsize=24:" // Add font size
            "fontcolor=white:" // Add font color
            "box=1:boxcolor=black@0.5:" // Add background box for better visibility
            "enable='between(t,${addTextModel.startFrom},${addTextModel.endAt})':"
            "x=${addTextModel.x}:y=${addTextModel.y}";
      }).toList();
      String drawTextCommand = multiTextCommands.join(',');

      // Construct the final FFmpeg command
      String command =
          "-i ${videoFile.path} -vf \"$drawTextCommand\" -c:a copy $outputVideoPath";
      safePrint(command);
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final outputFile = File(outputVideoPath);
        if (await outputFile.exists()) {
          return outputFile;
        }
      }
      listAllLogs(session);
      return null;
    } catch (e) {
      safePrint('Error adding texts to video: $e');
      return null;
    }
  }

  static Future<File?> embedSubtitleFile({
    required File videoFile,
    required File subtitleFileSRT,
  }) async {
    try {
      Directory temp = await getApplicationDocumentsDirectory();
      String outputVideoPath =
          "${temp.path}/${DateTime.now().microsecondsSinceEpoch}.mp4";
      String command =
          '-i ${videoFile.path} -vf subtitles=${subtitleFileSRT.path} $outputVideoPath';
      // String burnSubtitlesCommand =
      //     "-y -i ${videoFile.path} -vf subtitles=${subtitleFileSRT.path} -c:v mpeg4 $outputVideoPath";

      /// Subtitles command maker
      // String command = FFmpegSubtitleBurner.generateBurnCommand(
      //   inputVideoPath: videoFile.path,
      //   subtitlePath: subtitleFileSRT.path,
      //   outputPath: outputVideoPath,
      // );

// Advanced usage with custom subtitle styling and quality settings
//       final subtitleStyle = SubtitleStyle(
//         fontName: 'SF Pro Display',
//         fontSize: 28,
//         primaryColor: 'white',
//         outlineColor: 'black',
//         outlineWidth: 2.5,
//         bold: true,
//         alignment: 'center',
//         marginV: 30,
//         marginH: 20,
//       );
//
//       final qualitySettings = VideoQualitySettings(
//         preset: 'slow', // Slower preset = better compression
//         crf: '18', // Lower CRF = higher quality (18 is visually lossless)
//         videoBitrate: '5M', // Optional: Set specific bitrate
//         maxBitrate: '7M', // Optional: Set maximum bitrate
//         bufsize: '10M', // Optional: Set buffer size
//         videoCodec: 'libx264', // Use 'h264_nvenc' for NVIDIA GPU acceleration
//       );
//
//       String commandPro = FFmpegSubtitleBurner.generateBurnCommand(
//         inputVideoPath: videoFile.path,
//         subtitlePath: subtitleFileSRT.path,
//         outputPath: outputVideoPath,
//         subtitleStyle: subtitleStyle,
//         qualitySettings: qualitySettings,
//       );
//       copy(commandPro);
      /// Subtitles command maker
      // safePrint(outputVideoPath);
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode)) {
        final outputFile = File(outputVideoPath);
        if (await outputFile.exists()) {
          return outputFile;
        }
        throw Exception('Output file not found');
      } else {
        final logs = await session.getLogsAsString();
        final failStackTrace = await session.getFailStackTrace();
        safePrint(failStackTrace ?? logs);
        throw Exception();
      }
    } catch (err) {
      safePrint('Error burning subtitles');
      rethrow;
    }
  }

  static Future<File?> embedAssSubtitleFile({
    required File videoFile,
    required File subtitleFileASS,
  }) async {
    try {
      Directory temp = await getApplicationDocumentsDirectory();
      String outputVideoPath =
          "${temp.path}/${DateTime.now().microsecondsSinceEpoch}.mp4";

      // Escape paths to handle spaces and special characters
      final videoPath = videoFile.path.replaceAll("'", "'\\''");
      final assPath = subtitleFileASS.path.replaceAll("'", "'\\''");

      // Use ass filter instead of subtitles filter
      String command = '-i \'$videoPath\' -vf ass=\'$assPath\' '
          '-c:a copy ' // Copy audio without re-encoding
          '\'$outputVideoPath\'';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final outputFile = File(outputVideoPath);
        if (await outputFile.exists()) {
          return outputFile;
        }
        throw Exception('Output file not found');
      }

      listAllLogs(session);
    } catch (err) {
      rethrow;
    }
    return null;
  }

  static Future<File?> burnStyledSubtitles({
    required String inputVideoPath,
    required String srtFilePath,
    required double fontSize,
    required String textColor,
    required String backgroundColor,
    required double xPosition,
    required double yPosition,
    required String assFilePath,
  }) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String outputPath = path.join(
        tempDir.path,
        'output_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );

      // For ASS files, colors need to be in ASS format (BBGGRR)
      // Convert hex colors to ASS format
      String convertToAssColor(String hexColor) {
        hexColor = hexColor.replaceAll('#', '');
        if (hexColor.length == 6) {
          // Reorder from RGB to BGR
          String bb = hexColor.substring(4, 6);
          String gg = hexColor.substring(2, 4);
          String rr = hexColor.substring(0, 2);
          return '&H${bb}${gg}${rr}&'; // ASS color format
        }
        return '&HFFFFFF&'; // Default to white if invalid
      }

      final String assTextColor = convertToAssColor(textColor);
      final String assBgColor = convertToAssColor(backgroundColor);

      // Prepare FFmpeg command with enhanced ASS styling
      // Note: MarginL and MarginV are used for x and y positioning in ASS
      String ffmpegCommand =
          '-i "$inputVideoPath" -vf "ass=$assFilePath:force_style=\'FontSize=$fontSize,PrimaryColour=$assTextColor,BackColour=$assBgColor,MarginL=${xPosition.toInt()},MarginV=${yPosition.toInt()},Bold=1,Outline=1,Shadow=2\'" -c:a copy "$outputPath"';

      // Add fade transition
      ffmpegCommand =
          '-i "$inputVideoPath" -vf "fade=t=in:st=0:d=1,ass=$assFilePath:force_style=\'FontSize=$fontSize,PrimaryColour=$assTextColor,BackColour=$assBgColor,MarginL=${xPosition.toInt()},MarginV=${yPosition.toInt()},Bold=1,Outline=1,Shadow=2\'" -c:a copy "$outputPath"';

      // Execute FFmpeg command
      final session = await FFmpegKit.execute(ffmpegCommand);
      final ReturnCode? returnCode = await session.getReturnCode();

      // Check if the operation was successful
      if (ReturnCode.isSuccess(returnCode)) {
        listAllLogs(session);
        return File(outputPath);
      } else {
        // final String? logs = await session.getLogsAsString();
        // safePrint('FFmpeg failed with logs: $logs');
        listAllLogs(session);
        return null;
      }
    } catch (e) {
      safePrint('Error burning subtitles: $e');
      return null;
    }
  }
  // static Future<File?> embedAssSubtitleFile({
  //   required File videoFile,
  //   required File subtitleFileSRT,
  // }) async {
  //   try {
  //     Directory temp = await getApplicationDocumentsDirectory();
  //     String outputVideoPath =
  //         "${temp.path}/${DateTime.now().microsecondsSinceEpoch}.mp4";
  //     String command =
  //         '-i ${videoFile.path} -vf subtitles=${subtitleFileSRT.path} $outputVideoPath';
  //     final session = await FFmpegKit.execute(command);
  //     final returnCode = await session.getReturnCode();
  //     if (ReturnCode.isSuccess(returnCode)) {
  //       final outputFile = File(outputVideoPath);
  //       if (await outputFile.exists()) {
  //         return outputFile;
  //       }
  //       throw Exception('Output file not found');
  //     }
  //     listAllLogs(session);
  //   } catch (err) {
  //     // listAllLogs(session);
  //     rethrow;
  //   }
  // }

  static Future<File?> embedSomeAss({
    required File videoFile,
    required File subtitleFileSRT,
    bool hardcodedSubs =
        true, // Whether to burn subs into video or keep them as a separate stream
    String? fontDirectory, // Optional directory containing custom fonts
    bool maintainQuality = true,
  }) async {
    try {
      Directory temp = await getApplicationDocumentsDirectory();
      String outputVideoPath =
          "${temp.path}/${DateTime.now().microsecondsSinceEpoch}.mp4";
      // String command =
      //     '-i ${videoFile.path} -vf subtitles=${subtitleFileSRT.path} $outputVideoPath';
      // String burnSubtitlesCommand =
      //     "-y -i ${videoFile.path} -vf subtitles=${subtitleFileSRT.path} -c:v mpeg4 $outputVideoPath";

      /// Subtitles command maker
      // Build FFmpeg command
      List<String> arguments = [];

      // Input options
      arguments.addAll(['-i', videoFile.path]);

      // If using custom fonts, add fonts directory
      if (fontDirectory != null) {
        arguments.addAll([
          '-fonts_dir',
          fontDirectory,
        ]);
      }

      // Video quality settings
      if (maintainQuality) {
        arguments.addAll([
          '-c:v', 'libx264', // Use H.264 codec
          '-preset', 'slow', // Slower encoding = better quality
          '-crf', '18', // High quality (0-51, lower = better)
          '-c:a', 'copy', // Copy audio stream without re-encoding
        ]);
      }

      // Subtitle handling
      if (hardcodedSubs) {
        // Burn subtitles into video stream
        arguments.addAll([
          '-vf', 'ass=${subtitleFileSRT.path}', // Use ASS filter
          '-map', '0:v', // Map video stream
          '-map', '0:a', // Map audio stream
        ]);
      } else {
        // Keep subtitles as separate stream
        arguments.addAll([
          '-c:s', 'copy', // Copy subtitle stream
          '-map', '0:v', // Map video stream
          '-map', '0:a', // Map audio stream
          // '-map', '1:s', // Map subtitle stream
        ]);
      }

      // Output path
      arguments.add(outputVideoPath);
      // Convert arguments list to command string
      final command = arguments.join(' ');

      /// Subtitles command maker
      // safePrint(outputVideoPath);
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode)) {
        final outputFile = File(outputVideoPath);
        if (await outputFile.exists()) {
          return outputFile;
        }
        throw Exception('Output file not found');
      } else {
        // final logs = await session.getLogsAsString();
        // final failStackTrace = await session.getFailStackTrace();
        // safePrint(failStackTrace ?? logs);
        // throw Exception();
        listAllLogs(session);
      }
    } catch (err) {
      safePrint('Error burning subtitles');
      rethrow;
    }
    return null;
  }

  static Future<File?> subtitleStringToSRTFile(String subText) async {
    // 1
    // 00:00:00,000 --> 00:00:07,000
    // You know what we should all do?
    //
    // 2
    // 00:00:07,000 --> 00:00:09,000
    // Go see a musical.
    //
    // 3
    // 00:00:12,000 --> 00:00:14,000
    // Sure.
    //
    // 4
    // 00:00:14,000 --> 00:00:17,000
    // And you know which one we should see?
    //
    // 5
    // 00:00:17,000 --> 00:00:20,000
    // The 1996 Tony Award winner.

    try {
      final temp = await getApplicationCacheDirectory();
      String outputSubtitlePath =
          "${temp.path}/${DateTime.now().millisecondsSinceEpoch}.srt";
      // Create a File instance at the desired path
      File srtFile = File(outputSubtitlePath);

      // Write the subtitle content to the file
      await srtFile.writeAsString(subText);

      // Return the created file
      return srtFile;
    } catch (err) {
      safePrint(err);
      rethrow;
    }
  }

  // static Future<File?> imagesToVideo({
  //   required List<File> imageFiles,
  //   required Duration eachImageDuration,
  // }) async {
  //   if (imageFiles.isEmpty) return null;
  //   try {
  //     Directory temp = await getApplicationDocumentsDirectory();
  //     String outputVideoPath =
  //         "${temp.path}/${DateTime.now().millisecondsSinceEpoch}.mp4";
  //
  //     final imageFilesPaths = imageFiles.map((file) => file.path).toList();
  //     final imageInputs = imageFilesPaths
  //         .map((path) => '-loop 1 -t ${eachImageDuration.inSeconds} -i $path')
  //         .join(' ');
  //     final command =
  //         '-y $imageInputs -filter_complex "[0:v][1:v][2:v][3:v]concat=n=${imageFiles.length}:v=1:a=0,format=yuv420p[v]" -map "[v]" $outputVideoPath';
  //     final session = await FFmpegKit.execute(command);
  //     final returnCode = await session.getReturnCode();
  //     if (ReturnCode.isSuccess(returnCode)) {
  //       final outputFile = File(outputVideoPath);
  //       if (await outputFile.exists()) {
  //         return outputFile;
  //       }
  //       throw Exception('Output file not found');
  //     } else {
  //       final logs = await session.getLogsAsString();
  //       final failStackTrace = await session.getFailStackTrace();
  //       throw Exception('FFmpeg failed: ${failStackTrace ?? logs}');
  //     }
  //   } catch (err) {
  //     safePrint('Error combining media: $err');
  //     rethrow;
  //   }
  // }

  static Future<File?> extractAudioFromVideo({
    required File videoFile,
  }) async {
    try {
      // videoFile = await renameFileIfNecessary(videoFile);
      // Create temp directory for processing if needed
      final temp = await getApplicationCacheDirectory();
      String outputFilePath =
          "${temp.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a";
      // original command below
      // String command = "-i ${videoFile.path} -q:a 0 -map a $outputFilePath";
      String command =
          "-i ${videoFile.path} -vn -c:a aac -strict experimental $outputFilePath";

      // String command2 = "-i ${videoFile.path} -vn -c:a copy $outputFilePath";
      // String command3 = "-i ${videoFile.path} $outputFilePath";
      safePrint(command);
      // Execute FFmpeg command
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final outputFile = File(outputFilePath);
        if (await outputFile.exists()) {
          return outputFile;
        }
        throw Exception('Output file not found');
      } else {
        listAllLogs(session);
      }
    } catch (err) {
      // safePrint('Error extracting audio: $err');
      rethrow;
    }
    return null;
  }

  static Future<File?> addVideoFilter({
    required List<FFmpegFilter> selectedFilters,
    required File videoFile,
  }) async {
    try {
      final temp = await getApplicationCacheDirectory();
      String outputFilePath =
          "${temp.path}/audio_${DateTime.now().millisecondsSinceEpoch}.mp4";
      // Construct the filter chain
      final filterChain =
          selectedFilters.map((filter) => filter.command).join(',');

      // Construct the complete FFmpeg command
      final command =
          '-i ${videoFile.path} -vf "$filterChain" -c:a copy $outputFilePath';
      // safePrint(command);
      // Execute FFmpeg command
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final outputFile = File(outputFilePath);
        if (await outputFile.exists()) {
          return outputFile;
        }
        throw Exception('Output file not found');
      } else {
        final logs = await session.getLogsAsString();
        final failStackTrace = await session.getFailStackTrace();
        throw Exception('FFmpeg failed: ${failStackTrace ?? logs}');
      }
    } catch (err) {
      safePrint('Error extracting audio: $err');
      rethrow;
    }
  }

  // static Future<File?> extractAudioFromVideo({
  //   required File videoFile,
  //   // AudioFormat audioFormat = AudioFormat.mp3,
  //   int audioQuality = 0, // 0-9, lower is better quality
  // }) async {
  //   try {
  //     // Validate input file
  //     if (!await videoFile.exists()) {
  //       safePrint('Video file does not exist');
  //       return null;
  //     }
  //
  //     // Create temp directory for processing
  //     final temp = await getApplicationCacheDirectory();
  //     String outputFilePath =
  //         "${temp.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac";
  //
  //     // Flexible audio extraction commands
  //     List<String> extractionCommands = [
  //       // High-quality extraction
  //       "-i ${videoFile.path} -vn -c:a libmp3lame -q:a $audioQuality $outputFilePath",
  //
  //       // Fallback copy method
  //       "-i ${videoFile.path} -vn -c:a copy $outputFilePath",
  //
  //       // Alternative extraction method
  //       "-i ${videoFile.path} -q:a $audioQuality -map a $outputFilePath"
  //     ];
  //
  //     // Try commands sequentially
  //     for (String command in extractionCommands) {
  //       try {
  //         safePrint('Attempting audio extraction: $command');
  //         final session = await FFmpegKit.execute(command);
  //         final returnCode = await session.getReturnCode();
  //
  //         if (ReturnCode.isSuccess(returnCode)) {
  //           final outputFile = File(outputFilePath);
  //           if (await outputFile.exists()) {
  //             return outputFile;
  //           }
  //         }
  //       } catch (_) {
  //         // Continue to next command if this one fails
  //         continue;
  //       }
  //     }
  //
  //     // Log detailed error if all methods fail
  //     final lastSession = await FFmpegKit.execute(extractionCommands.last);
  //     final logs = await lastSession.getLogsAsString();
  //     final failStackTrace = await lastSession.getFailStackTrace();
  //
  //     throw Exception('Audio extraction failed: ${failStackTrace ?? logs}');
  //   } catch (err) {
  //     safePrint('Error extracting audio: $err');
  //     rethrow;
  //   }
  // }

  static Future<File?> combineMediaToVideo({
    required List<MediaInput> mediaInputs,
    required double outputFrameRate,
    String? outputFilePath,
  }) async {
    if (mediaInputs.isEmpty) return null;

    try {
      // Create temp directory for processing if needed
      final temp = await getApplicationCacheDirectory();
      outputFilePath ??=
          "${temp.path}/${DateTime.now().millisecondsSinceEpoch}.mp4";

      // Prepare input arguments for each media file
      final inputArgs = <String>[];
      final filterInputs = <String>[];

      for (var i = 0; i < mediaInputs.length; i++) {
        final media = mediaInputs[i];

        if (media.isVideo) {
          // For videos, just add them as inputs
          inputArgs.add('-i "${media.file.path}"');
          filterInputs.add('[$i:v]');
        } else {
          // For images, add loop and duration
          inputArgs.add(
              '-loop 1 -t ${media.duration!.inSeconds} -i "${media.file.path}"');
          filterInputs.add('[$i:v]');
        }
      }

      // Build the FFmpeg command
      final filterComplex =
          '${filterInputs.join('')}concat=n=${mediaInputs.length}:v=1:a=0,format=yuv420p[v]';

      final command = [
        '-y', // Overwrite output file if exists
        inputArgs.join(' '),
        '-filter_complex "$filterComplex"',
        '-map "[v]"',
        '-c:v libx264', // Use H.264 codec
        '-preset fast', // Faster encoding
        '-crf 23', // Balance between quality and file size
        '-r $outputFrameRate', // Set output framerate
        '-movflags +faststart', // Enable fast start for web playback
        '"$outputFilePath"'
      ].join(' ');

      // Execute FFmpeg command
      final session = await FFmpegKit.execute(
        command,
        // extraArgs: [
        //   '-Wno-unused-function',
        //   '-Wno-deprecated-declarations',
        //   '-fstrict-aliasing',
        //   '-DIOS',
        //   '-DFFMPEG_KIT'
        // ]
      );
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final outputFile = File(outputFilePath);
        if (await outputFile.exists()) {
          return outputFile;
        }
        throw Exception('Output file not found');
      } else {
        final logs = await session.getLogsAsString();
        final failStackTrace = await session.getFailStackTrace();
        throw Exception('FFmpeg failed: ${failStackTrace ?? logs}');
      }
    } catch (err) {
      safePrint('Error combining media: $err');
      rethrow;
    }
  }

  ///
  // static Future<File?> combineMediaToVideo({
  //   required List<MediaInput> mediaInputs,
  //   required double outputFrameRate,
  //   String? outputFilePath,
  // }) async {
  //   if (mediaInputs.isEmpty) return null;
  //
  //   try {
  //     // Create temp directory for processing if needed
  //     final temp = await getApplicationCacheDirectory();
  //     outputFilePath ??=
  //         "${temp.path}/${DateTime.now().millisecondsSinceEpoch}.mp4";
  //
  //     // Prepare input arguments for each media file
  //     final inputArgs = <String>[];
  //     final filterInputs = <String>[];
  //
  //     for (var i = 0; i < mediaInputs.length; i++) {
  //       final media = mediaInputs[i];
  //
  //       if (media.isVideo) {
  //         // For videos, just add them as inputs
  //         inputArgs.add('-i "${media.file.path}"');
  //         filterInputs.add('[$i:v]');
  //       } else {
  //         // For images, add loop and duration
  //         inputArgs.add(
  //             '-loop 1 -t ${media.duration!.inSeconds} -i "${media.file.path}"');
  //         filterInputs.add('[$i:v]');
  //       }
  //     }
  //
  //     // Build the FFmpeg command
  //     final filterComplex =
  //         '${filterInputs.join('')}concat=n=${mediaInputs.length}:v=1:a=0,format=yuv420p[v]';
  //
  //     final command = [
  //       '-y', // Overwrite output file if exists
  //       inputArgs.join(' '),
  //       '-filter_complex "$filterComplex"',
  //       '-map "[v]"',
  //       '-c:v libx264', // Use H.264 codec
  //       '-preset fast', // Faster encoding
  //       '-crf 23', // Balance between quality and file size
  //       '-r $outputFrameRate', // Set output framerate
  //       '-movflags +faststart', // Enable fast start for web playback
  //       '"$outputFilePath"'
  //     ].join(' ');
  //
  //     // Execute FFmpeg command
  //     final session = await FFmpegKit.execute(command);
  //     final returnCode = await session.getReturnCode();
  //
  //     if (ReturnCode.isSuccess(returnCode)) {
  //       final outputFile = File(outputFilePath);
  //       if (await outputFile.exists()) {
  //         return outputFile;
  //       }
  //       throw Exception('Output file not found');
  //     } else {
  //       final logs = await session.getLogsAsString();
  //       final failStackTrace = await session.getFailStackTrace();
  //       throw Exception('FFmpeg_failed: ${failStackTrace ?? logs}');
  //     }
  //   } catch (err) {
  //     safePrint('Error combining media: $err');
  //     rethrow;
  //   }
  // }
  ///
  // static Future<File?> imagesToVideo({
  //   required List<File> imageFiles,
  //   required Duration eachImageDuration,
  // }) async {
  //   if (imageFiles.isEmpty) return null;
  //   try {
  //     Directory temp = await getApplicationCacheDirectory();
  //     String outputVideoPath =
  //         "${temp.path}/${DateTime.now().millisecondsSinceEpoch}.mp4";
  //
  //     final imageFilesPaths = imageFiles.map((file) => file.path).toList();
  //     final imageInputs = imageFilesPaths
  //         .map((path) => '-loop 1 -t ${eachImageDuration.inSeconds} -i $path')
  //         .join(' ');
  //
  //     // final command =
  //     //     '-y $imageInputs -filter_complex "[0:v][1:v][2:v][3:v]concat=n=${imageFiles.length}:v=1:a=0,format=yuv420p[v]" -map "[v]" $outputVideoPath';
  //     final command =
  //         '-y $imageInputs -filter_complex "concat=n=${imageFiles.length}:v=1:a=0,format=yuv420p[v]" -map "[v]" -c:v libx264 -r 30 $outputVideoPath';
  //     // final command = '';
  //     // safePrint(command);
  //
  //     final session = await FFmpegKit.execute(command).then((ss) async {
  //       final returnCode = await ss.getReturnCode();
  //
  //       if (ReturnCode.isSuccess(returnCode)) {
  //         // SUCCESS
  //       } else if (ReturnCode.isCancel(returnCode)) {
  //         // CANCEL
  //       } else {
  //         final failStackTrace = await ss.getFailStackTrace();
  //         throw Exception("Failed $failStackTrace");
  //       }
  //     });
  //     final returnCode = await session.getReturnCode();
  //     safePrint(returnCode);
  //     safePrint(
  //         "${File(outputVideoPath).existsSync() ? "EXISTS" : "NON_EXISTENT"}: $outputVideoPath");
  //     return File(outputVideoPath);
  //   } catch (err) {
  //     safePrint(err.toString());
  //     rethrow;
  //   }
  // }

  Future<List<File>> ensureAllMediasHaveSameAspectRatio({
    required List<File> inputFiles,
  }) async {
    return inputFiles;
  }

  static String _escapeFFmpegText(String text) {
    return text
        .replaceAll('\\', '\\\\') // Escape backslashes first
        .replaceAll("'", "\\'") // Escape single quotes
        .replaceAll(':', '\\:') // Escape colons
        .replaceAll('=', '\\=') // Escape equals
        .replaceAll(',', '\\,') // Escape commas
        .replaceAll('[', '\\[') // Escape square brackets
        .replaceAll(']', '\\]') // Escape square brackets
        .replaceAll('(', '\\(') // Escape parentheses
        .replaceAll(')', '\\)') // Escape parentheses
        .replaceAll('%', '\\%') // Escape percent signs
        .replaceAll('\n', ' ') // Replace newlines with spaces
        .replaceAll('\r', '') // Remove carriage returns
        .replaceAll('\t', ' '); // Replace tabs with spaces
  }

  // Helper method to get video metadata
  static Future<Map<String, int>?> _getVideoMetadata(File videoFile) async {
    try {
      // Command to get video information
      final command = '-i "${videoFile.path}"';
      final session = await FFmpegKit.execute(command);
      final logs = await session.getLogsAsString();

      // Regular expressions to find width and height
      final RegExp dimensionRegex = RegExp(
        r'Stream.*Video.* ([0-9]{2,})x([0-9]{2,})',
        caseSensitive: false,
      );

      // Try to find dimensions in the logs
      final match = dimensionRegex.firstMatch(logs);

      if (match != null && match.groupCount >= 2) {
        final width = int.tryParse(match.group(1) ?? '');
        final height = int.tryParse(match.group(2) ?? '');

        if (width != null && height != null) {
          return {
            'width': width,
            'height': height,
          };
        }
      }

      // Alternative method if the first method fails
      final widthMatch = RegExp(r'width=(\d+)').firstMatch(logs);
      final heightMatch = RegExp(r'height=(\d+)').firstMatch(logs);

      if (widthMatch != null && heightMatch != null) {
        final width = int.tryParse(widthMatch.group(1) ?? '');
        final height = int.tryParse(heightMatch.group(1) ?? '');

        if (width != null && height != null) {
          return {
            'width': width,
            'height': height,
          };
        }
      }

      // If no dimensions found
      safePrint(
          'Could not extract video dimensions from FFmpeg output:\n$logs');
      return null;
    } catch (e) {
      safePrint('Error getting video metadata: $e');
      return null;
    }
  }

  static Future<File> muteVideoSegment(File input, String outputPath) async {
    final command =
        '-y -i "${input.path}" -c:v copy -af "volume=0" -c:a aac "$outputPath"';
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    if (ReturnCode.isSuccess(returnCode)) {
      return File(outputPath);
    } else {
      throw Exception('Failed to mute video segment');
    }
  }
}

class FFmpegResult {
  final bool success;
  final File? outputFile;
  final String? error;
  final String? logs;

  FFmpegResult({
    required this.success,
    this.outputFile,
    this.error,
    this.logs,
  });
}

class VideoTextOverlayOptions {
  final String text;
  final double x; // X coordinate (0-1 relative to video width)
  final double y; // Y coordinate (0-1 relative to video height)
  final double fontSize;
  final String? fontFile; // Path to custom font file
  final String fontColor; // Hex color code with alpha
  final double startTime; // When text starts appearing
  final double? duration; // How long text stays on screen
  final String? transitionEffect; // Simple transition effect
  final String? boxColor; // Optional background box color
  final double? boxOpacity; // Background box opacity
  final double? boxPadding; // Padding around text in the box

  const VideoTextOverlayOptions({
    required this.text,
    this.x = 0.5, // Center horizontally by default
    this.y = 0.5, // Center vertically by default
    this.fontSize = 24,
    this.fontFile,
    this.fontColor = '#FFFFFFFF', // White with full opacity
    this.startTime = 0,
    this.duration,
    this.transitionEffect,
    this.boxColor,
    this.boxOpacity,
    this.boxPadding,
  });
}
