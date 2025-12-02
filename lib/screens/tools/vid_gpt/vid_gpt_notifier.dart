import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:ai_video_creator_editor/database/models/generated_audio_meta.dart';
import 'package:ai_video_creator_editor/database/object_box_singleton.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/video_editor_provider.dart';
import 'package:ai_video_creator_editor/screens/tools/vid_gpt/video_gpt.dart';
import 'package:ai_video_creator_editor/screens/tools/vid_gpt/video_gpt_complete.dart';
import 'package:ai_video_creator_editor/screens/tools/vid_gpt/video_gpt_edit_chapter.dart';
import 'package:ai_video_creator_editor/utils/functions.dart';
import 'package:dio/dio.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/log.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/session.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../../components/file_image_viewer.dart';
import '../../../constants/voices_list.dart';
import '../../../controllers/azure_provider.dart';
import '../../../models/video_gpt_model.dart';
import '../../../utils/dl.dart';
import '../../../utils/http_helpers.dart';
import '../simple_video_result.dart';

class SetupLanguageController extends ChangeNotifier {
  GPTVoice gptVoice;

  SetupLanguageController({
    Map<String, dynamic>? initialLanguage,
    Map<String, dynamic>? initialGender,
    Map<String, dynamic>? initialStyle,
    Map<String, dynamic>? initialVoice,
  }) : gptVoice = GPTVoice(
          language: initialLanguage ?? allLanguagesList[0],
          gender: initialGender ?? msVoicesGenderList[0],
          style: initialStyle ?? msStylesList[0],
          voice: initialVoice ??
              msVoicesList.firstWhere(
                (element) =>
                    element["LocaleName"] == allLanguagesList[0]["model_id"],
              ),
        );

  void updateLanguage(Map<String, dynamic> language) {
    gptVoice = gptVoice.copyWith(language: language);
    notifyListeners();
  }

  void updateGender(Map<String, dynamic> gender) {
    gptVoice = gptVoice.copyWith(gender: gender);
    notifyListeners();
  }

  void updateVoiceStyle(Map<String, dynamic> style) {
    gptVoice = gptVoice.copyWith(style: style);
    notifyListeners();
  }

  void updateVoice(Map<String, dynamic> voice) {
    gptVoice = gptVoice.copyWith(voice: voice);
    notifyListeners();
  }

  // Getters for values
  Map<String, dynamic> get language => gptVoice.language;

  Map<String, dynamic> get gender => gptVoice.gender;

  Map<String, dynamic> get style => gptVoice.style;

  Map<String, dynamic> get voice => gptVoice.voice;

  List<Map<String, dynamic>> setVoices() {
    String lang = gptVoice.language["model_id"];
    String gender = gptVoice.gender["model_id"];
    String style = gptVoice.style["model_id"];

    List<Map<String, dynamic>>? filteredList = msVoicesList
        .where((element) =>
            (lang == ""
                ? (element["LocaleName"]).isNotEmpty
                : element["LocaleName"] == lang) &&
            (gender == ""
                ? (element["Gender"]).isNotEmpty
                : element["Gender"] == gender) &&
            (style == ""
                ? (element["StyleList"] as List).isEmpty
                : ((element["StyleList"] as List).contains(style))))
        .toList();
    return filteredList;
  }

  Map<String, dynamic> firstVoiceInLang() => msVoicesList.firstWhere(
        (element) => element["LocaleName"] == gptVoice.language["model_id"],
      );

  Future<VideoGptModel?> videoGpt({
    required Map<String, dynamic> data,
    required bool generateText,
    required bool generateAudio,
  }) async {
    // var headers = await URLS.headers();
    // String url = URLS.videoGpt;
    try {
      // Response response = await HTTPHelperApi().dioPost(
      //   url: url,
      //   headers: headers,
      //   data: data,
      // );
      Response response = await HTTPHelperApi().dioGet(
        url:
            "https://raw.githubusercontent.com/evanswanyoike/evanswanyoike.github.io/refs/heads/main/vid.json",
        headers: {},
        data: data,
      );
      Map<String, dynamic> resData = jsonDecode(response.data);
      resData["generateText"] = generateText;
      resData["generateAudio"] = generateAudio && generateText;
      VideoGptModel videoGptModel = VideoGptModel.fromJson(resData);
      return videoGptModel;
    } on DioException catch (error) {
      safePrint(error.response?.data);
      rethrow;
    }
  }

  /// generate all voices
  List<VideoGPTFinalValue> allVideoGPTFinalValue = [];

  upDateAllVideoGPTFinalValueList(List<VideoGPTFinalValue> val) {
    allVideoGPTFinalValue = val;
    notifyListeners();
  }

