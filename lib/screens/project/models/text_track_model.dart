import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class TextTrackModel {
  final String id;
  final String text;
  final double trimStartTime;
  final double trimEndTime;
  // Styling properties
  final Color textColor;
  final double fontSize;
  final String fontFamily;
  final Offset position;
  final double rotation; // Rotation in degrees
  final DateTime lastModified; // Timestamp for tracking changes
  // Auto-wrap properties
  final bool autoWrap; // Always enabled for auto-wrapping
  final double? maxWidth; // Calculated from boundaries
  final double? maxHeight; // Calculated from boundaries
  final int laneIndex; // Lane index (0-2) for multi-lane support, max 3 simultaneous tracks

  TextTrackModel({
    String? id,
    required this.text,
    this.trimStartTime = 0,
    this.trimEndTime = 0,
    this.textColor = Colors.white,
    this.fontSize = 30.0,
    this.fontFamily = 'Arial',
    this.position = const Offset(100, 100),
    this.rotation = 0.0, // Default rotation
    DateTime? lastModified,
    this.autoWrap = true, // Always enabled for auto-wrapping
    this.maxWidth,
    this.maxHeight,
    this.laneIndex = 0, // Default to lane 0
  })  : id = id ?? const Uuid().v4(),
        lastModified = lastModified ?? DateTime.now();

  TextTrackModel copyWith({
    String? id,
    String? text,
    double? startTime,
    double? endTime,
    Color? textColor,
    double? fontSize,
    String? fontFamily,
    Offset? position,
    double? rotation, // Add rotation to copyWith
    DateTime? lastModified,
    bool updateTimestamp =
        false, // Only update timestamp when explicitly requested
    bool? autoWrap,
    double? maxWidth,
    double? maxHeight,
    int? laneIndex,
  }) {
    return TextTrackModel(
      id: id ?? this.id,
      text: text ?? this.text,
      trimStartTime: startTime ?? this.trimStartTime,
      trimEndTime: endTime ?? this.trimEndTime,
      textColor: textColor ?? this.textColor,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      position: position ?? this.position,
      rotation: rotation ?? this.rotation, // Pass rotation
      lastModified: lastModified ??
          (updateTimestamp ? DateTime.now() : this.lastModified),
      autoWrap: autoWrap ?? this.autoWrap,
      maxWidth: maxWidth ?? this.maxWidth,
      maxHeight: maxHeight ?? this.maxHeight,
      laneIndex: laneIndex ?? this.laneIndex,
    );
  }
}
