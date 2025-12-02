// ignore_for_file: body_might_complete_normally_nullable

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/urls.dart';
import '../models/locale_keys.g.dart';
import '../utils/dl.dart';
import '../utils/functions.dart';

String audioFilesPath = "";

class AzureProvider extends ChangeNotifier {
  Future<File?> azureTTS(
    BuildContext context, {
    required String gender,
    required String voice,
    required String script,
    bool returnTempPath = false,
  }) async {
    final dio = Dio();
    int charactersLength = script.length;
    String xmlData = '''
       <speak version='1.0' xml:lang='en-US'>
	<voice xml:lang='en-US' xml:gender='$gender' name='$voice'>
"$script"
    </voice>
</speak>
      ''';

    /// todo: handle request on flutter app, 1000 characters for 0.5 golden coins

    Options options = Options(
      headers: {'Content-Type': 'application/ssml+xml'},
      responseType: ResponseType.bytes,
    );

    dio.options.headers = {
      "Ocp-Apim-Subscription-Key": "239fc1d8889c498f9f4d9ebc03c5ddd2",
      "Content-Type": "application/ssml+xml",
      "X-Microsoft-OutputFormat": "audio-16khz-128kbitrate-mono-mp3"
    };
    try {
      Response response = await dio.post(
        "https://eastus.tts.speech.microsoft.com/cognitiveservices/v1/",
        data: xmlData,
        options: options,
      );
      if (response.statusCode == 200) {
        File? file;
        if (returnTempPath) {
          file = await uint8ListToFile(response.data as Uint8List, 'mp3');
        } else {
          file = await saveFileAndShowToast(
              uint8List: response.data as Uint8List, context: context);
        }
        MSVoice msVoice = MSVoice(charactersLength: charactersLength);
        // context
        //     .read<SaveOfflineController>()
        //     .saveArtToOffline(data: msVoice, context: context, modelID: null);
        return file;
      }
    } on DioException catch (err) {
      safePrint(err.response?.data);
      rethrow;
    }
  }

  Future<File?> saveFileAndShowToast(
      {required Uint8List uint8List, required BuildContext context}) async {
    try {
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
          ? "${fallbackPath?.path}${Platform.isMacOS ? "/$appName" : ""}/Voice/voice-${DateTime.now().microsecondsSinceEpoch}.mp3"
          : "${picturesAethiaPath?.path ?? fallbackPath?.path}/$appName/Voice/voice-${DateTime.now().microsecondsSinceEpoch}.mp3";
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
      // context
      //     .read<SaveOfflineController>()
      //     .saveArtToOffline(data: msVoice, context: context, modelID: null);
      return file;
    } catch (err) {
      rethrow;
    }
  }
}

class AudioOutputFormat {
  AudioOutputFormat._();

  static const String raw16khz16bitMonoPcm = "raw-16khz-16bit-mono-pcm";
  static const String riff16khz16bitMonopcm = "riff-16khz-16bit-mono-pcm";
  static const String raw24khz16BitMonoPcm = "raw-24khz-16bit-mono-pcm";
  static const String riff24khz16BitMonoPcm = "riff-24khz-16bit-mono-pcm";
  static const String raw48khz16BitMonoPcm = "raw-48khz-16bit-mono-pcm";
  static const String riff48khz16BitMonoPcm = "riff-48khz-16bit-mono-pcm";
  static const String raw8khz8bitMonoMulaw = "raw-8khz-8bit-mono-mulaw";
  static const String riff8khz8BitMonoMulaw = "riff-8khz-8bit-mono-mulaw";
  static const String raw8khz8BitMonoAlaw = "raw-8khz-8bit-mono-alaw";
  static const String riff8khz8BitMonoAlaw = "riff-8khz-8bit-mono-alaw";
  static const String audio16khz32kBitrateMonoMp3 =
      "audio-16khz-32kbitrate-mono-mp3";
  static const String audio16khz64kBitrateMonoMp3 =
      "audio-16khz-64kbitrate-mono-mp3";
  static const String audio16khz128kBitrateMonoMp3 =
      "audio-16khz-128kbitrate-mono-mp3";
  static const String audio24khz48kBitrateMonoMp3 =
      "audio-24khz-48kbitrate-mono-mp3";
  static const String audio24khz96kBitrateMonoMp3 =
      "audio-24khz-96kbitrate-mono-mp3";
  static const String audio24khz160kBitrateMonoMp3 =
      "audio-24khz-160kbitrate-mono-mp3";
  static const String audio48khz96kBitrateMonoMp3 =
      "audio-48khz-96kbitrate-mono-mp3";
  static const String audio48khz192kBitrateMonoMp3 =
      "audio-48khz-192kbitrate-mono-mp3";
  static const String raw16khz16BitMonoTrueSilk =
      "raw-16khz-16bit-mono-truesilk";
  static const String raw24khz16BitMonoTrueSilk =
      "raw-24khz-16bit-mono-truesilk";
  static const String webm16khz16BitMonoOpus = "webm-16khz-16bit-mono-opus";
  static const String webm24khz16BitMonoOpus = "webm-24khz-16bit-mono-opus";
  static const String ogg16khz16BitMonoOpus = "ogg-16khz-16bit-mono-opus";
  static const String ogg24khz16BitMonoOpus = "ogg-24khz-16bit-mono-opus";
  static const String ogg48khz16BitMonoOpus = "ogg-48khz-16bit-mono-opus";
}

class MSVoice {
  int charactersLength;

  MSVoice({required this.charactersLength});
}
