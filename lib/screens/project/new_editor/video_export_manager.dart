import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:ai_video_creator_editor/screens/project/models/text_track_model.dart';
import 'package:ai_video_creator_editor/screens/project/models/video_track_model.dart';
import 'package:ai_video_creator_editor/screens/project/models/canvas_transform.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/text_overlay_manager.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/transition_picker.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/video_editor_provider.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/video_editor_page_updated.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/canvas_configuration.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/canvas/text_rotation_manager.dart';
import 'package:ai_video_creator_editor/utils/text_auto_wrap_helper.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// ✅ UPDATED: Now rotation-aware for consistent text overlay positioning
/// The VideoExportManager now properly handles video rotation when calculating
/// gaps and mapping coordinates from preview to video space, ensuring that
/// text overlays appear in the correct positions in exported videos.
class VideoExportManager {
  /// Export unified sequential canvas composition with dual canvas system support
  /// Now uses asset-wise transitions from VideoTrackModel.transitionToNext
  static Future<String> exportSequentialCanvas(
    BuildContext context, {
    required String outputPath,
    required List<VideoTrackModel> videoTracks,
    required List<TextTrackModel> textTracks,
    required Size canvasSize,
    required CanvasRatio canvasRatio,
    required VideoEditorProvider editorProvider,
  }) async {
    final tempDir = await getTemporaryDirectory();

    try {
      // Step 1: Create dual canvas configuration for preview-to-export scaling
      final canvasConfig = CanvasConfiguration.fromContainer(
        containerSize: canvasSize,
        canvasRatio: canvasRatio,
      );

      final targetWidth = canvasConfig.exportCanvasSize.width.toInt();
      final targetHeight = canvasConfig.exportCanvasSize.height.toInt();

      print('🎬 Sequential canvas export with dual canvas system:');
      print(
          '   Preview canvas: ${canvasConfig.previewCanvasSize.width}x${canvasConfig.previewCanvasSize.height}');
      print('   Export canvas: ${targetWidth}x${targetHeight}');
      print('   Scale factor: ${canvasConfig.scaleFactor.toStringAsFixed(3)}x');

      // Step 2: Pre-process image-based tracks
      print('\n📐 Pre-processing stretched image tracks...');
      for (int i = 0; i < videoTracks.length; i++) {
        final track = videoTracks[i];
        if (track.isImageBased && track.customDuration != null) {
          print(
              '   🖼️ Track $i: Image-based with custom duration ${track.customDuration}s');

          final originalVideoDimensions =
              await _getVideoDimensions(track.processedFile.path);
          if (originalVideoDimensions == null) {
            print(
                '   ⚠️ Could not determine original video dimensions, skipping track $i');
            continue;
          }

          final originalImageDimensions =
              await _getImageDimensions(track.originalFile.path);
          final stretchedFile = await _createStretchedImageVideo(
            track.originalFile,
            track.customDuration!,
            originalVideoDimensions,
            tempDir,
            originalImageSize: originalImageDimensions,
          );

          if (stretchedFile != null) {
            videoTracks[i] = track.copyWith(processedFile: stretchedFile);
            print('   ✅ Generated stretched video: ${stretchedFile.path}');
          } else {
            print('   ⚠️ Failed to generate stretched video for track $i');
          }
        }
      }
      print('✅ Stretched image pre-processing complete\n');

      // Step 3: Process videos with canvas transforms and audio handling
      List<String> processedVideoPaths = [];
      for (int i = 0; i < videoTracks.length; i++) {
        final track = videoTracks[i];
        String videoPath = track.processedFile.path;

        final scaledPosition =
            canvasConfig.scalePositionToExport(track.canvasPosition);
        final scaledSize = canvasConfig.scaleSizeToExport(track.canvasSize);

        final transform = CanvasTransform(
          position: scaledPosition,
          size: scaledSize,
          scale: track.canvasScale,
          rotation: -track.canvasRotation * (3.14159 / 180),
          cropRect: track.canvasCropRect,
        );

        videoPath = await _applyVideoTrimming(videoPath, tempDir.path, track) ??
            videoPath;

        // Handle audio (mute or add silent track)
        final hasAudio = track.hasOriginalAudio;
        final isMuted = editorProvider.isVideoMuted(track.id);

        if (hasAudio && isMuted) {
          videoPath = await _addSilentAudioToMutedVideo(videoPath, tempDir.path,
                  expectedDuration: track.totalDuration.toDouble()) ??
              videoPath;
        } else if (!hasAudio && !track.isImageBased) {
          videoPath = await _addSilentAudio(videoPath, tempDir.path,
                  expectedDuration: track.totalDuration.toDouble()) ??
              videoPath;
        }

        final processedPath = await _processVideoForSequentialCanvas(
          videoPath,
          transform,
          canvasConfig.exportCanvasSize,
          '${tempDir.path}/processed_video_$i.mp4',
          filter: track.filter,
          track: track,
        );

        String finalPath = processedPath ?? videoPath;
        if (processedPath != null && track.filter != 'none') {
          finalPath = await _applyFilterToProcessedVideo(
                processedPath,
                '${tempDir.path}/filtered_video_$i.mp4',
                track.filter,
              ) ??
              processedPath;
        }

        processedVideoPaths.add(finalPath);
        print('✅ Video $i processed successfully: $finalPath');
      }

      print('\n🔊 Validating audio streams for all videos...');
      for (int i = 0; i < processedVideoPaths.length; i++) {
        final hasAudio = await _hasAudioStream(processedVideoPaths[i]);
        if (!hasAudio) {
          print('   ⚠️ Video $i missing audio - adding silent audio');
          final tempDir = await getTemporaryDirectory();
          final videoDuration = await _getVideoDuration(processedVideoPaths[i]);
          final fixedPath = await _addSilentAudio(
            processedVideoPaths[i],
            tempDir.path,
            expectedDuration: videoDuration,
          );
          if (fixedPath != null) {
            processedVideoPaths[i] = fixedPath;
            print('   ✅ Silent audio added to video $i');
          }
        } else {
          print('   ✓ Video $i has audio stream');
        }
      }
      print('✅ Audio validation complete\n');

      // Step 4: Apply start and end transitions
      final updatedPaths = await _applyStartEndTransitions(
        processedVideoPaths,
        videoTracks,
        tempDir.path,
      );

      // 🔧 FIX: Re-probe REAL durations after start/end transitions
      for (int i = 0; i < updatedPaths.length; i++) {
        final realDuration =
            await _getVideoDuration(updatedPaths[i]); // seconds (double)
        videoTracks[i] = videoTracks[i].copyWith(
          totalDuration: (realDuration * 1000).toInt(),

          // REQUIRED: Keep trim end synced to real duration
          videoTrimEnd: realDuration,
        );

        print("🔧 FIXED: Updated track[$i] duration = $realDuration seconds");
      }

// then use updatedPaths everywhere below
      final String combinedVideoPath =
          '${tempDir.path}/combined_sequential.mp4';

      await _combineVideosWithAssetWiseTransitions(
        updatedPaths,
        combinedVideoPath,
        videoTracks: videoTracks,
      );

      // Step 6: Add text overlays
      String currentPath = combinedVideoPath;
      if (textTracks.isNotEmpty) {
        final textOverlayPath = '${tempDir.path}/with_canvas_text_overlays.mp4';
        currentPath = await _addCanvasTextOverlaysToSequentialVideo(
              combinedVideoPath,
              textOverlayPath,
              textTracks,
              canvasConfig.exportCanvasSize,
              videoTracks,
              canvasConfig,
            ) ??
            combinedVideoPath;
      }

      // Step 7: Merge audio tracks if needed
      final mergedAudioPath = await editorProvider.mergeMultipleAudioToVideo(
        context,
        combinedVideoPath: currentPath,
      );
      if (mergedAudioPath != null) currentPath = mergedAudioPath;

      // Step 8: Copy final output
      await File(currentPath).copy(outputPath);
      print('Sequential canvas export completed: $outputPath');
      return outputPath;
    } catch (e) {
      print('Sequential canvas export error: $e');
      rethrow;
    }
  }

// Add this helper method to create a black video
  static Future<String?> _createBlackVideo(
    String tempDirPath,
    double duration,
    Size videoSize,
  ) async {
    final outputPath =
        '$tempDirPath/black_screen_${DateTime.now().millisecondsSinceEpoch}.mp4';

    try {
      final width = videoSize.width.toInt();
      final height = videoSize.height.toInt();

      // Ensure even dimensions
      final evenWidth = width % 2 == 0 ? width : width - 1;
      final evenHeight = height % 2 == 0 ? height : height - 1;

      print('🎬 Creating black video:');
      print('   Duration: ${duration}s');
      print('   Dimensions: ${evenWidth}x${evenHeight}');

      // Create black video with silent audio
      final command =
          '-f lavfi -i color=c=black:s=${evenWidth}x${evenHeight}:r=30:d=$duration '
          '-f lavfi -i anullsrc=channel_layout=stereo:sample_rate=48000 '
          '-c:v libx264 -preset ultrafast -crf 23 -pix_fmt yuv420p '
          '-c:a aac -ar 48000 -ac 2 -b:a 128k '
          '-shortest -y "$outputPath"';

      print('   Command: $command');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final outputFile = File(outputPath);
        if (await outputFile.exists() && await outputFile.length() > 0) {
          print('   ✅ Black video created: ${await outputFile.length()} bytes');
          return outputPath;
        }
      }

      print('   ❌ Failed to create black video');
      return null;
    } catch (e) {
      print('   ❌ Error creating black video: $e');
      return null;
    }
  }