  Future<void> generateAudioFileAndVideoFile({
    required BuildContext context,
    required List<Data> data,
    required bool generateText,
    required bool generateAudio,
    required GptOrientation orientation,
    required SubtitleConfig subtitleConfig,
  }) async {
    safePrint("🚀 ========== GENERATE AUDIO/VIDEO FILES STARTED ==========");
    safePrint("📊 INPUT PARAMETERS:");
    safePrint("   Data segments: ${data.length}");
    safePrint("   Generate text: $generateText");
    safePrint("   Generate audio: $generateAudio");
    safePrint("   Orientation: $orientation");
    safePrint("   Subtitle enabled: ${subtitleConfig.enabled}");

    if (data.isEmpty) {
      safePrint("❌ ERROR: No data segments provided - aborting process");
      return;
    }
    final azureProvider = context.read<AzureProvider>();
    safePrint(
        "🔄 Starting concurrent processing of ${data.length} segments...");

    // Process all items concurrently
    final List<Future<VideoGPTFinalValue?>> tasks = data.map((value) async {
      try {
        safePrint(
            "📝 Processing segment: '${value.prompt?.substring(0, 50) ?? 'No prompt'}...'");
        // Generate audio file
        // File? audioFile = !generateAudio
        //     ? null
        //     : await azureProvider.azureTTS(
        //         context,
        //         gender: gptVoice.genderValue,
        //         voice: gptVoice.voiceValue,
        //         script: value.prompt ?? "",
        //         returnTempPath: true,
        //       );

        File? audioFile;

        // Only generate audio if generateAudio is enabled
        if (generateAudio) {
          GeneratedAudioMeta? generatedAudioMeta = value.generatedAudioId == null
              ? null
              : await ObjectBoxSingleTon.instance
                  .getGeneratedAudioMeta(value.generatedAudioId!);
          if (generatedAudioMeta != null) {
            // Use original full-length audio for VideoGPT export, not trimmed version
            audioFile = File(generatedAudioMeta.originalFilePath!);
            safePrint(
                "📻 Using original full-length audio: ${generatedAudioMeta.originalFilePath}");
          } else {
            final generatedAudio = await azureProvider.azureTTS(
              context,
              gender: gptVoice.genderValue,
              voice: gptVoice.voiceValue,
              script: value.prompt ?? "",
              returnTempPath: true,
            );
            if (generatedAudio != null) {
              // Keep full audio duration - no trimming
              // Video will be adjusted to match audio duration in createNarrationVideo
              safePrint(
                  "🎵 Generated new full-length audio: ${generatedAudio.path}");
              final newMeta = GeneratedAudioMeta(
                id: 0,
                prompt: value.prompt ?? "",
                originalFilePath: generatedAudio.path,
                trimmedFilePath: generatedAudio.path, // Use original path
              );
              value.generatedAudioId = await ObjectBoxSingleTon.instance
                  .putGeneratedAudioMeta(newMeta);
              audioFile = generatedAudio; // Use original audio file
            }
          }
        } else {
          safePrint("🔇 Audio generation skipped (muted mode)");
        }

        // Generate video file
        final videoFile = await saveFileToTemp(
            urlPath: value.video?.videoFiles
                    ?.getVideoWithOrientation(orientation)
                    .link ??
                "");

        // Skip this item if video file is null, or if audio is required but null
        if (videoFile == null || (generateAudio && audioFile == null)) {
          safePrint(
              "Skipping item because ${videoFile == null ? 'video' : 'audio'} file is null for prompt: ${value.prompt}");
          return null;
        }
        // Return processed value
        final finalValue = VideoGPTFinalValue(
          prompt: value.prompt ?? "",
          videoFile: videoFile,
          audioFile: audioFile,
        );
        safePrint(
            "Created VideoGPTFinalValue with prompt: '${finalValue.prompt}'");
        return finalValue;
      } catch (err, stackTrace) {
        // Log the error
        safePrint("Error processing data item: $err");
        safePrint(stackTrace.toString());
        return null; // Skip this item on error
      }
    }).toList();
    // Wait for all tasks to complete
    safePrint(
        "⏳ Waiting for all ${tasks.length} concurrent tasks to complete...");
    final results = await Future.wait(tasks);
    // Filter out null results and update the list
    allVideoGPTFinalValue.clear();
    allVideoGPTFinalValue.addAll(
      results.whereType<VideoGPTFinalValue>(),
    );
    safePrint(
        "✅ Completed processing: ${allVideoGPTFinalValue.length}/${results.length} segments successful");

    safePrint("Final video values for processing:");
    for (int i = 0; i < allVideoGPTFinalValue.length; i++) {
      safePrint("Video ${i + 1}: '${allVideoGPTFinalValue[i].prompt}'");
    }

    // Notify listeners about updates
    notifyListeners();

    safePrint("🎬 ========== STARTING FINAL VIDEO EXPORT PROCESS ==========");
    safePrint("📊 Export Summary:");
    safePrint("   - Total segments: ${allVideoGPTFinalValue.length}");
    safePrint("   - Subtitle enabled: ${subtitleConfig.enabled}");
    safePrint("   - Font size: ${subtitleConfig.fontSize}");
    safePrint("   - Font color: ${subtitleConfig.fontColor}");
    safePrint("   - Background color: ${subtitleConfig.backgroundColor}");
    safePrint("   - Position: ${subtitleConfig.position}");

    try {
      await createNarrationVideo(
          videoValues: allVideoGPTFinalValue,
          context: context,
          subtitleConfig: subtitleConfig);
    } catch (err) {
      safePrint(err.toString());
      rethrow;
    }
  }

