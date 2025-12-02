import 'package:ai_video_creator_editor/components/gradient_scaffold.dart';
import 'package:ai_video_creator_editor/constants/extensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../constants/colors.dart';
import 'gradient_border.dart';

class SelectorWithPage extends StatefulWidget {
  // final GestureTapCallback onTap;
  final String title;
  final Widget? leading;

  // final Widget? subTitle;
  // final List<Map<String, dynamic>> list;
  final SelectorController selectorController;

  const SelectorWithPage({
    super.key,
    // required this.onTap,
    required this.title,
    this.leading,
    // this.subTitle,
    required this.selectorController,
    // required this.list,
  });

  @override
  State<SelectorWithPage> createState() => _SelectorWithPageState();
}

class _SelectorWithPageState extends State<SelectorWithPage> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: GestureDetector(
        // onTap: widget.onTap,
        onTap: () async {
          setState(() {});
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.0),
            // gradient: ColorConstants.uploadButtonGradient,
            gradient: ColorConstants.textFieldGradient,
            border: GradientBoxBorder(
              width: 1,
              gradient: ColorConstants.uploadButtonBorderGradient,
            ),
          ),
          child: SizedBox(
            // height: MediaQuery.of(context).size.height / 8,
            child: Material(
              elevation: 0.1,
              color: ColorConstants.primaryColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                contentPadding: const EdgeInsets.all(8.0),
                title: Text(
                  widget.title,
                  style: const TextStyle(
                    color: Color.fromRGBO(220, 220, 220, 1),
                    fontSize: 19.0,
                  ),
                ),
                leading: widget.leading,
                trailing: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Icon(Icons.arrow_forward_ios_sharp),
                ),
                subtitle:
                    Text(widget.selectorController.selectedMap?["name"] ?? ""),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SelectorController {
  List<Map<String, dynamic>> list;
  Map<String, dynamic>? selectedMap;
  String? selectedID;
  final String title;

  SelectorController({
    required this.list,
    this.selectedID,
    this.selectedMap,
    required this.title,
  });

  select({required Map<String, dynamic> map}) {
    selectedMap = map;
    selectedID = map["id"];
  }
}

class FullPageSelector extends StatefulWidget {
  final String? initialID;
  final SelectorController selectorController;

  const FullPageSelector({
    super.key,
    required this.initialID,
    required this.selectorController,
  });

  @override
  State<FullPageSelector> createState() => _FullPageSelectorState();
}

class _FullPageSelectorState extends State<FullPageSelector> {
  TextEditingController searchTextEditingController = TextEditingController();
  List<Map<String, dynamic>> itemListOnSearch = [];

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: Text(widget.selectorController.title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(8.0),
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              height: 45.0,
              child: CupertinoSearchTextField(
                controller: searchTextEditingController,
                suffixIcon: const Icon(Icons.mic),
                suffixMode: OverlayVisibilityMode.always,
                style: const TextStyle(color: Colors.white),
                onSuffixTap: () {
                  // use microphone
                },
                onChanged: (value) {
                  setState(
                    () {
                      itemListOnSearch = widget.selectorController.list
                          .where((element) => element["name"]
                              .toLowerCase()
                              .contains(value.toLowerCase()))
                          .toList();
                    },
                  );
                },
              ),
            ),
          ),
          searchTextEditingController.text.isNotEmpty &&
                  itemListOnSearch.isEmpty
              ? const Column(
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(0, 50, 0, 0),
                        child: Text(
                          'No results',
                          style: TextStyle(fontSize: 22),
                        ),
                      ),
                    )
                  ],
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: searchTextEditingController.text.isNotEmpty
                      ? itemListOnSearch.length
                      : widget.selectorController.list.length,
                  itemBuilder: (context, index) {
                    Map<String, dynamic> element =
                        searchTextEditingController.text.isNotEmpty
                            ? itemListOnSearch[index]
                            : widget.selectorController.list[index];
                    return GestureDetector(
                      onTap: () {
                        widget.selectorController.select(map: element);
                        setState(() {});
                        FocusScope.of(context).unfocus();
                        Navigator.pop(context);
                      },
                      child: ListTile(
                        title: Text(
                          element["name"],
                        ),
                        trailing:
                            widget.selectorController.selectedMap == element
                                ? const Icon(Icons.check)
                                : context.shrink(),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}
