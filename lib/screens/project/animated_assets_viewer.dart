import 'package:flutter/cupertino.dart';
import 'package:photo_manager/photo_manager.dart';

class AnimatedAssetsViewer extends StatefulWidget {
  final List<AssetEntity> assets;

  const AnimatedAssetsViewer({
    super.key,
    required this.assets,
  });

  @override
  State<AnimatedAssetsViewer> createState() => _AnimatedAssetsViewerState();
}

class _AnimatedAssetsViewerState extends State<AnimatedAssetsViewer> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
