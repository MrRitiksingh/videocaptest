import 'dart:async';

import 'package:ai_video_creator_editor/components/gradient_scaffold.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/video_editor_provider.dart';
import 'package:ai_video_creator_editor/screens/project/models/video_track_model.dart';
import 'package:ai_video_creator_editor/utils/snack_bar_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

class VideoTrimmer extends StatefulWidget {
  const VideoTrimmer({
    super.key,
    required this.videoTrack,
    required this.trackIndex,
  });

  final VideoTrackModel videoTrack;
  final int trackIndex;

  @override
  State<VideoTrimmer> createState() => _VideoTrimmerState();
}

class _VideoTrimmerState extends State<VideoTrimmer> {
  VideoPlayerController? _controller;

  double _startValue = 0.0;
  double _endValue = 0.0;

  bool _isPlaying = false;
  bool _progressVisibility = false;
  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  void _initializeVideo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _controller = VideoPlayerController.file(widget.videoTrack.processedFile);
      await _controller!.initialize();

      // Set initial trim values - for already trimmed videos, start from 0 to current duration
      final videoDuration = _controller!.value.duration.inSeconds.toDouble();

      // Ensure we have a valid duration
      if (videoDuration <= 0) {
        throw Exception("Invalid video duration: $videoDuration");
      }

      _startValue = 0.0;
      _endValue = videoDuration;

      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        showSnackBar(context, "Failed to load video for trimming.");
      }
    }
  }

  Future<void> _applyTrim() async {
    if (!_isInitialized || _controller == null) return;

    setState(() {
      _progressVisibility = true;
    });

    try {
      final provider = context.read<VideoEditorProvider>();

      // Apply the trim to the video track
      await provider.trimVideoTrack(
        widget.trackIndex,
        _startValue,
        _endValue,
      );

      setState(() {
        _progressVisibility = false;
      });

      if (mounted) {
        Navigator.pop(context);

        // Show success message with overlay adjustment info
        showSnackBar(context, "Video trimmed successfully!");

        // Note: Overlay adjustment messages are already logged in console
        // Could be enhanced to show specific adjustment details to user
      }
    } catch (e) {
      setState(() {
        _progressVisibility = false;
      });
      if (mounted) {
        showSnackBar(context, "Failed to trim video: ${e.toString()}");
      }
    }
  }

  void _togglePlayback() {
    if (_controller == null || !_isInitialized) return;

    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      // Seek to start position and play within trim range
      _controller!.seekTo(Duration(seconds: _startValue.toInt()));
      _controller!.play();
    }

    setState(() {
      _isPlaying = _controller!.value.isPlaying;
    });
  }

  void _onTrimChanged(double start, double end) {
    if (_controller == null || !_isInitialized) return;

    final maxDuration = _controller!.value.duration.inSeconds.toDouble();

    // Ensure values are within valid bounds
    final clampedStart = start.clamp(0.0, maxDuration);
    final clampedEnd = end.clamp(clampedStart, maxDuration);

    setState(() {
      _startValue = clampedStart;
      _endValue = clampedEnd;
    });

    // Update video position to show the trimmed section
    _controller!.seekTo(Duration(seconds: clampedStart.toInt()));
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    final minutes = duration.inMinutes;
    final remainingSeconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: const Text("Trim Video"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.white),
            onPressed: _progressVisibility ? null : _applyTrim,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isInitialized && _controller != null
              ? Stack(
                  children: [
                    Column(
                      children: [
                        // Video Preview
                        Expanded(
                          flex: 3,
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: AspectRatio(
                                aspectRatio: _controller!.value.aspectRatio,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    VideoPlayer(_controller!),
                                    // Play/Pause overlay
                                    GestureDetector(
                                      onTap: _togglePlayback,
                                      child: Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius:
                                              BorderRadius.circular(40),
                                        ),
                                        child: Icon(
                                          _isPlaying
                                              ? Icons.pause
                                              : Icons.play_arrow,
                                          color: Colors.white,
                                          size: 40,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Trim Controls
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                // Time Display
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Start: ${_formatDuration(_startValue)}',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 16),
                                    ),
                                    Text(
                                      'End: ${_formatDuration(_endValue)}',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 16),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Trim Slider
                                _buildTrimSlider(),

                                const SizedBox(height: 20),

                                // Duration Info
                                Text(
                                  'Duration: ${_formatDuration(_endValue - _startValue)}',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Loading Overlay
                    if (_progressVisibility)
                      Container(
                        color: Colors.black54,
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(height: 16),
                              Text(
                                'Trimming video...',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                )
              : const Center(
                  child: Text(
                    'Failed to load video',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
    );
  }

  Widget _buildTrimSlider() {
    if (!_isInitialized || _controller == null) {
      return const SizedBox.shrink();
    }

    final maxDuration = _controller!.value.duration.inSeconds.toDouble();

    // Ensure values are within bounds
    final clampedStartValue = _startValue.clamp(0.0, maxDuration);
    final clampedEndValue = _endValue.clamp(clampedStartValue, maxDuration);

    // Update values if they were clamped
    if (clampedStartValue != _startValue || clampedEndValue != _endValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _startValue = clampedStartValue;
          _endValue = clampedEndValue;
        });
      });
    }

    return Column(
      children: [
        RangeSlider(
          values: RangeValues(clampedStartValue, clampedEndValue),
          min: 0.0,
          max: maxDuration,
          divisions: maxDuration > 0 ? maxDuration.toInt() : 1,
          activeColor: Colors.blue,
          inactiveColor: Colors.grey,
          onChanged: (RangeValues values) {
            _onTrimChanged(values.start, values.end);
          },
        ),

        // Timeline markers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0:00',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                _formatDuration(maxDuration),
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
