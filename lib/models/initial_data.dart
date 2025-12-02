import 'package:video_player/video_player.dart';

import '../utils/picked_file_custom.dart';

class FeatureMediaInitials {
  int? initialTab;
  PickedFileCustom? initialMedia;
  String? name;
  VideoPlayerValue? videoPlayerValue;
  String? rayVideoGenerationId;

  FeatureMediaInitials({
    this.initialMedia,
    this.initialTab,
    this.name,
    this.videoPlayerValue,
    this.rayVideoGenerationId,
  });

  FeatureMediaInitials copyWith({
    int? initialTab,
    PickedFileCustom? initialMedia,
    String? name,
    VideoPlayerValue? videoPlayerValue,
    String? rayVideoGenerationId,
  }) {
    return FeatureMediaInitials(
      initialTab: initialTab ?? this.initialTab,
      initialMedia: initialMedia ?? this.initialMedia,
      name: name ?? this.name,
      videoPlayerValue: videoPlayerValue ?? this.videoPlayerValue,
      rayVideoGenerationId: rayVideoGenerationId ?? this.rayVideoGenerationId,
    );
  }
}