  ///
  // Future<File> createNarrationVideo({
  //   required List<VideoGPTFinalValue> videoValues,
  //   String fontColor = "white",
  //   int fontSize = 24,
  //   required BuildContext context,
  // }) async {
  //   try {
  //     // Get the temporary directory to save the output file
  //     final tempDir = await getTemporaryDirectory();
  //     final outputPath = join(tempDir.path,
  //         '${DateTime.now().millisecondsSinceEpoch}_narration_video.mp4');
  //
  //     // Build the FFmpeg command
  //     List<String> command = [];
  //
  //     // First, add all video inputs
  //     for (var video in videoValues) {
  //       command.addAll(['-i', video.videoFile.path]);
  //     }
  //
  //     // Then add all audio inputs
  //     for (var video in videoValues) {
  //       command.addAll(['-i', video.audioFile.path]);
  //     }
  //
  //     // Create the filter_complex string
  //     String filterComplex = "";
  //     List<String> segmentFilters = [];
  //
  //     // Process each video and audio pair
  //     for (var i = 0; i < videoValues.length; i++) {
  //       final video = videoValues[i];
  //       final videoIndex = i;
  //       final audioIndex = i + videoValues.length;
  //
  //       // Escape special characters in the prompt text
  //       String escapedPrompt = video.prompt
  //           .replaceAll("'", "\\'")
  //           .replaceAll(":", "\\:")
  //           .replaceAll(",", "\\,");
  //
  //       // 1. Prepare the video - scale, pad and loop it to match audio duration
  //       // The apad filter ensures audio stream doesn't end before video
  //       // The setpts filter ensures proper timing
  //       String videoFilter = "[$videoIndex:v]" +
  //           "scale=1920:1080:force_original_aspect_ratio=decrease," +
  //           "pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black," +
  //           "fps=30," +
  //           "drawtext=text='$escapedPrompt':" +
  //           "fontcolor=$fontColor:fontsize=$fontSize:" +
  //           "x=(w-text_w)/2:y=h-(text_h*2):" +
  //           "box=1:boxcolor=black@0.5:boxborderw=5," +
  //           "loop=loop=-1:size=10000:start=0," +
  //           "setpts=N/FRAME_RATE/TB[v${i}_prepared];";
  //
  //       // 2. Get the audio duration and trim/extend video to match
  //       String audioDurationFilter =
  //           "[$audioIndex:a]aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=stereo[a${i}_format];";
  //
  //       // 3. Combine the video and audio for this segment
  //       // The shortest=1 ensures the segment ends when either audio or video ends
  //       // Since we're looping the video, it will end when audio ends
  //       String segmentFilter = "[v${i}_prepared][a${i}_format]" +
  //           "trim=duration=shortest," +
  //           "setpts=PTS-STARTPTS," +
  //           "asetpts=PTS-STARTPTS[v${i}_final][a${i}_final];";
  //
  //       segmentFilters.add(videoFilter + audioDurationFilter + segmentFilter);
  //     }
  //
  //     // Add all segment filters to filter_complex
  //     filterComplex += segmentFilters.join("");
  //
  //     // Create the concat filter for processed videos
  //     String concatVideos = "";
  //     for (var i = 0; i < videoValues.length; i++) {
  //       concatVideos += "[v${i}_final]";
  //     }
  //     concatVideos += "concat=n=${videoValues.length}:v=1:a=0[outv];";
  //
  //     // Create the concat filter for processed audios
  //     String concatAudios = "";
  //     for (var i = 0; i < videoValues.length; i++) {
  //       concatAudios += "[a${i}_final]";
  //     }
  //     concatAudios += "concat=n=${videoValues.length}:v=0:a=1[outa]";
  //
  //     // Combine all parts of the filter_complex
  //     filterComplex += concatVideos + concatAudios;
  //
  //     // Add the filter_complex to the command
  //     command.addAll([
  //       "-filter_complex", filterComplex,
  //       "-map", "[outv]",
  //       "-map", "[outa]",
  //       "-c:v", "mpeg4",
  //       "-b:v", "2M",
  //       "-c:a", "aac",
  //       "-b:a", "192k",
  //       "-shortest", // End when shortest input stream ends
  //       "-y",
  //       outputPath
  //     ]);
  //
  //     // For debugging, log the complete command
  //     safePrint("FFmpeg command: ${command.join(' ')}");
  //
  //     // Execute FFmpeg command
  //     copy(command.join(' '));
  //     final session = await FFmpegKit.executeWithArguments(command);
  //     final returnCode = await session.getReturnCode();
  //
  //     // Log the command for debugging
  //
  //     listAllLogs(session);
  //
  //     if (returnCode?.isValueSuccess() == true) {
  //       Navigator.push(
  //         context,
  //         MaterialPageRoute(
  //           builder: (context) => SimpleVideoResult(
  //             videoFilePath: outputPath,
  //             betterPlayerDataSourceType: FileDataSourceType.file,
  //           ),
  //         ),
  //       );
  //       return File(outputPath);
  //     } else {
  //       final error = await session.getAllLogsAsString();
  //       throw Exception('FFmpeg failed with error: $error');
  //     }
  //   } catch (e) {
  //     throw Exception('Error creating narration video: $e');
  //   }
  // }

