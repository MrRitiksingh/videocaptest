import 'package:ai_video_creator_editor/routes/route_names.dart';
import 'package:flutter/material.dart';

import '../screens/landing.dart';
import '../screens/project/projects.dart';
import '../screens/splash.dart';
import '../screens/tools/caption/caption.dart';
import '../screens/tools/vid_gpt/video_gpt.dart';

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final args = settings.arguments;
    final routeName = settings.name;

    switch (routeName) {
      case RouteNames.splash:
        return MaterialPageRoute(builder: (_) => const Splash());
      case RouteNames.landing:
        return MaterialPageRoute(builder: (_) => const Landing());
      case RouteNames.caption:
        return MaterialPageRoute(builder: (_) => const Caption());
      case RouteNames.projects:
        return MaterialPageRoute(builder: (_) => const Projects());
      case RouteNames.videoGpt:
        return MaterialPageRoute(builder: (_) => const VideoGpt());
      default:
        return _errorRoute();
    }
  }

  static Route<dynamic> _errorRoute() {
    return MaterialPageRoute(
      builder: (_) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Error'),
          ),
          body: const Center(
            child: Text('Route not found'),
          ),
        );
      },
    );
  }
}
