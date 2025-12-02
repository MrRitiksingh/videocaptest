import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ai_video_creator_editor/utils/permissions.dart';
import 'package:ai_video_creator_editor/utils/picked_file_custom.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:easy_audio_trimmer/easy_audio_trimmer.dart';
import 'package:easy_localization/easy_localization.dart';
// import 'package:easy_audio_trimmer/easy_audio_trimmer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hl_image_picker/hl_image_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart' as vp;

import '../components/file_image_viewer.dart';
import '../constants/colors.dart';
import '../constants/urls.dart';
import '../models/locale_keys.g.dart';
import 'functions.dart';

int maxDurationOfPickedAudio = 300;
int maxDurationOfPickedVideo = 300;

Future<File?> pickVideo(BuildContext context, {int? durationSeconds}) async {
  File? imageTemp;
  AndroidDeviceInfo? androidInfo;

  /// Ask For permission

  if (Platform.isAndroid) {
    androidInfo = await DeviceInfoPlugin().androidInfo;
  }

  /// Ask For permission
  await getGalleryPermission().then((value) async {
    if (value.isGranted) {
      try {
        // var image = await ImagePicker().pickVideo(
        //   source: ImageSource.gallery,
        //   maxDuration: const Duration(seconds: 10),
        // );
        var pickedFile = Platform.isIOS
            ? await FilePicker.platform.pickFiles(
                type: FileType.video,
                // allowedExtensions: ["mp3", "m4a"] ,
              )
            : await ImagePicker().pickVideo(
                source: ImageSource.gallery,
                maxDuration: Duration(
                    seconds: durationSeconds ?? maxDurationOfPickedVideo),
              );
        if (pickedFile == null) return null;
        File? image;
        if (pickedFile.runtimeType == FilePickerResult) {
          FilePickerResult? filePickerResult = pickedFile as FilePickerResult;
          image = File(filePickerResult.paths.first!);
        } else if (pickedFile.runtimeType == XFile) {
          XFile xFile = pickedFile as XFile;
          image = File(xFile.path);
        }

        // pickedFile.runtimeType == FilePickerResult ;
        if (image == null) return null;

        ///old
        vp.VideoPlayerController videoPlayerController =
            vp.VideoPlayerController.file(File(image.path));
        await videoPlayerController.initialize();
        if (videoPlayerController.value.duration.inSeconds >=
            (durationSeconds ?? maxDurationOfPickedVideo)) {
          image = null;
          showToast(
              context: context,
              title: "",
              description: LocaleKeys.pleasePickShorterVideo.tr(),
              toastType: ToastType.warning);
          throw Error;
        } else {
          //ok
          imageTemp = File(image.path);
        }
      } on PlatformException catch (e) {
        debugPrint(e.message.toString());
        showToast(
            context: context,
            title: LocaleKeys.error.tr(),
            description: LocaleKeys.anError.tr(),
            toastType: ToastType.error);
      }
    } else if (value.isDenied) {
      showToast(
          context: context,
          title: LocaleKeys.pleaseGrantPermission.tr(),
          description: LocaleKeys.pleaseGrantPermission.tr(),
          toastType: ToastType.warning);
      await getGalleryPermission().then((value) async {
        if (value.isGranted) {
          try {
            var image = await ImagePicker().pickVideo(
              source: ImageSource.gallery,
              maxDuration: const Duration(seconds: 10),
            );
            if (image == null) return null;
            // imageTemp = File(image.path);
            vp.VideoPlayerController videoPlayerController =
                vp.VideoPlayerController.file(File(image.path));
            await videoPlayerController.initialize();
            if (videoPlayerController.value.duration.inSeconds >=
                (durationSeconds ?? maxDurationOfPickedVideo)) {
              image = null;
              showToast(
                  context: context,
                  title: "",
                  description: LocaleKeys.pleasePickShorterVideo.tr(),
                  toastType: ToastType.warning);
              throw Error;
            } else {
              //ok
              imageTemp = File(image.path);
            }
          } on PlatformException catch (e) {
            debugPrint(e.message.toString());
            showToast(
                context: context,
                title: LocaleKeys.error.tr(),
                description: LocaleKeys.anError.tr(),
                toastType: ToastType.error);
          }
        }
      });
    } else if (value.isPermanentlyDenied) {
      showToast(
          context: context,
          title: LocaleKeys.grantPermission.tr(),
          description: LocaleKeys.pleaseAllowFullPhotosAccess.tr(),
          toastType: ToastType.info);
      openAppInfoRequestPermission(
          context,
          Platform.isIOS
              ? LocaleKeys.toUploadVideosIos.tr(args: [appName])
              : androidInfo!.version.sdkInt <= 32
                  ? LocaleKeys.toUploadVideosAndroid.tr(args: [appName])
                  : LocaleKeys.toUploadVideosAndroid33.tr(args: [appName]));
    }
  });
  if (imageTemp != null) {
    imageTemp = await renameFileIfNecessary(imageTemp!);
  }
  return imageTemp;
}

