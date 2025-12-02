// audio_waveform.dart
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:flutter/cupertino.dart';

class AudioWaveform extends StatefulWidget {
  final String audioPath;
  final double width;
  final double height;
  final Color activeColor;
  final Color inactiveColor;

  const AudioWaveform({
    super.key,
    required this.audioPath,
    required this.width,
    required this.height,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  _AudioWaveformState createState() => _AudioWaveformState();
}

class _AudioWaveformState extends State<AudioWaveform> {
  List<double> _waveformData = [];

  @override
  void initState() {
    super.initState();
    _generateWaveformData();
  }

  Future<void> _generateWaveformData() async {
    // Use FFmpegKit to extract audio samples
    final command =
        '-i ${widget.audioPath} -f s16le -acodec pcm_s16le -ac 1 -ar 1000 pipe:1';
    final session = await FFmpegKit.execute(command);
    final output = await session.getOutput();

    // Convert raw audio data to waveform points
    final samples = output
        ?.split('\n')
        .where((s) => s.isNotEmpty)
        .map((s) => double.parse(s))
        .toList();

    setState(() {
      _waveformData = samples!;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(widget.width, widget.height),
      painter: WaveformPainter(
        waveformData: _waveformData,
        activeColor: widget.activeColor,
        inactiveColor: widget.inactiveColor,
      ),
    );
  }
}

// waveform_painter.dart
class WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final Color activeColor;
  final Color inactiveColor;
  final double progress;

  WaveformPainter({
    required this.waveformData,
    required this.activeColor,
    required this.inactiveColor,
    this.progress = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final paint = Paint()
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final pointSpacing = size.width / waveformData.length;
    final middleY = size.height / 2;
    final progressX = size.width * progress;

    for (var i = 0; i < waveformData.length; i++) {
      final x = i * pointSpacing;
      final amplitude = waveformData[i].abs();
      final normalizedAmplitude = (amplitude / 32768.0) * (size.height / 2);

      paint.color = x < progressX ? activeColor : inactiveColor;

      canvas.drawLine(
        Offset(x, middleY + normalizedAmplitude),
        Offset(x, middleY - normalizedAmplitude),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) =>
      waveformData != oldDelegate.waveformData ||
      activeColor != oldDelegate.activeColor ||
      inactiveColor != oldDelegate.inactiveColor ||
      progress != oldDelegate.progress;
}
