import 'package:ai_video_creator_editor/constants/extensions.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';

import '../constants/colors.dart';

class LoaderWidgetOverlay extends StatelessWidget {
  final Widget child;

  const LoaderWidgetOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LoaderOverlay(
      key: key,
      overlayWidgetBuilder: (progress) => Center(
        child: ripple(),
      ),
      overlayColor: ColorConstants.overLayColor,
      useDefaultLoading: false,
      disableBackButton: true,
      child: child,
    );
  }
}

Widget ripple() {
  return Material(
    color: Colors.transparent,
    child: Container(
      height: 150,
      width: 150,
      decoration: BoxDecoration(
        color: ColorConstants.primaryColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          10.sz(),
          // Text(LocaleKeys.loading.tr()),
        ],
      ),
    ),
  );
}
