import 'dart:io';

import 'package:uuid/uuid.dart';

class AudioTrackModel {
  final String id;
  final File audioFile;
  final double trimStartTime;
  final double trimEndTime;
  final double totalDuration;
  final DateTime lastModified; // Timestamp for tracking changes
  final int laneIndex; // Lane index (0-2) for multi-lane support, max 3 simultaneous tracks

  AudioTrackModel({
    String? id,
    required this.audioFile,
    this.trimStartTime = 0,
    this.trimEndTime = 0,
    this.totalDuration = 0,
    DateTime? lastModified,
    this.laneIndex = 0, // Default to lane 0
  })  : id = id ?? const Uuid().v4(),
        lastModified = lastModified ?? DateTime.now();

  AudioTrackModel copyWith({
    String? id,
    File? audioFile,
    double? trimStartTime,
    double? trimEndTime,
    double? totalDuration,
    DateTime? lastModified,
    bool updateTimestamp =
        false, // Only update timestamp when explicitly requested
    int? laneIndex,
  }) {
    return AudioTrackModel(
      id: id ?? this.id,
      audioFile: audioFile ?? this.audioFile,
      trimStartTime: trimStartTime ?? this.trimStartTime,
      trimEndTime: trimEndTime ?? this.trimEndTime,
      totalDuration: totalDuration ?? this.totalDuration,
      lastModified: lastModified ??
          (updateTimestamp ? DateTime.now() : this.lastModified),
      laneIndex: laneIndex ?? this.laneIndex,
    );
  }
}