  /// works kinda
  ///   An Exception if FFmpeg/FFprobe fails or another error occurs.
  Future<File> createNarrationVideo({
    required List<VideoGPTFinalValue> videoValues,
    required BuildContext context,
    required SubtitleConfig subtitleConfig,
  }) async {
    if (videoValues.isEmpty) {
      throw Exception("Cannot create video with empty input list.");
    }

    final int numSegments = videoValues.length;

    safePrint("🎥 ========== VIDEOGPT EXPORT PROCESS STARTED ==========");
    safePrint("📊 EXPORT SUMMARY:");
    safePrint("   Total video segments: $numSegments");
    safePrint("   Subtitle enabled: ${subtitleConfig.enabled}");
    safePrint("   Subtitle position: ${subtitleConfig.position.displayName}");
    safePrint("   Subtitle font size: ${subtitleConfig.fontSize}");
    safePrint("🔄 Starting duration analysis and video processing...\n");
    String? tempSrtPath; // To store the path for cleanup

    try {
      // --- Prepare SRT File Path (will generate after duration calculations) ---
      final Directory tempDir = await getTemporaryDirectory();
      tempSrtPath = join(tempDir.path,
          '${DateTime.now().millisecondsSinceEpoch}_subtitles.srt');

      // --- Output Path ---
      final String outputPath = join(tempDir.path,
          '${DateTime.now().millisecondsSinceEpoch}_narration_video_srt.mp4'); // Updated name

      // --- Build FFmpeg Command ---
      final List<String> command = [];

      // 1. Add all video inputs
      for (final videoData in videoValues) {
        if (!await videoData.videoFile.exists()) {
          throw Exception(
              "Input video file not found: ${videoData.videoFile.path}");
        }
        command.addAll(['-i', videoData.videoFile.path]);
      }

      // 2. Add all audio inputs (only if audio files exist)
      final bool hasAudio = videoValues.every((v) => v.audioFile != null);
      if (hasAudio) {
        for (final videoData in videoValues) {
          if (!await videoData.audioFile!.exists()) {
            throw Exception(
                "Input audio file not found: ${videoData.audioFile!.path}");
          }
          command.addAll(['-i', videoData.audioFile!.path]);
        }
      } else {
        safePrint("🔇 No audio files - creating video-only output");
      }

      // 3. Build the filter_complex string (Scale, Pad, Concat ONLY)
      // 3. Build the filter_complex string (Scale, Pad, Concat + Subtitles Integration)
      final StringBuffer filterComplex = StringBuffer();
      final List<String> concatInputs = [];
      // Define the final video output label from the filter complex.
      // It will be '[outv_sub]' if subtitles are added, otherwise '[outv]'.
      String finalVideoOutputLabel = "[outv]";

      // Part 1: Process individual segments with duration matching (scale, pad, fps, trim/loop)
      for (int i = 0; i < numSegments; i++) {
        final int videoInputIndex = i;
        final int audioInputIndex = hasAudio ? i + numSegments : -1;
        final videoData = videoValues[i];

        // Get actual durations for video and audio using VideoEditorProvider
        final videoEditorProvider = context.read<VideoEditorProvider>();
        final videoDuration = await videoEditorProvider
            .getMediaDuration(videoData.videoFile.path);
        final audioDuration = hasAudio
            ? await videoEditorProvider
                .getMediaDuration(videoData.audioFile!.path)
            : videoDuration; // Use video duration when no audio

        safePrint("=== SEGMENT $i DURATION ANALYSIS ===");
        safePrint("Video file: ${videoData.videoFile.path}");
        safePrint("Audio file: ${hasAudio ? videoData.audioFile!.path : 'None (muted)'}");
        safePrint("Video duration: ${videoDuration}s");
        safePrint("Audio duration: ${audioDuration}s");
        safePrint(
            "Duration difference: ${(videoDuration - audioDuration).abs()}s");

        String videoFilter;

        if (videoDuration > audioDuration) {
          // Case 1: Video longer than audio - TRIM video to match audio duration
          final trimAmount = videoDuration - audioDuration;
          safePrint("🎬 ACTION: TRIMMING VIDEO");
          safePrint("   Original video duration: ${videoDuration}s");
          safePrint("   Target audio duration: ${audioDuration}s");
          safePrint("   Amount to trim: ${trimAmount}s");
          safePrint("   FFmpeg filter: trim=duration=$audioDuration");

          videoFilter = "[$videoInputIndex:v]"
              "trim=duration=$audioDuration,"
              "scale=1920:1080:force_original_aspect_ratio=decrease,"
              "pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black,"
              "fps=30"
              "[v$i]";
        } else if (videoDuration < audioDuration) {
          // Case 2: Video shorter than audio - LOOP video to match audio duration
          final loops = (audioDuration / videoDuration).ceil();
          final totalLoopDuration = loops * videoDuration;
          final finalTrimAmount = totalLoopDuration - audioDuration;

          safePrint("🔄 ACTION: LOOPING VIDEO");
          safePrint("   Original video duration: ${videoDuration}s");
          safePrint("   Target audio duration: ${audioDuration}s");
          safePrint("   Number of loops needed: $loops");
          safePrint("   Total duration after looping: ${totalLoopDuration}s");
          safePrint("   Final trim amount: ${finalTrimAmount}s");
          safePrint(
              "   FFmpeg filters: loop=loop=${loops - 1} + trim=duration=$audioDuration");

          videoFilter = "[$videoInputIndex:v]"
              "loop=loop=${loops - 1}:size=32767:start=0,"
              "trim=duration=$audioDuration,"
              "scale=1920:1080:force_original_aspect_ratio=decrease,"
              "pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black,"
              "fps=30"
              "[v$i]";
        } else {
          // Case 3: Same duration - process normally
          safePrint("✅ ACTION: NO DURATION ADJUSTMENT NEEDED");
          safePrint("   Video duration: ${videoDuration}s");
          safePrint("   Audio duration: ${audioDuration}s");
          safePrint("   Perfect match - applying standard processing only");

          videoFilter = "[$videoInputIndex:v]"
              "scale=1920:1080:force_original_aspect_ratio=decrease,"
              "pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black,"
              "fps=30"
              "[v$i]";
        }

        filterComplex.write(videoFilter);
        filterComplex.write(";");

        if (hasAudio) {
          concatInputs.add("[v$i][${audioInputIndex}:a]");
        } else {
          concatInputs.add("[v$i]");
        }

        safePrint("📝 Generated filter for segment $i: $videoFilter");
        safePrint("=== END SEGMENT $i PROCESSING ===\n");
      }

      // Part 2: Concatenate the video/audio pairs
      safePrint("🔗 CONCATENATION PHASE");
      safePrint("Total segments to concatenate: $numSegments");
      safePrint("Concat inputs: $concatInputs");

      filterComplex.writeAll(concatInputs);
      if (hasAudio) {
        filterComplex.write(
            "concat=n=$numSegments:v=1:a=1[outv][outa]"); // Outputs [outv] and [outa]
      } else {
        filterComplex.write(
            "concat=n=$numSegments:v=1:a=0[outv]"); // Video only output
      }

      safePrint(
          "✅ Concatenation filter applied: concat=n=$numSegments:v=1:a=${hasAudio ? '1' : '0'}");

      // --- Generate SRT File with Correct Timing ---
      // Only generate subtitles if audio exists
      if (subtitleConfig.enabled && hasAudio) {
        await _generateSrtFileWithCorrectTiming(
            videoValues, tempSrtPath, context);
      } else if (subtitleConfig.enabled && !hasAudio) {
        safePrint("⚠️ Subtitles disabled - no audio available (muted mode)");
      }

      // --- Integration of Subtitles Filter ---
      // Part 3: Apply subtitles filter *within* the complex graph if SRT exists
      if (subtitleConfig.enabled && hasAudio && await File(tempSrtPath).exists()) {
        final String escapedSrtPath =
            _escapeFFmpegArgument(tempSrtPath); // Use your escaping function

        // Build the force_style string with subtitle configuration
        final String forceStyle = 'FontName=Roboto,'
            'FontSize=${subtitleConfig.fontSize.toInt()},'
            'PrimaryColour=${subtitleConfig.colorToHex(subtitleConfig.fontColor)},'
            'BackColour=${subtitleConfig.colorToHex(subtitleConfig.backgroundColor)},'
            'Alignment=${subtitleConfig.position.ffmpegAlignment},'
            'WrapStyle=0,'
            'MarginL=60,'
            'MarginR=60,'
            'Outline=2,'
            'Shadow=1';

        safePrint("Subtitle styling: $forceStyle");

        // Append the subtitles filter, taking [outv] as input and creating [outv_sub]
        // Use the subtitle configuration for styling
        filterComplex
            .write(";[outv]subtitles=$escapedSrtPath:fontsdir='/system/fonts/':"
                "force_style='$forceStyle'"
                "[outv_sub]");

        ///
        finalVideoOutputLabel = "[outv_sub]"; // Update the final label to map
        safePrint(
            "Applying subtitles filter within filter_complex using $escapedSrtPath");
      } else {
        safePrint(
            "Warning: SRT file not found or not generated. Skipping subtitles filter application.");
        // finalVideoOutputLabel remains "[outv]"
      }
      // --- End Subtitles Integration ---

      // 4. Add the complete filter_complex and map the FINAL streams
      command.addAll([
        '-filter_complex', filterComplex.toString(),
        '-map',
        finalVideoOutputLabel,
        // Map the final video stream (e.g., '[outv_sub]' or '[outv]')
      ]);

      // Only map audio stream if audio exists
      if (hasAudio) {
        command.addAll([
          '-map',
          '[outa]',
          // Map the concatenated audio stream
        ]);
      }

      // 5. Remove the separate -vf option (it's now inside filter_complex)
      // REMOVED: command.addAll(['-vf', 'subtitles=filename=$escapedSrtPath']);

      // 6. Add output options
      command.addAll([
        '-c:v',
        'libx264',
        '-pix_fmt',
        'yuv420p',
      ]);

      // Only add audio encoding options if audio exists
      if (hasAudio) {
        command.addAll([
          '-c:a',
          'aac',
          '-b:a',
          '192k',
        ]);
      }

      command.addAll([
        '-movflags',
        '+faststart',
        '-preset',
        'veryfast',
        '-y',
        outputPath
      ]);

      // --- Execute FFmpeg Command ---
      safePrint("🚀 FFMPEG EXECUTION PHASE");
      safePrint("--- Starting FFmpeg Execution (SRT Subtitles) ---");
      final String commandString = FFmpegKitConfig.argumentsToString(command);
      safePrint("📋 Complete FFmpeg Command:");
      safePrint("$commandString");
      safePrint("📁 Output file will be: $outputPath");

      final Session session = await FFmpegKit.executeWithArguments(command);
      final ReturnCode? returnCode = await session.getReturnCode();

      // --- Handle Result ---
      safePrint("--- FFmpeg Execution Finished ---");

      if (ReturnCode.isSuccess(returnCode)) {
        safePrint("FFmpeg process completed successfully (SRT Subtitles).");
        safePrint("Output file: $outputPath");

        // ignore: use_build_context_synchronously
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SimpleVideoResult(
                videoFilePath: outputPath,
                betterPlayerDataSourceType: FileDataSourceType.file,
              ),
            ),
          );
        } else {
          safePrint(
              "Warning: BuildContext was unmounted before navigation could occur.");
        }
        return File(outputPath);
      } else {
        // Handle Cancel and Error together for simplicity here
        final rcValue = returnCode?.getValue();
        final bool cancelled = ReturnCode.isCancel(returnCode);
        safePrint("FFmpeg process ${cancelled ? 'cancelled' : 'failed'}.");
        safePrint("FFmpeg Return Code: $rcValue");

        // --- Detailed Log Retrieval ---
        safePrint(
            "--- Detailed FFmpeg Logs Start (${cancelled ? 'Cancel' : 'Error'}) ---");
        final List<Log> logs = await session.getAllLogs();
        if (logs.isEmpty) {
          safePrint(
              "No logs captured by session.getAllLogs(). Attempting getAllLogsAsString...");
          final String? logString = await session.getAllLogsAsString();
          safePrint(logString ?? "No log string available either.");
        } else {
          for (final log in logs) {
            safePrint(
                "FFmpeg Log [${log.getLevel()}]: ${log.getMessage().trim()}");
          }
        }
        // Also print the full log string as a fallback
        final String? fallbackLogString = await session.getAllLogsAsString();
        safePrint(
            "--- Fallback Full Log String (${cancelled ? 'Cancel' : 'Error'}) ---");
        safePrint(fallbackLogString ?? "No fallback log string available.");
        safePrint("--- Detailed FFmpeg Logs End ---");

        // Clean up potentially incomplete output file
        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          try {
            await outputFile.delete();
            safePrint("Deleted incomplete output file: $outputPath");
          } catch (deleteError) {
            safePrint("Error deleting incomplete output file: $deleteError");
          }
        }

        throw Exception(
            'FFmpeg ${cancelled ? 'cancelled' : 'failed'} with Return Code: $rcValue. Check console logs for details.');
      }
    } catch (e, s) {
      safePrint("Error creating SRT subtitled video: $e");
      safePrint("Stack trace: $s");
      throw Exception('Error creating SRT subtitled video: $e');
    } finally {
      // --- Cleanup SRT File ---
      if (tempSrtPath != null) {
        try {
          final srtFile = File(tempSrtPath);
          if (await srtFile.exists()) {
            await srtFile.delete();
            safePrint("Deleted temporary SRT file: $tempSrtPath");
          }
        } catch (e) {
          safePrint("Error deleting temporary SRT file '$tempSrtPath': $e");
        }
      }
    }
  }

  // --- Helper Functions ---

  /// Generates an SRT subtitle file with voice-aware timing based on selected voice characteristics.
  Future<void> _generateSrtFileWithCorrectTiming(
      List<VideoGPTFinalValue> videoValues,
      String srtPath,
      BuildContext context) async {
    final StringBuffer srtContent = StringBuffer();
    Duration cumulativeDuration = Duration.zero;
    int sequenceNumber = 1;

    safePrint("Generating SRT file with correct timing at: $srtPath");
    safePrint("Number of video segments: ${videoValues.length}");

    // Get voice characteristics for better timing
    final voiceWPM =
        int.tryParse(gptVoice.voice["WordsPerMinute"]?.toString() ?? "150") ??
            150;
    final language = gptVoice.langValue;
    safePrint("🎙️ Voice-aware subtitle generation:");
    safePrint("   Voice WPM: $voiceWPM");
    safePrint("   Language: $language");
    safePrint("   Voice: ${gptVoice.voice["LocalName"]}");

    final videoEditorProvider = context.read<VideoEditorProvider>();

    for (int i = 0; i < videoValues.length; i++) {
      final videoData = videoValues[i];
      safePrint("Processing segment ${sequenceNumber}: '${videoData.prompt}'");

      // Get the actual final duration (audio duration, which video is trimmed/looped to match)
      final audioDuration = videoData.audioFile != null
          ? await videoEditorProvider.getMediaDuration(videoData.audioFile!.path)
          : 0;

      if (audioDuration <= 0) {
        safePrint(
            "Warning: Audio duration is zero or invalid for ${videoData.audioFile?.path ?? 'null'}. Skipping subtitle entry.");
        continue;
      }

      final segmentDuration = Duration(seconds: audioDuration);
      safePrint("Final segment duration: ${segmentDuration.inSeconds} seconds");

      // 2. Use voice-aware chunking for this segment
      final cleanedPrompt = videoData.prompt.trim().replaceAll('\n\n', '\n');
      final chunks = _intelligentChunking(cleanedPrompt, language, voiceWPM);

      safePrint("📝 Generated ${chunks.length} voice-aware chunks for segment");

      // 3. Calculate timing for each chunk within this segment
      Duration chunkStartTime = cumulativeDuration;

      for (int chunkIndex = 0; chunkIndex < chunks.length; chunkIndex++) {
        final chunkText = chunks[chunkIndex];

        // Calculate voice-based duration for this chunk
        final chunkDuration =
            _calculateVoiceBasedDuration(chunkText, voiceWPM, language);
        final chunkEndTime = chunkStartTime + chunkDuration;

        // Ensure we don't exceed the segment duration
        final maxEndTime = cumulativeDuration + segmentDuration;
        final adjustedEndTime =
            chunkEndTime.compareTo(maxEndTime) > 0 ? maxEndTime : chunkEndTime;

        // Format SRT block for this chunk
        srtContent.writeln(sequenceNumber);
        srtContent.writeln(
            '${_formatSrtTime(chunkStartTime)} --> ${_formatSrtTime(adjustedEndTime)}');
        srtContent.writeln(chunkText);
        srtContent.writeln(); // Blank line separator

        safePrint(
            "📝 Chunk $sequenceNumber: '$chunkText' (${chunkDuration.inSeconds}s)");

        chunkStartTime = adjustedEndTime;
        sequenceNumber++;
      }

      // Adjust sequence number since we added multiple chunks
      sequenceNumber--; // Will be incremented at the end of the loop

      // 4. Update cumulative duration and sequence number
      cumulativeDuration += segmentDuration;
      sequenceNumber++;
    }

    // 5. Write the SRT content to the file
    try {
      final File srtFile = File(srtPath);
      final srtContentString = srtContent.toString();
      await srtFile.writeAsString(srtContentString);
      safePrint("SRT file generated successfully.");
      safePrint("SRT Content:\n$srtContentString");
    } catch (e) {
      safePrint("Error writing SRT file '$srtPath': $e");
      throw Exception("Failed to write SRT file: $e");
    }
  }

  /// Formats a Duration object into SRT time format (HH:MM:SS,ms).
  String _formatSrtTime(Duration d) {
    final int totalMs = d.inMilliseconds;
    final int ms = totalMs % 1000;
    final int totalSeconds = totalMs ~/ 1000;
    final int seconds = totalSeconds % 60;
    final int totalMinutes = totalSeconds ~/ 60;
    final int minutes = totalMinutes % 60;
    final int hours = totalMinutes ~/ 60;

    final String hoursStr = hours.toString().padLeft(2, '0');
    final String minutesStr = minutes.toString().padLeft(2, '0');
    final String secondsStr = seconds.toString().padLeft(2, '0');
    final String msStr = ms.toString().padLeft(3, '0');

    return '$hoursStr:$minutesStr:$secondsStr,$msStr';
  }

  /// Escapes an argument for the FFmpeg command line.
  /// Puts single quotes around it and escapes internal single quotes.
  /// Adjust if needed based on how FFmpegKit handles arguments on the target OS.
  String _escapeFFmpegArgument(String argument) {
    // Escape single quotes within the argument for safe enclosure in single quotes
    final escapedInternal = argument.replaceAll("'", "'\\''");
    // Enclose the whole argument in single quotes
    return "'$escapedInternal'";
    // Alternative for paths - sometimes simpler escaping works if paths are well-formed
    // return argument.replaceAll(r'\', r'\\').replaceAll("'", "'\\''"); // Less safe if spaces are present
  }
}

