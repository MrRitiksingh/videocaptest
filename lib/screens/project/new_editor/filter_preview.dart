import 'package:ai_video_creator_editor/screens/project/new_editor/text_overlay_manager.dart';
import 'package:flutter/material.dart';

class FilterPreview extends StatelessWidget {
  final String filter;
  final Widget child;

  const FilterPreview({
    super.key,
    required this.filter,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: FilterManager.getColorFilter(filter),
      child: child,
    );
  }
}