Future<String> fileToBas64Wav(File file) async {
  List<int> fileBytes = await file.readAsBytes();
  String base64String = base64Encode(fileBytes);
  final fileString = "data:audio/wav;base64,$base64String";
  return fileString;
}

// Future<File?> pickImage(BuildContext context) async {
//   if (Platform.isMacOS) {
//     final image = await ImagePicker().pickImage(
//       source: ImageSource.gallery,
//       imageQuality: 95,
//       requestFullMetadata: false,
//     );
//     if (image == null) return null;
//     var imageTemp = File(image.path ?? "");
//     return imageTemp;
//   }
//   File? imageTemp;
//   AndroidDeviceInfo? androidInfo;
//
//   /// Ask For permission
//
//   if (Platform.isAndroid) {
//     androidInfo = await DeviceInfoPlugin().androidInfo;
//   }
//
//   await getGalleryPermission().then((value) async {
//     if (value.isGranted) {
//       try {
//         // safePrint("yasss");
//         final image = await ImagePicker().pickImage(
//           source: ImageSource.gallery,
//           imageQuality: 95,
//           requestFullMetadata: false,
//         );
//         if (image == null) return null;
//         imageTemp = File(image.path);
//       } catch (e) {
//         debugPrint(e.toString());
//         showToast(
//             context: context,
//             title: LocaleKeys.error.tr(),
//             description: LocaleKeys.anError.tr(),
//             toastType: ToastType.error);
//       }
//     } else if (value.isDenied) {
//       showToast(
//           context: context,
//           title: LocaleKeys.pleaseGrantPermission.tr(),
//           description: LocaleKeys.pleaseGrantPermission.tr(),
//           toastType: ToastType.warning);
//       await getGalleryPermission().then((value) async {
//         if (value.isGranted) {
//           try {
//             final image = await ImagePicker().pickImage(
//               source: ImageSource.gallery,
//               imageQuality: 95,
//               requestFullMetadata: false,
//             );
//             if (image == null) return null;
//             imageTemp = File(image.path);
//           } catch (e) {
//             debugPrint(e.toString());
//             showToast(
//                 context: context,
//                 title: LocaleKeys.error.tr(),
//                 description: LocaleKeys.anError.tr(),
//                 toastType: ToastType.error);
//           }
//         }
//       });
//     } else {
//       showToast(
//           context: context,
//           title: '',
//           description: LocaleKeys.pleaseAllowFullPhotosAccess.tr(),
//           toastType: ToastType.info);
//       openAppInfoRequestPermission(
//         context,
//         Platform.isIOS
//             ? LocaleKeys.toUploadPhotoIos.tr(args: [appName])
//             : androidInfo!.version.sdkInt <= 32
//                 ? LocaleKeys.toUploadPhotoAndroid.tr(args: [appName])
//                 : LocaleKeys.toUploadPhotoAndroid33.tr(args: [appName]),
//       );
//       // : "To upload photo, allow Aethia to access your device's photos.\nTap Settings>Permissions, and turn \"${androidInfo!.version.sdkInt <= 32 ? 'Storage' : 'Photos and videos'}\" on.");
//       // await Future.delayed(const Duration(seconds: 2));
//       // openAppSettings();
//     }
//   });
//   return imageTemp;
// }
final _picker = HLImagePicker();
Future<File?> pickImage(BuildContext context,
    {int? compressQuality,
    bool? resizeImage = false,
    bool? checkNSFW = false}) async {
  if (Platform.isMacOS) {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: compressQuality ?? 95,
      requestFullMetadata: false,
    );
    if (image == null) return null;
    var imageTemp = File(image.path);
    if (resizeImage == true) {
      File resizedImageFile = await resizeImageFile(pickedImageFile: imageTemp);
      imageTemp = resizedImageFile;
      // return resizedImageFile;
    }
    if (checkNSFW == true) {
      bool hasNudity = await hasNudityChecker(
          imageFile: PickedFileCustom(
              betterPlayerDataSourceType: FileDataSourceType.file,
              file: imageTemp));
      if (hasNudity) {
        showToast(
          context: context,
          title: "",
          description: LocaleKeys.pleaseTryAnotherImage.tr(),
          toastType: ToastType.warning,
        );
        return null;
      }
      // return imageTemp;
    }
    return imageTemp;
  }
  File? imageTemp;
  AndroidDeviceInfo? androidInfo;

  /// Ask For permission

  if (Platform.isAndroid) {
    androidInfo = await DeviceInfoPlugin().androidInfo;
  }

  await getGalleryPermission().then((value) async {
    if (value.isGranted) {
      try {
        final image = await _picker.openPicker(
          // cropping: true,
          // cropOptions: const HLCropOptions(),
          pickerOptions: const HLPickerOptions(
            usedCameraButton: true,
            enablePreview: true,
            maxFileSize: 8192,
            convertHeicToJPG: true,
            convertLivePhotosToJPG: true,
            mediaType: MediaType.image,
          ),
        );
        // setState(() {
        //   _selectedImages = images;
        // });
        // final image = await ImagePicker().pickImage(
        //   source: ImageSource.gallery,
        //   imageQuality: compressQuality ?? 95,
        //   requestFullMetadata: false,
        // );
        if (image.isEmpty) return null;
        imageTemp = File(image.first.path);
      } catch (e) {
        debugPrint(e.toString());
        showToast(
            context: context,
            title: LocaleKeys.error.tr(),
            description: LocaleKeys.anError.tr(),
            toastType: ToastType.error);
      }
    } else if (value.isDenied) {
      showToast(
          context: context,
          title: LocaleKeys.pleaseGrantPermission.tr(),
          description: LocaleKeys.pleaseGrantPermission.tr(),
          toastType: ToastType.warning);
      await getGalleryPermission().then((value) async {
        if (value.isGranted) {
          try {
            final image = await _picker.openPicker(
              pickerOptions: const HLPickerOptions(),
            );
            // final image = await ImagePicker().pickImage(
            //   source: ImageSource.gallery,
            //   imageQuality: compressQuality ?? 95,
            //   requestFullMetadata: false,
            // );
            if (image.isEmpty) return null;
            imageTemp = File(image.first.path);
          } catch (e) {
            debugPrint(e.toString());
            showToast(
                context: context,
                title: LocaleKeys.error.tr(),
                description: LocaleKeys.anError.tr(),
                toastType: ToastType.error);
          }
        }
      });
    } else {
      showToast(
          context: context,
          title: '',
          description: LocaleKeys.pleaseAllowFullPhotosAccess.tr(),
          toastType: ToastType.info);
      openAppInfoRequestPermission(
        context,
        Platform.isIOS
            ? LocaleKeys.toUploadPhotoIos.tr(args: [appName])
            : androidInfo!.version.sdkInt <= 32
                ? LocaleKeys.toUploadPhotoAndroid.tr(args: [appName])
                : LocaleKeys.toUploadPhotoAndroid33.tr(args: [appName]),
      );
      // : "To upload photo, allow Aethia to access your device's photos.\nTap Settings>Permissions, and turn \"${androidInfo!.version.sdkInt <= 32 ? 'Storage' : 'Photos and videos'}\" on.");
      // await Future.delayed(const Duration(seconds: 2));
      // openAppSettings();
    }
  });
  if (resizeImage == true && imageTemp != null) {
    File resizedImageFile = await resizeImageFile(pickedImageFile: imageTemp!);
    imageTemp = resizedImageFile;
    // return resizedImageFile;
  }
  if (checkNSFW == true) {
    bool hasNudity = await hasNudityChecker(
        imageFile: PickedFileCustom(
            betterPlayerDataSourceType: FileDataSourceType.file,
            file: imageTemp));
    if (hasNudity) {
      showToast(
        context: context,
        title: "",
        description: LocaleKeys.pleaseTryAnotherImage.tr(),
        toastType: ToastType.warning,
      );
      return null;
    }
    return imageTemp;
  }
  return imageTemp;
}

