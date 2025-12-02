import 'dart:math';

import 'package:ai_video_creator_editor/controllers/video_controller.dart';
import 'package:ai_video_creator_editor/utils/helpers.dart';
import 'package:flutter/material.dart';

class TransformData {
  const TransformData({
    this.scale = 1.0,
    this.rotation = 0.0,
    this.translate = Offset.zero,
  });
  final double rotation, scale;
  final Offset translate;

  TransformData copyWith({
    double? scale,
    double? rotation,
    Offset? translate,
  }) =>
      TransformData(
        scale: scale ?? this.scale,
        rotation: rotation ?? this.rotation,
        translate: translate ?? this.translate,
      );

  factory TransformData.fromRect(
    Rect rect,
    Size layout,
    Size maxSize,
    VideoEditorController? controller,
  ) {
    if (controller != null && controller.isRotated) {
      maxSize = maxSize.flipped;
    }

    final double scale = scaleToSize(maxSize, rect);
    final double rotation =
        -(controller?.rotation ?? 0) * (pi / 180.0); // Use normalized rotation
    final Offset translate = Offset(
      ((layout.width - rect.width) / 2) - rect.left,
      ((layout.height - rect.height) / 2) - rect.top,
    );

    return TransformData(
      rotation: rotation,
      scale: scale,
      translate: translate,
    );
  }

  factory TransformData.fromController(VideoEditorController controller) {
    return TransformData(
      rotation: -controller.rotation *
          (pi / 180.0), // Use normalized rotation, not cacheRotation
      scale: 1.0,
      translate: Offset.zero,
    );
  }
}
