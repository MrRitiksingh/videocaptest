import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/locale_keys.g.dart';
import 'functions.dart';

class CommonUtils {
  static const String _emailValidatorRegExp =
      r'^[a-zA-Z0-9+_.]+@[a-zA-Z0-9]+\.[a-zA-Z]+';

  static String? isValidateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return LocaleKeys.pleaseTypeYourEmail.tr();
    }

    if (RegExp(_emailValidatorRegExp).hasMatch(email)) {
      return null;
    } else {
      return LocaleKeys.pleaseEnterValidEmail.tr();
    }
  }

  static String? isPasswordValid(String? password, [int minLength = 8]) {
    if (password == null || password.isEmpty) {
      return LocaleKeys.pleaseTypePassword.tr();
    }
    bool hasMinLength = password.length >= minLength;

    if (!hasMinLength) {
      return LocaleKeys.yourPassAtLeast8.tr();
    }
    return null;
  }

  static void showSnackBar(BuildContext context, String message) {
    showToast(
        context: context,
        title: LocaleKeys.signIn.tr(),
        description: message,
        toastType: ToastType.warning);
  }

  static void showError(BuildContext context, String message) {
    showToast(
        context: context,
        title: LocaleKeys.error.tr(),
        description: message,
        toastType: ToastType.warning);
  }
}