class VideoGPTFinalValue {
  final String prompt;
  final File videoFile;
  final File? audioFile;

  @override
  toString() {
    return "prompt: $prompt, videoFile: ${videoFile.path}, audioFile: ${audioFile?.path ?? 'null'}";
  }

  VideoGPTFinalValue({
    required this.prompt,
    required this.videoFile,
    this.audioFile,
  });
}

class GPTVoice {
  Map<String, dynamic> language;
  Map<String, dynamic> gender;
  Map<String, dynamic> style;
  Map<String, dynamic> voice;

  GPTVoice({
    required this.language,
    required this.gender,
    required this.style,
    required this.voice,
  });

  get langValue => language["model_id"];

  get genderValue => gender["model_id"];

  get styleValue => style["model_id"];

  get voiceValue => voice["ShortName"];

  GPTVoice copyWith({
    Map<String, dynamic>? language,
    Map<String, dynamic>? gender,
    Map<String, dynamic>? style,
    Map<String, dynamic>? voice,
  }) {
    return GPTVoice(
      language: language ?? this.language,
      gender: gender ?? this.gender,
      style: style ?? this.style,
      voice: voice ?? this.voice,
    );
  }
}

// === Voice-Aware Subtitle Helper Methods ===

extension VoiceAwareSubtitles on SetupLanguageController {
  /// Intelligently chunks text based on language and voice characteristics
  List<String> _intelligentChunking(
      String text, String language, int voiceWPM) {
    // Clean the text first
    final cleanText =
        text.trim().replaceAll('\n\n', '\n').replaceAll('\n', ' ');

    // Choose chunking strategy based on language
    switch (language) {
      case "English (United States)":
      case "English (United Kingdom)":
      case "English (Australia)":
      case "English (Canada)":
        return _chunkEnglishText(cleanText, voiceWPM);
      case "Spanish (Spain)":
      case "Spanish (Mexico)":
        return _chunkSpanishText(cleanText, voiceWPM);
      case "Chinese (China)":
      case "Chinese (Taiwan)":
        return _chunkChineseText(cleanText, voiceWPM);
      default:
        return _chunkGenericText(cleanText, voiceWPM);
    }
  }

