import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:ai_video_creator_editor/components/gradient_scaffold.dart';

class OverlayVideoTrimmer extends StatefulWidget {
  final File videoFile;
  final double videoDuration;
  final double remainVideoDuration;

  const OverlayVideoTrimmer({
    Key? key,
    required this.videoFile,
    required this.videoDuration,
    required this.remainVideoDuration,
  }) : super(key: key);

  @override
  State<OverlayVideoTrimmer> createState() => _OverlayVideoTrimmerState();
}

class _OverlayVideoTrimmerState extends State<OverlayVideoTrimmer> {
  VideoPlayerController? _controller;
  double _startTime = 0.0;
  double _endTime = 0.0;
  double _opacity = 1.0;
  String _blendMode = 'overlay';
  double _overlayDuration = 3.0;
  bool _durationValid = true;

  double get _maxOverlayDuration =>
      widget.remainVideoDuration < widget.videoDuration
          ? widget.remainVideoDuration
          : widget.videoDuration;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _endTime = widget.videoDuration;
    _overlayDuration = _maxOverlayDuration < 3 ? _maxOverlayDuration : 3;
    _checkDuration();
  }

  void _checkDuration() {
    setState(() {
      _durationValid = _overlayDuration <= _maxOverlayDuration &&
          _startTime + _overlayDuration <= widget.videoDuration;
    });
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.file(widget.videoFile);
    await _controller!.initialize();
    setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onConfirm() {
    if (!_durationValid) return;
    final result = {
      'videoFile': widget.videoFile,
      'totalDuration': _overlayDuration,
      'opacity': _opacity,
      'blendMode': _blendMode,
      'videoTrimStart': _startTime,
      'videoTrimEnd': _startTime + _overlayDuration,
      'position': null, // Can be extended to support custom positioning
    };
    Navigator.of(context).pop(result);
  }

  void _togglePlay() {
    if (_controller == null) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Overlay Video Settings'),
        actions: [
          IconButton(
            onPressed: _durationValid ? _onConfirm : null,
            icon: const Icon(Icons.check, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          // Show available overlay duration
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Available overlay duration: ${_maxOverlayDuration.toStringAsFixed(1)}s',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          // Video preview
          if (_controller?.value.isInitialized == true)
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
                  child: VideoPlayer(_controller!),
                ),
                GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      (_controller?.value.isPlaying ?? false)
                          ? Icons.pause
                          : Icons.play_arrow,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          if (!_durationValid)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Overlay duration exceeds main video duration!',
                style: TextStyle(color: Colors.red),
              ),
            ),

          const SizedBox(height: 20),

          // Duration slider
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Overlay Duration: ${_overlayDuration.toStringAsFixed(1)}s'),
                Slider(
                  value: _overlayDuration,
                  min: 1.0,
                  max: _maxOverlayDuration,
                  onChanged: (value) {
                    setState(() {
                      _overlayDuration = value;
                      // Ensure we don't exceed the overlay video length
                      if (_startTime + _overlayDuration >
                          widget.videoDuration) {
                        _overlayDuration = widget.videoDuration - _startTime;
                      }
                      _checkDuration();
                    });
                  },
                ),
              ],
            ),
          ),

          // Video trim sliders
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Video Start: ${_startTime.toStringAsFixed(1)}s'),
                Slider(
                  value: _startTime,
                  min: 0.0,
                  max: widget.videoDuration - 1,
                  onChanged: (value) {
                    setState(() {
                      _startTime = value;
                      // Ensure we don't exceed the overlay video length or available space
                      if (_startTime + _overlayDuration >
                          widget.videoDuration) {
                        _overlayDuration = widget.videoDuration - _startTime;
                      }
                      if (_overlayDuration > _maxOverlayDuration) {
                        _overlayDuration = _maxOverlayDuration;
                      }
                      _checkDuration();
                    });
                  },
                ),
              ],
            ),
          ),

          // Opacity slider
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Opacity: ${(_opacity * 100).toInt()}%'),
                Slider(
                  value: _opacity,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (value) {
                    setState(() {
                      _opacity = value;
                    });
                  },
                ),
              ],
            ),
          ),

          // Blend mode selector
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Blend Mode:'),
                DropdownButton<String>(
                  value: _blendMode,
                  items: const [
                    DropdownMenuItem(value: 'overlay', child: Text('Overlay')),
                    // DropdownMenuItem(
                    //     value: 'multiply', child: Text('Multiply')),
                    // DropdownMenuItem(value: 'screen', child: Text('Screen')),
                    // DropdownMenuItem(value: 'darken', child: Text('Darken')),
                    // DropdownMenuItem(value: 'lighten', child: Text('Lighten')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _blendMode = value;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
