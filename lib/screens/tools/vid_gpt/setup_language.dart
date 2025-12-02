import 'package:ai_video_creator_editor/screens/tools/vid_gpt/vid_gpt_notifier.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:provider/provider.dart';

import '../../../components/drop_down.dart';
import '../../../components/gradient_scaffold.dart';
import '../../../components/srtle_card.dart';
import '../../../constants/urls.dart';
import '../../../constants/voices_list.dart';
import '../../../models/locale_keys.g.dart';

class SetupLanguage extends StatelessWidget {
  const SetupLanguage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SetupLanguageController>(
      builder: (context, provider, child) {
        return CupertinoScaffold(
          body: GestureDetector(
            onTap: () {
              showCupertinoModalBottomSheet(
                context: context,
                duration: const Duration(milliseconds: 200),
                builder: (context) {
                  return StatefulBuilder(
                    builder: (context, updateState) {
                      return GradientScaffold(
                        appBar: AppBar(
                          title: Text(LocaleKeys.language.tr()),
                        ),
                        body: SingleChildScrollView(
                          child: Column(
                            children: [
                              DropDownWidget(
                                index:
                                    allLanguagesList.indexOf(provider.language),
                                list: allLanguagesList,
                                hint: LocaleKeys.language.tr(),
                                onChanged: (value) {
                                  var selected = allLanguagesList.firstWhere(
                                      (element) =>
                                          element["model_id"] == value);
                                  provider.updateLanguage(selected);

                                  // Update the voice list based on the new language
                                  var voices = provider.setVoices();
                                  provider.updateVoice(voices.isEmpty
                                      ? provider.firstVoiceInLang()
                                      : voices[0]);

                                  updateState(() {});
                                },
                              ),
                              DropDownWidget(
                                index:
                                    msVoicesGenderList.indexOf(provider.gender),
                                list: msVoicesGenderList,
                                hint: LocaleKeys.gender.tr(),
                                onChanged: (value) {
                                  var selected = msVoicesGenderList.firstWhere(
                                      (element) =>
                                          element["model_id"] == value);
                                  provider.updateGender(selected);
                                  updateState(() {});
                                },
                              ),
                              DropDownWidget(
                                index: msStylesList.indexOf(provider.style),
                                list: msStylesList,
                                hint: LocaleKeys.style.tr(),
                                onChanged: (value) {
                                  var selected = msStylesList.firstWhere(
                                      (element) =>
                                          element["model_id"] == value);
                                  provider.updateVoiceStyle(selected);
                                  updateState(() {});
                                },
                              ),
                              const SizedBox(height: 30.0),
                              provider.setVoices().isNotEmpty
                                  ? SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children:
                                            provider.setVoices().map((voice) {
                                          return CustomStyleCard(
                                            onTap: () {
                                              provider.updateVoice(voice);
                                              updateState(() {});
                                              Navigator.pop(context);
                                            },
                                            selected: voice == provider.voice,
                                            imageUrl:
                                                '$defaultS3/App/gender/${voice["Gender"]}.jpg',
                                            title: '${voice["LocalName"]}',
                                          );
                                        }).toList(),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
            child: ListTile(
              leading: const Icon(Icons.translate, color: Colors.white),
              title: Text("${provider.gptVoice.langValue}",
                  style: const TextStyle(color: Colors.white)),
              subtitle: Text("${provider.gptVoice.voice["LocalName"]}",
                  style: const TextStyle(color: Colors.white)),
              trailing:
                  const Icon(Icons.arrow_forward_ios, color: Colors.white),
            ),
          ),
        );
      },
    );
  }
}
