import 'dart:io';
import 'dart:math';

import 'package:ai_video_creator_editor/utils/picked_file_custom.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'package:toastification/toastification.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../constants/colors.dart';

void safePrint(o) {
  if (kDebugMode) {
    print("$o");
  }
}

// void copy(o) {
//   if (kDebugMode) {
//     Clipboard.setData(ClipboardData(text: "$o"));
//   }
// }

int getRandom({int? maxNumber}) => Random().nextInt(maxNumber ?? 2147483647);

Future<File> resizeImageFile({
  required File pickedImageFile,
}) async {
  return pickedImageFile;
}

Future<File> resizeImageFileToThisDesiredSize({
  required File pickedImageFile,
  required Size desiredSize,
}) async {
  return pickedImageFile;
}

Future<PickedFileCustom> resizePickedFileCustomImage(
    {required PickedFileCustom pickedFileCustom}) async {
  return pickedFileCustom;
}

Future<Uint8List?> generateThumbnailData(
    {required String videoUrl, /*required*/ bool? passMacos}) async {
  final thumbnailFile = await VideoThumbnail.thumbnailData(
    video: videoUrl,
    imageFormat: ImageFormat.PNG,
    maxHeight: 0,
    maxWidth: 0,
    quality: 10,
  );
  // base64Decode(offlineArt!.imageBinary!.first),
  return thumbnailFile;
}

Future<bool> hasNudityChecker({required PickedFileCustom imageFile}) async {
  return false;
}

enum ToastType {
  error,
  info,
  success,
  warning,
}

showToast({
  required BuildContext context,
  required String title,
  required String description,
  required ToastType toastType,
  VoidCallback? onCloseTap,
  Widget? icon,
}) {
  Color getColor() {
    switch (toastType) {
      case ToastType.error:
        return ColorConstants.toastError;
      case ToastType.info:
        return ColorConstants.toastInfo;
      case ToastType.success:
        return ColorConstants.toastSuccess;
      case ToastType.warning:
        return ColorConstants.toastWarning;
    }
  }

  Icon getIcon() {
    switch (toastType) {
      case ToastType.error:
        return const Icon(Icons.error, color: Colors.white);
      case ToastType.info:
        return const Icon(Icons.info, color: Colors.white);
      case ToastType.success:
        return const Icon(Icons.check, color: Colors.white);
      case ToastType.warning:
        return const Icon(Icons.check, color: Colors.white);
    }
  }

  return toastification.show(
    context: context,
    title: Text(toastType == ToastType.success ? title : description),
    // title: title,
    description: Text(toastType == ToastType.success ? description : ""),
    autoCloseDuration: const Duration(seconds: 5),
    icon: icon ?? getIcon(),
    backgroundColor: getColor(),
    foregroundColor: Colors.white,
    showProgressBar: true,
    // showCloseButton: true,
    closeOnClick: true,
    pauseOnHover: true,
    callbacks: ToastificationCallbacks(
        onTap: (ToastificationItem toastificationItem) => onCloseTap),
  );
}