  /// English-specific text chunking with natural breaks
  List<String> _chunkEnglishText(String text, int voiceWPM) {
    final chunks = <String>[];

    // First, split by major punctuation
    final sentences = text.split(RegExp(r'[.!?:]\s+'));

    for (String sentence in sentences) {
      if (sentence.trim().isEmpty) continue;

      // If sentence is short enough, use as-is
      if (sentence.split(' ').length <= 6) {
        chunks.add(sentence.trim());
        continue;
      }

      // Break long sentences at commas and conjunctions
      final subChunks =
          sentence.split(RegExp(r',\s+|;\s+|\s+and\s+|\s+but\s+|\s+or\s+'));

      String currentChunk = '';
      for (String subChunk in subChunks) {
        final testChunk =
            currentChunk.isEmpty ? subChunk : '$currentChunk, $subChunk';

        if (testChunk.split(' ').length <= 6) {
          currentChunk = testChunk;
        } else {
          if (currentChunk.isNotEmpty) {
            chunks.add(currentChunk.trim());
          }
          currentChunk = subChunk;
        }
      }

      if (currentChunk.isNotEmpty) {
        chunks.add(currentChunk.trim());
      }
    }

    return chunks.where((chunk) => chunk.isNotEmpty).toList();
  }

  /// Spanish-specific text chunking
  List<String> _chunkSpanishText(String text, int voiceWPM) {
    // Spanish tends to have longer words, so slightly smaller chunks
    return _chunkByWordCount(text, 5);
  }

