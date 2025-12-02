import 'package:flutter/material.dart';

mixin Feature<T extends StatefulWidget> on State<T> {
  bool imageIsGenerating = false;
  bool isProcessing = false;

  resetImageIsGenerating() async {
    if (mounted) {
      setState(() {
        imageIsGenerating = true;
      });
    }
    await Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          imageIsGenerating = false;
          isProcessing = false;
        });
      }
    });
  }
}
