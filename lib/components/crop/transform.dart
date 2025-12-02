import 'package:ai_video_creator_editor/screens/project/models/transform_data.dart';
import 'package:flutter/material.dart';

// This file now exports the optimized transform components
// All functionality has been moved to optimized_transform.dart for better performance
export 'package:ai_video_creator_editor/components/crop/optimized_transform.dart';

// Legacy support - keeping the old classes for backward compatibility
// These will be deprecated in future versions
@Deprecated('Use OptimizedCropTransform instead')
class CropTransform extends StatelessWidget {
  const CropTransform({
    super.key,
    required this.transform,
    required this.child,
  });

  final Widget child;
  final TransformData transform;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipRRect(
        child: Transform.rotate(
          angle: transform.rotation,
          child: Transform.scale(
            scale: transform.scale,
            child: Transform.translate(
              offset: transform.translate,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

@Deprecated('Use OptimizedCropTransformWithAnimation instead')
class CropTransformWithAnimation extends StatelessWidget {
  const CropTransformWithAnimation({
    super.key,
    required this.transform,
    required this.child,
    this.shouldAnimate = true,
  });

  final Widget child;
  final TransformData transform;
  final bool shouldAnimate;

  @override
  Widget build(BuildContext context) {
    if (shouldAnimate == false) {
      return CropTransform(transform: transform, child: child);
    }

    return RepaintBoundary(
      child: AnimatedRotation(
        // convert rad to turns
        turns: transform.rotation * (57.29578 / 360),
        curve: Curves.easeInOut,
        duration: const Duration(milliseconds: 300),
        child: Transform.scale(
          scale: transform.scale,
          child: Transform.translate(
            offset: transform.translate,
            child: child,
          ),
        ),
      ),
    );
  }
}
