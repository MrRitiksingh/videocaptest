import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

Future<File> pickProjectAudio({
  required BuildContext context,
}) async {
  var output = await CupertinoScaffold.showCupertinoModalBottomSheet(
    context: context,
    builder: (context) {
      return StatefulBuilder(builder: (context, setState) {
        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: Text("Pick Audio"),
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              // CupertinoSlidingSegmentedControl(
              //   children: {},
              //   onValueChanged: (newValue) {},
              // ),
            ],
          ),
        );
      });
    },
  );
  return File("");
}