  /// Chinese-specific text chunking
  List<String> _chunkChineseText(String text, int voiceWPM) {
    // Chinese characters convey more meaning, can have longer chunks
    return _chunkByCharacterCount(text, 60);
  }

  /// Generic text chunking for other languages
  List<String> _chunkGenericText(String text, int voiceWPM) {
    return _chunkByWordCount(text, 5);
  }

  /// Simple word-count based chunking
  List<String> _chunkByWordCount(String text, int wordsPerChunk) {
    final words = text.split(' ');
    final chunks = <String>[];

    for (int i = 0; i < words.length; i += wordsPerChunk) {
      final end =
          (i + wordsPerChunk < words.length) ? i + wordsPerChunk : words.length;
      chunks.add(words.sublist(i, end).join(' '));
    }

    return chunks;
  }

  /// Character-count based chunking (useful for CJK languages)
  List<String> _chunkByCharacterCount(String text, int maxCharsPerChunk) {
    final words = text.split(' ');
    final chunks = <String>[];
    String currentChunk = '';

    for (String word in words) {
      final testChunk = currentChunk.isEmpty ? word : '$currentChunk $word';

      if (testChunk.length <= maxCharsPerChunk) {
        currentChunk = testChunk;
      } else {
        if (currentChunk.isNotEmpty) {
          chunks.add(currentChunk);
        }
        currentChunk = word;
      }
    }

    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk);
    }

    return chunks;
  }

  /// Calculate voice-based duration for a text chunk
  Duration _calculateVoiceBasedDuration(
      String text, int voiceWPM, String language) {
    final wordCount = text.split(' ').length;

    // Base calculation from voice WPM
    var durationMs = (wordCount / voiceWPM) * 60 * 1000;

    // Language-specific adjustments
    switch (language) {
      case "Spanish (Spain)":
      case "Spanish (Mexico)":
        durationMs *= 1.1; // Spanish tends to be slightly slower
        break;
      case "Chinese (China)":
      case "Chinese (Taiwan)":
        durationMs *= 0.9; // Chinese can be faster due to character density
        break;
      case "French (France)":
      case "French (Canada)":
        durationMs *= 1.05; // French slightly slower
        break;
      case "German (Germany)":
        durationMs *= 1.15; // German compound words take longer
        break;
      default:
        // English and other languages use base timing
        break;
    }

    // Add minimum duration for readability (at least 1.5 seconds per chunk)
    durationMs = math.max(durationMs, 1500);

    // Add maximum duration to prevent overly long chunks (max 6 seconds)
    durationMs = math.min(durationMs, 6000);

    return Duration(milliseconds: durationMs.round());
  }
}
