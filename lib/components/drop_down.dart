import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../constants/colors.dart';

class DropDownWidget extends StatelessWidget {
  final int index;
  final List<Map<String, dynamic>> list;
  final ValueChanged onChanged;
  final String hint;
  final bool? saw;
  final bool? showHint;
  final String? primaryKey;
  final bool? showBottomSheet;

  const DropDownWidget({
    super.key,
    required this.index,
    required this.list,
    required this.onChanged,
    required this.hint,
    this.saw,
    this.showHint = true,
    this.primaryKey,
    this.showBottomSheet = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.0),
            border: Border.all(
              color: const Color.fromRGBO(57, 190, 247, 1),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(37, 133, 230, 1),
                blurRadius: 3,
              ),
              BoxShadow(
                color: Color.fromRGBO(37, 81, 205, 1),
                blurRadius: 4,
              ),
            ],
            gradient: const LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                // Color.fromRGBO(37, 133, 230, 1),
                Color.fromRGBO(37, 81, 205, 1),
                Color.fromRGBO(30, 49, 136, 1),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 30, right: 30),
            child: DropdownButtonFormField(
              // value: saw ?? false ? list[index]["model_id"] : null,
              decoration:
                  InputDecoration(labelText: hint, border: InputBorder.none),
              isExpanded: true,
              value: list[index][primaryKey ?? "model_id"],
              hint: showHint == true ? Text(hint) : null,
              disabledHint: Text(hint),
              items: list
                  .map<DropdownMenuItem>(
                    (e) => DropdownMenuItem(
                      value: e[primaryKey ?? 'model_id'],
                      child: showHint == true
                          ? Text(
                              e[primaryKey ?? 'name'],
                              // textAlign: TextAlign.center,
                            )
                          : Text(
                              e[primaryKey ?? 'name'],
                              // textAlign: TextAlign.center,-
                            ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
              icon: const Padding(
                padding: EdgeInsets.only(left: 20),
                child: Icon(Icons.keyboard_arrow_down),
              ),
              iconEnabledColor: Colors.grey,
              //Icon color
              style: const TextStyle(color: Colors.white),
              dropdownColor: ColorConstants.primaryColor,
              // underline: Container(),
            ),
          ),
        ),
      ),
    );
  }
}

