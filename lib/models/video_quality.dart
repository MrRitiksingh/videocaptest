// Video Quality Enum and Settings Model
enum VideoQuality {
  high,
  medium,
  low,
}

// Video Quality Settings Model
class VideoQualitySettings {
  final int crf;
  final String preset;
  final String audioBitrate;
  final String displayName;
  final String description;

  const VideoQualitySettings({
    required this.crf,
    required this.preset,
    required this.audioBitrate,
    required this.displayName,
    required this.description,
  });

  static const Map<VideoQuality, VideoQualitySettings> settings = {
    VideoQuality.high: VideoQualitySettings(
      crf: 18,
      preset: 'slow',
      audioBitrate: '320k',
      displayName: 'High Quality',
      description: 'Best quality, larger file size, slower export',
    ),
    VideoQuality.medium: VideoQualitySettings(
      crf: 23,
      preset: 'medium',
      audioBitrate: '256k',
      displayName: 'Medium Quality',
      description: 'Balanced quality and file size',
    ),
    VideoQuality.low: VideoQualitySettings(
      crf: 28,
      preset: 'fast',
      audioBitrate: '128k',
      displayName: 'Low Quality',
      description: 'Smaller file size, faster export',
    ),
  };

  // Helper method to get settings for a quality level
  static VideoQualitySettings getSettings(VideoQuality quality) {
    return settings[quality]!;
  }

  // Helper method to get all quality options for dropdown
  static List<VideoQuality> getAllQualities() {
    return VideoQuality.values;
  }
}
