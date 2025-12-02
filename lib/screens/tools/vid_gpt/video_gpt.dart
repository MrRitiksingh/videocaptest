import 'package:ai_video_creator_editor/components/glowing_button.dart';
import 'package:ai_video_creator_editor/components/gradient_scaffold.dart';
import 'package:ai_video_creator_editor/components/progress_indicator.dart';
import 'package:ai_video_creator_editor/components/text_field.dart';
import 'package:ai_video_creator_editor/constants/colors.dart';
import 'package:ai_video_creator_editor/constants/extensions.dart';
import 'package:ai_video_creator_editor/models/locale_keys.g.dart';
import 'package:ai_video_creator_editor/screens/tools/vid_gpt/setup_language.dart';
import 'package:ai_video_creator_editor/screens/tools/vid_gpt/vid_gpt_notifier.dart';
import 'package:ai_video_creator_editor/screens/tools/vid_gpt/video_gpt_complete.dart';
import 'package:ai_video_creator_editor/utils/functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:provider/provider.dart';
import 'package:sliding_up_panel_custom/sliding_up_panel_custom.dart';

import '../../../components/sliding_up_scaffold.dart';
import '../../../constants/voices_list.dart';
import '../../../models/video_gpt_model.dart';
import '../../feature.dart';

class VideoGpt extends StatefulWidget {
  const VideoGpt({super.key});

  @override
  State<VideoGpt> createState() => _VideoGptState();
}

enum GptOrientation { landscape, portrait }

enum NarrationMode { enabled, disabled }

class _VideoGptState extends State<VideoGpt> with Feature<VideoGpt> {
  PanelController panelController = PanelController();
  TextEditingController promptTextEditingController = TextEditingController();
  GptOrientation gptOrientation = GptOrientation.landscape;
  // SliderController wanVideoSliderController =
  //     SliderController(max: 300, min: 30, value: 60, divisions: 9);

  // GPTVoice currentGPTVoice = GPTVoice(
  //   language: allLanguagesList[0],
  //   gender: msVoicesGenderList[0],
  //   style: msStylesList[0],
  //   voice: msVoicesList
  //       .where((element) => element["DisplayName"] == "Jenny Multilingual")
  //       .first,
  // );
  SetupLanguageController setupLanguageController = SetupLanguageController(
    initialLanguage: allLanguagesList[0], // Default or selected language
    initialGender: msVoicesGenderList[0], // Default or selected gender
    initialStyle: msStylesList[0], // Default or selected style
    initialVoice: msVoicesList[0],
  );
  NarrationMode narrationMode = NarrationMode.enabled;
  bool generateText = true; // enabled for users with >N coins
  @override
  Widget build(BuildContext context) {
    return LoaderWidgetOverlay(
      child: WillPopScope(
        onWillPop: () => Future.value(true),
        child: GradientScaffold(
          appBar: AppBar(
            title: const Text("Video GPT"),
          ),
          body: SlidingUpScaffold(
            panelController: panelController,
            body: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LocaleKeys.promptStar.tr().tr(),
                    style: const TextStyle(fontSize: 18.0),
                  ),
                  TextFieldWidget(
                    textEditingController: promptTextEditingController,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Orientation",
                          style: TextStyle(fontSize: 18.0, color: Colors.white),
                        ),
                        CupertinoSlidingSegmentedControl(
                          children: const {
                            GptOrientation.landscape: Text("Landscape",
                                style: TextStyle(
                                    fontSize: 16.0, color: Colors.white)),
                            GptOrientation.portrait: Text("Portrait",
                                style: TextStyle(
                                    fontSize: 16.0, color: Colors.white)),
                          },
                          thumbColor: ColorConstants.loadingWavesColor,
                          groupValue: gptOrientation,
                          onValueChanged: (val) {
                            HapticFeedback.lightImpact();
                            setState(() => gptOrientation = val!);
                          },
                        ),
                      ],
                    ),
                  ),
                  // SliderWidget(
                  //   title: LocaleKeys.durationSeconds.tr(),
                  //   sliderController: wanVideoSliderController,
                  // ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Narration",
                          style: TextStyle(fontSize: 18.0, color: Colors.white),
                        ),
                        CupertinoSlidingSegmentedControl<NarrationMode>(
                          children: const {
                            NarrationMode.enabled: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 13.0),
                              child: Text("Enable",
                                  style: TextStyle(
                                      fontSize: 16.0, color: Colors.white)),
                            ),
                            NarrationMode.disabled: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 13.0),
                              child: Text("Disable",
                                  style: TextStyle(
                                      fontSize: 16.0, color: Colors.white)),
                            ),
                          },
                          thumbColor: ColorConstants.loadingWavesColor,
                          groupValue: narrationMode,
                          onValueChanged: (val) {
                            HapticFeedback.lightImpact();
                            setState(() => narrationMode = val!);
                          },
                        ),
                      ],
                    ),
                  ),
                  narrationMode == NarrationMode.enabled
                      ? const SetupLanguage()
                      : context.shrink(),
                ],
              ),
            ),
            initialMaxHeight: MediaQuery.of(context).size.height * 0.85,
            panel: Column(
              children: [
                GlowingGenerateButton(
                  isProcessing: isProcessing,
                  onTap: () async {
                    if (promptTextEditingController.text.trim().isEmpty) {
                      showToast(
                          context: context,
                          title: "",
                          description: LocaleKeys.pleaseEnterPrompt.tr(),
                          toastType: ToastType.warning);
                      return;
                    }
                    try {
                      context.loaderOverlay.show();
                      Map<String, dynamic> data = {
                        "duration": 30,
                        "prompt": promptTextEditingController.text,
                        "language": context
                            .read<SetupLanguageController>()
                            .gptVoice
                            .langValue,
                      };
                      VideoGptModel? videoGptModel = await context
                          .read<SetupLanguageController>()
                          .videoGpt(
                            data: data,
                            generateText: generateText,
                            generateAudio:
                                narrationMode == NarrationMode.enabled,
                          );
                      context.loaderOverlay.hide();
                      handleCompleteVideoGpt(
                        videoGptModel: videoGptModel!,
                        context: context,
                        setupLanguageController: setupLanguageController,
                        gptOrientation: gptOrientation,
                      );
                    } catch (err) {
                      safePrint(err.toString());
                      context.loaderOverlay.hide();
                      showToast(
                        context: context,
                        title: "",
                        description: LocaleKeys.anError.tr(),
                        toastType: ToastType.warning,
                      );
                    }
                  },
                  string: LocaleKeys.generateVideoEM.tr(),
                ),
                // Padding(
                //   padding: const EdgeInsets.all(8.0),
                //   child: BooleanListTile(
                //     enabled: generateText,
                //     title: "Generate Video Script",
                //     onChanged: (val) => setState(() => generateText = val),
                //   ),
                // ),
                // !generateText
                //     ? context.shrink()
                //     : Padding(
                //         padding: const EdgeInsets.all(8.0),
                //         child: BooleanListTile(
                //           enabled: generateAudio,
                //           title: "Generate Audio from text",
                //           onChanged: (val) =>
                //               setState(() => generateAudio = val),
                //         ),
                //       ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

handleCompleteVideoGpt({
  required VideoGptModel videoGptModel,
  required BuildContext context,
  required SetupLanguageController setupLanguageController,
  required GptOrientation gptOrientation,
}) {
  Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => VideoGptComplete(
                videoGptModel: videoGptModel,
                gptOrientation: gptOrientation,
              )));
}

