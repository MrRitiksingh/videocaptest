import 'dart:async';
import 'dart:io';

import 'package:ai_video_creator_editor/components/gradient_scaffold.dart';
import 'package:easy_audio_trimmer/easy_audio_trimmer.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../../../utils/dl.dart';
import '../../../utils/snack_bar_utils.dart';

class AudioTrimmer extends StatefulWidget {
  const AudioTrimmer({
    super.key,
    required this.audioFile,
    required this.audioDuration,
    required this.remainAudioDuration,
  });

  final File audioFile;
  final double audioDuration;
  final double remainAudioDuration;

  @override
  State<AudioTrimmer> createState() => _AudioTrimmerState();
}

class _AudioTrimmerState extends State<AudioTrimmer> {
  final Trimmer _trimmer = Trimmer();

  double _startValue = 0.0;
  double _endValue = 0.0;

  bool _isPlaying = false;
  bool _progressVisibility = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAudio();
  }

  void _loadAudio() async {
    setState(() {
      isLoading = true;
    });
    await _trimmer.loadAudio(audioFile: widget.audioFile);
    setState(() {
      isLoading = false;
    });
  }

  Future<File?> _saveAudio() async {
    File? output;
    final Completer<File?> completer = Completer<File?>();
    setState(() {
      _progressVisibility = true;
    });
    await _trimmer.saveTrimmedAudio(
      startValue: _startValue,
      endValue: _endValue,
      audioFileName:
          "${getFileNameWithoutExtension(widget.audioFile.path)}_${DateTime.now().millisecondsSinceEpoch.toString()}_trimmed",
      onSave: (outputPath) {
        setState(() {
          _progressVisibility = false;
        });
        if (outputPath != null) {
          output = File(outputPath);
          completer.complete(output);
        } else {
          completer.complete(null);
        }
      },
    );
    return await completer.future;
  }

  @override
  void dispose() {
    if (mounted) {
      _trimmer.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (Navigator.of(context).userGestureInProgress) {
          return false;
        } else {
          return true;
        }
      },
      child: GradientScaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              icon: const Icon(Icons.check, color: Colors.white),
              onPressed: () async {
                final file = await _saveAudio();
                if (file == null) {
                  showSnackBar(context, "Failed audio cropping.");
                  return;
                }
                int? newAudioDuration = await getAudioLength(audio: file);
                if (newAudioDuration == null || newAudioDuration == 0) {
                  showSnackBar(context, "Failed audio cropping.");
                  return;
                }
                if (newAudioDuration > widget.remainAudioDuration) {
                  showSnackBar(context, "Not enough space to add audio.");
                  return;
                }
                // Return the trimmed file back to caller (pickAudioFile will handle adding)
                Navigator.pop<File>(context, file);
              },
            ),
          ],
        ),
        body: isLoading
            ? const CircularProgressIndicator()
            : Center(
                child: Container(
                  padding: const EdgeInsets.only(bottom: 30.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: <Widget>[
                      Visibility(
                        visible: _progressVisibility,
                        child: LinearProgressIndicator(
                          backgroundColor:
                              Theme.of(context).primaryColor.withOpacity(0.5),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          getFileNameWithoutExtension(widget.audioFile.path),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16.0),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 30.0),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: TrimViewer(
                            trimmer: _trimmer,
                            viewerHeight: 100,
                            maxAudioLength: Duration(
                                seconds: widget.remainAudioDuration.toInt()),
                            viewerWidth: MediaQuery.of(context).size.width,
                            durationStyle: DurationStyle.FORMAT_MM_SS,
                            backgroundColor: Theme.of(context).primaryColor,
                            barColor: Colors.blueAccent,
                            durationTextStyle: TextStyle(
                                color: Theme.of(context).primaryColor),
                            allowAudioSelection: true,
                            editorProperties: TrimEditorProperties(
                              circleSize: 10,
                              borderPaintColor: Colors.white,
                              borderWidth: 4,
                              borderRadius: 5,
                              circlePaintColor: Colors.white,
                            ),
                            areaProperties:
                                TrimAreaProperties.edgeBlur(blurEdges: true),
                            onChangeStart: (value) => _startValue = value,
                            onChangeEnd: (value) => _endValue = value,
                            onChangePlaybackState: (value) {
                              if (mounted) {
                                setState(() => _isPlaying = value);
                              }
                            },
                          ),
                        ),
                      ),
                      TextButton(
                        child: _isPlaying
                            ? const Icon(Icons.pause,
                                size: 80.0, color: Colors.white)
                            : const Icon(Icons.play_arrow,
                                size: 80.0, color: Colors.white),
                        onPressed: () async {
                          bool playbackState =
                              await _trimmer.audioPlaybackControl(
                            startValue: _startValue,
                            endValue: _endValue,
                          );
                          setState(() => _isPlaying = playbackState);
                        },
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

String getFileNameWithoutExtension(String filePath) {
  String fileName = basename(filePath);
  return fileName.replaceFirst(RegExp(r'\.[^\.]+$'), '');
}
