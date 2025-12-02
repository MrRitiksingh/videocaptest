import 'package:flutter/cupertino.dart';

extension Pad on BuildContext {
  unFocusKeyboard() => FocusScope.of(this).requestFocus(FocusNode());
  EdgeInsets largeScreenPadding() {
    return EdgeInsets.symmetric(
      horizontal: MediaQuery.of(this).size.width <= 1000
          ? 10
          : (MediaQuery.of(this).size.width ~/ 3.5).toDouble(),
    );
  }

  bool mobile() {
    return MediaQuery.of(this).size.width < 640;
  }

  SizedBox shrink() => const SizedBox.shrink();
}

extension Sz on num {
  Widget sz() => SizedBox(height: toDouble());
}

extension Md on String {
  String remo7veMarkdownSymbols() {
// Regular expression to match Markdown symbols including '#'
    RegExp regex = RegExp(r'[*_~`#]');
// Replace Markdown symbols with an empty string
    return replaceAll(regex, '');
  }

  String getLastChar() {
    if (isNotEmpty) {
      return substring(length - 1);
    }
    return ''; // Return an empty string if the input is empty
  }
}
