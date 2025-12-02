import 'package:flutter/material.dart';

import '../generated/assets.dart';
import 'landing.dart';

class Splash extends StatefulWidget {
  const Splash({super.key});

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  bool showWelcomeScreen = true;

  init() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const Landing(),
        ),
        (route) => false);
  }

  loadAllFeatures() async {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    // loadAllFeatures();
    init();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      Assets.imagesBg,
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      fit: BoxFit.cover,
    );
  }
}