Future<List<File>?> pickImages(BuildContext context,
    {bool? resizeImages = false}) async {
  if (Platform.isMacOS) {
    final images = await ImagePicker().pickMultiImage(
      imageQuality: 95,
      requestFullMetadata: Platform.isAndroid ? true : false,
    );
    List<File> imageTemp = [];
    images.map((image) => imageTemp.add(File(image.path))).toList();
    if (resizeImages == true && imageTemp.isNotEmpty) {
      List<File> imagesTempResized = [];
      for (File i in imageTemp) {
        File resizedImageFile = await resizeImageFile(pickedImageFile: i);
        imagesTempResized.add(resizedImageFile);
      }
      return imagesTempResized;
    }
    return imageTemp;
  }
  List<File> imageTemp = [];
  AndroidDeviceInfo? androidInfo;

  /// Ask For permission

  if (Platform.isAndroid) {
    androidInfo = await DeviceInfoPlugin().androidInfo;
  }

  await getGalleryPermission().then((value) async {
    if (value.isGranted) {
      try {
        final images = await ImagePicker().pickMultiImage(
          imageQuality: Platform.isAndroid ? null : 95,
          requestFullMetadata: Platform.isAndroid ? true : false,
        );
        // var imageTempMap =
        images.map((image) => imageTemp.add(File(image.path))).toList();
        if (resizeImages == true && imageTemp.isNotEmpty) {
          List<File> imagesTempResized = [];
          for (File i in imageTemp) {
            File resizedImageFile = await resizeImageFile(pickedImageFile: i);
            imagesTempResized.add(resizedImageFile);
          }
          return imagesTempResized;
        }
        return imageTemp;
      } catch (e) {
        debugPrint(e.toString());
        showToast(
            context: context,
            title: LocaleKeys.error.tr(),
            description: LocaleKeys.anError.tr(),
            toastType: ToastType.error);
      }
    } else if (value.isDenied) {
      showToast(
          context: context,
          title: LocaleKeys.pleaseGrantPermission.tr(),
          description: LocaleKeys.pleaseGrantPermission.tr(),
          toastType: ToastType.warning);
      await getGalleryPermission().then((value) async {
        if (value.isGranted) {
          try {
            // final image = await ImagePicker().pickImage(
            //   source: ImageSource.gallery,
            //   imageQuality: 95,
            //   requestFullMetadata: false,
            // );
            final images = await ImagePicker().pickMultiImage(
              imageQuality: 95,
              requestFullMetadata: Platform.isAndroid ? true : false,
            );
            // var imageTempMap =
            images.map((image) => imageTemp.add(File(image.path))).toList();
            if (resizeImages == true && imageTemp.isNotEmpty) {
              List<File> imagesTempResized = [];
              for (File i in imageTemp) {
                File resizedImageFile =
                    await resizeImageFile(pickedImageFile: i);
                imagesTempResized.add(resizedImageFile);
              }
              return imagesTempResized;
            }
            return imageTemp;
          } catch (e) {
            debugPrint(e.toString());
            showToast(
                context: context,
                title: LocaleKeys.error.tr(),
                description: LocaleKeys.anError.tr(),
                toastType: ToastType.error);
          }
        }
      });
    } else {
      showToast(
          context: context,
          title: '',
          description: LocaleKeys.pleaseAllowFullPhotosAccess.tr(),
          toastType: ToastType.info);
      openAppInfoRequestPermission(
        context,
        Platform.isIOS
            ? LocaleKeys.toUploadPhotoIos.tr(args: [appName])
            : androidInfo!.version.sdkInt <= 32
                ? LocaleKeys.toUploadPhotoAndroid.tr(args: [appName])
                : LocaleKeys.toUploadPhotoAndroid33.tr(args: [appName]),
      );
    }
  });
  if (resizeImages == true && imageTemp.isNotEmpty) {
    List<File> imagesTempResized = [];
    for (File i in imageTemp) {
      File resizedImageFile = await resizeImageFile(pickedImageFile: i);
      imagesTempResized.add(resizedImageFile);
    }
    return imagesTempResized;
  }
  return imageTemp;
}

