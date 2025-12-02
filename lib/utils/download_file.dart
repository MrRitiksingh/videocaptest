import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import '../models/locale_keys.g.dart';
import 'functions.dart';

String appName = "VibeTunes";

Future<void> saveVideoToGallery(
    {required String urlPath, required BuildContext context}) async {
  try {
    final path =
        '${Directory.systemTemp.path}/Aethia_Music_${DateTime.now().microsecondsSinceEpoch}${getRandom().toString().replaceAll(".", "")}.mp4';
    await Dio().download(
      urlPath,
      path,
    );
    await Gal.putVideo(path, album: appName)
        // await GallerySaver.saveVideo(urlPath, albumName: appName, toDcim: true)
        .then(
      (value) => showToast(
          context: context,
          title: LocaleKeys.download.tr(),
          description: LocaleKeys.downloadSuccessfully.tr(),
          toastType: ToastType.success),
      // showToast(context: context, title: '', description: '', toastType: ToastType.info);
    );
  } catch (e) {
    // debugPrint("Error ${e}");
    showToast(
        context: context,
        title: LocaleKeys.error.tr(),
        description: LocaleKeys.anError.tr(),
        toastType: ToastType.error);
  }
}

Future<void> saveVideoBytesToGallery(
    {required File videoFile, required BuildContext context}) async {
  try {
    final path = videoFile.path;
    safePrint(path);
    await Gal.putVideo(path, album: appName)
        // await GallerySaver.saveVideo(urlPath, albumName: appName, toDcim: true)
        .then(
      (value) => showToast(
          context: context,
          title: LocaleKeys.download.tr(),
          description: LocaleKeys.downloadSuccessfully.tr(),
          toastType: ToastType.success),
      // showToast(context: context, title: '', description: '', toastType: ToastType.info);
    );
  } catch (e) {
    // debugPrint("Error ${e}");
    showToast(
        context: context,
        title: LocaleKeys.error.tr(),
        description: LocaleKeys.anError.tr(),
        toastType: ToastType.error);
  }
}

saveAudioToDownloads(
    {required BuildContext context,
    required String audiUrl,
    String? fileName,
    String? folderName}) async {
  final dio = Dio();
  Response response = await dio.get(audiUrl,
      options: Options(
        responseType: ResponseType.bytes,
      ));
  var fallbackPath = Platform.isIOS
      ? await getApplicationDocumentsDirectory()
      : Platform.isAndroid
          ? await getExternalStorageDirectory()
          : Platform.isMacOS
              ? await getDownloadsDirectory()
              : null;
  Directory? picturesAethiaPath;
  if (!Platform.isMacOS) {
    if (Platform.isIOS) {
      picturesAethiaPath = await getApplicationDocumentsDirectory();
    } else {
      picturesAethiaPath = await getDownloadsDirectory();
    }
  }
  String savePath = Platform.isIOS || Platform.isMacOS
      ? "${fallbackPath?.path}${Platform.isMacOS ? "/$appName" : ""}/${folderName ?? "Speech Studio"}/${fileName ?? "voice"}-${DateTime.now().microsecondsSinceEpoch}.mp3"
      : "${picturesAethiaPath?.path ?? fallbackPath?.path}/$appName/${folderName ?? "Speech Studio"}/${fileName ?? "voice"}-${DateTime.now().microsecondsSinceEpoch}.mp3";
  Uint8List uint8List = response.data as Uint8List;
  File file = File(savePath);
  file.createSync(recursive: true);
  file.writeAsBytesSync(uint8List);
  safePrint("AUDIO SAVE PATH: $savePath");
  if (!context.mounted) return null;
  showToast(
    context: context,
    title: LocaleKeys.success.tr(),
    description: Platform.isIOS
        ? LocaleKeys.yourGeneratedVoiceSavedIOS.tr(args: [appName])
        : LocaleKeys.yourGeneratedVoiceSavedAndroid.tr(),
    toastType: ToastType.success,
  );
}

saveFileToDownloads(
    {required BuildContext context, required String audiUrl}) async {
  final dio = Dio();
  Response response = await dio.get(audiUrl,
      options: Options(
        responseType: ResponseType.bytes,
      ));
  var fallbackPath = Platform.isIOS
      ? await getApplicationDocumentsDirectory()
      : Platform.isAndroid
          ? await getExternalStorageDirectory()
          : Platform.isMacOS
              ? await getDownloadsDirectory()
              : null;
  Directory? picturesAethiaPath;
  if (!Platform.isMacOS) {
    picturesAethiaPath = Platform.isIOS
        ? await getApplicationDocumentsDirectory()
        : await getDownloadsDirectory();
  }
  String savePath = Platform.isIOS || Platform.isMacOS
      ? "${fallbackPath?.path}${Platform.isMacOS ? "/$appName" : ""}/Files/${appName}_file_${getRandomString(length: 24)}.${audiUrl.split(".").last}"
      : "${picturesAethiaPath?.path ?? fallbackPath?.path}/$appName/Files/${appName}_file_${getRandomString(length: 24)}.${audiUrl.split(".").last}";
  Uint8List uint8List = response.data as Uint8List;
  File file = File(savePath);
  file.createSync(recursive: true);
  file.writeAsBytesSync(uint8List);
  safePrint("File SAVE PATH: $savePath");
  if (!context.mounted) return null;
  showToast(
    context: context,
    title: LocaleKeys.success.tr(),
    description: Platform.isIOS
        ? LocaleKeys.yourGeneratedFileSavedIOS.tr(args: [appName])
        : LocaleKeys.yourGeneratedFileSavedAndroid.tr(),
    toastType: ToastType.success,
  );
}

Future<void> saveToGallery(
    {required String urlPath, required BuildContext context}) async {
  try {
    /// In Macos Download works but the project has to be built from xcode
    final path =
        '${Directory.systemTemp.path}/Aethia-${DateTime.now().microsecondsSinceEpoch}${getRandom().toString().replaceAll(".", "")}.png';
    await Dio().download(
      urlPath,
      path,
    );

    try {
      await Gal.putImage(path, album: Platform.isMacOS ? null : appName)
          // await GallerySaver.saveImage(urlPath, albumName: appName, toDcim: true)
          .then((value) => showToast(
              context: context,
              title: LocaleKeys.download.tr(),
              description: LocaleKeys.downloadSuccessfully.tr(),
              toastType: ToastType.success));
    } catch (err) {
      safePrint(err);
      rethrow;
    }
  } catch (e) {
    safePrint(e);
    // debugPrint("Error ${e}");
    showToast(
      context: context,
      title: LocaleKeys.error.tr(),
      description: LocaleKeys.anError.tr(),
      toastType: ToastType.error,
    );
  }
}

String getRandomString({int? length}) {
  const chars =
      'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
  Random rnd = Random();
  return String.fromCharCodes(
    Iterable.generate(
      length ?? 16,
      (_) => chars.codeUnitAt(
        rnd.nextInt(chars.length),
      ),
    ),
  );
}
