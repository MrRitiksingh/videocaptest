import 'package:flutter/material.dart';

class ColorConstants {
  static Color primaryColor = const Color.fromRGBO(26, 28, 43, 1);
  static Color loadingWavesColor = const Color.fromRGBO(76, 171, 224, 1);
  static Color overLayColor = Colors.white24;
  static Color toastInfo = Colors.lightBlue;
  static Color toastSuccess = const Color(0XFF50C878);
  static Color toastError = const Color(0XFFDC143C);
  static Color toastWarning = const Color(0XFFFF9800);
  static List<BoxShadow> darkBoxShadow = [
    BoxShadow(color: Color(0xff00C6D7), blurRadius: 10.0),
    BoxShadow(color: Color(0xff4A90E2), blurRadius: 10.0),
  ];

  static LinearGradient textFieldGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Colors.purple.withOpacity(0.1),
      Colors.purple.withOpacity(0.1),
      Colors.black45,
    ],
  );

  static LinearGradient uploadButtonBorderGradient = const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color.fromRGBO(238, 198, 253, 1),
      Color.fromRGBO(147, 174, 224, 1),
      Color.fromRGBO(75, 135, 181, 1),
      //
      Color.fromRGBO(75, 135, 181, 1),
      Color.fromRGBO(147, 174, 224, 1),
      Color.fromRGBO(238, 198, 253, 1),
    ],
  );
  static LinearGradient darkLinearGradient = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xff4A90E2),
      Color(0xff00C6D7),
    ],
  );
  static LinearGradient darkCardGradient = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.fromRGBO(29, 17, 48, 1),
      Color.fromRGBO(29, 17, 51, 1),
      Color.fromRGBO(23, 31, 61, 1),
      Color.fromRGBO(33, 52, 105, 1),
      Color.fromRGBO(18, 31, 56, 1),
      Color.fromRGBO(17, 32, 57, 1),
      Color.fromRGBO(16, 32, 56, 1),
    ],
  );
}

BorderRadius kBorderRadius = BorderRadius.circular(10.0);