Future<File?> pickCameraImage(
  BuildContext context, {
  int? compressQuality,
}) async {
  File? imageTemp;

  /// Ask For permission
  await getCameraPermission().then((value) async {
    if (value.isGranted) {
      try {
        final image = await ImagePicker().pickImage(
          source: ImageSource.camera,
          imageQuality: 80,
          requestFullMetadata: false,
          preferredCameraDevice: CameraDevice.front,
        );
        if (image == null) return null;
        imageTemp = File(image.path);
      } catch (e) {
        debugPrint(e.toString());
        showToast(
          context: context,
          title: LocaleKeys.error.tr(),
          description: LocaleKeys.anError.tr(),
          toastType: ToastType.error,
        );
      }
    } else if (value.isDenied) {
      showToast(
          context: context,
          title: LocaleKeys.pleaseGrantPermission.tr(),
          description: LocaleKeys.pleaseAllowCameraEditAvatar.tr(),
          toastType: ToastType.warning);
      await getCameraPermission().then((value) async {
        if (value.isGranted) {
          try {
            final image = await ImagePicker().pickImage(
              source: ImageSource.camera,
              imageQuality: 80,
              requestFullMetadata: false,
              preferredCameraDevice: CameraDevice.front,
            );
            if (image == null) return null;
            imageTemp = File(image.path);
          } catch (e) {
            debugPrint(e.toString());
            showToast(
              context: context,
              title: LocaleKeys.error.tr(),
              description: LocaleKeys.anError.tr(),
              toastType: ToastType.error,
            );
          }
        }
      });
    } else {
      showToast(
        context: context,
        title: '',
        description: LocaleKeys.pleaseAllowCameraEditAvatar.tr(),
        toastType: ToastType.info,
      );
      openAppInfoRequestPermission(
          context,
          Platform.isIOS
              ? LocaleKeys.toUploadCameraIos.tr(args: [appName])
              : LocaleKeys.toUploadCameraAndroid.tr(args: [appName]));
    }
  });
  return imageTemp;
}

