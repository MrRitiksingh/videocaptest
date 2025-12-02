import 'package:ai_video_creator_editor/screens/project/models/video_track_model.dart';

/// Options for video preprocessing using easy_video_editor
class PreprocessingOptions {
  final TrimOptions? trimOptions;
  final CropOptions? cropOptions;
  final int rotationDegrees;
  final double speedFactor;
  final CompressionOptions? compressionOptions;
  final AudioOptions? audioOptions;

  const PreprocessingOptions({
    this.trimOptions,
    this.cropOptions,
    this.rotationDegrees = 0,
    this.speedFactor = 1.0,
    this.compressionOptions,
    this.audioOptions,
  });

  bool get hasAnyEdit =>
      trimOptions != null ||
      cropOptions != null ||
      rotationDegrees != 0 ||
      speedFactor != 1.0 ||
      compressionOptions != null ||
      audioOptions != null;

  PreprocessingOptions copyWith({
    TrimOptions? trimOptions,
    CropOptions? cropOptions,
    int? rotationDegrees,
    double? speedFactor,
    CompressionOptions? compressionOptions,
    AudioOptions? audioOptions,
  }) {
    return PreprocessingOptions(
      trimOptions: trimOptions ?? this.trimOptions,
      cropOptions: cropOptions ?? this.cropOptions,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      speedFactor: speedFactor ?? this.speedFactor,
      compressionOptions: compressionOptions ?? this.compressionOptions,
      audioOptions: audioOptions ?? this.audioOptions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trimOptions': trimOptions?.toJson(),
      'cropOptions': cropOptions?.toJson(),
      'rotationDegrees': rotationDegrees,
      'speedFactor': speedFactor,
      'compressionOptions': compressionOptions?.toJson(),
      'audioOptions': audioOptions?.toJson(),
    };
  }

  factory PreprocessingOptions.fromJson(Map<String, dynamic> json) {
    return PreprocessingOptions(
      trimOptions: json['trimOptions'] != null ? TrimOptions.fromJson(json['trimOptions']) : null,
      cropOptions: json['cropOptions'] != null ? CropOptions.fromJson(json['cropOptions']) : null,
      rotationDegrees: json['rotationDegrees'] ?? 0,
      speedFactor: json['speedFactor'] ?? 1.0,
      compressionOptions: json['compressionOptions'] != null ? CompressionOptions.fromJson(json['compressionOptions']) : null,
      audioOptions: json['audioOptions'] != null ? AudioOptions.fromJson(json['audioOptions']) : null,
    );
  }
}

class TrimOptions {
  final double startSeconds;
  final double endSeconds;
  
  const TrimOptions({required this.startSeconds, required this.endSeconds});

  Map<String, dynamic> toJson() {
    return {
      'startSeconds': startSeconds,
      'endSeconds': endSeconds,
    };
  }

  factory TrimOptions.fromJson(Map<String, dynamic> json) {
    return TrimOptions(
      startSeconds: json['startSeconds'],
      endSeconds: json['endSeconds'],
    );
  }
}

class CropOptions {
  final int x, y, width, height;
  
  const CropOptions({
    required this.x,
    required this.y, 
    required this.width,
    required this.height,
  });
  
  /// Create from your existing CropModel
  factory CropOptions.fromCropModel(CropModel cropModel) {
    return CropOptions(
      x: cropModel.x.toInt(),
      y: cropModel.y.toInt(),
      width: cropModel.width.toInt(),
      height: cropModel.height.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    };
  }

  factory CropOptions.fromJson(Map<String, dynamic> json) {
    return CropOptions(
      x: json['x'],
      y: json['y'],
      width: json['width'],
      height: json['height'],
    );
  }
}

enum VideoQuality {
  low,
  medium,
  high,
  veryHigh,
}

class CompressionOptions {
  final VideoQuality quality;
  final String? resolution;
  
  const CompressionOptions({required this.quality, this.resolution});

  Map<String, dynamic> toJson() {
    return {
      'quality': quality.name,
      'resolution': resolution,
    };
  }

  factory CompressionOptions.fromJson(Map<String, dynamic> json) {
    return CompressionOptions(
      quality: VideoQuality.values.firstWhere((e) => e.name == json['quality']),
      resolution: json['resolution'],
    );
  }
}

class AudioOptions {
  final bool mute;
  final bool extractAudio;
  
  const AudioOptions({this.mute = false, this.extractAudio = false});

  Map<String, dynamic> toJson() {
    return {
      'mute': mute,
      'extractAudio': extractAudio,
    };
  }

  factory AudioOptions.fromJson(Map<String, dynamic> json) {
    return AudioOptions(
      mute: json['mute'] ?? false,
      extractAudio: json['extractAudio'] ?? false,
    );
  }
}

enum ProcessingStrategy {
  easyVideoEditor,
  ffmpeg,
}

enum EditType {
  crop,
  trim,
  speed,
  rotate,
  compress,
  audioExtract,
  overlay,
  blend,
  transition,
  textOverlay,
}