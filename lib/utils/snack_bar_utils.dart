import 'package:flutter/material.dart';

showSnackBar(BuildContext context, String content) {
  ScaffoldMessenger.of(context).removeCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(content),
      duration: Duration(seconds: 5),
      showCloseIcon: true,
    ),
  );
}