Future<File?> pickAudio(BuildContext context,
    {bool? initialPath, int? durationSeconds}) async {
  File? audioTemp;
  AndroidDeviceInfo? androidInfo;
  if (Platform.isAndroid) {
    androidInfo = await DeviceInfoPlugin().androidInfo;
  }
  Directory? picturesAethiaPath;
  if (!Platform.isMacOS) {
    picturesAethiaPath = await getDownloadsDirectory();
  }

  /// Ask For permission
  await getAudioPermission(context).then((value) async {
    if (value?.isGranted == true) {
      try {
        FilePickerResult? image = await FilePicker.platform.pickFiles(
          type: Platform.isIOS ? FileType.custom : FileType.audio,
          allowedExtensions: Platform.isIOS ? ["mp3", "m4a"] : null,
          initialDirectory:
              Platform.isIOS || Platform.isMacOS && initialPath == true
                  ? "${picturesAethiaPath?.path}/$appName/Text2Voice/"
                  : null,
        );
        safePrint(image?.files.first.path);
        if (image == null) return null;
        if (image.files.isEmpty == true) return null;
        // safePrint(image.paths.toList().toString());
        final AudioPlayer player = AudioPlayer();
        player.setVolume(0);
        await player.play(DeviceFileSource(image.paths.first!));
        // safePrint(player.playerId);
        var duration = await player.getDuration();
        await player.dispose();
        safePrint("AUDIO_DURATION: ${duration?.inSeconds}");
        if ((duration?.inSeconds ?? 0) >=
            (durationSeconds ?? maxDurationOfPickedAudio)) {
          // if (false) {
          Trimmer trimmer = Trimmer();
          await trimmer.loadAudio(audioFile: File(image.files.first.path!));
          File? newFile = await trimAudio(
            context: context,
            // inputAudio: File(image.files.first.path!),
            desiredOutPutDuration: durationSeconds ?? maxDurationOfPickedAudio,
            audioDurationSeconds: duration?.inSeconds.toDouble() ?? 0,
            trimmer: trimmer,
          );
          // trimmer.dispose();
          if (newFile == null) return;
          audioTemp = newFile;

          // showToast(
          //     context: context,
          //     title: "",
          //     // description: LocaleKeys.pickShorterAudio.tr(),
          //     description:
          //         "Audio should be less ${durationSeconds ?? maxDurationOfPickedAudio} than seconds.",
          //     toastType: ToastType.warning);
          // throw Error;
          // if ((duration?.inSeconds ?? 0) >= 15) {}
        } else {
          audioTemp = File(image.files.first.path!);
        }
        await player.dispose();
      } catch (e) {
        debugPrint(e.toString());
        // showToast(
        //     context: context,
        //     title: LocaleKeys.error.tr(),
        //     description: LocaleKeys.anError.tr(),
        //     toastType: ToastType.error);
      }
    } else if (value?.isDenied == true) {
      // showToast(
      //     context: context,
      //     title: LocaleKeys.pleaseGrantPermission.tr(),
      //     description: LocaleKeys.pleaseGrantPermission.tr(),
      //     toastType: ToastType.warning);
      await getAudioPermission(context).then((value) async {
        if (value?.isGranted == true) {
          try {
            FilePickerResult? image = await FilePicker.platform.pickFiles(
              type: Platform.isIOS ? FileType.custom : FileType.audio,
              allowedExtensions: Platform.isIOS ? ["mp3", "m4a"] : null,
              initialDirectory: Platform.isIOS && initialPath == true
                  ? "${picturesAethiaPath?.path}/$appName/Text2Voice/"
                  : null,
            );
            if (image == null) return null;
            if (image.files.isEmpty == true) return null;
            final AudioPlayer player = AudioPlayer();
            player.setVolume(0);
            await player.play(DeviceFileSource(image.paths.first!));
            // safePrint(player.playerId);
            var duration = await player.getDuration();
            // if ((duration?.inSeconds ?? 0) >=
            //     (durationSeconds ?? maxDurationOfPickedAudio)) {
            //   player.dispose();
            //   image = null;
            //   // showToast(
            //   //     context: context,
            //   //     title: "",
            //   //     description: LocaleKeys.pickShorterAudio.tr(),
            //   //     toastType: ToastType.warning);
            // } else {
            //   await player.dispose();
            //   audioTemp = File(image.files.first.path!);
            // }
            if (false) {
              // if ((duration?.inSeconds ?? 0) >=
              //     (durationSeconds ?? maxDurationOfPickedAudio)) {
              // Trimmer trimmer = Trimmer();
              // await trimmer.loadAudio(audioFile: File(image.files.first.path!));
              // File? newFile = await trimAudio(
              //   context: context,
              //   // inputAudio: File(image.files.first.path!),
              //   desiredOutPutDuration:
              //       durationSeconds ?? maxDurationOfPickedAudio,
              //   audioDurationSeconds: duration?.inSeconds.toDouble() ?? 0,
              //   trimmer: trimmer,
              // );
              // trimmer.dispose();
              // if (newFile == null) return;
              // audioTemp = newFile;

              // showToast(
              //     context: context,
              //     title: "",
              //     // description: LocaleKeys.pickShorterAudio.tr(),
              //     description:
              //         "Audio should be less ${durationSeconds ?? maxDurationOfPickedAudio} than seconds.",
              //     toastType: ToastType.warning);
              // throw Error;
              // if ((duration?.inSeconds ?? 0) >= 15) {}
            } else {
              audioTemp = File(image.files.first.path!);
            }

            /// here
          } catch (e) {
            debugPrint(e.toString());
            // showToast(
            //     context: context,
            //     title: LocaleKeys.error.tr(),
            //     description: LocaleKeys.anError.tr(),
            //     toastType: ToastType.error);
          }
        }
      });
    } else if (value?.isPermanentlyDenied == true) {
      // showToast(
      //     context: context,
      //     title: LocaleKeys.grantPermission.tr(),
      //     description: Platform.isIOS || androidInfo!.version.sdkInt <= 32
      //         ?  LocaleKeys
      //             .pleaseAllowStorageAccess
      //             .tr()
      //         :  LocaleKeys
      //             .pleaseAllowMusicAccess
      //             .tr(),
      //     toastType: ToastType.info);
      openAppInfoRequestPermission(context, "Allow permission"
          // Platform.isIOS
          //     ? LocaleKeys.toUploadAudioIos.tr(args: [appName])
          //     : androidInfo!.version.sdkInt <= 32
          //         ? LocaleKeys.toUploadAudioAndroid.tr(args: [appName])
          //         : LocaleKeys.toUploadAudioAndroid33.tr(args: [appName]),
          );
      // : "To upload photo, allow Aethia to access your device's audios.\nTap Settings>Permissions, and turn \"${androidInfo!.version.sdkInt <= 32 ? 'Storage' : 'Music and audio'}\" on.");
    }
  });
  if (audioTemp != null) {
    audioTemp = await renameFileIfNecessary(audioTemp!);
  }
  return audioTemp;
}