// class DropDownWidgetCustom extends StatefulWidget {
//   // int selectedIndex;
//   final List<ImageModel> list;
//   final String hint;
//   final String? primaryKey;
//   final ModelsSheetController modelsSheetController;
//   final bool? isList;
//   final GestureTapCallback? runThisFunction;
//   const DropDownWidgetCustom({
//     super.key,
//     // required this.selectedIndex,
//     required this.list,
//     required this.hint,
//     this.primaryKey,
//     required this.modelsSheetController,
//     this.isList = false,
//     this.runThisFunction,
//   });
//
//   @override
//   State<DropDownWidgetCustom> createState() => _DropDownWidgetCustomState();
// }
//
// class _DropDownWidgetCustomState extends State<DropDownWidgetCustom> {
//   bool opened = false;
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 8.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Padding(
//               padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
//               child: Text(
//                 widget.hint,
//                 style: const TextStyle(fontSize: 18.0),
//                 textAlign: TextAlign.start,
//               ),
//             ),
//             GestureDetector(
//               onTap: () {
//                 setState(() => opened = true);
//                 showModalBottomSheet(
//                   constraints: BoxConstraints.tightFor(
//                     width: MediaQuery.of(context).size.width,
//                     height: null,
//                   ),
//                   shape: const RoundedRectangleBorder(
//                     borderRadius:
//                         BorderRadius.vertical(top: Radius.circular(10.0)),
//                   ),
//                   context: context,
//                   isScrollControlled: true,
//                   builder: (context) {
//                     return StatefulBuilder(builder: (context, updateState) {
//                       double height = MediaQuery.of(context).size.height * 0.75;
//                       return SizedBox(
//                         height: height,
//                         // height: widget.list.length * 50 > height
//                         //     ? height
//                         //     : widget.list.length * 50,
//                         width: MediaQuery.of(context).size.width,
//                         child: Card(
//                           margin: EdgeInsets.zero,
//                           color: ColorConstants.primaryColor,
//                           shape: const RoundedRectangleBorder(
//                             borderRadius: BorderRadius.only(
//                               topLeft: Radius.circular(8.0),
//                               topRight: Radius.circular(8.0),
//                             ),
//                           ),
//                           child: SingleChildScrollView(
//                             child: Column(
//                               children: [
//                                 Padding(
//                                   padding: const EdgeInsets.all(8.0),
//                                   child: Text(
//                                     widget.hint,
//                                     style: const TextStyle(fontSize: 18.0),
//                                   ),
//                                 ),
//                                 widget.isList == true
//                                     ? ListView(
//                                         reverse: false,
//                                         shrinkWrap: true,
//                                         physics:
//                                             const NeverScrollableScrollPhysics(),
//                                         children: widget.list.map((e) {
//                                           int? index = widget.list.indexOf(e);
//                                           return Padding(
//                                             padding: const EdgeInsets.all(8.0),
//                                             child: DecoratedBox(
//                                               decoration: BoxDecoration(
//                                                 borderRadius:
//                                                     BorderRadius.circular(10.0),
//                                                 border: Border.all(
//                                                   color: widget
//                                                               .modelsSheetController
//                                                               .selectedModel ==
//                                                           index
//                                                       ? CupertinoColors
//                                                           .systemBlue
//                                                       : Colors.white60,
//                                                   width: widget
//                                                               .modelsSheetController
//                                                               .selectedModel ==
//                                                           index
//                                                       ? 2
//                                                       : 1,
//                                                 ),
//                                               ),
//                                               child: ListTile(
//                                                 dense: true,
//                                                 splashColor: Colors.transparent,
//                                                 selected: widget
//                                                         .modelsSheetController
//                                                         .selectedModel ==
//                                                     index,
//                                                 // title: Text(widget.list[index][
//                                                 //         widget.primaryKey ??
//                                                 //             "name"] ??
//                                                 //     "",
//                                                 title: Text(
//                                                   widget.list[index].name ?? "",
//                                                 ),
//                                                 onTap: () => [
//                                                   updateState(() => widget
//                                                       .modelsSheetController
//                                                       .selectedModel = index),
//                                                   setState(() => [
//                                                         widget.modelsSheetController
//                                                                 .selectedModel =
//                                                             index,
//                                                         // widget
//                                                         //     .modelsSheetController
//                                                         //     .modelID = widget
//                                                         //         .list[index][
//                                                         //     widget.primaryKey ??
//                                                         //         "model_id"],
//                                                         // widget.modelsSheetController
//                                                         //         .modelID =
//                                                         //     widget.list[index]
//                                                         //         .modelId,
//                                                         // widget.modelsSheetController
//                                                         //         .modelName =
//                                                         //     widget.list[index]
//                                                         //         .name,
//                                                         // widget.modelsSheetController
//                                                         //         .modelType =
//                                                         //     widget.list[index]
//                                                         //         .modelType
//                                                         widget.modelsSheetController
//                                                                 .selectedImageModel =
//                                                             widget.list[index]
//                                                       ]),
//                                                   if (widget.runThisFunction !=
//                                                       null)
//                                                     {widget.runThisFunction!()},
//                                                   Navigator.of(context).pop(),
//                                                 ],
//                                                 leading: SizedBox(
//                                                   height: 40,
//                                                   width: 40,
//                                                   child: CachedNetworkImage(
//                                                       imageUrl: widget
//                                                               .list[index]
//                                                               .image ??
//                                                           "$defaultS3/App+Cards/ImageModelList/${widget.list[index].modelId}.jpg",
//                                                       width: double.maxFinite,
//                                                       height: double.maxFinite,
//                                                       fit: BoxFit.cover,
//                                                       progressIndicatorBuilder:
//                                                           (BuildContext context,
//                                                               String url,
//                                                               DownloadProgress
//                                                                   progress) {
//                                                         return const Center(
//                                                           child:
//                                                               CupertinoActivityIndicator(),
//                                                         );
//                                                       },
//                                                       errorListener: (obj) {},
//                                                       errorWidget: (ctx, url,
//                                                               error) =>
//                                                           Image.asset(
//                                                             "assets/images/logo.png",
//                                                             fit: BoxFit.cover,
//                                                           )
//                                                       // width: MediaQuery.of(context).size.width,
//                                                       // fit: BoxFit.fill,
//                                                       ),
//                                                 ),
//                                               ),
//                                             ),
//                                           );
//                                         }).toList(),
//                                       )
//                                     : GridView.extent(
//                                         reverse: false,
//                                         shrinkWrap: true,
//                                         physics:
//                                             const NeverScrollableScrollPhysics(),
//                                         maxCrossAxisExtent: 150,
//                                         children: widget.list.map((e) {
//                                           int? index = widget.list.indexOf(e);
//
//                                           return DropDownCard(
//                                             showRibbon:
//                                                 widget.list[index].showRibbon ??
//                                                     false,
//                                             selected: widget
//                                                     .modelsSheetController
//                                                     .selectedModel ==
//                                                 index,
//                                             onTap: () => [
//                                               updateState(() => widget
//                                                   .modelsSheetController
//                                                   .selectedModel = index),
//                                               setState(() => [
//                                                     widget.modelsSheetController
//                                                         .selectedModel = index,
//                                                     // widget.modelsSheetController
//                                                     //         .modelID =
//                                                     //     widget.list[index]
//                                                     //         .modelId,
//                                                     // widget.modelsSheetController
//                                                     //         .modelName =
//                                                     //     widget.list[index].name,
//                                                     // widget.modelsSheetController
//                                                     //         .modelType =
//                                                     //     widget.list[index]
//                                                     //         .modelType
//                                                     widget.modelsSheetController
//                                                             .selectedImageModel =
//                                                         widget.list[index]
//                                                   ]),
//                                               // safePrint(widget
//                                               //     .modelsSheetController.selectedModel),
//                                               // safePrint(index),
//                                               // safePrint(widget.modelsSheetController
//                                               //         .selectedModel ==
//                                               //     index),
//                                               if (widget.runThisFunction !=
//                                                   null)
//                                                 {widget.runThisFunction!()},
//
//                                               Navigator.of(context).pop(),
//                                             ],
//                                             imageUrl: widget
//                                                     .list[index].image ??
//                                                 "$defaultS3/App+Cards/ImageModelList/${widget.list[index].modelId}.jpg",
//                                             title:
//                                                 widget.list[index].name ?? "",
//                                           );
//                                         }).toList(),
//                                       ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       );
//                     });
//                   },
//                 ).whenComplete(() => setState(() => opened = false));
//               },
//               child: DecoratedBox(
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(16.0),
//                   border: Border.all(
//                     color: const Color.fromRGBO(57, 190, 247, 1),
//                   ),
//                   boxShadow: const [
//                     BoxShadow(
//                       color: Color.fromRGBO(37, 133, 230, 1),
//                       blurRadius: 3,
//                     ),
//                     BoxShadow(
//                       color: Color.fromRGBO(37, 81, 205, 0.5),
//                       blurRadius: 4,
//                     ),
//                   ],
//                   gradient: const LinearGradient(
//                     begin: Alignment.bottomCenter,
//                     end: Alignment.topCenter,
//                     colors: [
//                       // Color.fromRGBO(37, 133, 230, 1),
//                       Color.fromRGBO(37, 81, 205, 0.3),
//                       Color.fromRGBO(30, 49, 136, 0.3),
//                     ],
//                   ),
//                 ),
//                 child: Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 15.0),
//                   child: ListTile(
//                     dense: false,
//                     title: Text(widget
//                             .list[widget.modelsSheetController.selectedModel]
//                             .name ??
//                         ""),
//                     trailing: Icon(!opened
//                         ? CupertinoIcons.chevron_down
//                         : CupertinoIcons.chevron_up),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// class ModelsSheetController {
//   late int selectedModel;
//   ImageModel? selectedImageModel;
//
//   // List<ImageModel> listImageModel = [];
//   initialize({
//     required int selectedModel_,
//     required ImageModel selectedImageModel_,
//     // required List<ImageModel> listImageModel_,
//   }) {
//     selectedModel = selectedModel_;
//     // listImageModel = listImageModel_;
//     selectedImageModel = selectedImageModel_;
//   }
//
//   void dispose() {
//     selectedModel = 0;
//     selectedImageModel = null;
//   }
// }

// Widget dropDownBottomSheet({
//   required BuildContext context,
//   required int index,
//   required List<dynamic> list,
//   required ValueChanged onChanged,
//   required String hint,
// }) {
//   // String key = list[index].tag;
//   return Padding(
//     padding: const EdgeInsets.all(8.0),
//     child: DecoratedBox(
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(30.0),
//         // border: Border.all(
//         //   color: const Color.fromRGBO(57, 190, 247, 1),
//         // ),
//
//         // boxShadow: const [
//         //   BoxShadow(
//         //     color: Color.fromRGBO(37, 133, 230, 1),
//         //     blurRadius: 3,
//         //   ),
//         //   BoxShadow(
//         //     color: Color.fromRGBO(37, 81, 205, 1),
//         //     blurRadius: 4,
//         //   ),
//         // ],
//         border: const GradientBoxBorder(
//           gradient: LinearGradient(
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//             colors: [
//               Color.fromRGBO(37, 81, 205, 0.3),
//               Color.fromRGBO(57, 190, 247, 1),
//             ],
//           ),
//         ),
//         gradient: LinearGradient(
//           begin: Alignment.topCenter,
//           end: Alignment.bottomCenter,
//           colors: [
//             // Color.fromRGBO(37, 133, 230, 1),
//             Colors.transparent,
//             // Colors.transparent,
//             ColorConstants.primaryColor,
//             const Color.fromRGBO(37, 81, 205, 0.3),
//             const Color.fromRGBO(30, 49, 136, 0.5),
//           ],
//         ),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.only(left: 30, right: 30),
//         child: Column(
//           children: [
//             Text(hint),
//             GestureDetector(
//               onTap: () {
//                 showModalBottomSheet(
//                   context: context,
//                   builder: (context) {
//                     return SizedBox(
//                       width: MediaQuery.of(context).size.width,
//                       child: Card(
//                         clipBehavior: Clip.none,
//                         child: Flex(
//                           direction: Axis.vertical,
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             Text(
//                               hint,
//                               style: Theme.of(context).textTheme.headlineSmall,
//                             ),
//                             // Builder(builder: (context) {
//                             //   // var set = liste;
//                             //   var set = {};
//                             //   var r = list.toSet().toList();
//                             //   return Text("${r.toString()}");
//                             // }),
//                             Builder(
//                               builder: (context) {
//                                 Map<dynamic, List<dynamic>> gl =
//                                     list.groupBy((m) => m['is_premium']);
//                                 return ListView.separated(
//                                   itemCount: gl.keys.toList().length,
//                                   shrinkWrap: true,
//                                   itemBuilder: (context, position) {
//                                     // return Text("${gl}");
//                                     return Column(
//                                       children: [
//                                         SizedBox(
//                                           height: 100,
//                                           child: SingleChildScrollView(
//                                             scrollDirection: Axis.horizontal,
//                                             child: Row(
//                                               mainAxisSize: MainAxisSize.min,
//                                               mainAxisAlignment:
//                                                   MainAxisAlignment.start,
//                                               children: gl.values
//                                                       .toList()[position]
//                                                       .map((e) {
//                                                     // return Text(
//                                                     //     "${gl.values.toList()[position]}");
//                                                     int indexxx = gl.values
//                                                         .toList()[position]
//                                                         .indexOf(e);
//                                                     Map<String, dynamic> map =
//                                                         gl.values.toList()[
//                                                             position][indexxx];
//                                                     // var rt = gl.keys.toList()[pos]
//                                                     //     [indexxx][indexxx];
//                                                     return FittedBox(
//                                                       child: StyleCard(
//                                                         onTap: () {},
//                                                         selected:
//                                                             indexxx == position,
//                                                         imageUrl: map["image"],
//                                                         title: map["name"],
//                                                       ),
//                                                     );
//                                                   }).toList() ??
//                                                   [],
//                                             ),
//                                           ),
//                                         ),
//                                       ],
//                                     );
//                                   },
//                                   separatorBuilder: (context, pos) {
//                                     return const Divider();
//                                   },
//                                 );
//                                 // return Text("${rt.length}");
//                               },
//                             ),
//                           ],
//                         ),
//                       ),
//                     );
//                   },
//                 );
//               },
//               child: Text(
//                 list[index]["name"],
//                 style: Theme.of(context).textTheme.headlineMedium,
//               ),
//             ),
//           ],
//         ),
//       ),
//     ),
//   );
// }

class DropDownCard extends StatelessWidget {
  final GestureTapCallback onTap;
  final bool selected;
  final bool showRibbon;
  final String imageUrl;
  final String title;

  const DropDownCard({
    super.key,
    required this.onTap,
    required this.selected,
    required this.showRibbon,
    required this.imageUrl,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(3.0),
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 105.0,
          height: 130.0,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.0),
                    border: Border.all(
                      color: selected == true ? Colors.blue : Colors.grey,
                      width: selected == true ? 1 : 0.75,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Flex(
                      direction: Axis.vertical,
                      // mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          flex: 4,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(7.0),
                            child: imageUrl.isEmpty
                                ? Image.asset(
                                    "assets/card/signin.jpg",
                                    width: MediaQuery.of(context).size.width,
                                    fit: BoxFit.cover,
                                  )
                                : CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    width: double.maxFinite,
                                    height: double.maxFinite,
                                    fit: BoxFit.cover,
                                    progressIndicatorBuilder:
                                        (BuildContext context, String url,
                                            DownloadProgress progress) {
                                      return const Center(
                                        child: CupertinoActivityIndicator(),
                                      );
                                    },
                                    errorListener: (obj) {},
                                    errorWidget: (ctx, url, error) =>
                                        Image.asset(
                                          "assets/images/logo.png",
                                          fit: BoxFit.cover,
                                        )),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              showRibbon
                  ? Positioned(
                      top: -8,
                      right: -9,
                      child: Icon(
                        Icons.bookmark,
                        size: 45.0,
                        color: showRibbon == true
                            ? Colors.amber
                            : Colors.blueAccent,
                      ),
                    )
                  : const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}

extension Iterables<E> on Iterable<E> {
  Map<K, List<E>> groupBy<K>(K Function(E) keyFunction) => fold(
      <K, List<E>>{},
      (Map<K, List<E>> map, E element) =>
          map..putIfAbsent(keyFunction(element), () => <E>[]).add(element));
}
