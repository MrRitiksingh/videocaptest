// video_preview.dart
import 'package:ai_video_creator_editor/screens/project/new_editor/text_overlay_manager.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPreview extends StatelessWidget {
  final VideoPlayerController controller;
  final List<TextOverlay> textOverlays;

  const VideoPreview({
    super.key,
    required this.controller,
    this.textOverlays = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
        ...textOverlays.map((overlay) => Positioned(
              left: overlay.position.dx,
              top: overlay.position.dy,
              child: Transform.scale(
                scale: overlay.scale,
                child: Text(
                  overlay.text,
                  style: overlay.style.copyWith(color: overlay.color),
                ),
              ),
            )),
      ],
    );
  }
}
