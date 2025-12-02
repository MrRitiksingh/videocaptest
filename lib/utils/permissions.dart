import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../components/platform_alert_dialog.dart';
import '../models/locale_keys.g.dart';
import 'functions.dart';

Future<PermissionStatus?> getAudioPermission(BuildContext context) async {
  if (Platform.isMacOS) {
    return PermissionStatus.granted;
  }
  if (Platform.isIOS) {
    /// IOS request
    var status = await Permission.storage.status;
    status = await Permission.storage.request();
    return status;
  } else {
    PermissionStatus? status;

    /// android request
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt <= 32) {
      /// use [Permissions.storage.status] for Android 12 and below
      if (await Permission.storage.isDenied) {
        status = await openAppInfoRequestPermission(
          context,
          LocaleKeys.toUploadAudioStorage.tr(),
          requestPermission: true,
          requestPermissionCallback: () async {
            status = await Permission.storage
                .request()
                .whenComplete(() => Navigator.of(context).pop());
          },
        );
        return status;
      } else {
        return Permission.storage.status;
      }
    } else {
      /// use [Permissions.photos.status]
      if (await Permission.audio.isDenied) {
        status = await openAppInfoRequestPermission(
          context,
          LocaleKeys.toUploadAudioMusicNAudio.tr(),
          requestPermission: true,
          requestPermissionCallback: () async {
            status = await Permission.audio
                .request()
                .whenComplete(() => Navigator.of(context).pop());
          },
        );
        return status;
      } else {
        return Permission.audio.status;
      }
    }
  }
}

Future<PermissionStatus> getCameraPermission() async {
  if (Platform.isMacOS) {
    return PermissionStatus.granted;
  }
  var status = await Permission.camera.status;
  status = await Permission.camera.request();
  return status;
}

openAppInfoRequestPermission(BuildContext context, String content,
    {final bool? requestPermission,
    final VoidCallback? requestPermissionCallback}) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return requestPermission == true
          ? PlatformAlertDialog(
              title: LocaleKeys.notice.tr(),
              content: content,
              actionTitle: [
                LocaleKeys.notNow.tr(),
                LocaleKeys.continueT.tr(),
              ],
              actionPressed: [
                () => Navigator.of(context).pop(),
                requestPermissionCallback ?? () {},
              ],
            )
          : PlatformAlertDialog(
              title: LocaleKeys.notice.tr(),
              content: content,
              actionTitle: [
                  LocaleKeys.notNow.tr(),
                  LocaleKeys.settings.tr()
                ],
              actionPressed: [
                  () => Navigator.of(context).pop(),
                  () => openAppSettings()
                      .whenComplete(() => Navigator.of(context).pop()),
                ]);
    },
  );
}

Future<PermissionStatus> getGalleryPermission() async {
  var status = await Permission.mediaLibrary.request();
  if (Platform.isMacOS) {
    // safePrint("Macos photos permission requested");
    return PermissionStatus.granted;
    // var status = await Permission.photos.status;
    // status = await Permission.photos.request();
    // return status;
  } else if (Platform.isIOS) {
    /// IOS request
    var status = await Permission.photos.status;
    if (status.isGranted) {
      return PermissionStatus.granted;
    }
    status = await Permission.photos.request();
    safePrint("status: $status");
    return status;
  } else {
    /// android request
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt <= 32) {
      /// use [Permissions.storage.status] for Android 12 and below
      var status = await Permission.storage.status;
      status = await Permission.storage.request();
      return status;
    } else {
      /// use [Permissions.photos.status]
      var status = await Permission.photos.status;
      status = await Permission.photos.request();
      return status;
    }
  }
}
