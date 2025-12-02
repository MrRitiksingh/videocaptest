import 'package:flutter/material.dart';

import '../constants/colors.dart';
import 'gradient_border.dart';

class UploadButton extends StatelessWidget {
  final GestureTapCallback onTap;
  final String title;
  final bool? first;
  final Widget? trailing;
  final Widget? leading;
  final Widget? subTitle;

  const UploadButton({
    super.key,
    required this.onTap,
    required this.title,
    this.first,
    this.trailing,
    this.leading,
    this.subTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: GestureDetector(
        onTap: onTap,
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
                  title,
                  style: const TextStyle(
                    color: /*overridePath == null
                        ? const Color.fromRGBO(11, 112, 254, 1)
                        :*/
                        Color.fromRGBO(220, 220, 220, 1),
                    fontSize: 19.0,
                  ),
                ),
                leading: leading,
                // leading: overridePath == null
                //     ? Image.asset(
                //         first ?? false
                //             ? "assets/icons/purplebutton.png"
                //             : "assets/icons/bluebutton.png",
                //         height: 50,
                //         width: 50,
                //       )
                //     : Image.asset(
                //         overridePath!,
                //         height: 50,
                //         width: 50,
                //       ),
                trailing: trailing,
                subtitle: subTitle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
