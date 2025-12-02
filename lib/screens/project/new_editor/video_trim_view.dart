import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ai_video_creator_editor/utils/ffmpeg_utils.dart';
import 'package:ai_video_creator_editor/widgets/video_trim_editor.dart';

class VideoTrimView extends StatefulWidget {
  const VideoTrimView({super.key, required this.videoFile});

  final File videoFile;

  @override
  State<VideoTrimView> createState() => _VideoTrimViewState();
}

class _VideoTrimViewState extends State<VideoTrimView> {
  double _startTime = 0.0;
  double _endTime = 0.0;
  String? _selectedAudioPath;
  bool _isExporting = false;
  double _exportProgress = 0.0;
  double _originalAudioVolume = 1.0;
  double _addedAudioVolume = 1.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Trim Video'),
        actions: [
          if (_isExporting)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                      value: _exportProgress > 0 ? _exportProgress : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(_exportProgress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () => _exportVideo(context),
            ),
        ],
      ),
      body: Stack(
        children: [
          VideoTrimEditor(
            videoPath: widget.videoFile.path,
            onTrimChanged: (start, end) {
              setState(() {
                _startTime = start;
                _endTime = end;
              });
            },
            onAudioSelected: (audioPath) {
              setState(() {
                _selectedAudioPath = audioPath;
              });
            },
          ),
          if (_isExporting)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: CircularProgressIndicator(
                        value: _exportProgress > 0 ? _exportProgress : null,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Exporting video... ${(_exportProgress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _exportVideo(BuildContext context) async {
    setState(() {
      _isExporting = true;
      _exportProgress = 0.0;
    });

    try {
      // Ensure the video file exists
      if (!await widget.videoFile.exists()) {
        throw Exception('Video file does not exist');
      }

      // Create a unique output filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputFileName = 'trimmed_$timestamp.mp4';

      final outputPath = await FFmpegUtils.exportVideo(
        inputPath: widget.videoFile.path,
        outputFileName: outputFileName,
        audioPath: _selectedAudioPath,
        startTime: _startTime,
        endTime: _endTime,
        originalAudioVolume: _originalAudioVolume,
        addedAudioVolume: _addedAudioVolume,
        onProgress: (progress) {
          setState(() {
            _exportProgress = progress;
          });
        },
      );

      if (outputPath != null) {
        // Verify the output file exists
        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          Navigator.pop(context, outputPath);
        } else {
          throw Exception('Output file was not created');
        }
      } else {
        throw Exception('Failed to export video');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() {
        _isExporting = false;
        _exportProgress = 0.0;
      });
    }
  }
}