// class SetupLanguage extends StatefulWidget {
//   final Function(GPTVoice gptVoice) onUpdate;
//   const SetupLanguage({super.key, required this.onUpdate});
//
//   @override
//   State<SetupLanguage> createState() => _SetupLanguageState();
// }
//
// class _SetupLanguageState extends State<SetupLanguage> {
//   int selectedLanguage = 0;
//   int selectedGender = 0;
//   int selectedVoiceStyle = 0;
//   int selectedVoice = 0;
//   @override
//   Widget build(BuildContext context) {
//     List<Map<String, dynamic>> setVoices() {
//       String lang = allLanguagesList[selectedLanguage]["model_id"];
//       String gender = msVoicesGenderList[selectedGender]["model_id"];
//       String style = msStylesList[selectedVoiceStyle]["model_id"];
//       // safePrint(gender == '');
//       List<Map<String, dynamic>>? filteredList = msVoicesList
//           .where(
//             (element) =>
//                 // element["LocaleName"] == lang
//                 (lang == ""
//                     ? (element["LocaleName"]).isNotEmpty
//                     : element["LocaleName"] == lang) &&
//                 (gender == ""
//                     ? (element["Gender"]).isNotEmpty
//                     : element["Gender"] == gender) &&
//                 (style == ""
//                     ? (element["StyleList"] as List).isEmpty
//                     : ((element["StyleList"] as List).contains(style))),
//           )
//           .toList();
//       // filteredList.map((e) {
//       //   safePrint(e['Gender']);
//       // }).toList();
//       // selectedVoice = 0;
//       return filteredList;
//     }
//
//     Map<String, dynamic> firstVoiceInLang = msVoicesList
//         .where((element) =>
//             element["LocaleName"] ==
//             allLanguagesList[selectedLanguage]["model_id"])
//         .first;
//
//     return CupertinoScaffold(
//       body: GestureDetector(
//         onTap: () {
//           CupertinoScaffold.showCupertinoModalBottomSheet(
//             context: context,
//             duration: const Duration(milliseconds: 200),
//             builder: (context) {
//               return StatefulBuilder(builder: (context, updateState) {
//                 return GradientScaffold(
//                   appBar: AppBar(
//                     title: Text(LocaleKeys.language.tr()),
//                   ),
//                   body: SingleChildScrollView(
//                     child: Column(
//                       children: [
//                         DropDownWidget(
//                           index: selectedLanguage,
//                           list: allLanguagesList,
//                           hint: LocaleKeys.language.tr(),
//                           onChanged: (value) {
//                             var r = allLanguagesList.where(
//                                 (element) => element["model_id"] == value);
//                             var index = allLanguagesList.indexOf(r.first);
//                             selectedLanguage = index;
//                             selectedVoice = 0;
//                             setState(() {});
//                             updateState(() {});
//
//                             /// update value
//                             GPTVoice gPTVoice = GPTVoice(
//                               language: allLanguagesList[selectedLanguage],
//                               gender: msVoicesGenderList[selectedGender],
//                               style: msStylesList[selectedVoiceStyle],
//                               voice: setVoices().isEmpty
//                                   ? firstVoiceInLang
//                                   : setVoices()[0],
//                             );
//                             widget.onUpdate(gPTVoice);
//                           },
//                         ),
//                         DropDownWidget(
//                           index: selectedGender,
//                           list: msVoicesGenderList,
//                           hint: LocaleKeys.gender.tr(),
//                           onChanged: (value) {
//                             var r = msVoicesGenderList
//                                 .where(
//                                     (element) => element["model_id"] == value)
//                                 .toList();
//                             var index = msVoicesGenderList.indexOf(r.first);
//                             selectedGender = index;
//                             // selectedVoice = 0;
//                             setState(() {});
//                             updateState(() {});
//
//                             /// update value
//                             GPTVoice gPTVoice = GPTVoice(
//                               language: allLanguagesList[selectedLanguage],
//                               gender: msVoicesGenderList[selectedGender],
//                               style: msStylesList[selectedVoiceStyle],
//                               voice: setVoices().isEmpty
//                                   ? firstVoiceInLang
//                                   : setVoices()[0],
//                             );
//                             widget.onUpdate(gPTVoice);
//                           },
//                         ),
//                         DropDownWidget(
//                           index: selectedVoiceStyle,
//                           list: msStylesList,
//                           hint: LocaleKeys.style.tr(),
//                           onChanged: (value) {
//                             var r = msStylesList.where(
//                                 (element) => element["model_id"] == value);
//                             var index = msStylesList.indexOf(r.first);
//                             selectedVoiceStyle = index;
//                             selectedVoice = 0;
//                             setState(() {});
//                             updateState(() {});
//
//                             /// update value
//                             GPTVoice gPTVoice = GPTVoice(
//                               language: allLanguagesList[selectedLanguage],
//                               gender: msVoicesGenderList[selectedGender],
//                               style: msStylesList[selectedVoiceStyle],
//                               voice: setVoices().isEmpty
//                                   ? firstVoiceInLang
//                                   : setVoices()[0],
//                             );
//                             widget.onUpdate(gPTVoice);
//                           },
//                         ),
//                         const SizedBox(height: 30.0),
//                         setVoices().isNotEmpty
//                             ? SingleChildScrollView(
//                                 scrollDirection: Axis.horizontal,
//                                 child: Row(
//                                   mainAxisSize: MainAxisSize.min,
//                                   children: setVoices().map((e) {
//                                     int index = msVoicesList.indexOf(e);
//                                     return CustomStyleCard(
//                                       onTap: () {
//                                         selectedVoice = index;
//
//                                         GPTVoice gPTVoice = GPTVoice(
//                                           language: allLanguagesList[
//                                               selectedLanguage],
//                                           gender: msVoicesGenderList[
//                                               selectedGender],
//                                           style:
//                                               msStylesList[selectedVoiceStyle],
//                                           voice: msVoicesList[index],
//                                         );
//                                         setState(() {});
//                                         updateState(() {});
//                                         widget.onUpdate(gPTVoice);
//                                         Navigator.pop(context, gPTVoice);
//                                       },
//                                       selected: index == selectedVoice,
//                                       imageUrl:
//                                           '$defaultS3/App/gender/${e["Gender"]}.jpg',
//                                       title: '${e["LocalName"]}',
//                                     );
//                                   }).toList(),
//                                 ),
//                               )
//                             : const SizedBox.shrink(),
//                       ],
//                     ),
//                   ),
//                 );
//               });
//             },
//           );
//         },
//         child: ListTile(
//           leading: Icon(
//             Icons.translate,
//             color: Colors.white,
//           ),
//           title: Text(LocaleKeys.language.tr()),
//           subtitle: Text("${allLanguagesList[selectedLanguage]["name"]}"),
//           trailing: Icon(
//             Icons.arrow_forward_ios,
//             color: Colors.white,
//           ),
//         ),
//       ),
//     );
//   }
// }
