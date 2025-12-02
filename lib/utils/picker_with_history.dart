import 'dart:io';

import 'package:ai_video_creator_editor/constants/extensions.dart';
import 'package:ai_video_creator_editor/utils/picked_file_custom.dart';
import 'package:ai_video_creator_editor/utils/uploads.dart';
import 'package:dio/dio.dart';
import 'package:dio_http_cache_fix/dio_http_cache.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/file_image_viewer.dart';
import '../components/glowing_button.dart';
import '../components/text_field.dart';
import '../constants/colors.dart';
import '../models/locale_keys.g.dart';
import 'functions.dart';

Future<PickedFileCustom?> pickImageFromLocalOrUrl({
  required BuildContext ctx,
  required String fileType,
  String? requestType,
  // String? title,
  int? durationSeconds,
  bool? resizeImage = false,
  bool? checkNSFW = false,
}) async {
  // checkNSFW =
  //     checkNSFW == true ? checkNSFW : ctx.read<AWSAuthRepo>().checkAcc();
  int selectedTab = 0;
  PickedFileCustom? imageFile;
  TextEditingController textEditingController = TextEditingController();
  Future future = Future.value();
  imageFile = await showModalBottomSheet<PickedFileCustom?>(
    constraints: BoxConstraints.tightFor(
      width: MediaQuery.of(ctx).size.width,
      // height: null,
      height: MediaQuery.of(ctx).size.height * 0.65,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(10.0)),
    ),
    isScrollControlled: true,
    backgroundColor: ColorConstants.primaryColor,
    context: ctx,
    builder: (context) => StatefulBuilder(builder: (context, setState) {
      return Card(
        margin: EdgeInsets.zero,
        color: ColorConstants.primaryColor,
        child: ListView(
          // mainAxisSize: MainAxisSize.max,
          // crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Center(
                  child: Text(
                      fileType == "image"
                          ? LocaleKeys.selectAnImage.tr()
                          : fileType == "video"
                              ? LocaleKeys.selectAVideo.tr()
                              : "",
                      style: const TextStyle(fontSize: 20.0))),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: SizedBox(
                height: 100,
                child: Flex(
                  direction: Axis.horizontal,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        onTap: () async {
                          setState(() {
                            selectedTab = 0;
                          });
                          if (fileType == "image") {
                            await pickImage(context,
                                    resizeImage: resizeImage,
                                    checkNSFW: checkNSFW)
                                .then((File? value) {
                              if (value == null) return;
                              textEditingController.clear();
                              setState(() {
                                selectedTab = 0;
                                imageFile?.file = value;
                              });
                              imageFile = PickedFileCustom(
                                  fileUrl: null,
                                  file: value,
                                  betterPlayerDataSourceType:
                                      FileDataSourceType.file);
                              Navigator.pop(context, imageFile);
                            });
                          } else if (fileType == "video") {
                            await pickVideo(context,
                                    durationSeconds: durationSeconds)
                                .then((File? value) {
                              if (value == null) return;
                              textEditingController.clear();
                              setState(() {
                                selectedTab = 0;
                                imageFile?.file = value;
                              });
                              imageFile = PickedFileCustom(
                                  fileUrl: null,
                                  file: value,
                                  betterPlayerDataSourceType:
                                      FileDataSourceType.file);
                              Navigator.pop(context, imageFile);
                            });
                          }
                        },
                        child: ClipRRect(
                          child: Container(
                            height: 120,
                            width: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10.0),
                              border: Border.all(
                                  color: selectedTab == 0
                                      ? ColorConstants.loadingWavesColor
                                      : Colors.grey,
                                  width: selectedTab == 0 ? 2 : 1),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  CupertinoIcons.upload_circle,
                                  size: 70,
                                  color: Color.fromRGBO(11, 112, 254, 1),
                                ),
                                Flexible(
                                  child: Text(
                                    fileType == "image"
                                        ? LocaleKeys.uploadImage.tr()
                                        : LocaleKeys.uploadVideo.tr(),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    // style: const TextStyle(
                                    //   fontSize: 26.0,
                                    // ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20.0),
                    Text(LocaleKeys.or.tr()),
                    const SizedBox(width: 20.0),
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        onTap: () async {
                          setState(() {
                            selectedTab = 1;
                          });
                        },
                        child: Container(
                          height: 120,
                          width: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10.0),
                            border: Border.all(
                                color: selectedTab == 1
                                    ? ColorConstants.loadingWavesColor
                                    : Colors.grey,
                                width: selectedTab == 1 ? 2 : 1),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.link,
                                size: 70,
                                color: Color.fromRGBO(11, 112, 254, 1),
                              ),
                              Flexible(
                                child: Text(
                                  LocaleKeys.fromURL.tr(),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  // style: const TextStyle(
                                  //   fontSize: 16.0,
                                  // ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
            selectedTab == 1
                ? Column(
                    children: [
                      TextFieldWidget(
                        textEditingController: textEditingController,
                        maxLines: 5,
                        onFieldSubmitted: (value) {},
                        textInputAction: TextInputAction.go,
                        hintText: LocaleKeys.pasteImageURL.tr(),
                        suffix: IconButton(
                          onPressed: () async {
                            ClipboardData? clipboardContent =
                                await Clipboard.getData(Clipboard.kTextPlain);
                            textEditingController.text =
                                clipboardContent?.text ?? "";
                          },
                          icon: const Icon(Icons.paste),
                          // label: Text(LocaleKeys.paste.tr()),
                        ),
                      ),
                      GlowingGenerateButton(
                        onTap: () async {
                          textEditingController.text.trim();
                          bool isValidURL =
                              isValidUrl(textEditingController.text);
                          if (!isValidURL) {
                            if (!ctx.mounted) return;
                            showToast(
                                context: context,
                                title: "",
                                description: LocaleKeys.uRLNotFromImage.tr(),
                                toastType: ToastType.info);
                            return;
                          }
                          try {
                            bool isImage = await isImageUrl(
                                textEditingController.text, fileType);
                            if (isImage) {
                              String downloadUrl =
                                  textEditingController.text.trim();
                              imageFile = PickedFileCustom(
                                fileUrl: downloadUrl,
                                file: null,
                                betterPlayerDataSourceType:
                                    FileDataSourceType.network,
                              );
                              if (!ctx.mounted) return;
                              Navigator.pop(context, imageFile);
                            } else {
                              if (!ctx.mounted) return;
                              showToast(
                                  context: context,
                                  title: "",
                                  description: LocaleKeys.uRLNotFromImage.tr(),
                                  toastType: ToastType.info);
                            }
                          } catch (err) {
                            if (!context.mounted) return;
                            showToast(
                              context: context,
                              title: "",
                              description: LocaleKeys.anError.tr(),
                              toastType: ToastType.warning,
                            );
                          }
                        },
                        icon: Icons.add_a_photo,
                        string: Text(LocaleKeys.add.tr()).data,
                      ),
                      const SizedBox(height: 10.0),
                    ],
                  )
                : context.shrink(),
            selectedTab == 1
                ? context.shrink()
                : FutureBuilder(
                    // future: readConversationByLocalAIID(fileType: fileType),
                    future: future,
                    builder: (context, snapshot) {
                      if (snapshot.hasData &&
                          snapshot.connectionState == ConnectionState.done) {}
                      return context.shrink();
                    },
                  ),
          ],
        ),
      );
    }),
  );
  return imageFile;
}

class MultiImagePickerProvider extends ChangeNotifier {
  List<PickedFileCustom> imageFiles = [];
  List<PickedFileCustom> imageFilesWithCheck = [];
  TextEditingController textEditingController = TextEditingController();
}

Future<bool> isImageUrl(String url, String filetype) async {
  try {
    final dio = Dio();
    dio.interceptors
        .add(DioCacheManager(CacheConfig(baseUrl: url)).interceptor);
    final response = await dio.head(
      url,
      options: buildCacheOptions(const Duration(days: 2),
          forceRefresh: false, maxStale: const Duration(days: 3)),
    );
    if (response.statusCode == 200) {
      final contentType = response.headers['content-type'];
      if (contentType != null && contentType.first.startsWith(filetype)) {
        return true;
      }
    }
  } catch (e) {
    safePrint(e.toString());
    rethrow;
  }
  return false;
}

bool isValidUrl(String url) {
  final RegExp urlRegex = RegExp(
    r"^(ftp|http|https):\/\/[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)+([/?].*)?$",
    caseSensitive: false,
    multiLine: false,
  );
  return urlRegex.hasMatch(url);
}

Iterable<T> removeDuplicates<T>(Iterable<T> iterable) sync* {
  Set<T> items = {};
  for (T item in iterable) {
    if (!items.contains(item)) yield item;
    items.add(item);
  }
}
