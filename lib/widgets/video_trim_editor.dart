import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:ai_video_creator_editor/widgets/audio_picker.dart';

class VideoTrimEditor extends StatefulWidget {
  const VideoTrimEditor({
    super.key,
    required this.videoPath,
    required this.onTrimChanged,
    required this.onAudioSelected,
  });

  final String videoPath;
  final Function(double start, double end) onTrimChanged;
  final Function(String? audioPath) onAudioSelected;

  @override
  State<VideoTrimEditor> createState() => _VideoTrimEditorState();
}

class _VideoTrimEditorState extends State<VideoTrimEditor> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  double _startTime = 0.0;
  double _endTime = 0.0;
  String? _selectedAudioPath;
  bool _isOriginalAudioMuted = false;
  bool _isAddedAudioMuted = false;
  double _originalAudioVolume = 1.0;
  double _addedAudioVolume = 1.0;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      final controller = VideoPlayerController.file(File(widget.videoPath));
      await controller.initialize();

      if (mounted) {
        setState(() {
          _controller = controller;
          _isInitialized = true;
          _endTime = controller.value.duration.inMilliseconds / 1000;
        });
      } else {
        controller.dispose();
      }
    } catch (e) {
      print('Error initializing video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _updateTrim() {
    widget.onTrimChanged(_startTime, _endTime);
  }

  void _handleAudioSelection(String? audioPath) {
    setState(() {
      _selectedAudioPath = audioPath;
    });
    widget.onAudioSelected(audioPath);
  }

  Widget _buildAudioControl({
    required String title,
    required bool isMuted,
    required double volume,
    required Color accentColor,
    required Function(bool) onMuteToggle,
    required Function(double) onVolumeChanged,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(
                  isMuted ? Icons.volume_off : Icons.volume_up,
                  color: isMuted ? Colors.red : Colors.white,
                  size: 28,
                ),
                onPressed: () => onMuteToggle(!isMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.volume_down, color: Colors.white),
              Expanded(
                child: Slider(
                  value: volume,
                  onChanged: onVolumeChanged,
                  activeColor: accentColor,
                  inactiveColor: Colors.grey[700],
                ),
              ),
              const Icon(Icons.volume_up, color: Colors.white),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${(volume * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_controller!),
              IconButton(
                icon: Icon(
                  _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 50.0,
                  color: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _controller!.value.isPlaying
                        ? _controller!.pause()
                        : _controller!.play();
                  });
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Original Video Audio Controls
                  _buildAudioControl(
                    title: 'Original Video Audio',
                    isMuted: _isOriginalAudioMuted,
                    volume: _originalAudioVolume,
                    accentColor: Colors.blue,
                    onMuteToggle: (muted) {
                      setState(() {
                        _isOriginalAudioMuted = muted;
                        _originalAudioVolume = muted ? 0.0 : 1.0;
                      });
                    },
                    onVolumeChanged: (value) {
                      setState(() {
                        _originalAudioVolume = value;
                        _isOriginalAudioMuted = value == 0.0;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // Added Audio Controls (only show if audio is selected)
                  if (_selectedAudioPath != null)
                    _buildAudioControl(
                      title: 'Added Audio',
                      isMuted: _isAddedAudioMuted,
                      volume: _addedAudioVolume,
                      accentColor: Colors.green,
                      onMuteToggle: (muted) {
                        setState(() {
                          _isAddedAudioMuted = muted;
                          _addedAudioVolume = muted ? 0.0 : 1.0;
                        });
                      },
                      onVolumeChanged: (value) {
                        setState(() {
                          _addedAudioVolume = value;
                          _isAddedAudioMuted = value == 0.0;
                        });
                      },
                    ),
                  const SizedBox(height: 24),
                  // Trim Controls
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: Colors.grey[800]!),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Start: ${_startTime.toStringAsFixed(1)}s',
                              style: const TextStyle(color: Colors.white),
                            ),
                            Text(
                              'End: ${_endTime.toStringAsFixed(1)}s',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SliderRange(
                          min: 0.0,
                          max:
                              _controller!.value.duration.inMilliseconds / 1000,
                          start: _startTime,
                          end: _endTime,
                          onChanged: (start, end) {
                            setState(() {
                              _startTime = start;
                              _endTime = end;
                            });
                            _updateTrim();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Audio Picker
                  AudioPicker(
                    onAudioSelected: _handleAudioSelection,
                    selectedAudioPath: _selectedAudioPath,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class SliderRange extends StatelessWidget {
  const SliderRange({
    super.key,
    required this.min,
    required this.max,
    required this.start,
    required this.end,
    required this.onChanged,
  });

  final double min;
  final double max;
  final double start;
  final double end;
  final Function(double start, double end) onChanged;

  @override
  Widget build(BuildContext context) {
    return RangeSlider(
      values: RangeValues(start, end),
      min: min,
      max: max,
      onChanged: (values) {
        onChanged(values.start, values.end);
      },
      activeColor: Colors.blue,
      inactiveColor: Colors.grey[700],
    );
  }
}
