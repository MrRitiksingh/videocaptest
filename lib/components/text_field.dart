import 'package:ai_video_creator_editor/components/gradient_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/colors.dart';

class TextFieldWidget extends StatelessWidget {
  final TextEditingController? textEditingController;
  final String? hintText;
  final TextInputType? textInputType;
  final int? maxLines;
  final bool? obscureText;
  final bool? enabled;
  final Function(String? value)? onValidate;
  final Function(String? value)? valueDidChange;
  final List<TextInputFormatter>? textInputFormatter;
  final Iterable<String>? autofillHints;
  final Widget? suffix;
  final TextAlign? textAlign;
  final int? maxLength;
  final double? borderRadius;
  final bool? includeDecoration;
  final BoxDecoration? overrideDecoration;
  final EdgeInsets? padding;
  final BorderRadius? borderRadiusDecoration;
  final FocusNode? focusNode;
  final Widget? prefixIcon;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputAction? textInputAction;

  const TextFieldWidget({
    super.key,
    required this.textEditingController,
    this.hintText,
    this.textInputType,
    this.maxLines,
    this.obscureText,
    this.enabled,
    this.onValidate,
    this.valueDidChange,
    this.textInputFormatter,
    this.autofillHints,
    this.suffix,
    this.textAlign,
    this.maxLength,
    this.borderRadius,
    this.includeDecoration,
    this.overrideDecoration,
    this.padding,
    this.borderRadiusDecoration,
    this.focusNode,
    this.prefixIcon,
    this.onFieldSubmitted,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.all(8.0),
      child: DecoratedBox(
        decoration: includeDecoration == false
            ? overrideDecoration ??
                BoxDecoration(
                  // gradient: ColorConstants.darkCardGradient,
                  gradient: const LinearGradient(
                    colors: [
                      // Color.fromRGBO(23, 16, 42, 1),
                      Color.fromRGBO(39, 34, 61, 1),
                      // Color.fromRGBO(39, 34, 59, 1),
                      // Color.fromRGBO(41, 33, 59, 1),
                      Colors.transparent,
                    ],
                  ),
                  borderRadius: borderRadiusDecoration ??
                      BorderRadius.circular(borderRadius ?? 12.0),
                  border:
                      Border.all(color: const Color.fromRGBO(44, 45, 95, 1)),
                )
            : BoxDecoration(
                gradient: ColorConstants.textFieldGradient,
                borderRadius: BorderRadius.circular(borderRadius ?? 12.0),
                border: GradientBoxBorder(
                  gradient: ColorConstants.uploadButtonBorderGradient,
                ),
              ),
        child: TextFormField(
          onFieldSubmitted: onFieldSubmitted,
          textInputAction: textInputAction,
          maxLength: maxLength,
          textAlign: textAlign == null ? TextAlign.start : textAlign!,
          autofillHints: autofillHints,
          onChanged: valueDidChange,
          inputFormatters: textInputFormatter,
          validator: (val) => onValidate!(val),
          obscureText: obscureText ?? false,
          enabled: enabled ?? true,
          controller: textEditingController,
          keyboardType: textInputType,
          maxLines: maxLines ?? 5,
          decoration: InputDecoration(
              suffixIcon: suffix,
              contentPadding: const EdgeInsets.only(
                top: 8.0,
                bottom: 8.0,
                right: 8.0,
                left: 12.0,
              ),
              hintText: hintText ?? "",
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              prefixIcon: prefixIcon
              // prefixIcon: textEditingController?.text.isEmpty == true &&
              //         prefixIcon != null
              //     ? SizedBox(
              //         height: 30,
              //         width: 30,
              //         child: prefixIcon,
              //       )
              //     : context.shrink(),
              ),
        ),
      ),
    );
  }
}

class TinyTextField extends StatelessWidget {
  final TextEditingController? textEditingController;
  final String? hintText;
  final TextInputType? textInputType;
  final int? maxLines;
  final bool? obscureText;
  final bool? enabled;
  final Function(String? value)? onValidate;
  final Function(String? value)? valueDidChange;
  final List<TextInputFormatter>? textInputFormatter;
  final Iterable<String>? autofillHints;
  final Widget? suffix;
  final TextAlign? textAlign;
  final int? maxLength;
  final double? borderRadius;
  final bool? includeDecoration;
  final BoxDecoration? overrideDecoration;
  final EdgeInsets? padding;
  final BorderRadius? borderRadiusDecoration;
  final FocusNode? focusNode;
  final Widget? prefixIcon;

  const TinyTextField({
    super.key,
    required this.textEditingController,
    this.hintText,
    this.textInputType,
    this.maxLines,
    this.obscureText,
    this.enabled,
    this.onValidate,
    this.valueDidChange,
    this.textInputFormatter,
    this.autofillHints,
    this.suffix,
    this.textAlign,
    this.maxLength,
    this.borderRadius,
    this.includeDecoration,
    this.overrideDecoration,
    this.padding,
    this.borderRadiusDecoration,
    this.focusNode,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      width: 100,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(8.0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: ColorConstants.darkCardGradient,
            borderRadius: BorderRadius.circular(borderRadius ?? 12.0),
            border: Border.all(color: const Color.fromRGBO(44, 45, 95, 1)),
          ),
          child: ClipRect(
            child: TextFormField(
              // style: const TextStyle(fontSize: 16.0, height: 10.0),
              maxLength: maxLength,
              textAlign: textAlign == null ? TextAlign.start : textAlign!,
              autofillHints: autofillHints,
              onChanged: valueDidChange,
              inputFormatters: textInputFormatter,
              validator: (val) => onValidate!(val),
              obscureText: obscureText ?? false,
              enabled: enabled ?? true,
              controller: textEditingController,
              keyboardType: textInputType,
              maxLines: maxLines ?? 5,
              decoration: InputDecoration(
                counterText: "",
                suffixIcon: suffix,
                contentPadding: const EdgeInsets.only(
                  top: 8.0,
                  bottom: 8.0,
                  right: 8.0,
                  left: 12.0,
                ),
                hintText: hintText ?? "",
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: prefixIcon,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
