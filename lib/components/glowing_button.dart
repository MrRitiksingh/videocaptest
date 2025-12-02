import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants/colors.dart';

class GlowingGenerateButton extends StatelessWidget {
  final GestureTapCallback? onTap;
  final Future<bool>? verifyFunction;
  final String? string;
  final IconData? icon;
  final bool? isProcessing;

  const GlowingGenerateButton({
    super.key,
    required this.onTap,
    required this.string,
    this.icon,
    this.verifyFunction,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: (Platform.isMacOS || kIsWeb) &&
              MediaQuery.of(context).size.width >= 1000
          ? EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width / 4, vertical: 4.0)
          : const EdgeInsets.only(top: 10.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 20.0),
        child: InkWell(
          onTap: isProcessing == false ? onTap : () {},
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              boxShadow: ColorConstants.darkBoxShadow,
              gradient: ColorConstants.darkLinearGradient,
              borderRadius: kBorderRadius,
            ),
            child: Builder(
              builder: (context) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      string ?? "",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22.0,
                      ),
                    ),
                    const SizedBox(width: 20.0),
                    isProcessing == true
                        ? const CupertinoActivityIndicator()
                        : const SizedBox.shrink(),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