// Modified _applyStartEndTransitions method
  static Future<List<String>> _applyStartEndTransitions(
    List<String> processedVideoPaths,
    List<VideoTrackModel> videoTracks,
    String tempDir,
  ) async {
    List<String> updatedPaths = List.from(processedVideoPaths);

    // Get video dimensions from first video
    final videoDimensions = await _getVideoDimensions(updatedPaths[0]);
    if (videoDimensions == null) {
      print(
          '⚠️ Could not determine video dimensions for black screen creation');
      return updatedPaths;
    }

    // --- START Transition ---
    final firstTrack = videoTracks.first;
    if (firstTrack.transitionFromStart != null &&
        firstTrack.transitionFromStart != TransitionType.none) {
      final transitionDuration = firstTrack.transitionFromStartDuration ?? 1.0;

      print(
          '🎬 Applying START transition: ${firstTrack.transitionFromStart!.name} (${transitionDuration}s)');

      try {
        // Create black screen video
        final blackVideoPath = await _createBlackVideo(
          tempDir,
          transitionDuration,
          videoDimensions,
        );

        if (blackVideoPath != null) {
          // Apply transition between black screen and first video
          final transitionedPath =
              '$tempDir/start_transition_${DateTime.now().millisecondsSinceEpoch}.mp4';

          final result = await _applyXFadeBetweenTwo(
            blackVideoPath,
            updatedPaths[0],
            transitionedPath,
            firstTrack.transitionFromStart!,
            transitionDuration,
            transitionDuration, // Black video duration
          );

          if (result != null) {
            updatedPaths[0] = result;
            print('   ✅ START transition applied successfully');

            // Clean up black video
            try {
              await File(blackVideoPath).delete();
            } catch (e) {
              // Ignore cleanup errors
            }
          } else {
            print('   ⚠️ START transition failed, keeping original video');
          }
        } else {
          print(
              '   ⚠️ Failed to create black screen, skipping START transition');
        }
      } catch (e) {
        print('   ❌ Error applying START transition: $e');
      }
    }

    // --- END Transition ---
    final lastTrack = videoTracks.last;
    if (lastTrack.transitionToEnd != null &&
        lastTrack.transitionToEnd != TransitionType.none) {
      final transitionDuration = lastTrack.transitionToEndDuration ?? 1.0;

      print(
          '🎬 Applying END transition: ${lastTrack.transitionToEnd!.name} (${transitionDuration}s)');

      try {
        // FIX: Create black screen with DOUBLE the transition duration
        // This ensures the transition completes fully (video fades out completely to black)
        final blackScreenDuration = transitionDuration * 1.0;

        final blackVideoPath = await _createBlackVideo(
          tempDir,
          blackScreenDuration,
          videoDimensions,
        );

        if (blackVideoPath != null) {
          // Get duration of last video
          final lastVideoDuration = await _getVideoDuration(updatedPaths.last);

          // Apply transition between last video and black screen
          final transitionedPath =
              '$tempDir/end_transition_${DateTime.now().millisecondsSinceEpoch}.mp4';

          // FIX: Use the LAST VIDEO's duration for offset (not the black screen duration)
          // This ensures the transition starts at the right time
          final result = await _applyXFadeBetweenTwo(
            updatedPaths.last,
            blackVideoPath,
            transitionedPath,
            lastTrack.transitionToEnd!,
            transitionDuration,
            lastVideoDuration, // ← Correct: use last video's duration for offset
          );

          if (result != null) {
            updatedPaths[updatedPaths.length - 1] = result;
            print('   ✅ END transition applied successfully');
            print(
                '   📊 Final video includes ${transitionDuration}s fade to black at end');

            // Clean up black video
            try {
              await File(blackVideoPath).delete();
            } catch (e) {
              // Ignore cleanup errors
            }
          } else {
            print('   ⚠️ END transition failed, keeping original video');
          }
        } else {
          print('   ⚠️ Failed to create black screen, skipping END transition');
        }
      } catch (e) {
        print('   ❌ Error applying END transition: $e');
      }
    }

    print("✅ Start/End transitions processing complete.\n");
    return updatedPaths;
  }

  /// Get video duration in seconds using FFprobe
  static Future<double> _getVideoDuration(String videoPath) async {
    try {
      final session = await FFprobeKit.execute(
          '-v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$videoPath"');
      final output = await session.getOutput();

      if (output != null && output.trim().isNotEmpty) {
        return double.tryParse(output.trim()) ?? 0.0;
      }
      return 0.0;
    } catch (e) {
      print('   ⚠️ Error getting video duration: $e');
      return 0.0;
    }
  }

  static String cleanPath(String path) {
    return path.startsWith('file://') ? path.replaceFirst('file://', '') : path;
  }

  // static Future<void> _adjustSpeed(
  //   String inputPath,
  //   String outputPath,
  //   double speed,
  // ) async {
  //   final tempo = 1 / speed;
  //   final command =
  //       '-i $inputPath -filter_complex "[0:v]setpts=${tempo}*PTS[v];[0:a]atempo=$speed[a]" -map "[v]" -map "[a]" $outputPath';
  //   await FFmpegKit.execute(command);
  // }

  static List<String> _exportLogs = []; // Store export logs for debugging

  // Method to get export logs for debugging
  static List<String> getExportLogs() => List.from(_exportLogs);

  // Method to show export logs in a dialog
  static void showExportLogs(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Export Debug Logs'),
        content: Container(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _exportLogs
                  .map((log) => Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          log,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  static Future<void> _createTextImage({
    required String text,
    required String fontFamily,
    required double fontSize,
    required Color color,
    required double rotation,
    required double maxWidth,
    required double maxHeight,
    required String outputPath,
  }) async {
    // Create text style with consistent line height
    final textStyle = TextStyle(
      fontSize: fontSize,
      fontFamily: fontFamily,
      color: color,
      height: 1.0, // Use consistent line height to match preview
    );

    // Wrap text if needed
    List<String> lines = TextAutoWrapHelper.wrapTextToFit(
      text,
      maxWidth,
      maxHeight,
      textStyle,
    );

    // Create text painter with consistent line height
    final textPainter = TextPainter(
      text: TextSpan(
        text: lines.join('\n'),
        style: textStyle,
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
      textHeightBehavior: TextHeightBehavior(
        leadingDistribution: TextLeadingDistribution.even,
      ),
    );

    textPainter.layout(maxWidth: maxWidth);

    // Calculate canvas size (with padding for rotation)
    double textWidth = textPainter.width;
    double textHeight = textPainter.height;

    // If rotated, calculate bounding box from center reference point
    double canvasWidth, canvasHeight;
    if (rotation != 0) {
      final angleRad = rotation * math.pi / 180;
      final cos = math.cos(angleRad).abs();
      final sin = math.sin(angleRad).abs();

      // Calculate the bounding box dimensions when rotating around the center
      // This ensures the rotated text fits within the canvas when rotated around its center
      canvasWidth = textWidth * cos + textHeight * sin;
      canvasHeight = textWidth * sin + textHeight * cos;

      // Add extra padding to ensure rotated text doesn't get clipped
      // This accounts for the fact that rotation around center can extend beyond original bounds
      canvasWidth += 8; // Extra padding for center-based rotation
      canvasHeight += 8;
    } else {
      canvasWidth = textWidth;
      canvasHeight = textHeight;
    }

    // Add small padding
    canvasWidth += 4;
    canvasHeight += 4;

    // Create picture recorder
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // Apply rotation if needed
    if (rotation != 0) {
      // IMPROVED APPROACH: Paint text at center, rotate around center, then compensate for top-left positioning

      // Calculate the center of the canvas
      final centerX = canvasWidth / 2;
      final centerY = canvasHeight / 2;

      // Calculate the center of the original text (before rotation)
      final textCenterX = textWidth / 2;
      final textCenterY = textHeight / 2;

      // Apply rotation transformation around the center of the canvas
      canvas.translate(centerX, centerY);
      canvas.rotate(rotation * math.pi / 180);
      canvas.translate(-centerX, -centerY);

      // Paint text at the center of the canvas
      // This ensures the text is centered within the rotated bounding box
      final textOffset = Offset(
        centerX - textCenterX,
        centerY - textCenterY,
      );
      textPainter.paint(canvas, textOffset);
    } else {
      // For non-rotated text, paint at top-left with small padding
      canvas.translate(2, 2);
      textPainter.paint(canvas, Offset.zero);
    }

    // Convert to image
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      canvasWidth.ceil(),
      canvasHeight.ceil(),
    );

    // Convert to PNG
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    // Save to file
    final file = File(outputPath);
    await file.writeAsBytes(pngBytes);

    // Dispose all UI objects to free memory
    try {
      // Dispose TextPainter
      textPainter.dispose();

      // Dispose Picture
      picture.dispose();

      // Dispose ui.Image
      image.dispose();

      _exportLogs
          .add('Successfully disposed UI objects for text image: $outputPath');
    } catch (e) {
      _exportLogs.add('Warning: Failed to dispose some UI objects: $e');
    }
  }

  /// Apply filter to already-processed video (separate pass after canvas processing)
  /// This mimics the old global filter approach: simple filter application without complex encoding
  static Future<String?> _applyFilterToProcessedVideo(
    String inputPath,
    String outputPath,
    String filter,
  ) async {
    if (filter == 'none' || !FilterManager.filters.containsKey(filter)) {
      return inputPath; // No filter to apply, return original
    }

    print('🎨 Applying filter to processed video: $filter');
    print('   Input: $inputPath');
    print('   Output: $outputPath');

    try {
      final filterArgs = FilterManager.filters[filter]!;
      if (filterArgs.length < 2 || filterArgs[0] != '-vf') {
        print('   ⚠️  Invalid filter format, skipping');
        return inputPath;
      }

      // Simple FFmpeg command: input → filter → output (audio copy)
      // Mimics old global filter approach - no profile/level/preset constraints
      final command = [
        '-i', inputPath,
        ...filterArgs, // ['-vf', 'curves=vintage']
        '-c:a', 'copy', // Copy audio without re-encoding
        '-y',
        outputPath
      ];

      final session = await FFmpegKit.execute(command.join(' '));
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        print('   ✅ Filter applied successfully: $outputPath');
        return outputPath;
      } else {
        print('   ❌ Filter application failed, using original video');
        final output = await session.getOutput();
        if (output != null && output.isNotEmpty) {
          print('   Error: $output');
        }
        return inputPath; // Fallback to original
      }
    } catch (e) {
      print('   ❌ Exception applying filter: $e');
      return inputPath; // Fallback to original
    }
  }

  /// Process video for sequential canvas with enhanced transformations and filters
  static Future<String?> _processVideoForSequentialCanvas(
    String videoPath,
    CanvasTransform transform,
    Size targetCanvasSize,
    String outputPath, {
    String filter = 'none',
    VideoTrackModel? track,
  }) async {
    print('🎬 Processing video for sequential canvas: $videoPath');
    print(
        '   Target canvas size: ${targetCanvasSize.width}x${targetCanvasSize.height}');
    print('   Output path: $outputPath');

    try {
      // Validate input file exists
      final inputFile = File(videoPath);
      if (!await inputFile.exists()) {
        print('❌ Input video file does not exist: $videoPath');
        return null;
      }

      final targetWidth = targetCanvasSize.width.toInt();
      final targetHeight = targetCanvasSize.height.toInt();

      // Ensure even dimensions for H.264 compatibility
      final evenWidth = targetWidth % 2 == 0 ? targetWidth : targetWidth - 1;
      final evenHeight =
          targetHeight % 2 == 0 ? targetHeight : targetHeight - 1;

      print(
          '   📐 Dimensions: ${targetWidth}x${targetHeight} → ${evenWidth}x${evenHeight}');

      // All videos are guaranteed to have audio after preprocessing
      print(
          '   🎵 Processing video with existing audio (guaranteed by preprocessing)');

      List<String> ffmpegArgs = ['-i', videoPath];

      // Build video filters
      List<String> filters = [];

      // Apply crop if enabled
      if (track?.canvasCropModel?.enabled == true &&
          track?.canvasCropModel != null) {
        final cropFilter = track!.canvasCropModel!.toFFmpegFilter();
        if (cropFilter.isNotEmpty) {
          filters.add(cropFilter);
          print('   ✂️  Applied crop: $cropFilter');
        }
      }

      // NOTE: Filters are now applied AFTER canvas processing as a separate pass
      // This avoids complex filter chain issues during canvas transformation

      // Calculate target dimensions considering rotation
      int finalWidth = evenWidth;
      int finalHeight = evenHeight;

      if (transform.rotation != 0) {
        final degrees = (transform.rotation * 180 / math.pi).round();
        // For 90° and 270° rotations, dimensions swap
        if (degrees == 90 || degrees == 270) {
          finalWidth = evenHeight; // Swap dimensions
          finalHeight = evenWidth;
          print(
              '   📐 Rotation $degrees° detected - swapping target dimensions: ${evenWidth}x${evenHeight} → ${finalWidth}x${finalHeight}');
        }
      }

      // Flutter-correct transform pipeline: Scale → Rotate → Crop → Position
      final assetX = transform.position.dx;
      final assetY = transform.position.dy;
      final assetWidth = transform.size.width;
      final assetHeight = transform.size.height;
      final assetScale = transform.scale;
      final assetRotation = transform.rotation;

      print(
          '   🎯 Flutter-correct transform pipeline (Scale → Rotate → Crop → Position):');
      print(
          '     Asset position: (${assetX.toStringAsFixed(1)}, ${assetY.toStringAsFixed(1)})');
      print(
          '     Asset size: ${assetWidth.toStringAsFixed(1)}x${assetHeight.toStringAsFixed(1)}');
      print('     Asset scale: ${assetScale.toStringAsFixed(3)}');
      print(
          '     Asset rotation: ${(assetRotation * 180 / math.pi).toStringAsFixed(1)}°');
      print('     Canvas: ${evenWidth}x${evenHeight}');

      if (assetWidth <= 0 || assetHeight <= 0) {
        // Invalid asset size - create black placeholder
        filters.add('scale=${evenWidth}:${evenHeight}');
        filters.add('geq=0:128:128'); // Create black video
        filters.add('format=yuv420p');
        print('   ❌ Invalid asset size - using black placeholder');
      } else {
        // Step 1: Scale to base asset size
        final baseScaledWidth = assetWidth.toInt();
        final baseScaledHeight = assetHeight.toInt();

        // Ensure reasonable dimensions
        final safeBaseWidth =
            math.max(2, math.min(baseScaledWidth, evenWidth * 5));
        final safeBaseHeight =
            math.max(2, math.min(baseScaledHeight, evenHeight * 5));

        filters.add('scale=${safeBaseWidth}:${safeBaseHeight}');
        print(
            '   📏 Step 1 - Scale to base: ${safeBaseWidth}x${safeBaseHeight}');

        // Step 2: Apply scale transform
        var currentWidth = safeBaseWidth.toDouble();
        var currentHeight = safeBaseHeight.toDouble();

        if (assetScale != 1.0) {
          final scaledWidth = (currentWidth * assetScale).toInt();
          final scaledHeight = (currentHeight * assetScale).toInt();

          // Limit max scale dimensions
          final maxScaledWidth = math.min(scaledWidth, evenWidth * 5);
          final maxScaledHeight = math.min(scaledHeight, evenHeight * 5);

          if (maxScaledWidth > 0 && maxScaledHeight > 0) {
            filters.add('scale=${maxScaledWidth}:${maxScaledHeight}');
            currentWidth = maxScaledWidth.toDouble();
            currentHeight = maxScaledHeight.toDouble();
            print(
                '   🔍 Step 2 - Apply scale: ${maxScaledWidth}x${maxScaledHeight} (${assetScale.toStringAsFixed(3)}x)');
          }
        }

        // Step 3: Apply rotation (BEFORE position calculations)
        if (assetRotation != 0) {
          final degrees = (assetRotation * 180 / math.pi).round();
          String rotationFilter = '';

          if (degrees == 90 || degrees == -270) {
            rotationFilter = 'transpose=1';
            // Swap dimensions after 90° rotation
            final temp = currentWidth;
            currentWidth = currentHeight;
            currentHeight = temp;
          } else if (degrees == 180 || degrees == -180) {
            rotationFilter = 'transpose=2,transpose=2';
            // Dimensions stay the same for 180°
          } else if (degrees == 270 || degrees == -90) {
            rotationFilter = 'transpose=2';
            // Swap dimensions after 270° rotation
            final temp = currentWidth;
            currentWidth = currentHeight;
            currentHeight = temp;
          } else {
            rotationFilter = 'rotate=${assetRotation}:fillcolor=black';
            // For arbitrary rotations, dimensions are complex - use bounding box approach
            final radians = assetRotation.abs();
            final cos = math.cos(radians);
            final sin = math.sin(radians);
            final newWidth = currentWidth * cos + currentHeight * sin;
            final newHeight = currentWidth * sin + currentHeight * cos;
            currentWidth = newWidth;
            currentHeight = newHeight;
          }

          filters.add(rotationFilter);
          print(
              '   🔄 Step 3 - Apply rotation: ${degrees}° → ${currentWidth.toStringAsFixed(1)}x${currentHeight.toStringAsFixed(1)}');
        }

        // Step 4: Calculate position for the rotated asset with center-based scaling
        final originalCenterX = assetX + (safeBaseWidth / 2);
        final originalCenterY = assetY + (safeBaseHeight / 2);

        // Calculate final position accounting for center-based transforms
        final finalAssetX = originalCenterX - (currentWidth / 2);
        final finalAssetY = originalCenterY - (currentHeight / 2);

        print('   📐 Step 4 - Position calculation:');
        print(
            '     Original center: (${originalCenterX.toStringAsFixed(1)}, ${originalCenterY.toStringAsFixed(1)})');
        print(
            '     Post-rotation size: ${currentWidth.toStringAsFixed(1)}x${currentHeight.toStringAsFixed(1)}');
        print(
            '     Final position: (${finalAssetX.toStringAsFixed(1)}, ${finalAssetY.toStringAsFixed(1)})');

        // Step 5: Calculate visibility and crop (mimic ClipRect on rotated asset)
        final assetLeft = finalAssetX;
        final assetTop = finalAssetY;
        final assetRight = finalAssetX + currentWidth;
        final assetBottom = finalAssetY + currentHeight;

        // Calculate visible area (intersection with canvas)
        final visibleLeft = math.max(0.0, assetLeft);
        final visibleTop = math.max(0.0, assetTop);
        final visibleRight = math.min(evenWidth.toDouble(), assetRight);
        final visibleBottom = math.min(evenHeight.toDouble(), assetBottom);

        final visibleWidth = math.max(0.0, visibleRight - visibleLeft);
        final visibleHeight = math.max(0.0, visibleBottom - visibleTop);

        print('   🔍 Step 5 - Visibility (post-rotation):');
        print(
            '     Rotated asset: (${assetLeft.toStringAsFixed(1)}, ${assetTop.toStringAsFixed(1)}) to (${assetRight.toStringAsFixed(1)}, ${assetBottom.toStringAsFixed(1)})');
        print('     Canvas: (0, 0) to (${evenWidth}, ${evenHeight})');
        print(
            '     Visible: (${visibleLeft.toStringAsFixed(1)}, ${visibleTop.toStringAsFixed(1)}) to (${visibleRight.toStringAsFixed(1)}, ${visibleBottom.toStringAsFixed(1)})');
        print(
            '     Visible size: ${visibleWidth.toStringAsFixed(1)}x${visibleHeight.toStringAsFixed(1)}');

        if (visibleWidth <= 0 || visibleHeight <= 0) {
          // Asset completely outside canvas - create black placeholder
          filters.add('scale=${evenWidth}:${evenHeight}');
          filters.add('geq=0:128:128');
          filters.add('format=yuv420p');
          print(
              '   ⚠️  Rotated asset completely outside canvas - black placeholder');
        } else {
          // Step 6: Crop the rotated asset to canvas bounds
          if (assetLeft < 0 ||
              assetTop < 0 ||
              assetRight > evenWidth ||
              assetBottom > evenHeight) {
            // Rotated asset extends beyond canvas bounds - crop it

            // Calculate crop parameters relative to the rotated asset
            final cropLeft = math.max(0.0, -finalAssetX);
            final cropTop = math.max(0.0, -finalAssetY);
            final cropWidth = visibleWidth;
            final cropHeight = visibleHeight;

            print('   ✂️  Step 6 - Crop rotated asset:');
            print(
                '     Crop offset: (${cropLeft.toStringAsFixed(1)}, ${cropTop.toStringAsFixed(1)})');
            print(
                '     Crop size: ${cropWidth.toStringAsFixed(1)}x${cropHeight.toStringAsFixed(1)}');

            // Apply crop with safe integer values
            final safeCropLeft = math.max(0, cropLeft.toInt());
            final safeCropTop = math.max(0, cropTop.toInt());
            final safeCropWidth = math.max(1, cropWidth.toInt());
            final safeCropHeight = math.max(1, cropHeight.toInt());

            filters.add(
                'crop=${safeCropWidth}:${safeCropHeight}:${safeCropLeft}:${safeCropTop}');
            print(
                '   ✂️  Applied crop: ${safeCropWidth}x${safeCropHeight} at (${safeCropLeft}, ${safeCropTop})');
          }

          // Step 7: Position the final (rotated + cropped) asset on canvas
          final finalX = math.max(0.0, finalAssetX).toInt();
          final finalY = math.max(0.0, finalAssetY).toInt();

          filters.add(
              'pad=${evenWidth}:${evenHeight}:${finalX}:${finalY}:color=black');
          print('   🎯 Step 7 - Final positioning: (${finalX}, ${finalY})');
        }
      }

      // Note: Rotation is now integrated into the main transform pipeline above

      // Note: Scale transformation is now handled in the main positioning pipeline above
      // No separate scale processing needed - prevents FFmpeg crashes from oversized scaling

      // Note: Visual filters will be applied to final combined video, not individual assets

      // Apply opacity if needed
      if (transform.opacity != 1.0) {
        filters
            .add('format=yuva420p,colorchannelmixer=aa=${transform.opacity}');
        print('   🌫️  Applied opacity: ${transform.opacity}');
      }

      if (filters.isNotEmpty) {
        ffmpegArgs.addAll(['-vf', filters.join(',')]);
      }

      // Normalize audio to 48kHz stereo to ensure consistency across all videos
      // This prevents timestamp discontinuities when videos have different sample rates
      ffmpegArgs.addAll([
        '-map',
        '0:v:0',
        '-map',
        '0:a:0',
        '-c:a',
        'aac',
        '-ar',
        '48000',
        '-ac',
        '2',
        '-b:a',
        '128k'
      ]);

      ffmpegArgs.addAll([
        '-c:v', 'libx264',
        '-preset', 'medium',
        '-crf', '23',
        '-r', '30',
        '-movflags', '+faststart', // Optimize for streaming
        '-y', // Overwrite output file
        outputPath
      ]);

      final command = ffmpegArgs.join(' ');
      print('🔧 Enhanced sequential canvas processing command:');
      print('   $command');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      // Get detailed error information
      final output = await session.getOutput();
      final allLogs = await session.getAllLogs();

      if (ReturnCode.isSuccess(returnCode)) {
        print('✅ Successfully processed video: $outputPath');

        // Verify output file was created and has reasonable size
        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          final fileSize = await outputFile.length();
          print('   📄 Output file size: ${fileSize} bytes');
          return outputPath;
        } else {
          print('❌ Output file was not created despite success return code');
          return null;
        }
      } else {
        print('❌ FFmpeg failed for enhanced sequential canvas processing');
        print('   Return code: $returnCode');
        if (output != null && output.isNotEmpty) {
          print('   FFmpeg output: $output');
        }
        if (allLogs.isNotEmpty) {
          print('   FFmpeg logs (last 5):');
          final lastLogs = allLogs.length > 5
              ? allLogs.sublist(allLogs.length - 5)
              : allLogs;
          for (final log in lastLogs) {
            print('     Level ${log.getLevel()}: ${log.getMessage()}');
          }
        }

        // Try fallback processing
        print('🔄 Attempting fallback processing...');
        return await _processVideoForSequentialCanvasFallback(
          videoPath,
          transform,
          targetCanvasSize,
          outputPath,
          filter: filter,
        );
      }
    } catch (e) {
      print('❌ Exception in enhanced sequential canvas processing: $e');
      print('🔄 Attempting fallback processing...');
      return await _processVideoForSequentialCanvasFallback(
        videoPath,
        transform,
        targetCanvasSize,
        outputPath,
        filter: filter,
      );
    }
  }

  /// Fallback processing for videos that fail enhanced processing
  static Future<String?> _processVideoForSequentialCanvasFallback(
    String videoPath,
    CanvasTransform transform,
    Size targetCanvasSize,
    String outputPath, {
    String filter = 'none',
  }) async {
    print('🆘 Fallback processing for: $videoPath');

    try {
      final targetWidth = targetCanvasSize.width.toInt();
      final targetHeight = targetCanvasSize.height.toInt();

      // Ensure even dimensions
      final evenWidth = targetWidth % 2 == 0 ? targetWidth : targetWidth - 1;
      final evenHeight =
          targetHeight % 2 == 0 ? targetHeight : targetHeight - 1;

      // Simple processing - just scale and pad
      List<String> ffmpegArgs = ['-i', videoPath];

      // Build basic filter chain
      String filterChain =
          'scale=$evenWidth:$evenHeight:force_original_aspect_ratio=decrease,';
      filterChain +=
          'pad=$evenWidth:$evenHeight:(ow-iw)/2:(oh-ih)/2:color=black';

      // NOTE: Filters are now applied AFTER canvas processing as a separate pass

      ffmpegArgs.addAll(['-vf', filterChain]);

      // Simple audio handling - copy if exists, ignore if not
      ffmpegArgs.addAll([
        '-map',
        '0:v:0',
        '-map',
        '0:a?',
        '-c:v',
        'libx264',
        '-c:a',
        'copy',
        '-preset',
        'fast',
        '-crf',
        '23',
        '-y',
        outputPath
      ]);

      final command = ffmpegArgs.join(' ');
      print('🔧 Fallback command: $command');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        print('✅ Fallback processing succeeded: $outputPath');
        return outputPath;
      } else {
        print('❌ Fallback processing also failed');
        final output = await session.getOutput();
        if (output != null && output.isNotEmpty) {
          print('   Fallback error: $output');
        }
        return null;
      }
    } catch (e) {
      print('❌ Exception in fallback processing: $e');
      return null;
    }
  }

  /// Concatenate two videos with a hard cut (no transition)
  static Future<String?> _concatTwoVideosHardCut(
    String video1Path,
    String video2Path,
    String outputPath,
  ) async {
    print('📎 Concatenating two videos (hard cut):');
    print('   Video 1: $video1Path');
    print('   Video 2: $video2Path');
    print('   Output: $outputPath');

    try {
      final tempDir = await getTemporaryDirectory();
      final concatFile = File(
          '${tempDir.path}/concat_temp_${DateTime.now().millisecondsSinceEpoch}.txt');

      // Create concat file
      final concatContent =
          "file '${video1Path.replaceAll("'", "\\'")}'\nfile '${video2Path.replaceAll("'", "\\'")}'";
      await concatFile.writeAsString(concatContent);

      // Concat with re-encoding for compatibility
      final command = '-y -f concat -safe 0 -i "${concatFile.path}" '
          '-c:v libx264 -preset ultrafast -c:a aac -ar 48000 -ac 2 '
          '-b:a 128k -b:v 800k "$outputPath"';

      print('   FFmpeg command: $command');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      // Clean up temp file
      try {
        await concatFile.delete();
      } catch (e) {
        // Ignore cleanup errors
      }

      if (ReturnCode.isSuccess(returnCode)) {
        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          final fileSize = await outputFile.length();
          print(
              '   ✅ Hard cut concat successful: $outputPath (${fileSize} bytes)');
          return outputPath;
        }
      }

      print('   ❌ Hard cut concat failed');
      return null;
    } catch (e) {
      print('   ❌ Exception in hard cut concat: $e');
      return null;
    }
  }

  static Future<bool> _hasAudioStream(String videoPath) async {
    try {
      final session = await FFprobeKit.execute(
          '-v error -select_streams a:0 -show_entries stream=codec_type -of csv=p=0 "$videoPath"');
      final output = await session.getOutput();
      return output?.trim() == 'audio';
    } catch (e) {
      print('❌ Error checking audio stream: $e');
      return false;
    }
  }

  /// Apply xfade transition between two videos
  static Future<String?> _applyXFadeBetweenTwo(
    String video1Path,
    String video2Path,
    String outputPath,
    TransitionType transition,
    double duration,
    double video1Duration,
  ) async {
    print('🎬 Applying xfade transition between two videos:');
    print('   Video 1: $video1Path (duration: ${video1Duration}s)');
    print('   Video 2: $video2Path');
    print('   Transition: ${transition.name} (${duration}s)');
    print('   Output: $outputPath');

    try {
      // CRITICAL FIX: Verify both videos have audio before attempting crossfade
      final video1HasAudio = await _hasAudioStream(video1Path);
      final video2HasAudio = await _hasAudioStream(video2Path);

      print('   Video 1 has audio: $video1HasAudio');
      print('   Video 2 has audio: $video2HasAudio');

      // If either video lacks audio, add silent audio first
      String processedVideo1 = video1Path;
      String processedVideo2 = video2Path;
      final tempDir = await getTemporaryDirectory();

      if (!video1HasAudio) {
        print('   ⚠️ Video 1 missing audio - adding silent audio');
        final tempPath =
            '${tempDir.path}/silent_v1_${DateTime.now().millisecondsSinceEpoch}.mp4';
        processedVideo1 = await _addSilentAudio(
              video1Path,
              tempDir.path,
              expectedDuration: video1Duration,
            ) ??
            video1Path;
      }

      if (!video2HasAudio) {
        print('   ⚠️ Video 2 missing audio - adding silent audio');
        final video2Duration = await _getVideoDuration(video2Path);
        processedVideo2 = await _addSilentAudio(
              video2Path,
              tempDir.path,
              expectedDuration: video2Duration,
            ) ??
            video2Path;
      }

      final xfadeName = _getXFadeTransitionName(transition);
      final offset = video1Duration - duration;

      print(
          '   Calculated offset: ${offset}s (${video1Duration}s - ${duration}s)');

      // Build filter complex with validated audio streams
      final videoFilter =
          '[0:v][1:v]xfade=transition=$xfadeName:duration=$duration:offset=$offset[v]';
      final audioFilter = '[0:a][1:a]acrossfade=d=$duration[a]';
      final filterComplex = '$videoFilter; $audioFilter';

      final command = [
        '-i',
        '"$processedVideo1"',
        '-i',
        '"$processedVideo2"',
        '-filter_complex',
        '"$filterComplex"',
        '-map',
        '[v]',
        '-map',
        '[a]',
        '-c:v',
        'libx264',
        '-preset',
        'ultrafast',
        '-profile:v',
        'baseline',
        '-level',
        '3.1',
        '-pix_fmt',
        'yuv420p',
        '-c:a',
        'aac',
        '-ar',
        '48000',
        '-ac',
        '2',
        '-b:v',
        '800k',
        '-b:a',
        '128k',
        '-y',
        '"$outputPath"'
      ].join(' ');

      print('   FFmpeg command: $command');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      // Cleanup temporary files
      if (processedVideo1 != video1Path) {
        try {
          await File(processedVideo1).delete();
        } catch (_) {}
      }
      if (processedVideo2 != video2Path) {
        try {
          await File(processedVideo2).delete();
        } catch (_) {}
      }

      if (ReturnCode.isSuccess(returnCode)) {
        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          final fileSize = await outputFile.length();
          print(
              '   ✅ XFade transition successful: $outputPath (${fileSize} bytes)');
          return outputPath;
        }
      }

      print('   ❌ XFade transition failed');
      final output = await session.getOutput();
      if (output != null && output.isNotEmpty) {
        print('   Error: $output');
      }
      return null;
    } catch (e) {
      print('   ❌ Exception in xfade transition: $e');
      return null;
    }
  }

  /// Combine videos progressively with selective transitions
  /// Only applies xfade where transition is specified, uses hard cut otherwise
  static Future<void> _combineWithProgressiveMerging(
    List<String> videoPaths,
    String outputPath,
    List<TransitionType?> transitions,
    List<double> transitionDurations,
    List<VideoTrackModel> videoTracks,
  ) async {
    print('🔄 Progressive merging with selective transitions...');
    print('   Total videos: ${videoPaths.length}');

    try {
      final tempDir = await getTemporaryDirectory();
      String currentVideo = videoPaths[0];

      // CRITICAL FIX: Probe actual duration instead of using track data
      double currentVideoDuration = await _getVideoDuration(currentVideo);

      print('📊 Cumulative duration tracking:');
      print('   Initial (Video 0): ${currentVideoDuration}s');

      for (int i = 1; i < videoPaths.length; i++) {
        final nextVideo = videoPaths[i];
        final transition = transitions[i - 1];
        final duration = transitionDurations[i - 1];

        // CRITICAL FIX: Probe next video's actual duration
        final nextVideoDuration = await _getVideoDuration(nextVideo);

        final tempOutput =
            '${tempDir.path}/progressive_${i}_${DateTime.now().millisecondsSinceEpoch}.mp4';

        print('   Step $i: Merging videos ${i - 1}→$i');
        print('      Current cumulative: ${currentVideoDuration}s');
        print('      Next video duration: ${nextVideoDuration}s');

        if (transition != null && transition != TransitionType.none) {
          print('      Using xfade: ${transition.name} (${duration}s overlap)');

          // Use actual probed duration instead of track duration
          final result = await _applyXFadeBetweenTwo(
            currentVideo,
            nextVideo,
            tempOutput,
            transition,
            duration,
            currentVideoDuration, // Using probed duration
          );

          if (result != null) {
            currentVideoDuration =
                currentVideoDuration + nextVideoDuration - duration;
            print(
                '      ✓ XFade complete. New cumulative: ${currentVideoDuration}s');

            if (i > 1 && currentVideo != videoPaths[0]) {
              try {
                await File(currentVideo).delete();
              } catch (_) {}
            }
            currentVideo = result;
          } else {
            throw Exception('Failed to apply xfade transition at step $i');
          }
        } else {
          print('      Using hard cut (no overlap)');
          final result = await _concatTwoVideosHardCut(
            currentVideo,
            nextVideo,
            tempOutput,
          );

          if (result != null) {
            currentVideoDuration += nextVideoDuration;
            print(
                '      ✓ Hard cut complete. New cumulative: ${currentVideoDuration}s');

            if (i > 1 && currentVideo != videoPaths[0]) {
              try {
                await File(currentVideo).delete();
              } catch (_) {}
            }
            currentVideo = result;
          } else {
            throw Exception('Failed to concat videos at step $i');
          }
        }
      }

      print('📊 Final cumulative duration: ${currentVideoDuration}s');

      await File(currentVideo).copy(outputPath);

      if (currentVideo != videoPaths[0]) {
        try {
          await File(currentVideo).delete();
        } catch (_) {}
      }

      print('✅ Progressive merging completed: $outputPath');
    } catch (e) {
      print('❌ Progressive merging failed: $e');
      print('🔄 Falling back to simple concatenation...');
      await _combineWithConcatAndFallback(
        videoPaths,
        outputPath,
        videoTracks: videoTracks,
      );
    }
  }

  /// Combine videos with asset-wise transitions (each video pair can have different transitions)
  static Future<void> _combineVideosWithAssetWiseTransitions(
    List<String> videoPaths,
    String outputPath, {
    required List<VideoTrackModel> videoTracks,
  }) async {
    print(
        '🎬 Combining ${videoPaths.length} videos with asset-wise transitions...');

    if (videoPaths.isEmpty) {
      print('❌ No videos to combine');
      return;
    }

    if (videoPaths.length == 1) {
      // Single video, just copy it
      print('📁 Single video, copying: ${videoPaths[0]} → $outputPath');
      await File(videoPaths[0]).copy(outputPath);
      return;
    }

    // Validate all input files exist
    for (int i = 0; i < videoPaths.length; i++) {
      final file = File(videoPaths[i]);
      if (!await file.exists()) {
        throw Exception('Input video $i does not exist: ${videoPaths[i]}');
      }
      final fileSize = await file.length();
      print('   📄 Video $i: ${videoPaths[i]} (${fileSize} bytes)');
    }

    // Extract transitions and durations from video tracks
    List<TransitionType?> transitions = [];
    List<double> transitionDurations = [];
    bool hasAnyTransition = false;

    for (int i = 0; i < videoTracks.length - 1; i++) {
      final track = videoTracks[i];
      final transition = track.transitionToNext;
      final duration = track.transitionToNextDuration;

      transitions.add(transition);
      transitionDurations.add(duration);

      if (transition != null && transition != TransitionType.none) {
        hasAnyTransition = true;
        print('   ✓ Transition $i→${i + 1}: ${transition.name} (${duration}s)');
      } else {
        print('   ○ No transition $i→${i + 1} (direct concat)');
      }
    }

    // Decide on processing strategy based on transitions
    if (!hasAnyTransition) {
      // No transitions at all - use simple concatenation
      print('🔍 No transitions detected - using simple concatenation');
      await _combineWithConcatAndFallback(
        videoPaths,
        outputPath,
        videoTracks: videoTracks,
      );
    } else {
      // Has at least one transition - use progressive merging
      // This handles: all transitions, some transitions, or mixed scenarios
      print(
          '🔍 Transitions detected - using progressive merging (handles mixed transitions)');
      await _combineWithProgressiveMerging(
        videoPaths,
        outputPath,
        transitions,
        transitionDurations,
        videoTracks,
      );
    }
  }

  /// Add text overlays to sequential video using canvas-based text-to-image conversion
  /// Note: textTracks should already be scaled to export coordinates when calling this method
  static Future<String?> _addCanvasTextOverlaysToSequentialVideo(
    String videoPath,
    String outputPath,
    List<TextTrackModel> textTracks, // Already scaled to export coordinates
    Size exportCanvasSize,
    List<VideoTrackModel> videoTracks,
    CanvasConfiguration canvasConfig, // Canvas configuration for scaling
  ) async {
    if (textTracks.isEmpty) return videoPath;

    try {
      // Calculate total duration of sequential video
      double totalDuration = 0.0;
      for (final track in videoTracks) {
        totalDuration += track.totalDuration.toDouble();
      }

      print(
          '🎨 Canvas text overlay export: ${textTracks.length} tracks, canvas: ${exportCanvasSize.width}x${exportCanvasSize.height}');

      // Sort text tracks by lane index to ensure correct layering
      // Lower lane indices (0) render first (bottom layer)
      // Higher lane indices (2) render last (top layer)
      final sortedTextTracks = List<TextTrackModel>.from(textTracks)
        ..sort((a, b) => a.laneIndex.compareTo(b.laneIndex));

      print('📊 Multi-lane text export order:');
      for (int i = 0; i < sortedTextTracks.length; i++) {
        final track = sortedTextTracks[i];
        print(
            '   Layer ${i + 1}: Lane ${track.laneIndex} - "${track.text}" (${track.trimStartTime.toStringAsFixed(1)}s-${track.trimEndTime.toStringAsFixed(1)}s)');
      }

      // Convert each text track to image with canvas-aware scaling
      List<Map<String, dynamic>> textImages = [];
      final tempDir = await getTemporaryDirectory();

      for (int i = 0; i < sortedTextTracks.length; i++) {
        final textTrack = sortedTextTracks[i];

        // Calculate preview font size first (matching CanvasTextOverlayPainter logic)
        final previewCanvasSize = canvasConfig.previewCanvasSize;
        final referenceWidth =
            1920.0; // Same reference as CanvasTextOverlayPainter
        final previewScale = previewCanvasSize.width / referenceWidth;
        final previewFontSize =
            textTrack.fontSize * previewScale.clamp(0.5, 3.0);

        // Scale the preview font size to export size (maintaining visual consistency)
        final exportFontSize =
            canvasConfig.scaleFontSizeToExport(previewFontSize);

        print(
            '🔤 VideoExportManager - Text track ${i + 1}/${sortedTextTracks.length} (Lane ${textTrack.laneIndex}):');
        print('   Text: "${textTrack.text}"');
        print(
            '   Timeline: ${textTrack.trimStartTime.toStringAsFixed(1)}s - ${textTrack.trimEndTime.toStringAsFixed(1)}s');
        print('   Base font size: ${textTrack.fontSize}');
        print(
            '   Preview scale: ${previewScale.toStringAsFixed(3)} (${previewCanvasSize.width} / $referenceWidth)');
        print('   Preview font size: ${previewFontSize.toStringAsFixed(1)}');
        print(
            '   Export scale factor: ${canvasConfig.scaleFactor.toStringAsFixed(3)}');
        print('   Export font size: ${exportFontSize.toStringAsFixed(1)}');

        // Calculate export position using CanvasConfiguration scaling
        final exportPosition =
            canvasConfig.scalePositionToExport(textTrack.position);
        double exportX = exportPosition.dx;
        double exportY = exportPosition.dy;

        // Apply rotation-aware position adjustment using TextRotationManager for consistency with preview
        if (textTrack.rotation != 0) {
          // Calculate available width for proper text wrapping (same as text rendering phase)
          final exportCanvasSize = canvasConfig.exportCanvasSize;
          final estimatedAvailableWidth =
              exportCanvasSize.width - exportX - 10.0; // 10px buffer
          final maxTextWidth =
              math.max(estimatedAvailableWidth, 100.0); // Minimum 100px width

          // Calculate text dimensions for rotation adjustment using constrained layout
          final tempTextStyle = TextStyle(
            fontSize: exportFontSize,
            fontFamily: textTrack.fontFamily,
            color: textTrack.textColor,
            height: 1.0,
          );

          final tempPainter = TextPainter(
            text: TextSpan(text: textTrack.text, style: tempTextStyle),
            textDirection: TextDirection.ltr,
          );
          // ✅ FIX: Use constrained layout to get wrapped text dimensions
          tempPainter.layout(maxWidth: maxTextWidth);

          final textWidth = tempPainter.width;
          final textHeight = tempPainter.height;
          tempPainter.dispose();

          print('🔧 Fixed dimension calculation for multiline text:');
          print(
              '   Max text width constraint: ${maxTextWidth.toStringAsFixed(1)}px');
          print(
              '   Wrapped text dimensions: ${textWidth.toStringAsFixed(1)}x${textHeight.toStringAsFixed(1)}');
          print('   (vs single-line would be much wider)');

          // Calculate preview text dimensions first (at preview scale) with consistent constraints
          final previewScale = canvasConfig.previewCanvasSize.width /
              1920.0; // Same scale used in preview
          final previewFontSize =
              textTrack.fontSize * previewScale.clamp(0.5, 3.0);
          final previewTextStyle = TextStyle(
            fontSize: previewFontSize,
            fontFamily: textTrack.fontFamily,
            height: 1.0,
          );

          // ✅ FIX: Calculate preview max width constraint proportional to export constraint
          final previewCanvasWidth = canvasConfig.previewCanvasSize.width;
          final previewMaxWidth =
              (maxTextWidth * previewCanvasWidth) / exportCanvasSize.width;
          final constrainedPreviewMaxWidth =
              math.max(previewMaxWidth, 20.0); // Minimum 20px width

          final previewTextPainter = TextPainter(
            text: TextSpan(text: textTrack.text, style: previewTextStyle),
            textDirection: TextDirection.ltr,
          );
          // ✅ FIX: Use constrained layout to match export dimension calculation
          previewTextPainter.layout(maxWidth: constrainedPreviewMaxWidth);
          final previewTextWidth = previewTextPainter.width;
          final previewTextHeight = previewTextPainter.height;
          previewTextPainter.dispose();

          print('🔧 Fixed preview dimension calculation:');
          print(
              '   Preview max width constraint: ${constrainedPreviewMaxWidth.toStringAsFixed(1)}px');
          print(
              '   Preview wrapped dimensions: ${previewTextWidth.toStringAsFixed(1)}x${previewTextHeight.toStringAsFixed(1)}');
          print(
              '   Export wrapped dimensions: ${textWidth.toStringAsFixed(1)}x${textHeight.toStringAsFixed(1)}');

          // Calculate simple text center (mathematically correct approach)
          // Canvas rotates around: position + (textWidth/2, textHeight/2)
          final previewTextCenter = Offset(
            textTrack.position.dx + (previewTextWidth / 2),
            textTrack.position.dy + (previewTextHeight / 2),
          );

          // Scale the preview text center to export coordinates
          final exportTextCenter =
              canvasConfig.scalePositionToExport(previewTextCenter);

          // Calculate rotated bounds at export scale
          final rotatedBounds = TextRotationManager.calculateRotatedTextBounds(
            textWidth: textWidth,
            textHeight: textHeight,
            rotation: textTrack.rotation,
          );

          // Position the rotated image so its center aligns with the scaled text center
          exportX = exportTextCenter.dx - (rotatedBounds['width']! / 2);
          exportY = exportTextCenter.dy - (rotatedBounds['height']! / 2);

          // ✅ NEW: Apply manual deviation for rotated text
          final originalExportX = exportX;
          final originalExportY = exportY;
          exportX += 0.0; // Manual X deviation
          exportY += 0.0; // Manual Y deviation

          // ✅ FIX: Add boundary validation to keep positions within canvas
          final beforeBoundaryX = exportX;
          final beforeBoundaryY = exportY;

          // Ensure the rotated text image stays within canvas bounds
          final rotatedWidth = rotatedBounds['width']!;
          final rotatedHeight = rotatedBounds['height']!;

          // Clamp X position to ensure the entire rotated text fits within canvas width
          exportX = exportX.clamp(
              0.0, math.max(0.0, exportCanvasSize.width - rotatedWidth));

          // Clamp Y position to ensure the entire rotated text fits within canvas height
          exportY = exportY.clamp(
              0.0, math.max(0.0, exportCanvasSize.height - rotatedHeight));

          print('📍 Position calculation with boundary validation:');
          print(
              '   Original position: (${originalExportX.toStringAsFixed(1)}, ${originalExportY.toStringAsFixed(1)})');
          print(
              '   After manual deviation: (${beforeBoundaryX.toStringAsFixed(1)}, ${beforeBoundaryY.toStringAsFixed(1)})');
          print(
              '   After boundary clamp: (${exportX.toStringAsFixed(1)}, ${exportY.toStringAsFixed(1)})');
          print(
              '   Canvas size: ${exportCanvasSize.width}x${exportCanvasSize.height}');
          print(
              '   Rotated bounds: ${rotatedWidth.toStringAsFixed(1)}x${rotatedHeight.toStringAsFixed(1)}');

          print('🔄 Simple Canvas rotation center (with manual deviation):');
          print(
              '   Preview text dimensions: ${previewTextWidth.toStringAsFixed(1)}x${previewTextHeight.toStringAsFixed(1)} (font: ${previewFontSize.toStringAsFixed(1)})');
          print(
              '   Export text dimensions: ${textWidth.toStringAsFixed(1)}x${textHeight.toStringAsFixed(1)} (font: ${exportFontSize.toStringAsFixed(1)})');
          print('   Rotation: ${textTrack.rotation}°');
          print(
              '   Preview text center: (${previewTextCenter.dx.toStringAsFixed(1)}, ${previewTextCenter.dy.toStringAsFixed(1)})');
          print(
              '   Export text center (scaled): (${exportTextCenter.dx.toStringAsFixed(1)}, ${exportTextCenter.dy.toStringAsFixed(1)})');
          print(
              '   Rotated bounds: ${rotatedBounds['width']!.toStringAsFixed(1)}x${rotatedBounds['height']!.toStringAsFixed(1)}');
          print(
              '   Final export position: (${exportX.toStringAsFixed(1)}, ${exportY.toStringAsFixed(1)})');
        }

        print(
            '🎯 VideoExportManager - Position scaling with CanvasConfiguration:');
        print(
            '   Preview position: (${textTrack.position.dx}, ${textTrack.position.dy})');
        print(
            '   Export position: (${exportX.toStringAsFixed(1)}, ${exportY.toStringAsFixed(1)})');
        print(
            '   Position scale factor: ${canvasConfig.scaleFactor.toStringAsFixed(3)}');

        // Create text image with canvas parameters
        final imagePath =
            '${tempDir.path}/canvas_text_${textTrack.id}_${DateTime.now().millisecondsSinceEpoch}.png';

        // Calculate available space for text wrapping using the same calculation as dimension phase
        // (exportCanvasSize was already calculated earlier for rotated text)
        final exportCanvasSize = canvasConfig.exportCanvasSize;
        final availableWidth = exportCanvasSize.width -
            exportX -
            10.0; // 10px buffer (same as dimension calc)
        final availableHeight =
            exportCanvasSize.height - exportY - 5.0; // 5px buffer

        print('📐 Available space calculation:');
        print(
            '   Export canvas: ${exportCanvasSize.width}x${exportCanvasSize.height}');
        print(
            '   Available width: ${availableWidth.toStringAsFixed(1)} (${exportCanvasSize.width} - ${exportX.toStringAsFixed(1)} - 10.0)');
        print(
            '   Available height: ${availableHeight.toStringAsFixed(1)} (${exportCanvasSize.height} - ${exportY.toStringAsFixed(1)} - 5.0)');

        await _createTextImage(
          text: textTrack.text,
          fontFamily: textTrack.fontFamily,
          fontSize: exportFontSize,
          color: textTrack.textColor,
          rotation: textTrack.rotation,
          maxWidth: math.max(
              availableWidth, 100.0), // Use full available width like preview
          maxHeight: math.max(
              availableHeight, 50.0), // Use full available height like preview
          outputPath: imagePath,
        );

        // Store image info for FFmpeg overlay
        textImages.add({
          'path': imagePath,
          'x': exportX,
          'y': exportY,
          'startTime': textTrack.trimStartTime,
          'endTime': textTrack.trimEndTime,
          'text': textTrack.text,
        });

        print(
            '📝 Canvas text image $i: "${textTrack.text}" -> ${exportX.toInt()}, ${exportY.toInt()}');
      }

      if (textImages.isEmpty) {
        print('⚠️ No text images created');
        return videoPath;
      }

      // Build FFmpeg command with image overlays
      List<String> inputs = ['-i "$videoPath"'];

      // Add image inputs
      for (final imageInfo in textImages) {
        final duration = imageInfo['endTime'] - imageInfo['startTime'];
        inputs.add('-t $duration -i "${imageInfo['path']}"');
      }

      // Build overlay filter complex
      List<String> overlayFilters = [];
      String currentInput = '0:v';

      for (int i = 0; i < textImages.length; i++) {
        final imageInfo = textImages[i];
        final imageIndex = i + 1;
        final outputLabel = i < textImages.length - 1 ? '[v${i + 1}]' : '';

        final filter = '[$currentInput][$imageIndex:v]overlay='
            'x=${imageInfo['x'].toInt()}:'
            'y=${imageInfo['y'].toInt()}:'
            'enable=\'between(t,${imageInfo['startTime']},${imageInfo['endTime']})\'$outputLabel';

        overlayFilters.add(filter);
        currentInput = 'v${i + 1}';
      }

      final filterComplex = overlayFilters.join(';');
      final command =
          '${inputs.join(' ')} -filter_complex "$filterComplex" -c:v libx264 -preset ultrafast -c:a copy "$outputPath"';

      print('Canvas text overlay command: $command');
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      // Clean up temporary image files
      for (final imageInfo in textImages) {
        try {
          await File(imageInfo['path']).delete();
        } catch (e) {
          print(
              'Warning: Could not delete temp image ${imageInfo['path']}: $e');
        }
      }

      return ReturnCode.isSuccess(returnCode) ? outputPath : null;
    } catch (e) {
      print('Canvas text overlay error: $e');
      return null;
    }
  }

  // =============================================================================
  // ENHANCED CANVAS-BASED EXPORT HELPER FUNCTIONS
  // =============================================================================

  // /// Check if a video has an audio stream using the working method from preview system
  // static Future<bool> _hasAudioStream(String videoPath) async {
  //   try {
  //     print('🔍 _hasAudioStream: Checking $videoPath');

  //     // First check if file exists
  //     final file = File(videoPath);
  //     if (!await file.exists()) {
  //       print('❌ _hasAudioStream: File does not exist: $videoPath');
  //       return false;
  //     }

  //     // Use the exact working command from video_editor_provider.dart (preview system)
  //     final session = await FFmpegKit.execute('-hide_banner -i "$videoPath"');
  //     final output = await session.getOutput();
  //     final returnCode = await session.getReturnCode();

  //     print('🔍 _hasAudioStream FFmpeg result:');
  //     print('   Return code: $returnCode');
  //     print('   Output length: ${output?.length ?? 0}');

  //     // Use the working detection method from preview: check for "Audio:" in output
  //     final hasAudio = output?.contains('Audio:') == true;
  //     print('🔍 _hasAudioStream result: $hasAudio');

  //     return hasAudio;
  //   } catch (e) {
  //     print("❌ Error checking audio stream for $videoPath: $e");
  //     return false;
  //   }
  // }

  /// Add silent audio track to muted video (2-step process: mute original audio, then add silent)
  static Future<String?> _addSilentAudioToMutedVideo(
      String videoPath, String tempDirPath,
      {double? expectedDuration}) async {
    try {
      // Step 1: Set original audio volume to 0 (based on combineSegments line 1496-1507)
      final tempMutedPath =
          '${tempDirPath}/temp_muted_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final volumeMuteCmd =
          '-y -i "$videoPath" -af "volume=0" -c:v copy -c:a aac "$tempMutedPath"';

      print('🔇 Step 1 - Muting original audio: $volumeMuteCmd');

      final muteSession = await FFmpegKit.execute(volumeMuteCmd);
      final muteReturnCode = await muteSession.getReturnCode();

      if (!ReturnCode.isSuccess(muteReturnCode)) {
        print('❌ Failed to mute original audio, using original video');
        return videoPath;
      }

      // Step 2: Use existing _addSilentAudio function
      print('🔇 Step 2 - Adding silent audio using existing function');
      final result = await _addSilentAudio(tempMutedPath, tempDirPath,
          expectedDuration: expectedDuration);

      if (result != null) {
        print('✅ Successfully created muted video with silent audio: $result');
        return result;
      } else {
        print('❌ Failed to add silent audio to muted video');
        return videoPath;
      }
    } catch (e) {
      print(
          '❌ Error creating muted video with silent audio for $videoPath: $e');
      return videoPath;
    }
  }

  /// Apply video trimming using FFmpeg if trim boundaries are set
  static Future<String?> _applyVideoTrimming(
      String inputPath, String tempDirPath, VideoTrackModel track) async {
    final trimStart = track.videoTrimStart; // in seconds
    final trimEnd = track.videoTrimEnd; // in seconds
    final originalDuration = track.originalDuration; // in seconds
    final expectedDuration =
        track.totalDuration.toDouble(); // totalDuration is already in seconds

    print('🔄 Checking trim for video: $inputPath');
    print(
        '   Trim start: ${trimStart}s, Trim end: ${trimEnd}s, Original duration: ${originalDuration}s');
    print(
        '   Expected duration (from preview): ${expectedDuration.toStringAsFixed(3)}s');

    // Skip if no actual trimming needed
    if (trimStart <= 0 && (trimEnd <= 0 || trimEnd >= originalDuration)) {
      print('   No trimming needed - using original video');
      return inputPath;
    }

    // Calculate effective duration
    final effectiveEnd = trimEnd > 0 ? trimEnd : originalDuration;
    final effectiveDuration = effectiveEnd - trimStart;

    if (effectiveDuration <= 0) {
      print(
          '   Invalid trim duration: ${effectiveDuration}s - using original video');
      return inputPath;
    }

    // Validate that the calculated trim duration matches the expected duration
    final durationDiff = (effectiveDuration - expectedDuration).abs();
    if (durationDiff > 0.01) {
      // Allow 0.01s tolerance
      print('⚠️  WARNING: Trim duration mismatch!');
      print(
          '   Calculated trim duration: ${effectiveDuration.toStringAsFixed(3)}s');
      print(
          '   Expected duration from preview: ${expectedDuration.toStringAsFixed(3)}s');
      print('   Difference: ${durationDiff.toStringAsFixed(3)}s');
      // Use expected duration from preview to ensure consistency
      print(
          '   Using expected duration for trimming to maintain preview consistency');
    }

    final outputPath =
        '${tempDirPath}/trimmed_${DateTime.now().millisecondsSinceEpoch}.mp4';

    // Use FFmpeg to trim the video - use expected duration for perfect preview alignment
    final trimDuration =
        expectedDuration; // Use preview duration for consistency
    final command =
        '-y -i "$inputPath" -ss $trimStart -t ${trimDuration.toStringAsFixed(3)} -c copy "$outputPath"';

    print('🎬 Applying video trimming with preview-aligned duration: $command');

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      // Verify the output file exists and has content
      final outputFile = File(outputPath);
      if (await outputFile.exists() && await outputFile.length() > 0) {
        print('✅ Video trimmed successfully: $inputPath -> $outputPath');
        print('   Trimmed duration: ${effectiveDuration}s');
        return outputPath;
      } else {
        print('❌ Failed to create trimmed video file: $outputPath');
        return inputPath;
      }
    } else {
      final logs = await session.getAllLogs();
      print('❌ Failed to trim video: $inputPath');
      print('   Return code: $returnCode');
      print(
          '   FFmpeg logs: ${logs.map((log) => log.getMessage()).join('\n')}');
      return inputPath; // Fallback to original
    }
  }

  /// Add silent audio track to video without audio
  static Future<String?> _addSilentAudio(String videoPath, String tempDirPath,
      {double? expectedDuration}) async {
    try {
      final outputPath =
          '$tempDirPath/silent_audio_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // Use the exact working pattern from editor_controller.dart line 185-186
      // Add explicit duration control if expected duration is provided
      String command =
          '-y -i "$videoPath" -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=48000 -shortest -c:v copy -c:a aac';

      if (expectedDuration != null && expectedDuration > 0) {
        command += ' -t ${expectedDuration.toStringAsFixed(3)}';
        print(
            '📐 Adding silent audio with duration control: ${expectedDuration.toStringAsFixed(3)}s');
      } else {
        print('📐 Adding silent audio with video-based duration (shortest)');
      }

      command += ' "$outputPath"';

      print('Adding silent audio with command: $command');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        // Verify the output file exists and has content
        final outputFile = File(outputPath);
        if (await outputFile.exists() && await outputFile.length() > 0) {
          print('✅ Added silent audio to: $videoPath -> $outputPath');
          return outputPath;
        } else {
          print('❌ Failed to create silent audio file: $outputPath');
          return null;
        }
      } else {
        final logs = await session.getAllLogs();
        print('❌ Failed to add silent audio to: $videoPath');
        print('   Return code: $returnCode');
        print(
            '   FFmpeg logs: ${logs.map((log) => log.getMessage()).join('\n')}');
        return null;
      }
    } catch (e) {
      print('❌ Error adding silent audio to $videoPath: $e');
      return null;
    }
  }

  /// Create a stretched video from an image file for export
  /// This method generates the actual video file that was deferred during preview
  /// Uses the original video dimensions to ensure dimensional consistency
  /// If originalImageSize is provided, the image's aspect ratio will be preserved
  static Future<File?> _createStretchedImageVideo(
    File originalImageFile,
    double newDuration,
    Size originalVideoSize,
    Directory tempDir, {
    Size? originalImageSize,
  }) async {
    try {
      final outputPath =
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_stretched_img.mp4';

      print('   🎬 Generating stretched image video:');
      print('      Image: ${originalImageFile.path}');
      print('      Duration: ${newDuration}s');
      print(
          '      Target video dimensions: ${originalVideoSize.width.toInt()}x${originalVideoSize.height.toInt()}');

      // Build scale filter that preserves original image aspect ratio
      // Output dimensions match the original processed video file
      String scaleFilter;
      if (originalImageSize != null) {
        // Preserve original image aspect ratio by fitting it within the target dimensions
        final scaledWidth = originalVideoSize.width.toInt();
        final scaledHeight = originalVideoSize.height.toInt();

        scaleFilter =
            'scale=$scaledWidth:$scaledHeight:force_original_aspect_ratio=decrease,'
            'pad=$scaledWidth:$scaledHeight:(ow-iw)/2:(oh-ih)/2:color=black';

        print(
            '      Original image dimensions: ${originalImageSize.width.toInt()}x${originalImageSize.height.toInt()}');
        print(
            '      Scaling to fit video dimensions while preserving aspect ratio');
      } else {
        // Fallback: scale to video dimensions (matches initial conversion behavior)
        final videoWidth = originalVideoSize.width.toInt();
        final videoHeight = originalVideoSize.height.toInt();
        scaleFilter =
            'scale=$videoWidth:$videoHeight:force_original_aspect_ratio=decrease,'
            'pad=$videoWidth:$videoHeight:(ow-iw)/2:(oh-ih)/2:color=black';
        print(
            '      Using video dimensions with aspect ratio preservation (original image dimensions not available)');
      }

      // FFmpeg command to create video with specified duration and silent audio
      final command = '-loop 1 -t $newDuration -i "${originalImageFile.path}" '
          '-f lavfi -i anullsrc=r=44100:cl=stereo '
          '-vf "$scaleFilter" '
          '-c:v h264 -preset medium -crf 23 -pix_fmt yuv420p '
          '-c:a aac -b:a 128k '
          '-shortest '
          '-r 30 "$outputPath"';

      print('      FFmpeg command: $command');

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      final logs = await session.getLogsAsString();

      if (ReturnCode.isSuccess(returnCode) && File(outputPath).existsSync()) {
        final outputFile = File(outputPath);
        final fileSize = await outputFile.length();
        print(
            '      ✅ Stretched video created: $outputPath (${fileSize} bytes)');
        return outputFile;
      } else {
        print('      ❌ Failed to create stretched video');
        print('      FFmpeg logs: $logs');
        return null;
      }
    } catch (e) {
      print('      ❌ Error creating stretched image video: $e');
      return null;
    }
  }

  /// Get the original dimensions of an image file
  /// Returns Size(width, height) or null if dimensions cannot be determined
  static Future<Size?> _getImageDimensions(String imagePath) async {
    try {
      final session = await FFprobeKit.execute(
          '-v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$imagePath"');
      final output = await session.getOutput();

      if (output != null && output.trim().isNotEmpty) {
        final parts = output.trim().split('x');
        if (parts.length == 2) {
          final width = double.tryParse(parts[0]);
          final height = double.tryParse(parts[1]);
          if (width != null && height != null) {
            return Size(width, height);
          }
        }
      }
      return null;
    } catch (e) {
      print('      ⚠️ Error getting image dimensions: $e');
      return null;
    }
  }

  /// Get the dimensions of a video file
  /// Returns Size(width, height) or null if dimensions cannot be determined
  static Future<Size?> _getVideoDimensions(String videoPath) async {
    try {
      final session = await FFprobeKit.execute(
          '-v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$videoPath"');
      final output = await session.getOutput();

      if (output != null && output.trim().isNotEmpty) {
        final parts = output.trim().split('x');
        if (parts.length == 2) {
          final width = double.tryParse(parts[0]);
          final height = double.tryParse(parts[1]);
          if (width != null && height != null) {
            return Size(width, height);
          }
        }
      }
      return null;
    } catch (e) {
      print('      ⚠️ Error getting video dimensions: $e');
      return null;
    }
  }

  /// Combine exactly 2 videos using xfade transitions with proper logging and error handling
  static Future<void> _combineWith2VideoXFade(
    List<String> videoPaths,
    String outputPath,
    TransitionType transition,
    List<VideoTrackModel> videoTracks,
  ) async {
    if (videoPaths.length != 2) {
      throw Exception(
          '_combineWith2VideoXFade expects exactly 2 videos, got ${videoPaths.length}');
    }

    if (videoTracks.length < 2) {
      throw Exception(
          '_combineWith2VideoXFade expects at least 2 video tracks, got ${videoTracks.length}');
    }

    print(
        '🎬 XFade: Combining 2 canvas-processed videos with transition: ${transition.name}');

    try {
      // Get xfade transition name
      final xfadeName = _getXFadeTransitionName(transition);

      // Calculate offset (first video duration - 1 second overlap)
      final firstVideoDuration = videoTracks[0].totalDuration.toDouble();
      final transitionDuration = 1.0; // 1 second transition
      final offset = firstVideoDuration - transitionDuration;

      // Calculate duration transparency
      final expectedDuration = videoTracks[0].totalDuration.toDouble() +
          videoTracks[1].totalDuration.toDouble();
      final actualDuration = expectedDuration - transitionDuration;

      print('🎬 XFade: First video duration: ${firstVideoDuration}s');
      print(
          '🎬 XFade: Second video duration: ${videoTracks[1].totalDuration.toDouble()}s');
      print('🎬 XFade: Transition duration: ${transitionDuration}s');
      print('🎬 XFade: Calculated offset: ${offset}s');
      print('🎬 XFade: Expected total duration: ${expectedDuration}s');
      print('🎬 XFade: Actual duration (with overlap): ${actualDuration}s');
      print(
          '🎬 XFade: Duration reduction: ${expectedDuration - actualDuration}s');
      print('🎬 XFade: Using transition: $xfadeName');

      // Build filter complex with both video and audio processing (with proper audio delays)
      final videoFilter =
          '[0:v][1:v]xfade=transition=$xfadeName:duration=$transitionDuration:offset=$offset[v]';
      final audioFilter =
          _generateAudioMixChainWithDelays(videoTracks, transitionDuration);
      final filterComplex = '$videoFilter; $audioFilter';

      // Build FFmpeg command for 2-video xfade with MediaCodec-compatible H.264 profile
      final command = [
        '-i', '"${videoPaths[0]}"',
        '-i', '"${videoPaths[1]}"',
        '-filter_complex', '"$filterComplex"',
        '-map', '[v]',
        '-map', '[a]',
        '-c:v', 'libx264',
        '-preset', 'ultrafast',
        '-profile:v',
        'baseline', // Force baseline profile for MediaCodec compatibility
        '-level', '3.1', // Use level 3.1 for device compatibility
        '-pix_fmt', 'yuv420p', // Ensure compatible pixel format
        '-c:a', 'aac',
        '-ar', '48000',
        '-ac', '2',
        '-b:v', '800k',
        '-b:a', '128k',
        '-y', // Overwrite output
        '"$outputPath"'
      ].join(' ');

      print('🎬 XFade: Video filter: $videoFilter');
      print('🎬 XFade: Audio filter: $audioFilter');
      print(
          '🎬 XFade: Using H.264 baseline profile, level 3.1 for MediaCodec compatibility');

      print('🎬 XFade: Executing FFmpeg command:');
      print('   $command');

      // Execute FFmpeg command
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        // Verify output file exists and has content
        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          final fileSize = await outputFile.length();
          print(
              '✅ XFade: Successfully created transition video: $outputPath (${fileSize} bytes)');
        } else {
          throw Exception(
              'XFade: FFmpeg reported success but output file does not exist: $outputPath');
        }
      } else {
        // Get detailed error logs from FFmpeg
        final logs = await session.getLogs();
        final errorDetails = logs.map((log) => log.getMessage()).join('\n');

        print('❌ XFade: FFmpeg failed with return code: $returnCode');
        print('❌ XFade: Error details:');
        print(errorDetails);

        throw Exception(
            'XFade: FFmpeg execution failed with code $returnCode: $errorDetails');
      }
    } catch (e) {
      print('❌ XFade: Exception during 2-video transition: $e');
      print('🔄 XFade: Falling back to simple concatenation...');

      // Fallback to simple concatenation on any error
      await _combineWithConcatAndFallback(
        videoPaths,
        outputPath,
        videoTracks: videoTracks,
      );
    }
  }

  /// Combine 3+ videos using chained xfade transitions with per-asset transition support
  static Future<void> _combineWithMultiVideoXFade(
    List<String> videoPaths,
    String outputPath,
    List<TransitionType?> transitions,
    List<double> transitionDurations,
    List<VideoTrackModel> videoTracks,
  ) async {
    if (videoPaths.length < 2) {
      throw Exception(
          '_combineWithMultiVideoXFade expects 2+ videos, got ${videoPaths.length}');
    }

    if (videoTracks.length < videoPaths.length) {
      throw Exception(
          '_combineWithMultiVideoXFade expects ${videoPaths.length} video tracks, got ${videoTracks.length}');
    }

    if (transitions.length != videoPaths.length - 1) {
      throw Exception(
          '_combineWithMultiVideoXFade expects ${videoPaths.length - 1} transitions, got ${transitions.length}');
    }

    print(
        '🎬 Multi-XFade: Combining ${videoPaths.length} canvas-processed videos with asset-wise transitions');

    // Log each transition
    for (int i = 0; i < transitions.length; i++) {
      final trans = transitions[i];
      final dur = transitionDurations[i];
      if (trans != null && trans != TransitionType.none) {
        print('   Transition $i→${i + 1}: ${trans.name} (${dur}s)');
      } else {
        print('   Transition $i→${i + 1}: none (concat)');
      }
    }

    try {
      // Convert transitions to xfade names
      List<String> xfadeNames = transitions.map((t) {
        if (t == null || t == TransitionType.none) {
          return 'fade'; // Default fallback for null transitions
        }
        return _getXFadeTransitionName(t);
      }).toList();

      // Calculate offsets for all transitions with varying durations
      final offsets = _calculateXFadeOffsetsWithVaryingDurations(
        videoTracks,
        transitionDurations,
      );

      // Generate filter chain with varying transitions and durations
      final filterChain = _generateXFadeFilterChainWithVaryingTransitions(
        videoPaths.length,
        offsets,
        xfadeNames,
        transitionDurations,
      );

      // Calculate duration transparency with varying transition durations
      final expectedDuration = videoTracks.fold(
          0.0, (sum, track) => sum + track.totalDuration.toDouble());
      final totalTransitionOverlap =
          transitionDurations.fold(0.0, (sum, duration) => sum + duration);
      final actualDuration = expectedDuration - totalTransitionOverlap;

      print(
          '🎬 Multi-XFade: Generated ${filterChain.length} transition filters');
      print('🎬 Multi-XFade: Expected total duration: ${expectedDuration}s');
      print(
          '🎬 Multi-XFade: Actual duration (with ${videoPaths.length - 1} overlaps): ${actualDuration}s');
      print(
          '🎬 Multi-XFade: Total transition overlap: ${totalTransitionOverlap}s');

      // Build input parameters
      List<String> inputs = [];
      for (int i = 0; i < videoPaths.length; i++) {
        inputs.add('-i');
        inputs.add('"${videoPaths[i]}"');
      }

      // Combine video filter chain and add audio mixing with proper delays for varying durations
      final videoFilterChain = filterChain.join(';');
      final audioChain = _generateAudioMixChainWithVaryingDelays(
          videoTracks, transitionDurations);
      final fullFilterComplex = '$videoFilterChain; $audioChain';

      // Build complete FFmpeg command with MediaCodec-compatible H.264 profile
      final command = [
        ...inputs,
        '-filter_complex', '"$fullFilterComplex"',
        '-map', '[v]',
        '-map', '[a]',
        '-c:v', 'libx264',
        '-preset', 'ultrafast',
        '-profile:v',
        'baseline', // Force baseline profile for MediaCodec compatibility
        '-level', '3.1', // Use level 3.1 for device compatibility
        '-pix_fmt', 'yuv420p', // Ensure compatible pixel format
        '-c:a', 'aac',
        '-ar', '48000',
        '-ac', '2',
        '-b:v', '800k',
        '-b:a', '128k',
        '-y', // Overwrite output
        '"$outputPath"'
      ].join(' ');

      print(
          '🎬 Multi-XFade: Using H.264 baseline profile, level 3.1 for MediaCodec compatibility');
      print('🎬 Multi-XFade: Executing FFmpeg command:');
      print('   $command');

      // Execute FFmpeg command
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        // Verify output file exists and has content
        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          final fileSize = await outputFile.length();
          print(
              '✅ Multi-XFade: Successfully created ${videoPaths.length}-video transition: $outputPath (${fileSize} bytes)');
        } else {
          throw Exception(
              'Multi-XFade: FFmpeg reported success but output file does not exist: $outputPath');
        }
      } else {
        // Get detailed error logs from FFmpeg
        final logs = await session.getLogs();
        final errorDetails = logs.map((log) => log.getMessage()).join('\n');

        print('❌ Multi-XFade: FFmpeg failed with return code: $returnCode');
        print('❌ Multi-XFade: Error details:');
        print(errorDetails);

        throw Exception(
            'Multi-XFade: FFmpeg execution failed with code $returnCode: $errorDetails');
      }
    } catch (e) {
      print(
          '❌ Multi-XFade: Exception during ${videoPaths.length}-video transition: $e');
      print('🔄 Multi-XFade: Falling back to simple concatenation...');

      // Fallback to simple concatenation on any error
      await _combineWithConcatAndFallback(
        videoPaths,
        outputPath,
        videoTracks: videoTracks,
      );
    }
  }

  /// Combine videos with concat fallback (simple concatenation without transitions)
  static Future<void> _combineWithConcatAndFallback(
    List<String> videoPaths,
    String outputPath, {
    List<VideoTrackModel>? videoTracks,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final concatFile = File(
        '${tempDir.path}/concat_list_${DateTime.now().millisecondsSinceEpoch}.txt');

    // Create concat file content
    final concatContent = videoPaths
        .map((path) => "file '${path.replaceAll("'", "\\'")}'")
        .join('\n');

    await concatFile.writeAsString(concatContent);
    print('📝 Created concat file with ${videoPaths.length} entries');

    // Calculate and log expected total duration from VideoTrackModel
    double expectedTotalDuration = 0.0;
    if (videoTracks != null) {
      for (int i = 0; i < videoPaths.length && i < videoTracks.length; i++) {
        final track = videoTracks[i];
        final trackDuration = track.totalDuration
            .toDouble(); // totalDuration is already in seconds
        expectedTotalDuration += trackDuration;
        print(
            '   📄 Video $i (${videoPaths[i]}): Expected duration ${trackDuration.toStringAsFixed(3)}s from VideoTrackModel');
      }
      print(
          '📐 Total expected duration from preview: ${expectedTotalDuration.toStringAsFixed(3)}s');
    } else {
      print('⚠️  No VideoTrackModel provided - cannot validate durations');
    }

    // Primary method: Use concat with video re-encoding and audio normalization
    // Audio is re-encoded to 48kHz stereo to prevent timestamp discontinuities
    // and ensure compatibility across Android and iOS devices
    // Add explicit duration control to match preview expectations
    String primaryCommand = '-y -f concat -safe 0 -i "${concatFile.path}" '
        '-map 0:v -map 0:a? -c:v libx264 -preset ultrafast '
        '-c:a aac -ar 48000 -ac 2 -b:a 128k -b:v 800k';

    // Add duration limiting if we have expected duration from preview
    if (expectedTotalDuration > 0) {
      primaryCommand += ' -t ${expectedTotalDuration.toStringAsFixed(3)}';
      print(
          '📐 Added duration control: limiting output to ${expectedTotalDuration.toStringAsFixed(3)}s to match preview');
    }

    primaryCommand += ' "$outputPath"';

    print(
        '🔧 Primary concat command (video re-encode, audio normalize to 48kHz stereo):');
    print('   $primaryCommand');

    final primarySession = await FFmpegKit.execute(primaryCommand);
    final primaryReturnCode = await primarySession.getReturnCode();
    final primaryOutput = await primarySession.getOutput();

    if (ReturnCode.isSuccess(primaryReturnCode)) {
      // Verify output file exists and has content
      final outputFile = File(outputPath);
      if (await outputFile.exists() && await outputFile.length() > 0) {
        final outputSize = await outputFile.length();
        print('✅ Primary concat successful: $outputPath (${outputSize} bytes)');

        // Transitions are handled at the beginning of this method

        return;
      } else {
        print('⚠️  Primary concat succeeded but output file missing/empty');
      }
    } else {
      print('❌ Primary concat failed (return code: $primaryReturnCode)');
      if (primaryOutput != null && primaryOutput.isNotEmpty) {
        print('   Primary concat error: $primaryOutput');
      }
    }

    // Fallback method: Simple stream copy (like reference fallback)
    // Reference uses: '-y -f concat -safe 0 -i "$inputListPath" -c copy "$outputPath"'
    print('🔄 Attempting fallback concat with stream copy...');
    String fallbackCommand =
        '-y -f concat -safe 0 -i "${concatFile.path}" -c copy';

    // Add duration limiting to fallback as well
    if (expectedTotalDuration > 0) {
      fallbackCommand += ' -t ${expectedTotalDuration.toStringAsFixed(3)}';
      print(
          '📐 Added duration control to fallback: limiting to ${expectedTotalDuration.toStringAsFixed(3)}s');
    }

    fallbackCommand += ' "$outputPath"';

    print('🔧 Fallback concat command:');
    print('   $fallbackCommand');

    final fallbackSession = await FFmpegKit.execute(fallbackCommand);
    final fallbackReturnCode = await fallbackSession.getReturnCode();

    if (ReturnCode.isSuccess(fallbackReturnCode)) {
      final outputFile = File(outputPath);
      if (await outputFile.exists() && await outputFile.length() > 0) {
        final outputSize = await outputFile.length();
        print(
            '✅ Fallback concat successful: $outputPath (${outputSize} bytes)');

        // Transitions are handled at the beginning of this method

        return;
      } else {
        print('⚠️  Fallback concat succeeded but output file missing/empty');
      }
    } else {
      final fallbackOutput = await fallbackSession.getOutput();
      print('❌ Fallback concat also failed (return code: $fallbackReturnCode)');
      if (fallbackOutput != null && fallbackOutput.isNotEmpty) {
        print('   Fallback error: $fallbackOutput');
      }
      throw Exception('Both primary and fallback concatenation methods failed');
    }

    throw Exception('Concatenation succeeded but output file is invalid');
  }

  /// Apply simple transition using the original working method
  /// Takes individual videos and applies transition between them, then outputs to final path
  static Future<bool> _applySimpleTransition(
    List<String> videoPaths,
    String outputPath,
    TransitionType transition,
    List<VideoTrackModel> videoTracks,
    String tempDirPath,
  ) async {
    if (videoPaths.length < 2) {
      print('⚠️  Not enough videos for transition, skipping');
      return true; // Not an error, just skip
    }

    print('🎬 === TRANSITION DEBUG START ===');
    print('   Transition type: ${transition.name}');
    print('   Number of videos: ${videoPaths.length}');
    print('   Output path: $outputPath');

    try {
      // Add comprehensive video validation before transition
      for (int i = 0; i < videoPaths.length; i++) {
        final videoPath = videoPaths[i];
        final videoFile = File(videoPath);

        if (!await videoFile.exists()) {
          print('❌ Video $i does not exist: $videoPath');
          return false;
        }

        final fileSize = await videoFile.length();
        print('📄 Video $i validation:');
        print('   Path: $videoPath');
        print('   Size: ${fileSize} bytes');

        if (i < videoTracks.length) {
          final track = videoTracks[i];
          print('   Expected duration: ${track.totalDuration}s');
          print('   Track ID: ${track.id}');
        }

        // Probe video details with FFmpeg
        final probeCommand = '-hide_banner -i "$videoPath" -f null -';
        final probeSession = await FFmpegKit.execute(probeCommand);
        final probeOutput = await probeSession.getOutput();

        if (probeOutput != null) {
          // Extract video dimensions and duration from output
          final dimensionMatch =
              RegExp(r'Video:.*?(\d{3,4})x(\d{3,4})').firstMatch(probeOutput);
          final durationMatch =
              RegExp(r'Duration: (\d{2}):(\d{2}):(\d{2})\.(\d{2})')
                  .firstMatch(probeOutput);

          if (dimensionMatch != null) {
            print(
                '   Actual dimensions: ${dimensionMatch.group(1)}x${dimensionMatch.group(2)}');
          }

          if (durationMatch != null) {
            final hours = int.parse(durationMatch.group(1)!);
            final minutes = int.parse(durationMatch.group(2)!);
            final seconds = int.parse(durationMatch.group(3)!);
            final centiseconds = int.parse(durationMatch.group(4)!);
            final totalSeconds =
                hours * 3600 + minutes * 60 + seconds + centiseconds / 100.0;
            print('   Actual duration: ${totalSeconds}s');
          }

          // Check for audio streams
          final hasAudio = probeOutput.contains('Audio:');
          print('   Has audio stream: $hasAudio');
        }
      }

      // For simplicity, let's handle the basic case of two videos first
      if (videoPaths.length == 2) {
        final video1 = videoPaths[0];
        final video2 = videoPaths[1];
        final rawOffsetTime =
            videoTracks[0].totalDuration; // Duration of first video

        // Ensure offset is a valid number and within reasonable bounds
        final offsetTime = rawOffsetTime.isNaN || rawOffsetTime <= 0
            ? 5.0
            : rawOffsetTime.toDouble();

        print('🎯 Processing 2-video transition:');
        print('   Video 1: $video1');
        print('   Video 2: $video2');
        print('   Raw offset time: ${rawOffsetTime}s');
        print('   Validated offset time: ${offsetTime}s');

        // Improved xfade command with better audio handling and timing
        // Handle potential audio stream issues more robustly
        final command = '-i "$video1" -i "$video2" '
            '-filter_complex "'
            '[0:v]tpad=stop_mode=clone:stop_duration=1[pad0];'
            '[pad0][1:v]xfade=transition=${transition.name}:duration=1:offset=$offsetTime[vfaded];'
            '[0:a?][1:a?]concat=n=2:v=0:a=1[afaded]' // ? handles optional audio streams
            '" '
            '-map "[vfaded]" -map "[afaded]?" ' // ? makes audio mapping optional
            '-c:v libx264 -preset medium -crf 23 -c:a aac '
            '-shortest ' // Ensure output doesn't exceed shortest stream
            '-y "$outputPath"';

        print('🔧 Complete FFmpeg command:');
        print('   $command');
        print('');

        final session = await FFmpegKit.execute(command);
        final returnCode = await session.getReturnCode();
        final output = await session.getOutput();
        final allLogs = await session.getAllLogs();

        print('📊 FFmpeg execution results:');
        print('   Return code: $returnCode');
        print('   Success: ${ReturnCode.isSuccess(returnCode)}');

        if (ReturnCode.isSuccess(returnCode)) {
          // Validate output file
          final outputFile = File(outputPath);
          if (await outputFile.exists()) {
            final outputSize = await outputFile.length();
            print('✅ Transition applied successfully');
            print('   Output file size: ${outputSize} bytes');

            // Quick probe of output file
            final outputProbeCommand =
                '-hide_banner -i "$outputPath" -f null -';
            final outputProbeSession =
                await FFmpegKit.execute(outputProbeCommand);
            final outputProbeOutput = await outputProbeSession.getOutput();

            if (outputProbeOutput != null) {
              final outputDurationMatch =
                  RegExp(r'Duration: (\d{2}):(\d{2}):(\d{2})\.(\d{2})')
                      .firstMatch(outputProbeOutput);
              if (outputDurationMatch != null) {
                final hours = int.parse(outputDurationMatch.group(1)!);
                final minutes = int.parse(outputDurationMatch.group(2)!);
                final seconds = int.parse(outputDurationMatch.group(3)!);
                final centiseconds = int.parse(outputDurationMatch.group(4)!);
                final totalSeconds = hours * 3600 +
                    minutes * 60 +
                    seconds +
                    centiseconds / 100.0;
                print('   Output duration: ${totalSeconds}s');
              }
            }

            print('🎬 === TRANSITION DEBUG END (SUCCESS) ===');
            return true;
          } else {
            print('❌ Transition command succeeded but output file missing');
            return false;
          }
        } else {
          print('❌ Primary transition failed with return code: $returnCode');

          if (output != null && output.isNotEmpty) {
            print('📝 FFmpeg stdout output:');
            print(
                '   ${output.length > 500 ? output.substring(0, 500) + '...' : output}');
          }

          if (allLogs.isNotEmpty) {
            print('📝 FFmpeg detailed logs (first 5):');
            for (int i = 0; i < math.min(allLogs.length, 5); i++) {
              final logMessage = allLogs[i].getMessage();
              if (logMessage.isNotEmpty) {
                print('   [$i]: $logMessage');
              }
            }
          }

          // Try alternative approach with simpler audio handling
          print('🔄 Attempting fallback transition approach...');
          final fallbackCommand = '-i "$video1" -i "$video2" '
              '-filter_complex "'
              '[0:v][1:v]xfade=transition=${transition.name}:duration=1:offset=$offsetTime[v];'
              '[0:a][1:a]acrossfade=d=1[a]'
              '" '
              '-map "[v]" -map "[a]" '
              '-c:v libx264 -preset fast -crf 23 -c:a aac '
              '-y "$outputPath"';

          print('🔧 Fallback FFmpeg command:');
          print('   $fallbackCommand');

          final fallbackSession = await FFmpegKit.execute(fallbackCommand);
          final fallbackReturnCode = await fallbackSession.getReturnCode();

          if (ReturnCode.isSuccess(fallbackReturnCode)) {
            final outputFile = File(outputPath);
            if (await outputFile.exists() && await outputFile.length() > 0) {
              print('✅ Fallback transition succeeded!');
              print('🎬 === TRANSITION DEBUG END (FALLBACK SUCCESS) ===');
              return true;
            }
          }

          final fallbackOutput = await fallbackSession.getOutput();
          print('❌ First fallback also failed');
          if (fallbackOutput != null && fallbackOutput.isNotEmpty) {
            print(
                '📝 Fallback error: ${fallbackOutput.substring(0, math.min(300, fallbackOutput.length))}');
          }

          // Try third approach: Simple concat without transition if all else fails
          print('🔄 Attempting simple concatenation as final fallback...');
          final tempDir = await getTemporaryDirectory();
          final concatFile = File(
              '${tempDir.path}/transition_concat_${DateTime.now().millisecondsSinceEpoch}.txt');

          final concatContent = [video1, video2]
              .map((path) => "file '${path.replaceAll("'", "\\'")}'")
              .join('\n');

          await concatFile.writeAsString(concatContent);

          final concatCommand =
              '-f concat -safe 0 -i "${concatFile.path}" -c copy -y "$outputPath"';
          print('🔧 Final fallback (concat) command:');
          print('   $concatCommand');

          final concatSession = await FFmpegKit.execute(concatCommand);
          final concatReturnCode = await concatSession.getReturnCode();

          if (ReturnCode.isSuccess(concatReturnCode)) {
            final outputFile = File(outputPath);
            if (await outputFile.exists() && await outputFile.length() > 0) {
              print(
                  '✅ Final fallback (concatenation without transition) succeeded!');
              print(
                  '🎬 === TRANSITION DEBUG END (CONCAT FALLBACK SUCCESS) ===');
              // Clean up temp concat file
              try {
                await concatFile.delete();
              } catch (e) {
                // Ignore cleanup errors
              }
              return true;
            }
          }

          print('❌ All transition approaches failed');
          print('🎬 === TRANSITION DEBUG END (ALL FAILED) ===');
          return false;
        }
      } else {
        // For multiple videos, we need to apply transitions sequentially
        // For now, let's just return false to use concatenation
        print(
            '⚠️  Multiple video transitions not yet implemented, using concatenation');
        print('🎬 === TRANSITION DEBUG END (MULTI-VIDEO SKIP) ===');
        return false;
      }
    } catch (e, stackTrace) {
      print('❌ Exception in simple transition: $e');
      print('📚 Stack trace: $stackTrace');
      print('🎬 === TRANSITION DEBUG END (EXCEPTION) ===');
      return false;
    }
  }

  /// Calculate cumulative offsets for multi-video xfade transitions
  static List<double> _calculateXFadeOffsets(
    List<VideoTrackModel> videoTracks,
    double transitionDuration,
  ) {
    List<double> offsets = [];
    double cumulativeTime = 0.0;

    for (int i = 0; i < videoTracks.length - 1; i++) {
      cumulativeTime +=
          videoTracks[i].totalDuration.toDouble() - transitionDuration;
      offsets.add(cumulativeTime);
      print(
          '🎬 XFade Offset: Video $i→${i + 1} at ${cumulativeTime.toStringAsFixed(3)}s');
    }

    return offsets;
  }

  /// Generate xfade filter chain for multiple videos (legacy - uniform transitions)
  static List<String> _generateXFadeFilterChain(
    int videoCount,
    List<double> offsets,
    String xfadeName,
    double transitionDuration,
  ) {
    List<String> filters = [];

    for (int i = 1; i < videoCount; i++) {
      // First transition: [0:v][1:v], subsequent: [vN-1][N:v]
      String inputLabel = i == 1 ? '[0:v]' : '[v${i - 1}]';

      // Last transition outputs [v], others output [vN]
      String outputLabel = i == videoCount - 1 ? '[v]' : '[v$i]';

      String filter =
          '$inputLabel[$i:v]xfade=transition=$xfadeName:duration=$transitionDuration:offset=${offsets[i - 1]}$outputLabel';
      filters.add(filter);

      print('🎬 XFade Filter $i: $filter');
    }

    return filters;
  }

  /// Generate xfade filter chain with varying transitions and durations (asset-wise)
  static List<String> _generateXFadeFilterChainWithVaryingTransitions(
    int videoCount,
    List<double> offsets,
    List<String> xfadeNames,
    List<double> transitionDurations,
  ) {
    List<String> filters = [];

    for (int i = 1; i < videoCount; i++) {
      // First transition: [0:v][1:v], subsequent: [vN-1][N:v]
      String inputLabel = i == 1 ? '[0:v]' : '[v${i - 1}]';

      // Last transition outputs [v], others output [vN]
      String outputLabel = i == videoCount - 1 ? '[v]' : '[v$i]';

      final xfadeName = xfadeNames[i - 1];
      final duration = transitionDurations[i - 1];
      final offset = offsets[i - 1];

      String filter =
          '$inputLabel[$i:v]xfade=transition=$xfadeName:duration=$duration:offset=$offset$outputLabel';
      filters.add(filter);

      print(
          '🎬 XFade Filter $i: $filter (transition=$xfadeName, duration=${duration}s)');
    }

    return filters;
  }

  /// Calculate cumulative offsets with varying transition durations (asset-wise)
  static List<double> _calculateXFadeOffsetsWithVaryingDurations(
    List<VideoTrackModel> videoTracks,
    List<double> transitionDurations,
  ) {
    List<double> offsets = [];
    double cumulativeTime = 0.0;

    for (int i = 0; i < videoTracks.length - 1; i++) {
      final transitionDuration = transitionDurations[i];
      cumulativeTime +=
          videoTracks[i].totalDuration.toDouble() - transitionDuration;
      offsets.add(cumulativeTime);
      print(
          '🎬 XFade Offset: Video $i→${i + 1} at ${cumulativeTime.toStringAsFixed(3)}s (transition: ${transitionDuration}s)');
    }

    return offsets;
  }

  /// Generate audio crossfade chain that pairs with xfade video transitions
  static String _generateAudioMixChainWithDelays(
      List<VideoTrackModel> videoTracks, double transitionDuration) {
    if (videoTracks.isEmpty) {
      return '';
    }

    if (videoTracks.length == 1) {
      // Single video, just map audio directly
      return '[0:a]acopy[a]';
    }

    if (videoTracks.length == 2) {
      // 2-video case: simple acrossfade
      final audioChain = '[0:a][1:a]acrossfade=d=$transitionDuration[a]';
      print('🎬 Audio Crossfade (2-video): $audioChain');
      return audioChain;
    }

    // Multi-video case: chain acrossfade operations like xfade
    List<String> audioFilters = [];

    // First crossfade: [0:a][1:a]acrossfade=d=1[a1]
    audioFilters.add('[0:a][1:a]acrossfade=d=$transitionDuration[a1]');
    print(
        '🎬 Audio Crossfade 1: [0:a][1:a]acrossfade=d=$transitionDuration[a1]');

    // Subsequent crossfades: [a1][2:a]acrossfade=d=1[a2], [a2][3:a]acrossfade=d=1[a3], etc.
    for (int i = 2; i < videoTracks.length; i++) {
      final prevOutput = 'a${i - 1}';
      final currentOutput = i == videoTracks.length - 1 ? 'a' : 'a$i';
      final filter =
          '[$prevOutput][${i}:a]acrossfade=d=$transitionDuration[$currentOutput]';
      audioFilters.add(filter);
      print('🎬 Audio Crossfade $i: $filter');
    }

    final fullAudioChain = audioFilters.join(';');
    print('🎬 Audio Chain with Crossfades: $fullAudioChain');

    return fullAudioChain;
  }

  /// Generate audio crossfade chain with varying transition durations (asset-wise)
  static String _generateAudioMixChainWithVaryingDelays(
      List<VideoTrackModel> videoTracks, List<double> transitionDurations) {
    if (videoTracks.isEmpty) {
      return '';
    }

    if (videoTracks.length == 1) {
      // Single video, just map audio directly
      return '[0:a]acopy[a]';
    }

    if (videoTracks.length == 2) {
      // 2-video case: simple acrossfade with custom duration
      final duration = transitionDurations[0];
      final audioChain = '[0:a][1:a]acrossfade=d=$duration[a]';
      print(
          '🎬 Audio Crossfade (2-video): $audioChain (duration=${duration}s)');
      return audioChain;
    }

    // Multi-video case: chain acrossfade operations with varying durations
    List<String> audioFilters = [];

    // First crossfade: [0:a][1:a]acrossfade=d=<duration0>[a1]
    final firstDuration = transitionDurations[0];
    audioFilters.add('[0:a][1:a]acrossfade=d=$firstDuration[a1]');
    print('🎬 Audio Crossfade 1: [0:a][1:a]acrossfade=d=$firstDuration[a1]');

    // Subsequent crossfades with varying durations
    for (int i = 2; i < videoTracks.length; i++) {
      final prevOutput = 'a${i - 1}';
      final currentOutput = i == videoTracks.length - 1 ? 'a' : 'a$i';
      final duration = transitionDurations[i - 1];
      final filter =
          '[$prevOutput][${i}:a]acrossfade=d=$duration[$currentOutput]';
      audioFilters.add(filter);
      print('🎬 Audio Crossfade $i: $filter (duration=${duration}s)');
    }

    final fullAudioChain = audioFilters.join(';');
    print('🎬 Audio Chain with Varying Crossfades: $fullAudioChain');

    return fullAudioChain;
  }

  /// Map TransitionType enum to FFmpeg xfade transition names
  static String _getXFadeTransitionName(TransitionType transition) {
    switch (transition) {
      case TransitionType.fade:
        return 'fade';
      case TransitionType.fadeblack:
        return 'fadeblack';
      case TransitionType.fadewhite:
        return 'fadewhite';
      case TransitionType.wipeleft:
        return 'wipeleft';
      case TransitionType.wiperight:
        return 'wiperight';
      case TransitionType.wipeup:
        return 'wipeup';
      case TransitionType.wipedown:
        return 'wipedown';
      case TransitionType.slideleft:
        return 'slideleft';
      case TransitionType.slideright:
        return 'slideright';
      case TransitionType.slideup:
        return 'slideup';
      case TransitionType.slidedown:
        return 'slidedown';
      case TransitionType.smoothleft:
        return 'smoothleft';
      case TransitionType.smoothright:
        return 'smoothright';
      case TransitionType.smoothup:
        return 'smoothup';
      case TransitionType.smoothdown:
        return 'smoothdown';
      case TransitionType.circlecrop:
        return 'circlecrop';
      case TransitionType.rectcrop:
        return 'rectcrop';
      case TransitionType.circleclose:
        return 'circleclose';
      case TransitionType.circleopen:
        return 'circleopen';
      case TransitionType.horzclose:
        return 'horzclose';
      case TransitionType.horzopen:
        return 'horzopen';
      case TransitionType.vertclose:
        return 'vertclose';
      case TransitionType.vertopen:
        return 'vertopen';
      case TransitionType.diagbl:
        return 'diagbl';
      case TransitionType.diagbr:
        return 'diagbr';
      case TransitionType.diagtl:
        return 'diagtl';
      case TransitionType.diagtr:
        return 'diagtr';
      case TransitionType.distance:
        return 'distance';
      case TransitionType.squeezev:
        return 'squeezev';
      case TransitionType.squeezeh:
        return 'squeezeh';
      case TransitionType.zoomin:
        return 'zoomin';
      case TransitionType.fadegrays:
        return 'fadegrays';
      case TransitionType.none:
      default:
        return 'none'; // Default fallback
    }
  }

  /// Analyze and print detailed audio codec information for debugging
  /// Returns true if audio streams found, false otherwise
  static Future<bool> _analyzeAudioCodec(String videoPath) async {
    try {
      print('🎵 Analyzing audio codec for: $videoPath');

      // Use FFprobe to get media information
      final session = await FFprobeKit.getMediaInformation(videoPath);
      final information = await session.getMediaInformation();

      if (information == null) {
        print('   ❌ Could not retrieve media information');
        return false;
      }

      // Get all streams
      final streams = information.getStreams();

      if (streams == null || streams.isEmpty) {
        print('   ⚠️  No streams found in media file');
        return false;
      }

      // Filter audio streams
      final audioStreams = streams.where((stream) {
        final codecType = stream.getAllProperties()?['codec_type'];
        return codecType == 'audio';
      }).toList();

      if (audioStreams.isEmpty) {
        print('   ⚠️  No audio streams found');
        return false;
      }

      print('   ✅ Audio streams found: ${audioStreams.length}');

      // Print detailed information for each audio stream
      for (int i = 0; i < audioStreams.length; i++) {
        final stream = audioStreams[i];
        final props = stream.getAllProperties();

        if (props == null) continue;

        final codecName = props['codec_name'] ?? 'unknown';
        final codecLongName = props['codec_long_name'] ?? '';
        final sampleRate = props['sample_rate'] ?? 'unknown';
        final channels = props['channels'] ?? 'unknown';
        final channelLayout = props['channel_layout'] ?? 'unknown';
        final bitRate = props['bit_rate'] ?? 'unknown';
        final duration = props['duration'] ?? 'unknown';

        print('   📊 Audio Stream $i:');
        print('      Codec: $codecName ($codecLongName)');
        print('      Sample Rate: $sampleRate Hz');
        print('      Channels: $channels ($channelLayout)');
        print('      Bit Rate: $bitRate bps');
        print('      Duration: $duration seconds');

        // Additional useful properties
        if (props.containsKey('profile')) {
          print('      Profile: ${props['profile']}');
        }
        if (props.containsKey('sample_fmt')) {
          print('      Sample Format: ${props['sample_fmt']}');
        }
      }

      return true;
    } catch (e) {
      print('   ❌ Error analyzing audio codec: $e');
      return false;
    }
  }
}