Future<File> renameFileIfNecessary(File file) async {
  // Get the original file path and name
  String originalPath = file.path;
  String originalName = file.uri.pathSegments.last;

  // Create a new filename by removing spaces and hyphens
  String newName = originalName.replaceAll(' ', '').replaceAll('-', '');

  // Check if renaming is needed (i.e., if the new name differs from the original)
  if (newName != originalName) {
    // Construct the new path by appending the modified filename
    String directory = originalPath.substring(
        0, originalPath.lastIndexOf(Platform.pathSeparator));
    String newPath =
        '$directory${Platform.pathSeparator}${DateTime.now().millisecondsSinceEpoch}$newName';

    // Copy the file and return the new file object
    File copiedFile = await file.copy(newPath);
    safePrint('File copied to: ${copiedFile.path}');
    return copiedFile;
  } else {
    // Return the original file if no renaming is needed
    safePrint('File does not need renaming: ${file.path}');
    return file;
  }
}

Future<File?> urlToTempFile({required String url}) async {
  Directory temp = await getApplicationCacheDirectory();
  String fileExtension = url.split(".").last;
  String savePath =
      "${temp.path}/temp_${DateTime.now().millisecondsSinceEpoch}.$fileExtension";
  try {
    Dio dio = Dio();
    Response response = await dio.download(url, savePath);
    return File(savePath);
  } catch (err) {
    rethrow;
  }
}

