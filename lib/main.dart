import 'dart:ui';

import 'package:ai_video_creator_editor/constants/urls.dart';
import 'package:ai_video_creator_editor/controllers/preferences_singleton.dart';
import 'package:ai_video_creator_editor/database/object_box_singleton.dart';
import 'package:ai_video_creator_editor/routes/route_generator.dart';
import 'package:ai_video_creator_editor/routes/route_names.dart';
import 'package:ai_video_creator_editor/screens/project/new_editor/video_editor_provider.dart';
import 'package:ai_video_creator_editor/screens/tools/caption/captions_controller.dart';
import 'package:ai_video_creator_editor/screens/tools/vid_gpt/vid_gpt_notifier.dart';
import 'package:ai_video_creator_editor/utils/picker_with_history.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'constants/colors.dart';
import 'controllers/assets_controller.dart';
import 'controllers/azure_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ObjectBoxSingleTon.init();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));
  await PreferenceUtils.init();
  await EasyLocalization.ensureInitialized();
  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('zh', 'CN'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('en', 'US'),
      child: const MyApp(),
    ),
  );
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeData light = ThemeData(
      colorScheme: ColorScheme.fromSeed(
          seedColor: ColorConstants.primaryColor, brightness: Brightness.light),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      sliderTheme: const SliderThemeData(trackHeight: 2.0),
      useMaterial3: true,
    );
    ThemeData dark = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: ColorConstants.primaryColor,
        brightness: Brightness.dark,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      scaffoldBackgroundColor: ColorConstants.primaryColor,
      sliderTheme: const SliderThemeData(trackHeight: 2.0),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: ColorConstants.primaryColor,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20.0,
        ),
      ),
      useMaterial3: true,
    );
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AssetController()),
        ChangeNotifierProvider(create: (context) => MultiImagePickerProvider()),
        ChangeNotifierProvider(create: (context) => VideoEditorProvider()),
        ChangeNotifierProvider(create: (context) => CaptionsController()),
        ChangeNotifierProvider(create: (context) => SetupLanguageController()),
        ChangeNotifierProvider(create: (context) => AzureProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        title: appName,
        builder: (context, child) => LoaderOverlay(child: child!),
        debugShowCheckedModeBanner: false,
        theme: light,
        darkTheme: dark,
        themeMode: ThemeMode.dark,
        onGenerateRoute: RouteGenerator.generateRoute,
        initialRoute: RouteNames.splash,
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.stylus,
            PointerDeviceKind.invertedStylus,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.unknown,
          },
        ),
      ),
    );
  }
}
