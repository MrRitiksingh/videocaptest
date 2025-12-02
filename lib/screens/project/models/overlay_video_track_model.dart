import 'dart:io';
import 'dart:ui';

class OverlayVideoTrackModel {
  final String id;
  final File videoFile;
  final double trimStartTime; // When this overlay starts in the main timeline
  final double trimEndTime; // When this overlay ends in the main timeline
  final double totalDuration; // Duration of the overlay video
  final double opacity; // Opacity of the overlay (0.0 to 1.0)
  final String blendMode; // Blend mode: 'overlay', 'multiply', 'screen', etc.
  final Rect? position; // Position and size of overlay (null = full screen)
  final double videoTrimStart; // Trim start of the overlay video itself
  final double videoTrimEnd; // Trim end of the overlay video itself

  OverlayVideoTrackModel({
    required this.id,
    required this.videoFile,
    required this.trimStartTime,
    required this.trimEndTime,
    required this.totalDuration,
    this.opacity = 1.0,
    this.blendMode = 'overlay',
    this.position,
    this.videoTrimStart = 0.0,
    double? videoTrimEnd,
  }) : videoTrimEnd = videoTrimEnd ?? totalDuration;

  OverlayVideoTrackModel copyWith({
    String? id,
    File? videoFile,
    double? trimStartTime,
    double? trimEndTime,
    double? totalDuration,
    double? opacity,
    String? blendMode,
    Rect? position,
    double? videoTrimStart,
    double? videoTrimEnd,
  }) {
    return OverlayVideoTrackModel(
      id: id ?? this.id,
      videoFile: videoFile ?? this.videoFile,
      trimStartTime: trimStartTime ?? this.trimStartTime,
      trimEndTime: trimEndTime ?? this.trimEndTime,
      totalDuration: totalDuration ?? this.totalDuration,
      opacity: opacity ?? this.opacity,
      blendMode: blendMode ?? this.blendMode,
      position: position ?? this.position,
      videoTrimStart: videoTrimStart ?? this.videoTrimStart,
      videoTrimEnd: videoTrimEnd ?? this.videoTrimEnd,
    );
  }
}