Future<File?> trimAudio({
  required BuildContext context,
  required int desiredOutPutDuration,
  required double audioDurationSeconds,
  required Trimmer trimmer,
}) async {
  File? outputAudio;
  try {
    bool loading = false;
    double startValue = 0.0;
    double endValue = 0.0;
    bool isPlaying = false;
    outputAudio = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("Trim Audio: $desiredOutPutDuration sec"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      trimmer.currentAudioFile!.path
                          .split(Platform.pathSeparator)
                          .last,
                      maxLines: 1,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  loading
                      ? const Padding(
                          padding: EdgeInsets.all(30.0),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 20.0),
                                Text("trimming..."),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                  top: 10.0, bottom: 30.0),
                              child: TextButton(
                                child: isPlaying
                                    ? const Icon(Icons.pause, size: 80.0)
                                    : const Icon(Icons.play_arrow, size: 80.0),
                                onPressed: () async {
                                  bool playbackState =
                                      await trimmer.audioPlaybackControl(
                                    startValue: startValue,
                                    endValue: endValue,
                                  );
                                  setState(() => isPlaying = playbackState);
                                },
                              ),
                            ),
                            // TrimViewer(
                            //   // type: ,
                            //   trimmer: trimmer,
                            //   viewerHeight: 100,
                            //   showDuration: true,
                            //   maxAudioLength:
                            //       Duration(seconds: desiredOutPutDuration),
                            //   viewerWidth: MediaQuery.of(context).size.width,
                            //   durationStyle: DurationStyle.FORMAT_MM_SS,
                            //   backgroundColor: Theme.of(context).primaryColor,
                            //   barColor: Colors.white,
                            //   // durationTextStyle: TextStyle(
                            //   //     color: Theme.of(context).primaryColor),
                            //   allowAudioSelection: true,
                            //   editorProperties: TrimEditorProperties(
                            //     sideTapSize: 4,
                            //     circleSize: 8,
                            //     borderPaintColor: Colors.pinkAccent,
                            //     borderWidth: 4,
                            //     borderRadius: 10,
                            //     circlePaintColor: Colors.pink.shade400,
                            //   ),
                            //   areaProperties:
                            //       TrimAreaProperties.edgeBlur(blurEdges: true),
                            //   onChangeStart: (value) => startValue = value,
                            //   onChangeEnd: (value) => endValue = value,
                            //   onChangePlaybackState: (value) {
                            //     if (context.mounted) {
                            //       setState(() => isPlaying = value);
                            //     }
                            //   },
                            // ),
                          ],
                        ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    if (loading) return;
                    // await trimmer.audioPlayer?.dispose();
                    setState(() => isPlaying = false);
                    try {
                      trimmer.dispose();
                    } catch (err) {
                      //
                    }
                    Navigator.pop(context, null);
                  },
                  child: Text(
                    "Cancel",
                    style: TextStyle(color: loading ? Colors.grey : null),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    setState(() => loading = true);
                    try {
                      trimmer.audioPlayer?.pause();
                      // var adCompleterpleter = Completer<void>();
                      File trimmedAudio = await saveTrimAudio(
                        filePath: trimmer.currentAudioFile!.path,
                        trimmer: trimmer,
                        startValue: startValue,
                        endValue: endValue,
                      );
                      // adCompleter.complete();
                      // await adCompleter.future;
                      // ffmpeg -i "original.mp3" -ss 60 -to 70 "new.mp3"
                      // await Future.delayed(Duration(seconds: 3));
                      // setState(() => loading = false);
                      safePrint("trimmedAudio: ${trimmedAudio.path}");
                      outputAudio = trimmedAudio;
                      Navigator.pop(context, trimmedAudio);
                    } catch (err) {
                      Navigator.pop(context, null);
                    }
                  },
                  child: const Text("Trim"),
                ),
              ],
            );
          },
        );
      },
    );
    return outputAudio;
  } catch (err) {
    return outputAudio;
  }
}

