import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class ThumbnailsSlider extends StatefulWidget {
  final List<File> currentVideoThumbnails;
  final Duration videoDuration;
  final Function(Duration, Duration) onVideoTrimChanged;
  final Function(Duration, Duration) onAudioTrimChanged;

  const ThumbnailsSlider({
    super.key,
    required this.currentVideoThumbnails,
    required this.videoDuration,
    required this.onVideoTrimChanged,
    required this.onAudioTrimChanged,
  });

  @override
  ThumbnailsSliderState createState() => ThumbnailsSliderState();
}

class ThumbnailsSliderState extends State<ThumbnailsSlider> {
  final ScrollController _videoScrollController = ScrollController();
  final ScrollController _audioScrollController = ScrollController();

  double _currentVideoTimeInSeconds = 0.0;
  double _currentAudioTimeInSeconds = 0.0;

  double _videoStartTrim = 0.0;
  double _videoEndTrim = 1.0;
  double _audioStartTrim = 0.0;
  double _audioEndTrim = 1.0;

  double thumbnailWidth = 60.0;
  double spacing = 10.0;
  double padding = 100.0;

  @override
  void initState() {
    super.initState();
    _videoScrollController.addListener(_onVideoScroll);
    _audioScrollController.addListener(_onAudioScroll);
  }

  @override
  void dispose() {
    _videoScrollController.removeListener(_onVideoScroll);
    _audioScrollController.removeListener(_onAudioScroll);
    _videoScrollController.dispose();
    _audioScrollController.dispose();
    super.dispose();
  }

  void _onVideoScroll() {
    final totalScrollableWidth = _calculateTotalWidth();
    final scrollPercentage =
        _videoScrollController.offset / totalScrollableWidth;
    setState(() {
      _currentVideoTimeInSeconds =
          widget.videoDuration.inSeconds * scrollPercentage;
      _currentVideoTimeInSeconds = _currentVideoTimeInSeconds.clamp(
          0.0, widget.videoDuration.inSeconds.toDouble());
    });
  }

  void _onAudioScroll() {
    final totalScrollableWidth = _calculateTotalWidth();
    final scrollPercentage =
        _audioScrollController.offset / totalScrollableWidth;
    setState(() {
      _currentAudioTimeInSeconds =
          widget.videoDuration.inSeconds * scrollPercentage;
      _currentAudioTimeInSeconds = _currentAudioTimeInSeconds.clamp(
          0.0, widget.videoDuration.inSeconds.toDouble());
    });
  }

  double _calculateTotalWidth() {
    return (widget.currentVideoThumbnails.length * (thumbnailWidth + spacing)) -
        spacing +
        2 * padding;
  }

  Widget _buildTrimHandle({
    required double value,
    required Function(double) onChanged,
    Color color = Colors.blue,
  }) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final localPosition = box.globalToLocal(details.globalPosition);
        final newValue = (localPosition.dx - padding) /
            (_calculateTotalWidth() - 2 * padding);
        onChanged(newValue.clamp(0.0, 1.0));
      },
      child: Container(
        width: 20,
        height: 60,
        decoration: BoxDecoration(
          color: color.withOpacity(0.5),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(Icons.drag_handle, size: 16, color: color),
            Icon(Icons.drag_handle, size: 16, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline({
    required ScrollController scrollController,
    required double startTrim,
    required double endTrim,
    required Function(double) onStartTrimChanged,
    required Function(double) onEndTrimChanged,
    Color trimColor = Colors.blue,
    bool isAudio = false,
  }) {
    return Stack(
      children: [
        SingleChildScrollView(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: padding),
            child: Row(
              children: isAudio
                  ? [
                      Container(
                        width: _calculateTotalWidth() - 2 * padding,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: CustomPaint(
                          painter: AudioWaveformPainter(),
                        ),
                      ),
                    ]
                  : widget.currentVideoThumbnails.map((element) {
                      return Padding(
                        padding: EdgeInsets.only(right: spacing),
                        child: SizedBox(
                          height: 60.0,
                          width: thumbnailWidth,
                          child: Image.file(
                            element,
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    }).toList(),
            ),
          ),
        ),
        Positioned(
          left: padding + startTrim * (_calculateTotalWidth() - 2 * padding),
          child: _buildTrimHandle(
            value: startTrim,
            onChanged: onStartTrimChanged,
            color: trimColor,
          ),
        ),
        Positioned(
          left: padding + endTrim * (_calculateTotalWidth() - 2 * padding),
          child: _buildTrimHandle(
            value: endTrim,
            onChanged: onEndTrimChanged,
            color: trimColor,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Video Timeline
        _buildTimeline(
          scrollController: _videoScrollController,
          startTrim: _videoStartTrim,
          endTrim: _videoEndTrim,
          onStartTrimChanged: (value) {
            setState(() {
              _videoStartTrim = value;
              widget.onVideoTrimChanged(
                Duration(
                    seconds: (value * widget.videoDuration.inSeconds).round()),
                Duration(
                    seconds: (_videoEndTrim * widget.videoDuration.inSeconds)
                        .round()),
              );
            });
          },
          onEndTrimChanged: (value) {
            setState(() {
              _videoEndTrim = value;
              widget.onVideoTrimChanged(
                Duration(
                    seconds: (_videoStartTrim * widget.videoDuration.inSeconds)
                        .round()),
                Duration(
                    seconds: (value * widget.videoDuration.inSeconds).round()),
              );
            });
          },
          trimColor: Colors.blue,
        ),
        SizedBox(height: 20),
        // Audio Timeline
        _buildTimeline(
          scrollController: _audioScrollController,
          startTrim: _audioStartTrim,
          endTrim: _audioEndTrim,
          onStartTrimChanged: (value) {
            setState(() {
              _audioStartTrim = value;
              widget.onAudioTrimChanged(
                Duration(
                    seconds: (value * widget.videoDuration.inSeconds).round()),
                Duration(
                    seconds: (_audioEndTrim * widget.videoDuration.inSeconds)
                        .round()),
              );
            });
          },
          onEndTrimChanged: (value) {
            setState(() {
              _audioEndTrim = value;
              widget.onAudioTrimChanged(
                Duration(
                    seconds: (_audioStartTrim * widget.videoDuration.inSeconds)
                        .round()),
                Duration(
                    seconds: (value * widget.videoDuration.inSeconds).round()),
              );
            });
          },
          trimColor: Colors.green,
          isAudio: true,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(
                  Duration(seconds: _currentVideoTimeInSeconds.toInt()))),
              Text(_formatDuration(widget.videoDuration)),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }
}

// Custom painter for audio waveform visualization
class AudioWaveformPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[600]!
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    var x = 0.0;
    final width = size.width;
    final height = size.height;

    while (x < width) {
      // Generate random heights for demonstration
      final y = height / 2 + (math.Random().nextDouble() - 0.5) * height / 2;
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      x += 5;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
