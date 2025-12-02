import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';

import '../utils/functions.dart';
import 'locale_keys.g.dart';

class TimerToNextRequest {
  List<TimeVerifier> list = [];

  bool shouldAllow({
    required String routeName,
    required BuildContext context,
    int? allowAfterSeconds,
  }) {
    /// todo: fix me
    // if (context.read<AuthController>().userHasMoreThan100Golden()) {
    //   return true;
    // }
    TimeVerifier? locke =
        list.where((e) => e.routeName == routeName).firstOrNull;
    if (locke == null) {
      return true;
    } else {
      DateTime now = DateTime.now();
      if (now.difference(locke.lastRequest).inSeconds <=
          (allowAfterSeconds ?? 60)) {
        showToast(
          context: context,
          title: "",
          description: LocaleKeys.aiIsBusy.tr(),
          toastType: ToastType.info,
        );
        return false;
      } else {
        removeKey(routeName);
        return true;
      }
    }
  }

  removeKey(String routeName) {
    TimeVerifier? locke =
        list.where((e) => e.routeName == routeName).firstOrNull;
    if (locke == null) return;
    list.remove(locke);
  }

  addKey(String routeName) {
    list.removeWhere((element) => element.routeName == routeName);
    list.add(TimeVerifier(routeName: routeName, lastRequest: DateTime.now()));
  }
}

class TimeVerifier {
  String routeName;
  DateTime lastRequest;

  TimeVerifier({
    required this.routeName,
    required this.lastRequest,
  });
}