Future<File> saveTrimAudio({
  required String filePath,
  required Trimmer trimmer,
  required double startValue,
  required double endValue,
}) async {
  String op = "";
  var adCompleter = Completer<void>();
  try {
    String fileName =
        '${filePath.split(Platform.pathSeparator).last.split(".").first}_${getRandom() + getRandom()}';
    await trimmer.saveTrimmedAudio(
      startValue: startValue,
      endValue: endValue,
      audioFileName: fileName,
      // "trim_${DateTime.now().millisecondsSinceEpoch.toString()}",
      outputFormat: FileFormat.mp3,
      storageDir: StorageDir.temporaryDirectory,
      onSave: (outputPath) {
        if (outputPath == null) throw Exception("could not save trimmed audio");
        safePrint("OUTPUT_PATH: ${outputPath} $op");
        op = outputPath;
        adCompleter.complete();
      },
    );
    await adCompleter.future;
    safePrint("OUTPUT_PATH: $op");
    return File(op);
  } catch (err) {
    safePrint("Trim Error: $err");
    rethrow;
  }
}

enum PickedFileType {
  galleryImage,
  cameraImage,
  video,
  audio,
  record,
  localSpeech,
}

pickImageBottomSheet({
  required BuildContext context,
  required GestureTapCallback firstOnTap,
  required GestureTapCallback secondOnTap,
  bool? isAdvanced,
  String? title,
  PickedFileType? firstWidgetType,
  PickedFileType? secondWidgetType,
}) {
  showModalBottomSheet(
    constraints: BoxConstraints.tightFor(
      width: MediaQuery.of(context).size.width,
      height: null,
    ),
    backgroundColor: ColorConstants.primaryColor,
    context: context,
    builder: (context) => Card(
      color: ColorConstants.primaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(10.0),
        ),
      ),
      margin: EdgeInsets.zero,
      child: SizedBox(
        height: MediaQuery.of(context).size.height / 4,
        child: Flex(
          direction: Axis.vertical,
          children: [
            Text(
              title ?? LocaleKeys.editImage.tr(),
              style: const TextStyle(fontSize: 20),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    GestureDetector(
                      onTap: firstOnTap,
                      child: pickerFileTypeWidget(firstWidgetType ??
                          PickedFileType.galleryImage), // gallery
                    ),
                    isAdvanced == true
                        ? GestureDetector(
                            onTap: secondOnTap,
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.video_file,
                                  size: 60,
                                ),
                                Text(LocaleKeys.video.tr())
                              ],
                            ),
                          )
                        : GestureDetector(
                            onTap: secondOnTap,
                            child: pickerFileTypeWidget(
                                secondWidgetType ?? PickedFileType.cameraImage),
                          ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    ),
  );
}

Widget pickerFileTypeWidget(PickedFileType pickedFileType) {
  switch (pickedFileType) {
    case PickedFileType.galleryImage:
      return Column(
        children: [
          const Icon(
            Icons.image,
            size: 60,
          ),
          Text(LocaleKeys.gallery.tr())
        ],
      );
    case PickedFileType.cameraImage:
      return Column(
        children: [
          const Icon(
            Icons.camera_alt,
            size: 60,
          ),
          Text(LocaleKeys.camera.tr())
        ],
      );
    case PickedFileType.video:
      return Column(
        children: [
          const Icon(
            Icons.video_file,
            size: 60,
          ),
          Text(LocaleKeys.video.tr())
        ],
      );
    case PickedFileType.audio:
      return Column(
        children: [
          const Icon(
            Icons.audio_file,
            size: 60,
          ),
          Text(LocaleKeys.audio.tr())
        ],
      );
    case PickedFileType.record:
      return const Column(
        children: [
          Icon(
            Icons.mic,
            size: 60,
          ),
          Text("Record")
        ],
      );
    case PickedFileType.localSpeech:
      return Column(
        children: [
          const Icon(
            Icons.multitrack_audio,
            size: 60,
          ),
          Text(LocaleKeys.savedSpeech.tr())
        ],
      );

    default:
      return const SizedBox.shrink();
  }
}
