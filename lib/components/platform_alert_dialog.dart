import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PlatformAlertDialog extends StatelessWidget {
  final String title;
  final String content;
  final List<String>? actionTitle;
  final List<VoidCallback>? actionPressed;

  const PlatformAlertDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actionTitle,
    required this.actionPressed,
  }) : assert(actionTitle?.length == actionPressed?.length);

  @override
  Widget build(BuildContext context) {
    return Platform.isAndroid
        ? AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(child: Text(content)),
            actions: actionTitle?.map((e) {
              int index = actionTitle?.indexOf(e) ?? 0;
              return CupertinoButton(
                onPressed: actionPressed?[index],
                child: Text(e),
              );
            }).toList(),
          )
        : CupertinoAlertDialog(
            title: Text(title),
            content: SingleChildScrollView(child: Text(content)),
            actions: actionTitle!.map((e) {
              int index = actionTitle?.indexOf(e) ?? 0;
              return CupertinoDialogAction(
                onPressed: actionPressed?[index],
                child: Text(e),
              );
            }).toList(),
          );
  }
}

class AdvancedPlatformAlertDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<String>? actionTitle;
  final List<VoidCallback>? actionPressed;

  const AdvancedPlatformAlertDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actionTitle,
    required this.actionPressed,
  }) : assert(actionTitle?.length == actionPressed?.length);

  @override
  Widget build(BuildContext context) {
    return Platform.isAndroid
        ? AlertDialog(
            scrollable: true,
            title: Text(title),
            content: content,
            actions: actionTitle?.map((e) {
              int index = actionTitle?.indexOf(e) ?? 0;
              return CupertinoButton(
                onPressed: actionPressed?[index],
                child: Text(e),
              );
            }).toList(),
          )
        : AlertDialog(
            scrollable: true,
            // scrollController: ScrollController(),
            title: Text(title),
            content: content,
            actions: actionTitle!.map((e) {
              int index = actionTitle?.indexOf(e) ?? 0;
              return CupertinoButton(
                onPressed: actionPressed?[index],
                child: Text(e),
              );
            }).toList(),
          );
  }
}
